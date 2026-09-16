# Contributing

Contributions should preserve the project's non-destructive file guarantees and offline runtime. Before opening a change:

1. Run `./scripts/test-all.sh`.
2. Confirm no generated fixture, user image, build cache, credential, signing file, or output directory is staged.
3. Add tests for changes to path handling, state transitions, preset migration, or output validation.
4. Keep `shared/contracts` platform-neutral and versioned.

Bug reports should include macOS version, architecture, input format, selected preset, and the user-facing error code. Do not attach private images unless they can be shared publicly and their metadata has been removed.
