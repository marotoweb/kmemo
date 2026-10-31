# Changelog

## 0.1.8

### 📦 F-Droid
- **F-Droid metadata:** added Fastlane metadata (short/full description, icon, changelog) and prepared the app for F-Droid inclusion via `fdroiddata`.

## 0.1.7

### ✨ Features
- **Editor options (Settings → Editor):** automatic line wrapping in titles and list items, and optional strikethrough for checked checklist items.
- **List reordering:** drag checklist items (`⋮≡` handle) to reorder, with automatic persistence.
- **Link previews:** URLs in the note body are underlined. Tapping a link offers Preview, Open or Edit. The preview shows thumbnail, title and domain (Open Graph).
  - No automatic requests: metadata is only fetched after a user action.
  - Local cache per note (not synced); the preview reappears when the note is reopened.
  - Card menu: Open URL, Copy URL, Remove (with an **Undo** action).
  - The home screen shows the preview at the bottom of the note card.
- **Home screen widget:** the preview respects the editor options (line wrapping and strikethrough).
- **Export notes to kDrive (.docx):** from the note options menu, "Copy to kDrive" generates a `.docx` file with the title and body and uploads it to the configured kDrive folder.
- **Home multi-selection actions:** with multiple notes selected, the top bar menu allows **Send** (Share Plus) and **Copy to kDrive** (a single `.docx` with all notes grouped together).
- **Individual sharing:** in the editor, the **Send** option shares the note via Share Plus.
- **kDrive-not-configured warning:** export actions show a snackbar with a direct shortcut to the sync Settings.

### 🐛 Fixes
- **Link preview titles:** HTML entities in `og:title`, `<title>` and `og:site_name` (e.g. `&#xE1;` → `á`) are now decoded, including numeric decimal/hex and common named entities. Older cached previews are decoded on read, so they are fixed without a new download.
- **Meta tag parsing:** `og:*` tags are also read when `content` appears before `property`/`name`.

### 🛠️ Changes
- **Add link:** inserts the URL into the note body (no longer uses link chips).
- **Comments in English:** all source-code comments (Dart, Kotlin, XML, tests) translated to English.
- **AGENTS.md:** explicit rule that code comments are always in English, regardless of the conversation language.

## 0.1.6
# 🚀 What's New in 0.1.6 — First Public Release

This version marks the public launch of **kMemo**, a minimalist, productivity-focused note-taking app built with Flutter and local SQLite (Drift) persistence.

### ✨ Features
- **Block-based editor:** Notes made of text blocks and task lists (checklists), each independently editable.
- **Automatic light/dark theme:** Full support with custom color palettes for both themes.
- **Home Screen Widget (4×3):** Native Android widget showing the latest notes with a colored background per note, text preview and checkbox icons.
- **Remote sync with kDrive (Infomaniak):** Upload and download notes to the cloud with optional client-side AES encryption.
- **Internationalization:** Support for 6 languages (Portuguese, English, French, German, Italian, Spanish) with a "System" option to follow the device language.
- **Text sharing:** Receives text shared from other apps and automatically creates a new note.
- **Empty note rejection:** Notes created but left empty are automatically deleted on exit, avoiding the accumulation of empty notes.
- **Checkbox detection in shared text:** Shared text with `[ ]` / `[X]` items is automatically converted to checklist mode.
- **App links:** Support for opening notes via `kmemo://note/{uuid}`.

### 🛠️ Fixes and Adjustments
- **Smart persistence:** The note is only saved when there are real changes (dirty-checking).
- **Widget click fix:** Tapping a note in the widget opens that note directly in edit mode.
- **kDrive help card:** The instructions card only appears on the kDrive tab, leaving room for WebDAV.
- **Lint warnings fixed:** All static analyzer warnings resolved.
- **Comments and logs in English:** All comments and debug messages translated to English.

### 🔒 Security and Privacy
- **Optional AES encryption:** Notes can be encrypted on the client before being sent to the cloud.
- **Offline-first:** All notes are stored locally in SQLite; sync is asynchronous and does not block the UI.
- **No telemetry:** The app does not collect or send usage data.

### 📦 Build and Distribution
- **Generated icons** for Android, iOS, Web, Windows and macOS via `flutter_launcher_icons`.
- **Release APK** available for direct installation.

### ⚠️ Known limitations
- **Android-only widget:** The home screen widget is Android-exclusive.
- **Web version not supported:** The app uses SQLite via FFI, which is not web-compatible.
- **WebDAV under development:** The protocol selector is available, but the WebDAV implementation is not yet complete.
- **Unimplemented features:** Photo capture, gallery image selection, audio recording, pinning notes (pin), notifications/reminders and text formatting (bold, italic, etc.) are commented out in the code as TODOs.

---

## 0.1.5
# 🚀 What's New in 0.1.5

