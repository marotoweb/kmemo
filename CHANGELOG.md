# Changelog

## 0.2.0

### ✨ Features
- **WebDAV sync:** remote sync now works with any WebDAV server (Nextcloud, ownCloud, Synology, self-hosted, …) besides kDrive. The server URL needs no scheme: HTTPS is assumed (an explicit `http://` is kept for local servers). Notes use the same JSON payload, so they can be moved between backends; switching backend re-uploads the whole library, and activating one backend removes the other's configuration (token, server, credentials and passphrase). Encryption, passphrase handling and conflict resolution work exactly as with kDrive. WebDAV has no version history, so "Clear old versions" remains kDrive-only.

### 🐛 Fixes
- **Home widget updates:** the payload is now built with one block query instead of one per note, updates that arrive while another build is running are coalesced, and the rebuild waits 300 ms after the last change instead of running on every keystroke. Before, typing rebuilt the widget dozens of times per second (invisible, since the widget is only seen when the app is in the background) and two overlapping updates could leave the widget showing stale data.
- **Archive screen: clear wording and a delete swipe:** the three-dot menu option that moves the selected notes to the trash was labelled "Delete permanently", even though the notes stay recoverable in the trash. It now just says "Delete". Archived notes can also be swiped to the left to move them to the trash, with an undo action — before, only the unarchive swipe existed.

## 0.1.19

### 🖼️ Store listing
- **New screenshots:** the store listing now shows six screenshots for each language (Portuguese and English), taken with neutral demo notes: the home screen with pinned and coloured notes, the text editor, a checklist with struck-through items, a note with a background image, the settings screen and the home screen widget. The previous images were taller than the 9:16 ratio accepted by F-Droid, so the store could not display them.

## 0.1.18

### 🐛 Fixes
- **Notes could be uploaded without encryption:** with encryption configured but the passphrase not loaded (the sync settings had been saved once with the passphrase field empty, which stored an empty passphrase and looked like "no passphrase" on the next start), a sync uploaded the notes in plain text — the encryption check only ran before the download, never before the upload. Uploads are now refused in that state.
- **Encryption can no longer be bypassed:** saving the sync settings with the passphrase field empty keeps the saved passphrase instead of overwriting it with an empty one, an empty passphrase never enables encryption, and an upload fails instead of writing a note in plain text when the passphrase is missing. Restoring the passphrase re-uploads every note encrypted; use "Clear old versions" afterwards to remove the plain-text history.
- **No secrets in the log:** the kDrive token was printed on startup, and the sync settings logged the token and passphrase lengths. Those lines now only say `present`/`empty`, and release builds no longer write any app log at all.
- **Trash keeps the remote note:** sending a note to the trash no longer deletes its `.json` from kDrive. The note is uploaded flagged as being in the trash, so other devices show it in their trash too; the remote file is deleted only when the note is permanently removed from the trash.
- **kDrive sync no longer duplicates notes:** updating an existing note sent a `file_id` that the kDrive API rejects when combined with `file_name`/`conflict` (HTTP 422), so every sync fell back to creating a new remote file and left the previous one orphaned — the origin of the "note not found" errors when deleting. Existing notes are now overwritten by name in a single request with `conflict=version`.
- **Shared text without a checklist stays plain text:** text shared from another app only becomes a checklist when it contains real markers (`[ ]`, `[x]`, `- [ ]`, `* [X]`). Anything else opens as paragraphs, and a line without a marker inside a checklist continues the previous item instead of creating an empty checkbox.
- **Red screen after swiping a note:** archiving or trashing a note no longer throws "A dismissed Dismissible widget is still part of the tree". The card now disappears when the list rebuilds after the note is saved, instead of being dismissed before it is removed. The archive screen (unarchive swipe) uses the same wrapper.
- **Scrolling no longer triggers the swipe:** a diagonal up/down scroll used to grab the note card and reveal the archive/trash action, and a fast fling could even run it. The card now takes the gesture only when the finger moves clearly sideways, so a vertical or diagonal scroll always scrolls the list.
- **Easier swipe actions:** a swipe now triggers at 35% of the card width instead of 90%, which was hard to reach on a long note card (walking the thumb across more than half the screen). The icon behind the card is dimmed until the drag is far enough, so it is clear when releasing will act. A short or fast fling still does nothing.
- **Open search stays in sync with the notes:** archiving, trashing, restoring or editing a note while the search is open now refreshes the results right away. Before, the results were a snapshot taken when the query ran, so a note that had just been archived or deleted stayed in the list until the user typed again (and a restored or edited note was missing from it).
- **Sort button stays in place:** the sort icon keeps the same position when the search field opens; the close button now sits before it.

