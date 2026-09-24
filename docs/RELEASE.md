# Release

Release verification is intentionally separate from publishing.

1. Install a stable full Xcode and select it with `xcode-select`.
2. Run schema, worker, Swift unit, integration, file-protection, and UI tests.
3. Run `./scripts/build-release.sh` to build both `arm64` and `x86_64`, combine and inspect the application and helper executables, verify the ad-hoc signature, and create a ZIP plus SHA-256 file under `Artifacts/`.
4. Run the app with networking disabled and verify no external resource request occurs.
5. Review `third_party/THIRD_PARTY_NOTICES.md` and bundled license files.
6. Run `./scripts/verify-release.sh` and inspect the Git diff for user data, secrets, caches, and temporary files.
7. Sign, notarize, publish a GitHub Release, or submit to the App Store only with explicit authorization and valid user-owned credentials.

The default release build is ad-hoc signed so it can be launched and tested locally. It is not a Developer ID or App Store artifact, is not notarized, and should be published only as an explicitly labeled prerelease. The build scripts never read signing identities or change system Xcode settings.

## Windows

1. Use a clean Windows x64 build environment with .NET SDK 8.0.425 and Visual Studio 2022 Build Tools.
2. Run `.\scripts\windows\run-core-checks.ps1`.
3. Run `.\scripts\windows\build-release.ps1 -Version 0.2.0`.
4. From a signed-in interactive desktop, run `.\scripts\windows\run-ui-tests.ps1` against the published executable on Windows 10 and Windows 11.
5. Require every functional check and every application-internal visual render check to pass. A desktop screenshot alone is not sufficient because DirectComposition capture can return a blank surface.
6. Inspect the ZIP contents and ensure `SquooshPro.exe`, `SquooshPro.dll`, `SquooshPro.pri`, user documentation, the project license, and third-party license files are present.
7. Recalculate the ZIP SHA-256, compare it with the generated `.sha256` file, and scan the repository diff for credentials, user data, caches, and test artifacts.

The Windows package is self-contained and must be distributed as the complete extracted directory. Moving only `SquooshPro.exe` is unsupported. Until an Authenticode certificate is configured, publish it only as an unsigned prerelease and explain that SmartScreen can appear.

## macOS Version Overrides

Version and build number can be supplied without editing the script:

```bash
SQUOOSH_VERSION=0.1.0 SQUOOSH_BUILD_NUMBER=1 ./scripts/build-release.sh
```
