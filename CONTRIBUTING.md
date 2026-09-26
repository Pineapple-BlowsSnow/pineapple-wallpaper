# Contributing

PineappleWallpaper is a small native macOS project. Contributions that keep it offline and dependency-light are welcome.

1. Open an issue describing the user problem and expected behavior.
2. Build with `./scripts/build-app.sh` and run `./scripts/check.sh`.
3. For UI changes, test the empty library, import, switch, pause, remove, and relaunch flows on a Mac. Include before/after screenshots with your own redistributable footage or placeholder content.
4. Keep media files and local application data out of commits. Add tests for changes to persistence, import, deduplication, or deletion behavior.
5. Submit a focused pull request with what changed, how it was validated, and known limitations.

Formatting follows the existing Swift source. Keep UI strings readable and explain user-visible changes in the pull request. Do not add analytics or network access without an explicit feature proposal and privacy review.
