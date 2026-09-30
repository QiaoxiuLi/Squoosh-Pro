# Release

Release verification is intentionally separate from publishing.

1. Install a stable full Xcode and select it with `xcode-select`.
2. Run schema, worker, Swift unit, integration, file-protection, and UI tests.
3. Run `./scripts/build-release.sh` to build both `arm64` and `x86_64`, combine and inspect the application and helper executables, verify the ad-hoc signature, and create a ZIP plus SHA-256 file under `Artifacts/`.
4. Run the app with networking disabled and verify no external resource request occurs.
5. Review `third_party/THIRD_PARTY_NOTICES.md` and bundled license files.
6. Run `./scripts/verify-release.sh` and inspect the Git diff for user data, secrets, caches, and temporary files.
7. Sign, notarize, publish a GitHub Release, or submit to the App Store only with explicit authorization and valid user-owned credentials.

The default release build is ad-hoc signed. It is not a Developer ID or App Store artifact and is not notarized. Any authorized public release must clearly disclose these limitations; publishing does not establish distribution signing or complete platform certification. The build scripts never read signing identities or change system Xcode settings.

## Windows

1. Use a Windows x64 build environment with .NET SDK 10.0.401. An isolated SDK directory is supported through `-DotNetPath`; Visual Studio MSBuild is not required.
2. Run `.\scripts\windows\run-core-checks.ps1 -DotNetPath <path-to-dotnet.exe>`.
3. Run `.\scripts\windows\build-release.ps1 -Version 0.3.1 -DotNetPath <path-to-dotnet.exe>`.
4. From a signed-in interactive desktop, run `.\scripts\windows\run-ui-tests.ps1` against the published executable on Windows 10 and Windows 11.
5. Require every functional check and every application-internal visual render check to pass, including decoded previews, native mouse dragging, real pixel zoom, preset persistence, and compact/wide resizing. A desktop screenshot alone is not sufficient because DirectComposition capture can return a blank surface. SSH-only acceptance can invoke `run-interactive-ui-validation.ps1` with the published runner and application; its temporary scheduled task is removed afterward.
6. Inspect the ZIP contents and ensure `SquooshPro.exe`, `SquooshPro.dll`, `SquooshPro.pri`, `Assets/SquooshPro.ico`, `Assets/SquooshPro.png`, user documentation, the project license, and third-party license files are present. Require the native executable, shortcut, small/large window and title-bar icon checks to pass.
7. Recalculate the ZIP SHA-256, compare it with the generated `.sha256` file, and scan the repository diff for credentials, user data, caches, and test artifacts.

The Windows package is self-contained and must be distributed as the complete extracted directory. Moving only `SquooshPro.exe` is unsupported. Until an Authenticode certificate is configured, clearly label the download as unsigned and explain that SmartScreen can appear. Do not describe a GitHub Release as equivalent to Microsoft Store validation or commercial signing.

## macOS Version Overrides

Version and build number can be supplied without editing the script:

```bash
SQUOOSH_VERSION=0.3.1 SQUOOSH_BUILD_NUMBER=1 ./scripts/build-release.sh
```

`SQUOOSH_ARTIFACT_DIR` can point to a fresh directory inside project `Artifacts/` to retain earlier app bundles while building a new version.

## Icon Resources

Rebuild icons with `bash scripts/build-icons.sh` after changing the shared PNG master. Check resources and the actual macOS system/runtime icon with `swift scripts/check-app-icon.swift <project-root> <app-bundle> [pid]`. This check normalizes system icon padding and rejects an unrelated application's icon as a negative control. Do not clear global icon caches, restart Finder/Dock or overwrite user-created shortcuts during validation.
