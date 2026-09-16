import Foundation
import SquooshCore
import WebKit

private final class CodecResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    let root: URL

    init(root: URL) {
        self.root = root.resolvingSymlinksInPath().standardizedFileURL
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              requestURL.scheme == "squoosh-pro",
              requestURL.host == "codec",
              let decodedPath = requestURL.path.removingPercentEncoding else {
            urlSchemeTask.didFailWithError(SquooshProError.unsafePath)
            return
        }
        let relativePath = decodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !relativePath.isEmpty, !relativePath.split(separator: "/").contains("..") else {
            urlSchemeTask.didFailWithError(SquooshProError.unsafePath)
            return
        }
        let fileURL = root.appendingPathComponent(relativePath).resolvingSymlinksInPath().standardizedFileURL
        guard fileURL.path.hasPrefix(root.path + "/"), let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
            urlSchemeTask.didFailWithError(SquooshProError.unsafePath)
            return
        }
        let mimeType: String
        switch fileURL.pathExtension.lowercased() {
        case "html": mimeType = "text/html"
        case "js": mimeType = "text/javascript"
        case "wasm": mimeType = "application/wasm"
        default: mimeType = "application/octet-stream"
        }
        let response = URLResponse(url: requestURL, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: mimeType.hasPrefix("text/") ? "utf-8" : nil)
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

public protocol CodecHostProtocol: AnyObject {
    func capabilities() async throws -> [String]
    func encodeRGBA(_ data: Data, width: Int, height: Int, format: CodecFormat, options: [String: Double], requestID: UUID) async throws -> Data
    func cancel(requestID: UUID) async
    func shutdown() async
}

@MainActor
public final class SquooshWasmCodecHost: NSObject, CodecHostProtocol, WKNavigationDelegate {
    private var webView: WKWebView!
    private var loaded = false
    private var loadError: Error?
    private var loadWaiters: [CheckedContinuation<Void, Error>] = []
    private var activeRequestID: UUID?
    private var resourceHandler: CodecResourceSchemeHandler?
    private let chunkSize = 262_144

    public override init() {
        super.init()
        installWebView()
    }

    public func capabilities() async throws -> [String] {
        try await waitUntilReady()
        let value = try await call("return window.SquooshPro.capabilities();")
        guard let dictionary = value as? [String: Any] else {
            throw SquooshProError.unknown("编码器能力响应类型无效：\(String(describing: type(of: value)))")
        }
        if let codecs = dictionary["codecs"] as? [String] { return codecs }
        if let codecs = dictionary["codecs"] as? [Any] {
            let names = codecs.compactMap { $0 as? String }
            if !names.isEmpty { return names }
        }
        throw SquooshProError.unknown("编码器能力响应缺少 codecs")
    }

    public func networkIsolationProbe() async throws -> Bool {
        try await waitUntilReady()
        let value = try await call("return await window.SquooshPro.networkIsolationProbe();")
        return value as? Bool == true
    }

    public func encodeRGBA(_ data: Data, width: Int, height: Int, format: CodecFormat, options: [String: Double], requestID: UUID) async throws -> Data {
        try await waitUntilReady()
        try Task.checkCancellation()
        guard data.count == width * height * 4 else { throw SquooshProError.decodeFailed }
        let identifier = requestID.uuidString
        activeRequestID = requestID
        defer {
            if activeRequestID == requestID { activeRequestID = nil }
        }

        do {
            _ = try await call(
                "return window.SquooshPro.begin(requestID, width, height, codec, options, totalBytes);",
                arguments: ["requestID": identifier, "width": width, "height": height, "codec": format.rawValue, "options": options, "totalBytes": data.count]
            )
            var offset = 0
            while offset < data.count {
                try Task.checkCancellation()
                let end = min(offset + chunkSize, data.count)
                let encoded = data.subdata(in: offset..<end).base64EncodedString()
                _ = try await call("return window.SquooshPro.append(requestID, chunk);", arguments: ["requestID": identifier, "chunk": encoded])
                offset = end
            }
            let response = try await call("return await window.SquooshPro.encode(requestID);", arguments: ["requestID": identifier])
            guard let dictionary = response as? [String: Any], dictionary["ok"] as? Bool == true,
                  let chunkCount = dictionary["chunks"] as? Int else { throw SquooshProError.encodeFailed }
            var output = Data()
            for index in 0..<chunkCount {
                try Task.checkCancellation()
                let value = try await call("return window.SquooshPro.outputChunk(requestID, index);", arguments: ["requestID": identifier, "index": index])
                guard let base64 = value as? String, let bytes = Data(base64Encoded: base64) else {
                    throw SquooshProError.workerCrashed
                }
                output.append(bytes)
            }
            _ = try? await call("return window.SquooshPro.finish(requestID);", arguments: ["requestID": identifier])
            return output
        } catch is CancellationError {
            await cancel(requestID: requestID)
            throw SquooshProError.cancelled
        } catch let error as SquooshProError where error == .cancelled {
            throw error
        } catch {
            _ = try? await call("return window.SquooshPro.finish(requestID);", arguments: ["requestID": identifier])
            throw error
        }
    }