### ✨ Improvements
- **Clear old versions:** each edit keeps the previous content as a version on kDrive, which is useful to recover an older note but also keeps the text as it was written (including plain text saved before encryption was enabled). Settings → Sync now has a "Clear old versions" action that deletes that history for every note in the selected folder and keeps only the current version. It is explicit, confirmed and irreversible.

### 🔧 Internal
- **Dead code removed:** unreferenced helpers in the database, provider and kDrive layers, the old `BlockExtension` leftover, eleven unused strings, three widget drawables that no layout referenced, the `docx_template` and `cupertino_icons` dependencies (never imported) and the unreferenced `old_icon.png`.

## 0.1.17

### 🐛 Fixes
- **Note reopened on every start after a widget tap:** the note uuid queued by the widget is now consumed as soon as the note opens and cleared when the app leaves the foreground, instead of surviving in `SharedPreferences` and reopening that note on the next start.
- **Long-press selection:** long-pressing a note card without dragging now selects it for multi-selection again. Selection is detected from the reorder callbacks, because the card widget is unmounted as soon as the delayed drag starts and a pointer listener on it never received the release.
- **Accidental selection while scrolling:** scrolling over note cards no longer selects the card under the finger.
- **Scroll stutter and jumps:** note cards now render their body text and link previews synchronously from preloaded caches. Previously every visible card ran a SQLite query for its blocks and loaded its URL preview asynchronously, so the list jumped when a preview appeared and stuttered while scrolling.
- **Accidental archive/restore while swiping:** a swipe only acts after the card is dragged almost the full width (90%). A short or fast swipe no longer triggers the action; the home and trash screens share the same guard.
- **Readable snackbars in dark mode:** all snackbars use theme-aware text and action colors, so the "Undo" action is no longer amber on a light background.
- **Link preview card contrast:** the preview card now uses the theme surface colors for its title and domain, so the text stays readable over a note background image in light mode. Links in the note body use a lighter blue over background images.
- **Preview from the card menu:** the three-dot menu on a link preview card now includes "Preview", which re-downloads the metadata and restores a removed preview.
- **Widget card spacing:** the widget reserves a single title line (instead of two) and uses tighter line heights, so short and long notes no longer show a large empty area under the text.
- **Widget background contrast:** the widget window now uses `#212121` (the dark home screen background), a color that is not in the dark card palette, so neutral `#1E1E1E` cards no longer blend into the widget background.
- **Widget scroll jumps:** each card height now has its own XML layout and view type, so the ListView never recycles a view between different heights. On Android 12+ the widget now passes the whole collection inline with `RemoteCollectionItems`, removing the asynchronous loading placeholder that still caused a jump when an item loaded with a different height; card backgrounds use a tinted rounded shape instead of a per-item bitmap.
- **Widget reload while scrolling:** while the app is in the background the widget payload is frozen (the JSON is not rewritten and the widget is not notified), so background sync/edits cannot reorder or reset the list while the user is scrolling the home-screen widget. The latest data is applied when the app returns to the foreground. The payload also carries a version hash, so a launcher-initiated update with unchanged data no longer calls `notifyAppWidgetViewDataChanged` and keeps the scroll position. Widgets are rebuilt after an app update that changes the item layout.

