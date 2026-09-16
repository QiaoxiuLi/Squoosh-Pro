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

Version and build number can be supplied without editing the script:

```bash
SQUOOSH_VERSION=0.1.0 SQUOOSH_BUILD_NUMBER=1 ./scripts/build-release.sh
```
