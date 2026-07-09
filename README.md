# Rust Book Reader

A simple dark reader app for the Rust Book with an integrated Gemini tutor.

Author: Amit (amitxd)

### Features
- Native study dashboard with reading progress & time tracker
- 120Hz display refresh support
- Highlight text selection to explain with Gemini
- Offline mode & cache synchronization
- Encrypted API key storage

### Libraries
- webview_flutter
- google_generative_ai
- flutter_secure_storage
- shared_preferences
- flutter_markdown_plus / flutter_highlight

### Commands
- Run: `flutter run`
- Build (Optimized arm64): `flutter build apk --release --target-platform=android-arm64 --obfuscate --split-debug-info=build/app/outputs/symbols --no-keep-dwarf`