### ✨ Features
- **Internationalization:** Support for 6 languages (Portuguese, English, French, German, Italian, Spanish) with 152 localization keys.
- **Language selector:** Available in Settings to test all locales.
- **Text sharing:** Receives text shared from other apps and automatically creates a new note.
- **Shared text sanitization:** Removal of control characters and whitespace normalization.
- **Public release preparation:** README and AGENTS.md consolidated for release.
- **Updated icons:** New app icon (brain + lightbulb + K) applied to all platforms.

### 🛠️ Fixes and Adjustments
- **Dirty-checking:** The note is not marked as modified when opened; it only persists when there are real changes.
- **Sync business logic:** Sync does not start automatically when the token is entered; the user must select the destination folder and tap "Sync now".
- **Translated comments and logs:** All comments and debug messages corrected to English.
- **Color palette:** Alignment of the dark color palette between editor and note card.

---

## 0.1.4
# 🚀 What's New in 0.1.4

### ✨ Features
- **Remote sync with kDrive (Infomaniak):** Upload and download notes to the cloud.
- **Optional AES encryption:** Notes can be encrypted on the client before being sent to the cloud.
- **Hierarchical folder navigation:** The user can browse and create folders inside kDrive.
- **Push + Pull:** Created/edited/archived/deleted notes are sent; remote notes not present locally are downloaded.
- **Conflict resolution:** Last-write-wins based on the update date (`updatedAt`).
- **Rate limit:** Respects the Infomaniak API limit of 60 requests per minute.

### 🛠️ Fixes and Adjustments
- **Private folder (id=5) as effective root:** The kDrive API does not allow writing to the root (id=1).
- **3-second debounce:** Avoids excessive API calls.
- **Encrypted notes in the cloud:** Passphrase dialog with up to 2 attempts; option to ignore or delete the remote note.
- **Re-encryption:** Decrypted notes are rewritten according to the global encryption configuration.

---

## 0.1.3
# 🚀 What's New in 0.1.3

### ✨ Features
- **Home Screen Widget (4×3):** Native Android widget with a colored background per note, text preview and checkbox icons.
- **Click-to-open:** Tapping a note in the widget opens that note directly in edit mode.
- **App links:** Support for opening notes via `kmemo://note/{uuid}`.
- **Custom icon:** Brain with lightbulb and K, applied to Android, iOS, Web, Windows and macOS.

### 🛠️ Fixes and Adjustments
- **Widget click fix:** Use of `FLAG_MUTABLE` for `PendingIntentTemplate` and extraction of `note_uuid` from the `data` URI.
- **Duplicate opening prevention:** `_isOpeningNote` flag to avoid duplicate navigation.

---

## 0.1.2
# 🚀 What's New in 0.1.2

### ✨ Features
- **Automatic dark theme:** Full support with custom color palettes for both themes.
- **Undo/redo:** Edit history in the note editor.
- **Search bar:** Inline search in the note editor.
- **Note archive:** Full management of archived notes.
- **Trash:** Soft delete with restore and permanent deletion.
- **Content preview:** In MemoCard, with an ellipsis indicator.

### 🛠️ Fixes and Adjustments
- **Persistence and focus:** Fixed focus loss with persistent IDs per block.
- **Line break:** Fixed line break/focus while typing.
- **Automatic capitalization:** Sentence-based in the title and checklist items.

---

## 0.1.1
# 🚀 What's New in 0.1.1

### ✨ Features
- **Block-based note editor:** Text and task lists (checklists).
- **Color management:** 16 background colors per note.
- **Attachments:** Images, audio and links associated with the note.
- **Archive notes:** Archive state with restore.

### 🛠️ Fixes and Adjustments
- **Isar → Drift migration:** Persistence engine changed from Isar to Drift (SQLite).
- **Parameter fixes:** BottomAppBar and color opacity in the UI.
- **withValues API:** Updated to the `withValues` API in Material 3.

---

## 0.1.0
# 🎉 Initial launch of kMemo! (v0.1.0)

We are thrilled to announce the first version of **kMemo**, a minimalist, productivity-focused note-taking app!

The goal of this app is to provide a distraction-free writing experience, with a dynamic block-based structure and offline-first persistence.

## ✨ Key Features in This Version:

*   **Offline-first persistence:** All data management is local through SQLite (via Drift).
*   **Block-based structure:** Text and task lists, each independently editable.
*   **Reactive state management:** Uses `Provider` combined with native Drift streams.
*   **Light/dark theme:** Full support with custom color palettes.
*   **GPLv3 license:** Distributed under the GNU General Public License v3.0.

---

This is just the beginning! The future of kMemo will be shaped by community feedback. If you find any problem or have suggestions, please open an [Issue](https://github.com/marotoweb/kmemo/issues).