### ✨ Improvements
- **Swipe actions:** on the home screen, swiping a card to the right archives it and swiping it to the left moves it to the trash. Both show a SnackBar with Undo.
- **Unified accent color:** switches, selected segments and buttons use the same vivid amber in light and dark mode. Text and outlined buttons use a darker/lighter amber where needed to keep the contrast readable.
- **Widget transparency:** Settings has a new Widgets section with two transparency sliders for the widget window background and the cards (0% = fully opaque, 100% = fully transparent). The window background is now a separate layer, so changing its transparency does not affect the cards, and the rounded corners are preserved. The values are stored locally and applied to the native widget; rapid adjustments are debounced (300 ms) so the widget is rebuilt once after the value settles.

### 🔧 Internal
- **Block preview cache:** all non-deleted blocks are loaded in a single query whenever the note list changes and served from memory to the cards; no database access happens while scrolling.
- **Link preview cache:** cached link previews and the per-note removed-URL sets are preloaded into memory at startup, and `fetchAndCache`/`saveRemoved` keep them up to date.
- **Single-query preview lookup:** home cards no longer open a `FutureBuilder` per card for blocks or URL previews.
- **Shared snackbar helper:** a single `buildAppSnackBar()` helper builds every snackbar with theme-aware colors.

## 0.1.16

### ✨ Features
- **Home sorting:** choose to sort notes by last modification, creation date or a custom order, from a new sort button in the app bar. The date modes support ascending/descending order.
- **Search notes:** a fully rounded search field replaces the app bar title and filters notes by title and content as you type.
- **Pinned notes:** pin/unpin notes from the multi-selection bar or the note editor. Pinned notes always stay at the top of the home list and of the native widget (marked with 📌).
- **Custom order (drag & drop):** in custom-order mode, select a single note and drag it vertically to reorder the list. Pinned and non-pinned notes form separate sections.
- **More background images:** new backgrounds `bg_2`–`bg_5`, plus support for PNG, JPEG and WebP files dropped into `assets/backgrounds/` (no code change needed). A dark scrim keeps the text readable over both light and dark images.
- **Smaller background assets:** `bg_1` is now a JPEG (1.25 MB → 177 KB), saving about 1 MB in the APK.
- **Search highlighting:** while searching on the home screen, matching words in note titles, body text and checklist items are highlighted with an amber background.
- **Hybrid drag gesture:** a single long-press + drag reorders any note (auto-switching to custom order when needed); a long-press released without dragging starts multi-selection. Dragging is available in all sort modes.
- **Transparent drag proxy:** the dragged note keeps its rounded corners with no dark rectangular background behind it.

### 🔧 Internal
- **Database schema v5:** adds `isPinned` (synced across devices) and `sortIndex` (local manual order) to notes, with an automatic migration.
- **Shared ordering rule:** the home screen and the native widget use the same sort logic.

## 0.1.15

### ✨ Features
- **Background image previews:** the background image picker (note editor and home style sheet) now shows a thumbnail of each available image instead of a text label.
- **Background images on home cards:** notes with a background image now render it on the home card too, with light text for proper contrast.
- **Vivid dark palette:** the dark-theme note colors are slightly lighter and less saturated, and are now shared by the editor, home cards and the native widget.

### 🐛 Fixes
- **No network when showing cached link previews (privacy):** OG preview images are now cached locally during an explicit preview fetch (cache v3) and rendered from local files only. Toggling "Show link previews" no longer loads remote images. Existing cached previews without a local image show a placeholder until the user requests a preview again.
- **Rounded widget corners:** cards are clipped to the widget's rounded background while scrolling, so they no longer overlap the corners.
- **Sync progress bar always visible:** the sync progress indicator is now pinned to the bottom of the sync screen, so it remains visible while scrolling the destination folder list.
- **Clearer encryption sync warnings:** the confirmation shown when enabling or disabling encryption now explains exactly what happens to local and remote notes (re-upload/replace, download and decrypt), instead of the generic "sync all notes" message.
- **Link preview menu:** the "Preview" action in the link menu is hidden when "Show link previews" is disabled.
- **Home card line wrapping:** with "Automatic line wrapping" enabled, note titles and checklist items on the home cards now wrap instead of being truncated to a single line.
- **Color vs. background image:** choosing a color now clears the background image consistently in the editor and on the home screen.
- **Home image selection:** picking a background image in the home style sheet now applies the image (previously it changed the note color).