    public func cancel(requestID: UUID) async {
        guard activeRequestID == requestID else {
            _ = try? await call("return window.SquooshPro.cancel(requestID);", arguments: ["requestID": requestID.uuidString])
            return
        }
        activeRequestID = nil
        rebuild(failingWith: SquooshProError.cancelled)
    }

    public func shutdown() async {
        failOutstanding(with: SquooshProError.cancelled)
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        loaded = false
    }

    private func installWebView() {
        guard let resource = Bundle.module.url(forResource: "codec-host", withExtension: "html", subdirectory: "CodecWorker") else {
            failLoading(SquooshProError.workerCrashed)
            return
        }
        let handler = CodecResourceSchemeHandler(root: resource.deletingLastPathComponent())
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.setURLSchemeHandler(handler, forURLScheme: "squoosh-pro")
        let replacement = WKWebView(frame: .zero, configuration: configuration)
        replacement.navigationDelegate = self
        resourceHandler = handler
        webView = replacement
        loaded = false
        loadError = nil
        replacement.load(URLRequest(url: URL(string: "squoosh-pro://codec/codec-host.html")!))
    }

    private func rebuild(failingWith error: Error) {
        failOutstanding(with: error)
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        installWebView()
    }

    private func failOutstanding(with error: Error) {
        let waiters = loadWaiters
        loadWaiters.removeAll()
        waiters.forEach { $0.resume(throwing: error) }
    }

    private func waitUntilReady() async throws {
        if loaded {
            for _ in 0..<40 {
                try Task.checkCancellation()
                if (try? await call("return Boolean(window.SquooshPro);")) as? Bool == true { return }
                try await Task.sleep(nanoseconds: 25_000_000)
            }
            let detail = try? await call("return { readyState: document.readyState, hostType: typeof window.SquooshPro, scripts: Array.from(document.scripts).map(value => value.src) };")
            throw SquooshProError.unknown("本地编码器页面未初始化：\(String(describing: detail))")
        }
        if let loadError { throw loadError }
        try await withCheckedThrowingContinuation { continuation in
            loadWaiters.append(continuation)
        }
        try await waitUntilReady()
    }

    private func call(_ body: String, arguments: [String: Any] = [:]) async throws -> Any {
        try Task.checkCancellation()
        guard let webView else { throw SquooshProError.workerCrashed }
        let result: Any?
        do {
            result = try await withTaskCancellationHandler {
                try await webView.callAsyncJavaScript(body, arguments: arguments, in: nil, contentWorld: .page)
            } onCancel: {
                Task { @MainActor [weak self] in
                    guard let self, webView === self.webView else { return }
                    self.rebuild(failingWith: SquooshProError.cancelled)
                }
            }
        } catch {
            if Task.isCancelled { throw SquooshProError.cancelled }
            let cocoaError = error as NSError
            if cocoaError.domain == WKError.errorDomain,
               cocoaError.code == WKError.Code.webContentProcessTerminated.rawValue {
                throw SquooshProError.workerCrashed
            }
            throw error
        }
        guard let result else { throw SquooshProError.workerCrashed }
        return result
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        loaded = true
        let waiters = loadWaiters
        loadWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard webView === self.webView else { return }
        failLoading(error)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard webView === self.webView else { return }
        failLoading(error)
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === self.webView else { return }
        activeRequestID = nil
        rebuild(failingWith: SquooshProError.workerCrashed)
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard webView === self.webView, let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(url.scheme == "squoosh-pro" && url.host == "codec" ? .allow : .cancel)
    }

    private func failLoading(_ error: Error) {
        loadError = error
        loaded = false
        let waiters = loadWaiters
        loadWaiters.removeAll()
        waiters.forEach { $0.resume(throwing: error) }
    }
}
