[![GitHub Latest Release](https://img.shields.io/github/v/release/marotoweb/kmemo?style=popout)](https://github.com/marotoweb/kmemo/releases/latest)
[![GitHub All Releases](https://img.shields.io/github/downloads/marotoweb/kmemo/total)](https://github.com/marotoweb/kmemo/releases)
<a href="https://www.buymeacoffee.com/marotoweb" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" width="72" height="20"></a>

<h1 align="center">
  <img src="assets/icon/icon.png" width="60" alt="kMemo Icon">
  kMemo
</h1>

<p align="center">
  <a href="https://f-droid.org/packages/com.marotoweb.kmemo/">
    <img src="https://f-droid.org/badge/get-it-on.png" alt="Get it on F-Droid" height="70">
  </a>
</p>

**kMemo** is a minimalist, productivity-focused mobile note-taking app, created in Europe and built with Flutter. Its interface moves away from traditional text editors, adopting a structure entirely driven by dynamic blocks, letting you mutate and reorder content fluidly and without visual distractions. **kMemo** was born from the need to keep our notes sovereign without being the product and without depending on big tech.

---

## 🚀 Key Features

- **Distraction-free writing:** Clean, continuous interface without mechanical borders. Each element blends in as if it were a single sheet of paper.
- **Block-based structure:** Each note's content is made of independent blocks (Text, Task Lists, Headings) that can be manipulated individually.
- **Offline-first persistence:** All data management is local through SQLite (via Drift), ensuring instant speed and absolute privacy.
- **Automatic dark theme (Dark Mode):** Full, dynamic support adapted to system settings, including dark, deep and desaturated color palettes for note and card backgrounds across all views.
- **Reactive ecosystem:** Uses `Provider` combined with native Drift streams for real-time updates in the UI and the home screen widget.
- **Home screen widget (4×3):** Native Android widget that shows the latest notes directly on the home screen, with a colored background per note, text preview and checkbox icons for lists. Background and card transparency can be adjusted in Settings → Widgets.
- **Internationalization:** Support for Portuguese, English, French, German, Italian and Spanish, with a "System" option to follow the device language.
- **Text sharing:** Receives text shared from other apps (Share Plus) and automatically creates a new note, or shares your notes with external apps.
- **Empty note rejection:** Notes created but left empty are automatically deleted on exit, avoiding the accumulation of empty notes.
- **Remote sync (kDrive or WebDAV):** Upload and download notes to kDrive (Infomaniak) or to any WebDAV server, with optional client-side AES encryption.
- **Sync button and pull to sync:** the cloud button in the top bar runs a manual sync from the home screen on any platform, and pulling the note list down does the same on a touch screen. While the list is held, a card shows the date and time of the last sync; the card can be turned off in Settings, next to the sync log.
- **Home Screen Widget integration:** Automatic synchronization with a native system widget for quick viewing of the latest notes and quick editing directly from the device desktop.
- **APP link:** Support for opening notes via APP link *kmemo://*
- **Editor options:** automatic line wrapping in titles and list items, and optional strikethrough for checked checklist items (configurable in Settings). The home screen widget respects these options in the preview.
- **Photos:** attach a photo from the camera or the gallery. A large photo asks whether to resize it to 1280 or 1920 pixels, and the size and the ask/always/never behaviour live in Settings → Notes. Every imported photo is re-encoded to remove its metadata, stored inside the app with a thumbnail, and can be viewed full screen or removed.
- **List reordering:** drag checklist items to reorder, with automatic persistence.
- **Home sorting and search:** sort notes by last modification, creation date or a custom order (ascending/descending for dates), and search by title and content from the app bar.
- **Find in note:** the editor has its own search. Every match is highlighted while you type (the one in focus in a stronger colour), the caret stays in the field, and Enter or the arrows move between matches and scroll them into view. It also works with keyboards that need conversion, such as Japanese.
- **Pinned notes:** pin notes to keep them at the top of the home list and the widget; pinning is synced across devices.
- **Custom home order:** in custom-order mode, select a single note and drag it vertically to reorder the list.
- **Link previews:** URLs in the note body are underlined; tapping a link opens a menu to preview (thumbnail, title, domain), open or edit the URL. Previews are only fetched on user action (no automatic requests), are cached locally, can be removed with an "Undo" option, and are also shown at the bottom of the home card.
- **Export to the configured backend:** from the note options menu, the export entry follows the backend sync is set to ("Copy to kDrive" or "Copy to WebDAV") and generates a .docx file with the note title and content, uploaded to the same remote folder the notes use. With no backend configured it reads "Copy to the cloud" and opens the sync Settings. The exported .docx is **not encrypted**, even when note encryption is enabled: encryption protects the note payload, while the document is a plain file. The confirmation message says so when encryption is on, and the note title is turned into a safe file name (no `/`, `\` or other path characters).
- **Share and export (single or multiple notes):** in the editor, "Send" shares the note via Share Plus. On the home screen, with multiple notes selected, the top bar menu allows "Send" (grouped text) and the same backend-aware export (a single .docx with all notes). If no remote storage is configured, a warning is shown with a shortcut to the sync Settings.
- **In-app update check:** Settings → "Check for updates" queries the latest GitHub release and notifies the user if a newer version is available, downloading the APK matching the device architecture.
- **Danger zone:** at the end of the Settings page, two destructive actions, each behind a confirmation that explains what it does. "Delete all notes" removes every note from this device (archive and trash included) and leaves the server untouched, so notes already synced come back on the next sync. "Delete all app data" clears the notes, the sync configuration and the caches, and puts every setting back to a fresh install.

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
| `remoteUpdatedAt` | DateTime | Payload timestamp of the remote copy this device last agreed with (local only) |
| `remoteRevision` | DateTime | Modified time of the remote file at the last listing (local only) |
| `colorIndex` | Int | Background color index |
| `bgImageIndex` | Int | Background image index |
| `imageAttachments` | String (JSON) | Image attachment paths |
| `audioAttachments` | String (JSON) | Audio attachments |
| `linkAttachments` | String (JSON) | Associated links |
| `isArchived` | Boolean | Archive state |
| `isDeleted` | Boolean | Trash state (soft delete) |
| `isPinned` | Boolean | Pinned to the top of the home list and widget (synced) |
| `sortIndex` | Int | Manual position used by the custom sort order (local only) |


### 2. Blocks (Dynamic Components)
| Field | Type | Description |
|-------|------|-------------|
| `id` | Int (PK) | Auto-increment |
| `uuid` | String | Unique block identifier |
| `memoUuid` | String (FK) | Link to the Memos table |
| `type` | Enum | `text`, `checklist`, `custom`, etc. |
| `content` | Map<String, dynamic> | Flexible content (text, checked, etc.) |
| `sortOrder` | Int | Display order |

> **Note on remote sync:** The `isSynced` and `remoteFileId` fields are local Drift state and are not sent in the JSON payload to the remote storage (kDrive or WebDAV).


---

## 📱 Home Screen Widget

The native Android widget shows active notes directly on the home screen:

- **Size:** 4×3 cells.
- **Content:** Note title and content preview.
- **Ordering:** follows the home list order — pinned notes first, then the selected sort mode.
- **Colors:** Each card uses the background color defined for each note, respecting the color palette of each theme defined in Settings (Light and Dark). The widget window uses its own background color, so neutral cards never blend into it.
- **Transparency:** Settings → Widgets has two sliders for the widget window background and the cards (0% = fully opaque, 100% = fully transparent). Adjustments are debounced, so the widget is rebuilt once the value settles.
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
- **Conflicts:** Merged note by note. A note edited only on this device is uploaded; a note edited only on the other device is downloaded; a note edited on both sides keeps both versions — the local note stays as it is and the remote version is saved as a separate note titled "(Conflict)" (in your language), which is uploaded like any other note. The check does not rely on which clock is ahead: it compares what changed on each side since the last sync. Sending a note to the trash is not a conflict when the other device restored it, and switching backend re-uploads the whole local library instead of merging with the previous backend's copies.
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

kMemo can also sync to any **WebDAV** server (Nextcloud, ownCloud, Synology, Box, a self-hosted server, …). The protocol selector at the top of **Settings → Sync** switches between kDrive and WebDAV.

### Configuration

1. Go to **Settings → Sync** and select **WebDAV**.
2. Enter the **server URL**, including the path where your files live. The scheme is optional — HTTPS is assumed, so `cloud.example.com/...` and `https://cloud.example.com/...` are the same (use `http://` only for a local server without TLS). Examples:
   - Nextcloud: `cloud.example.com/remote.php/dav/files/<username>/`
   - Synology: `nas.example.com:5006/`
3. Enter the **username** and **password** (or an app password, which is what Nextcloud and most servers recommend).
4. The destination folder defaults to `kmemo/notes`; it is created automatically on the first sync.
5. (Optional) Enable encryption and define a passphrase.
6. Tap **Test connection** to check the URL and credentials, then **Save** and **Sync now**.

### How it works

- Notes are stored as `<uuid>.json`, using exactly the same payload as kDrive, so a note can be moved between the two backends.
- **Push / pull / conflicts** behave like kDrive: offline-first, merged note by note, with a separate "(Conflict)" copy when both sides edited the same note.
- **No version history:** an upload overwrites the file. The "Clear old versions" action is therefore kDrive-only.
- **Only one backend may be configured at a time.** Saving the WebDAV configuration removes the kDrive token, drive, folder and passphrase, and saving kDrive removes the WebDAV server and credentials. The notes of the backend being activated are re-uploaded, so the new destination receives the whole library.

### Known limitations

- The server must accept HTTP Basic authentication. Use HTTPS (the default) except for a local server without TLS. Digest authentication and OAuth are not supported.
- The WebDAV server has no rate limit of its own, but some providers throttle requests; the app syncs one note at a time.

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

### Linux desktop

The notes, the editor, search, archive/trash, link previews, `.docx` export and
both sync backends also run as a Linux desktop app.

```bash
sudo apt install libsecret-1-dev libjsoncpp-dev   # keyring bindings
flutter build linux --release
./build/linux/x64/release/bundle/kmemo
```

#### AppImage

Every release also publishes a portable AppImage (no installation, no root):

```bash
chmod +x kMemo-vX.Y.Z-x86_64.AppImage
./kMemo-vX.Y.Z-x86_64.AppImage
```

To build it yourself:

```bash
linux/package-appimage.sh          # builds the Flutter bundle too
linux/package-appimage.sh --no-build
```

The script assembles an AppDir (bundle under `usr/bin`, `.desktop`, icon,
`AppRun`) and runs `appimagetool`, which it downloads once to
`~/.cache/kmemo/`. The result is `build/appimage/kMemo-<version>-x86_64.AppImage`
(about 19 MB).

Notes and settings are stored outside the AppImage, in
`~/.local/share/com.marotoweb.kmemo/`, so replacing the file with a newer
version keeps everything.

#### Flatpak

Not packaged yet. AppImage is the supported desktop format for now, because it
needs no runtime installed on the user's machine and no Flatpak manifest to be
kept in sync with the SDK.

Two platform notes:

- **Home-screen widget:** Android only. The widget section of the Settings
  screen is hidden on the desktop.
- **Secrets:** the kDrive token, the WebDAV password and the encryption
  passphrase live in the desktop keyring (gnome-keyring or KWallet). A locked
  or missing keyring does not stop the app — the notes still open — but the
  sync settings refuse to save the credentials and say so. Sharing has no share
  sheet on Linux: share_plus opens a `mailto:` compose window, and when no mail
  handler is registered the note text is copied to the clipboard instead.

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
| `lib/services/webdav_storage.dart` | WebDAV implementation (PROPFIND/PUT/GET/DELETE, MKCOL) |
| `lib/services/memo_serialization.dart` | Remote payload shared by both backends (build, encrypt, parse) |
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
| `android/app/src/main/kotlin/com/marotoweb/kmemo/MainActivity.kt` | Intent handling (widget + shared text) |
| `android/app/src/main/kotlin/com/marotoweb/kmemo/KMemoWidgetService.kt` | Native widget view factory |
| `android/app/src/main/kotlin/com/marotoweb/kmemo/KMemoWidgetProvider.kt` | AppWidget lifecycle |
| `assets/icon/icon.png` | App icon |
| `assets/backgrounds/` | Folder for note background images |

---

## 📥 Download & Distribution

- **GitHub Releases:** the latest signed APK is available on the [Releases page](https://github.com/marotoweb/kmemo/releases/latest).
- **F-Droid:** kMemo was accepted into F-Droid. The recipe was merged on 17 November 2026 ([merge request !55141](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/55141)); the listing at [f-droid.org/packages/com.marotoweb.kmemo](https://f-droid.org/packages/com.marotoweb.kmemo/) appears once the first build is published. The build is fully reproducible and all pipeline jobs pass.

---

## 📝 License

This project is distributed under the **GNU General Public License v3.0 (GPLv3)**.

## 📄 Disclaimer
The kMemo application is provided "AS IS", without warranties of any kind. The author is not responsible for any malfunction, data loss or errors that may arise from the use of this application.
