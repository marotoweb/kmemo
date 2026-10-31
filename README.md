# kMemo

**kMemo** is a minimalist, productivity-focused mobile note-taking app, created in Europe and built with Flutter. Its interface moves away from traditional text editors, adopting a structure entirely driven by dynamic blocks, letting you mutate and reorder content fluidly and without visual distractions. **kMemo** was born from the need to keep our notes sovereign without being the product and without depending on big tech.

**Current version: 0.1.6+7**

---

## 🚀 Key Features

- **Distraction-free writing:** Clean, continuous interface without mechanical borders. Each element blends in as if it were a single sheet of paper.
- **Block-based structure:** Each note's content is made of independent blocks (Text, Task Lists, Headings) that can be manipulated individually.
- **Offline-first persistence:** All data management is local through SQLite (via Drift), ensuring instant speed and absolute privacy.
- **Automatic dark theme (Dark Mode):** Full, dynamic support adapted to system settings, including dark, deep and desaturated color palettes for note and card backgrounds across all views.
- **Reactive ecosystem:** Uses `Provider` combined with native Drift streams for real-time updates in the UI and the home screen widget.
- **Home screen widget (4×3):** Native Android widget that shows the latest notes directly on the home screen, with a colored background per note, text preview and checkbox icons for lists.
- **Internationalization:** Support for Portuguese, English, French, German, Italian and Spanish, with a "System" option to follow the device language.
- **Text sharing:** Receives text shared from other apps (Share Plus) and automatically creates a new note, or shares your notes with external apps.
- **Empty note rejection:** Notes created but left empty are automatically deleted on exit, avoiding the accumulation of empty notes.
- **kDrive (Infomaniak) sync:** Upload and download notes to the cloud with optional client-side AES encryption.
- **Home Screen Widget integration:** Automatic synchronization with a native system widget for quick viewing of the latest notes and quick editing directly from the device desktop.
- **APP link:** Support for opening notes via APP link *kmemo://*
- **Editor options:** automatic line wrapping in titles and list items, and optional strikethrough for checked checklist items (configurable in Settings). The home screen widget respects these options in the preview.
- **List reordering:** drag checklist items to reorder, with automatic persistence.
- **Link previews:** URLs in the note body are underlined; tapping a link opens a menu to preview (thumbnail, title, domain), open or edit the URL. Previews are only fetched on user action (no automatic requests), are cached locally, can be removed with an "Undo" option, and are also shown at the bottom of the home card.
- **Export to kDrive:** from the note options menu, "Copy to kDrive" generates a .docx file with the note title and content and uploads it to the configured kDrive folder.
- **Share and export (single or multiple notes):** in the editor, "Send" shares the note via Share Plus. On the home screen, with multiple notes selected, the top bar menu allows "Send" (grouped text) and "Copy to kDrive" (a single .docx with all notes). If kDrive is not configured, a warning is shown with a shortcut to the sync Settings.

---

## 🛠️ Architecture and Technologies

