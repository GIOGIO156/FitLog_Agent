# Release APK artifacts

This directory retains locally built, ABI-specific Release APKs outside Flutter's disposable `build/` tree.

APK binaries and `SHA256SUMS.txt` are intentionally ignored by Git. Generate them with the configured Release build and copy the outputs from `build/app/outputs/flutter-apk/` into this directory.
