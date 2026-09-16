import Foundation

public struct JobStateMachine: Sendable {
    public private(set) var state: JobState
    public init(state: JobState = .draft) { self.state = state }

    public mutating func transition(to newState: JobState) throws {
        let allowed: [JobState: Set<JobState>] = [
            .draft: [.ready, .failed],
            .ready: [.running, .cancelled, .failed],
            .running: [.pausing, .cancelling, .completed, .completedWithErrors, .failed],
            .pausing: [.paused, .cancelling, .failed],
            .paused: [.running, .cancelling, .failed],
            .cancelling: [.cancelled, .failed],
            .cancelled: [], .completed: [], .completedWithErrors: [], .failed: [],
        ]
        guard allowed[state, default: []].contains(newState) else { throw SquooshProError.unknown("非法任务状态转换 \(state.rawValue) -> \(newState.rawValue)") }
        state = newState
    }
}

public struct FileStateMachine: Sendable {
    public private(set) var state: FileState
    public init(state: FileState = .queued) { self.state = state }

    public mutating func transition(to newState: FileState) throws {
        if newState == .failed || newState == .cancelled {
            guard state != .completed else { throw SquooshProError.unknown("已完成文件不能改为失败或取消") }
            state = newState
            return
        }
        let sequence: [FileState] = [.queued, .reading, .decoding, .transforming, .encoding, .verifying, .committing, .completed]
        guard let current = sequence.firstIndex(of: state), current + 1 < sequence.count, sequence[current + 1] == newState else { throw SquooshProError.unknown("非法文件状态转换 \(state.rawValue) -> \(newState.rawValue)") }
        state = newState
    }
}