## 0.1.14

### ✨ Features
- **Show link previews setting:** new Settings → Editor toggle "Show link previews" (enabled by default). When turned off, preview cards are hidden in the note editor and on note cards; the link tap menu still works.
- **Auto line wrap enabled by default:** the auto-wrap editor option is now on by default.
- **Sync progress:** re-uploading all notes (for example when enabling or disabling encryption) now shows a progress card with "N / M notes" instead of running silently.

### 🐛 Fixes
- **Editor cursor placement:** tapping the body now places the cursor instead of selecting text up to the tap point. The cursor also stays aligned with the last typed character because the transparent editor and the text overlay now use identical letter/word spacing.
- **Encrypted sync passphrase:** fixed a crash (`_dependents.isEmpty`) when submitting the passphrase and reused the validated passphrase across notes instead of asking again for every encrypted note.

## 0.1.13

### ✨ Features
- **Widget refresh on settings changes:** changing the editor options (auto line wrap, strikethrough for checked items), the theme (light/dark/system) or the language now refreshes the home screen widget immediately, instead of waiting for the next note edit.
- **Sync result count:** the "sync completed" snackbar now reports how many notes were uploaded or downloaded during that sync.
- **In-app update check:** Settings → "Check for updates" queries the latest GitHub release and notifies the user (dialog) if a newer version is available, with a link to download the APK matching the device architecture. Network errors are handled gracefully.
- **Smaller APKs (ABI split):** release builds now produce per-architecture APKs (armeabi-v7a, arm64-v8a, x86_64) instead of a single universal APK, reducing download size from ~65 MB to ~22–26 MB per architecture.

### 🐛 Fixes
- **kDrive folder listing pagination:** the v3 listing endpoint only returned the first page (10 items), so the first sync found at most 10 remote notes and the destination folder showed an incomplete list. Listing now follows the API's cursor-based pagination (`cursor`/`has_more`) and retrieves every entry. `page`/`per_page` are not accepted by this endpoint (HTTP 422), so they were removed.
- **Widget preview line count:** the widget preview now uses the real number of preview lines (up to 8) instead of collapsing to a single line when auto-wrap was off; auto-wrap only controls the ellipsis of long lines. This also removes the invalid `setEllipsize` call that could leave the widget stuck on the loading state.
- **Settings bottom padding:** added bottom padding to the settings list so the last options are not hidden behind the floating action button / navigation bar.
- **Status bar icon brightness:** status bar icons now follow the active theme (light or dark) instead of always using the same brightness.

### 🧪 Tests
- Added `test/kdrive_storage_pagination_test.dart` covering cursor pagination, missing `has_more`, repeated cursors and HTTP errors.
- Added `test/update_service_test.dart` covering version comparison (equal, greater, lesser, `v` prefix, missing parts, pre-release suffix).

## 0.1.12

### 🐛 Fixes
- **Reproducible build:** align the Android build for reproducible output: packaging excludes, R8/resource shrinking, FOSS Play dependency block, disabled ArtProfile tasks and Java 21.

## 0.1.11

### 🐛 Fixes
- **F-Droid reproducibility:** disable the AGP dependency metadata signing block (`dependenciesInfo`), which F-Droid rejects as an extra signing block.

## 0.1.10

### 🐛 Fixes
- **Release signing:** use the release keystore from `android/key.properties` instead of the debug signing config, so published APKs have a stable signing certificate and can be updated.
- **Reproducible build:** keep the `jni` build path and build-id normalization from 0.1.9.

## 0.1.9

### 📦 F-Droid
- **Reproducible build:** align the `jni` native library build with F-Droid by disabling the linker build-id and normalizing the build path.
- **App label:** use `kMemo` as the Android application label so `AutoName` matches the upstream metadata.

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
- **Developer guide:** explicit rule that code comments are always in English, regardless of the conversation language.

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
- **Public release preparation:** README and developer docs consolidated for release.
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