- **Framework:** [Flutter](https://flutter.dev) (configured with Material Design 3).
- **Database:** [Drift (SQLite)](https://drift.simonbinder.eu/) – Uses custom converters to serialize Enums (`BlockType`) and complex structures into JSON maps (`MapConverter`).
- **State management:** [Provider](https://pub.dev/packages/provider).
- **Internationalization:** `flutter_gen_l10n` with ARB files in `lib/l10n/`.
- **Native communication:** [home_widget](https://pub.dev/packages/home_widget) to feed the Android/iOS widget data.
- **Icons:** [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) for automatic icon generation on all platforms.
- **Security:** Optional local encryption using `encrypt` and `flutter_secure_storage`.

---

## 🗄️ Data Model (Drift)

The app organizes persistence through two relational tables with automatic cascade deletion:

### 1. Memos (Notes)
| Field | Type | Description |
|-------|------|-------------|
| `uuid` | String (PK) | Primary key |
| `title` | String | Note title |
| `createdAt` / `updatedAt` | DateTime | Time tracking |
| `isSynced` | Boolean | Remote sync state (local only) |
| `remoteFileId` | String | Optional remote file identifier (local only) |
| `colorIndex` | Int | Background color index |
| `bgImageIndex` | Int | Background image index |
| `imageAttachments` | String (JSON) | Image attachment paths |
| `audioAttachments` | String (JSON) | Audio attachments |
| `linkAttachments` | String (JSON) | Associated links |
| `isArchived` | Boolean | Archive state |
| `isDeleted` | Boolean | Trash state (soft delete) |


### 2. Blocks (Dynamic Components)
| Field | Type | Description |
|-------|------|-------------|
| `id` | Int (PK) | Auto-increment |
| `uuid` | String | Unique block identifier |
| `memoUuid` | String (FK) | Link to the Memos table |
| `type` | Enum | `text`, `checklist`, `custom`, etc. |
| `content` | Map<String, dynamic> | Flexible content (text, checked, etc.) |
| `sortOrder` | Int | Display order |

> **Note on remote sync:** The `isSynced` and `remoteFileId` fields are local Drift state and are not sent in the JSON payload to kDrive.


---

## 📱 Home Screen Widget

The native Android widget shows active notes directly on the home screen:

- **Size:** 4×3 cells.
- **Content:** Note title and content preview.
- **Colors:** Each card uses the background color defined for each note, respecting the color palette of each theme defined in Settings (Light and Dark).
- **Editing:** Tapping a note in the widget opens the app in edit mode for the selected note.

---

## ☁️ Remote Sync (kDrive / Infomaniak)

Since version 0.1.3+, kMemo supports remote note sync through **kDrive**, Infomaniak's sovereign cloud storage service.

### Business model
1. **Enter token:** The user enters the Infomaniak API token.
2. **Discover drives:** The app tries to find available drives; if only one exists, it pre-selects that drive.
3. **Browse folders:** The user navigates the private folder where new folders can be created.
4. **Encryption:** The user decides whether to enable encryption.
5. **Sync:** The user taps "Sync now"; all settings are saved and the first cloud sync is attempted.
6. **Encrypted notes in the cloud:** If encrypted notes exist in the cloud, the user is informed and asked for the passphrase of that note in a new dialog. After two failed decryption attempts, the user may choose to ignore or delete the remote note.
7. **Re-encryption:** If a previously encrypted note can be decrypted, it is rewritten according to the global encryption configuration (no encryption if disabled, or with a new passphrase if enabled).
8. **Change encryption:** When the user disables/enables encryption, all notes are marked as not synced locally and the user is asked whether to re-upload all local notes to the cloud encrypted or decrypted according to the global configuration.

### How it works

- **Offline-first:** All notes continue to be stored locally in SQLite, with a risk of losing notes if the app is accidentally uninstalled. Sync is an asynchronous layer that does not block the UI and lets your notes be saved sovereignly on a remote server.
- **Push:** Created, edited, archived or deleted notes are sent to kDrive.
- **Pull:** Notes that exist in kDrive but not on the device are downloaded automatically.
- **Conflicts:** Resolved by "last-write-wins" based on the update date (`updatedAt`).
- **Optional encryption:** You can enable client-side AES encryption with a passphrase you define. Without that passphrase, encrypted data cannot be recovered.
- **Destination folder:** Notes are stored inside a specific folder (not at the root), navigable hierarchically. The "Private" folder (id=5) is used as the effective root, since the kDrive API does not allow writing to the root (id=1).

### Configuration

1. Go to **Settings → Sync**.
2. Generate an API token at [manager.infomaniak.com](https://manager.infomaniak.com/v3/ng/accounts/token/list) with the `drive`, `user_info`, `accounts` scopes.
3. Paste the token into the app.
4. Select the kDrive drive where you want to store notes; the drive is discovered and pre-selected if it is the only one.
5. Choose where you want to store notes; you can create new folders.
6. (Optional) Enable encryption and define a passphrase.
7. Tap **"Sync now"** to save the configuration and run the first sync.

### Known limitations

- The Infomaniak API rate limit is 60 requests per minute.
- Sync requires an internet connection.
- The destination folder must be selected before the first sync.

---

## ☁️ Remote Sync (WebDAV)

- WebDAV protocol under development. The protocol selector is available in Settings → Sync, but the WebDAV implementation is not yet complete. Currently, only kDrive (Infomaniak) is functional.

---

### ⚠️ Important Notice

kMemo **is not affiliated with, endorsed by or sponsored by Infomaniak**. The **kDrive** service is a trademark of **Infomaniak**. Use of the kDrive API is done through tokens generated by the user in the Infomaniak account manager, in accordance with that company's terms of service.

---

## 📦 Running the Project

### Prerequisites
- Flutter SDK installed (`^3.10.7` or later).
- Configured Android/iOS device or emulator.
- Android SDK with API level 21+.

> [See my Linux installation article](https://medium.com/@marotoweb/how-to-install-flutter-on-ubuntu-24-04-3-lts-without-android-studio-17a41ee29468)

### Startup steps

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd kmemo
   ```

2. **Get the Pub dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run code generation (Drift/Build Runner):**
   ```bash
   flutter pub run build_runner build --force-jit
   ```

4. **Generate app icons (optional, if the icon changes):**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

5. **Build and run the app:**
   ```bash
   flutter run
   ```
---

## 🧭 Quick Navigation

| File | Description |
|------|-------------|
| `lib/main.dart` | Entry point, MultiProvider, theme, locale |
| `lib/database/database.dart` | Drift schema (Memos + Blocks) |
| `lib/l10n/` | Localization files (PT, EN, FR, DE, IT, ES) |
| `lib/providers/memo_provider.dart` | Memo logic, streams, bulk actions, sync |
| `lib/services/widget_service.dart` | Data sync for the widget |
| `lib/services/kdrive_storage.dart` | kDrive implementation (upload/download/list/delete) |
| `lib/services/encryption_service.dart` | Optional client-side AES encryption |
| `lib/services/storage_repository.dart` | Abstract remote storage interface |
| `lib/services/link_preview_service.dart` | Link detection, Open Graph fetch, local cache |
| `lib/services/docx_export_service.dart` | Builds valid .docx exports |
| `lib/ui/screens/memo_detail_screen.dart` | Note editor (text + checklist, saves only when changed) |
| `lib/ui/screens/home_screen.dart` | Home screen with active notes list + text sharing |
| `lib/ui/screens/trash_screen.dart` | Trash (restore / permanently delete) |
| `lib/ui/screens/archive_screen.dart` | Archived notes |
| `lib/ui/screens/settings_screen.dart` | Settings, theme, language, sync, open-source info |
| `lib/ui/screens/sync_settings_screen.dart` | kDrive configuration: token, drive, folder, encryption |
| `lib/models/block.dart` | BlockType and Block model definitions |
| `android/app/src/main/kotlin/com/marotoweb/kmemo/MainActivity.kt` | Intent handling (widget + shared text) |
| `android/app/src/main/kotlin/com/marotoweb/kmemo/KMemoWidgetService.kt` | Native widget view factory |
| `android/app/src/main/kotlin/com/marotoweb/kmemo/KMemoWidgetProvider.kt` | AppWidget lifecycle |
| `assets/icon/icon.png` | App icon |
| `assets/backgrounds/` | Folder for note background images |

---

## 📝 License

This project is distributed under the **GNU General Public License v3.0 (GPLv3)**.

## 📄 Disclaimer
The kMemo application is provided "AS IS", without warranties of any kind. The author is not responsible for any malfunction, data loss or errors that may arise from the use of this application.
