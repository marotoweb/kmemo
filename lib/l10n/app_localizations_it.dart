// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get discoveringDrives => 'Ricerca drive in corso...';

  @override
  String get discoveringFolders => 'Ricerca cartelle in corso...';

  @override
  String get add => 'Aggiungi';

  @override
  String get addLink => 'Aggiungi link';

  @override
  String get addImageFromGallery => 'Aggiungi immagine dalla galleria';

  @override
  String get addLinkLower => 'Aggiungi link';

  @override
  String get toggleCheckboxes => 'Attiva/disattiva caselle';

  @override
  String get remoteStorage => 'Archiviazione remota';

  @override
  String get archive => 'Archivia';

  @override
  String get archiveScreen => 'Archivio';

  @override
  String get passphrasesDoNotMatch => 'Le passphrases non coincidono';

  @override
  String get cancel => 'Annulla';

  @override
  String get confirm => 'Conferma';

  @override
  String get copyToKdrive => 'Copia su kDrive';

  @override
  String get create => 'Crea';

  @override
  String get createNewFolder => 'Crea nuova cartella';

  @override
  String get settings => 'Impostazioni';

  @override
  String get disableSync => 'Disattiva sincronizzazione';

  @override
  String get kdriveDrive => 'Drive kDrive';

  @override
  String get delete => 'Elimina';

  @override
  String get deletePermanently => 'Elimina definitivamente';

  @override
  String get deleteNote => 'Elimina nota';

  @override
  String get deletePermanently2 => 'Elimina definitivamente';

  @override
  String get encryptNotes => 'Cifra le note';

  @override
  String get send => 'Invia';

  @override
  String get sendFeedback => 'Invia feedback';

  @override
  String get chooseKdriveDrive => 'Scegli drive kDrive';

  @override
  String get noteWillBeMovedToTrash =>
      'Questa nota verrà spostata nel cestino. Continuare?';

  @override
  String get makeCopy => 'Crea copia';

  @override
  String get makeCopy2 => 'Crea copia';

  @override
  String get recordAudioNote => 'Registra nota audio';

  @override
  String get ignore => 'Ignora';

  @override
  String get enterFolderName => 'Inserisci un nome per la cartella';

  @override
  String get enterPassphrase => 'Inserisci una passphrase';

  @override
  String get clearCheckboxes => 'Cancella caselle';

  @override
  String get trash => 'Cestino';

  @override
  String get findInNote => 'Trova nella nota';

  @override
  String get noteArchived => 'Nota archiviata';

  @override
  String get noteEncryptedInCloud => 'Nota cifrata nel cloud';

  @override
  String get noteRestored => 'Nota ripristinata';

  @override
  String get notes => 'Note';

  @override
  String get couldNotDecrypt => 'Impossibile decifrare';

  @override
  String get ok => 'OK';

  @override
  String get openSource => 'Open source';

  @override
  String get encryptionPassphrase => 'Passphrase di cifratura';

  @override
  String get folderCreatedSuccessfully => 'Cartella creata con successo';

  @override
  String get removeFromArchive => 'Rimuovi dall\'archivio';

  @override
  String get sync => 'Sincronizza';

  @override
  String get syncTitle => 'Sincronizzazione';

  @override
  String syncCompletedWithCount(int count) {
    return 'Sincronizzazione completata: $count nota/note sincronizzate.';
  }

  @override
  String get syncUpToDate => 'Tutto aggiornato.';

  @override
  String get theme => 'Tema';

  @override
  String get takePhoto => 'Scatta foto';

  @override
  String get infomaniakToken => 'Token Infomaniak';

  @override
  String get version => 'Versione';

  @override
  String get lastEdited => 'Ultima modifica';

  @override
  String get undo => 'Annulla';

  @override
  String get pasteTokenHere => 'Incolla il token qui';

  @override
  String get confirmPassphrase => 'Conferma passphrase';

  @override
  String get listItem => 'Elemento elenco';

  @override
  String get findText => 'Trova testo';

  @override
  String get newFolderName => 'Nome nuova cartella';

  @override
  String get folderName => 'Nome cartella';

  @override
  String get note => 'Nota';

  @override
  String get passphrase => 'Passphrase';

  @override
  String get title => 'Titolo';

  @override
  String get thisNoteIsEncryptedInCloud =>
      'Questa nota è cifrata nel cloud. Inserisci la passphrase usata.';

  @override
  String get afterTwoAttempts =>
      'Dopo due tentativi la nota non è stata decifrata. Eliminare la nota remota?';

  @override
  String get drive => 'Drive';

  @override
  String get destinationFolder => 'Cartella di destinazione';

  @override
  String get encryption => 'Cifratura';

  @override
  String get active => 'Attiva';

  @override
  String get inactive => 'Inattiva';

  @override
  String get lastSync => 'Ultima sincronizzazione';

  @override
  String get configureRemoteStorage =>
      'Configura un archivio remoto per sincronizzare le note.';

  @override
  String get generateTokenAtManager =>
      'Genera un token su manager.infomaniak.com';

  @override
  String get noKdriveInAccount =>
      'Nessun drive kDrive in questo account. Attiva kDrive su manager.infomaniak.com.';

  @override
  String get encryptNotesOnClient =>
      'Cifra le note lato client prima dell\'invio al cloud';

  @override
  String get stepsToConfigure => 'Passi per la configurazione:';

  @override
  String get step1EnterToken => '1. Inserisci il token Infomaniak';

  @override
  String get step2SelectDrive => '2. Seleziona il drive kDrive';

  @override
  String get step3SelectFolder => '3. Seleziona la cartella di destinazione';

  @override
  String get step4ClickSync =>
      '4. Clicca su \"Sincronizza ora\" per salvare la configurazione e sincronizzare le note';

  @override
  String get generateTokenWithScopes =>
      'Genera un token su manager.infomaniak.com con gli scope seguenti:';

  @override
  String get definePassphrase =>
      'Imposta una passphrase per cifrare le note. Senza di essa i dati non sono recuperabili.';

  @override
  String get emptyFolder => 'Cartella vuota';

  @override
  String get trashIsEmpty => 'Il cestino è vuoto.';

  @override
  String get language => 'LINGUA';

  @override
  String get appearance => 'ASPETTO';

  @override
  String get syncSection => 'SINCRONIZZAZIONE';

  @override
  String get reportProblem => 'SEGNALA UN PROBLEMA';

  @override
  String get about => 'INFO';

  @override
  String get noArchivedNotes => 'Nessuna nota archiviata.';

  @override
  String get noteRemovedFromArchive => 'Nota rimossa dall\'archivio';

  @override
  String get noActiveNotes => 'Nessuna nota attiva';

  @override
  String get voiceRecording => 'Registrazione vocale';

  @override
  String get light => 'Chiaro';

  @override
  String get dark => 'Scuro';

  @override
  String get auto => 'Auto';

  @override
  String get syncSubtitle => 'Sincronizza le tue note con kDrive o WebDAV';

  @override
  String remoteOverwritePending(int count) {
    return '$count nota/e nella cartella di destinazione non è mai stata letta da questo dispositivo.';
  }

  @override
  String get remoteOverwriteTitle =>
      'Sostituire le note nella cartella di destinazione?';

  @override
  String remoteOverwriteBody(int count) {
    return 'Questo dispositivo non ha mai letto $count nota/e nella cartella di destinazione. Sostituirle carica la versione di questo dispositivo sopra quelle copie; su kDrive le precedenti restano nella cronologia del file. Se le copie remote sono cifrate, kMemo chiede prima la passphrase e continua a caricare cifrato.';
  }

  @override
  String get remoteOverwriteConfirm => 'Sostituisci';

  @override
  String get syncPhaseReading => 'Lettura delle note';

  @override
  String get syncPhaseUploading => 'Invio delle note';

  @override
  String syncUndecryptableNotes(int count) {
    return 'Alcune note non sono state decifrate ($count). Controlla la passphrase nelle impostazioni di sincronizzazione.';
  }

  @override
  String get secretStoreUnavailable =>
      'Impossibile salvare la password nel portachiavi di sistema. Sblocca gnome-keyring o KWallet e riprova.';

  @override
  String get syncBlockedNoPassphrase =>
      'La sincronizzazione è bloccata: la cifratura è attiva ma manca la passphrase. Le nuove note restano solo su questo dispositivo.';

  @override
  String get syncLog => 'Registro di sincronizzazione';

  @override
  String get syncLogSubtitle =>
      'Copia ciò che la sincronizzazione ha deciso (senza il contenuto delle note).';

  @override
  String get syncLogEmpty => 'Il registro è vuoto. Sincronizza prima.';

  @override
  String get reportBugSubtitle =>
      'Segnala un bug, suggerisci una funzionalità o lascia un commento';

  @override
  String get sharedNote => 'Nota condivisa';

  @override
  String get copiedToClipboard => 'Copiato negli appunti';

  @override
  String get colorsTab => 'Colori (16)';

  @override
  String get imagesTab => 'Immagini (16)';

  @override
  String get noteSentToTrash => 'Nota spostata nel cestino';

  @override
  String notesArchivedCount(String count) {
    return '$count note archiviate';
  }

  @override
  String notesSentToTrashCount(String count) {
    return '$count note spostate nel cestino';
  }

  @override
  String get lastSyncJustNow => 'Poco fa';

  @override
  String lastSyncMinutesAgo(String minutes) {
    return '$minutes min fa';
  }

  @override
  String lastSyncHoursAgo(String hours) {
    return '$hours h fa';
  }

  @override
  String get lastSyncNever => 'Mai';

  @override
  String syncErrorWithDetail(String error) {
    return 'Errore di sincronizzazione: $error';
  }

  @override
  String configSaveError(String error) {
    return 'Errore nel salvataggio della configurazione: $error';
  }

  @override
  String syncPartialFailure(String count) {
    return 'Sincronizzazione completata, ma $count file non è stato possibile decifrare. Verifica che la passphrase sia corretta.';
  }

  @override
  String get activeSyncTitle => 'Sincronizzazione attiva';

  @override
  String get inactiveSyncTitle => 'Sincronizzazione disattivata';

  @override
  String get configureRemoteSection => 'CONFIGURA L’ARCHIVIAZIONE REMOTA';

  @override
  String get selectDrive => 'Seleziona un drive';

  @override
  String get syncingNow => 'Sincronizzazione...';

  @override
  String get syncNowButton => 'Sincronizza ora';

  @override
  String selectedFolder(String name) {
    return 'Cartella selezionata: $name';
  }

  @override
  String get selectFolderToStoreNotes =>
      'Seleziona una cartella per salvare le note';

  @override
  String get folderWord => 'Cartella';

  @override
  String get itemWord => 'Elemento';

  @override
  String folderIdLabel(String id) {
    return 'Cartella (ID: $id)';
  }

  @override
  String fileIdLabel(String id) {
    return 'File (ID: $id)';
  }

  @override
  String idLabel(String id) {
    return 'ID: $id';
  }

  @override
  String cannotCreateInFile(String type) {
    return 'Impossibile creare una cartella all’interno di un file (tipo: $type).';
  }

  @override
  String errorListingFolder(String error) {
    return 'Errore nell’elenco della cartella: $error';
  }

  @override
  String createInFolder(String name) {
    return 'Crea dentro: $name';
  }

  @override
  String errorCreatingFolderIn(String folder, String error) {
    return 'Errore nella creazione della cartella in \"$folder\": $error';
  }

  @override
  String get scopeDrive => 'Prodotti kDrive';

  @override
  String get scopeUserInfo => 'Informazioni del profilo';

  @override
  String get scopeAccounts => 'Elenca gli account';

  @override
  String get noValidAccount =>
      'Nessun account Infomaniak valido trovato per questo token.';

  @override
  String errorDiscoveringAccounts(String error) {
    return 'Errore nella ricerca di account/drive: $error';
  }

  @override
  String get privateFolderEmpty => 'La cartella Private è vuota.';

  @override
  String errorListingPrivateFolder(String error) {
    return 'Errore nell’elenco della cartella Private: $error';
  }

  @override
  String get restore => 'Ripristina';

  @override
  String imageAttachmentsCount(String count) {
    return 'Allegati immagine ($count)';
  }

  @override
  String updatedOn(String date) {
    return 'Aggiornato: $date';
  }

  @override
  String notesUnarchivedCount(String count) {
    return '$count note rimosse dall’archivio';
  }

  @override
  String notesRestoredCount(String count) {
    return '$count note ripristinate';
  }

  @override
  String searchCounter(String current, String total) {
    return '$current di $total';
  }

  @override
  String decryptionFailuresCount(String count) {
    return '$count file non è stato possibile decifrare. Verifica la passphrase.';
  }

  @override
  String get widgetUntitled => 'Senza titolo';

  @override
  String get widgetEmptyNote => 'Nota vuota';

  @override
  String get emptyNoteRejected => 'Nota vuota rifiutata';

  @override
  String get languageSetting => 'Lingua';

  @override
  String get system => 'Sistema';

  @override
  String get editor => 'EDITOR';

  @override
  String get autoWrapLines => 'A capo automatico';

  @override
  String get autoWrapLinesSubtitle =>
      'Va a capo sulle righe lunghe in titoli ed elementi di lista.';

  @override
  String get strikethroughChecked => 'Barrare gli elementi spuntati';

  @override
  String get strikethroughCheckedSubtitle =>
      'Applica il barrato agli elementi di lista segnati come completati.';

  @override
  String get previewLink => 'Anteprima';

  @override
  String get linkCopied => 'Link copiato';

  @override
  String get linkPreviewRemoved => 'Anteprima rimossa';

  @override
  String get openLink => 'Apri URL';

  @override
  String get copyLink => 'Copia URL';

  @override
  String get removePreview => 'Rimuovi';

  @override
  String get openLinkShort => 'Apri';

  @override
  String get editLink => 'Modifica';

  @override
  String get kdriveNotConfigured => 'kDrive non configurato';

  @override
  String get copiedToKdrive => 'Copiato su kDrive';

  @override
  String get copyToKdriveFailed => 'Errore durante la copia su kDrive';

  @override
  String get copyToCloud => 'Copia sul cloud';

  @override
  String get copyToWebdav => 'Copia su WebDAV';

  @override
  String get copiedToCloud => 'Copiato sul cloud';

  @override
  String get copiedToWebdav => 'Copiato su WebDAV';

  @override
  String get copyToCloudFailed => 'Errore durante la copia sul cloud';

  @override
  String get copyToWebdavFailed => 'Errore durante la copia su WebDAV';

  @override
  String get cloudNotConfigured => 'Nessun archivio remoto configurato';

  @override
  String get docxNotEncrypted => 'Il file .docx non è cifrato.';

  @override
  String get checkForUpdates => 'Verifica aggiornamenti';

  @override
  String upToDateMessage(String version) {
    return 'Stai usando la versione più recente ($version).';
  }

  @override
  String get newVersionAvailable => 'Nuova versione disponibile';

  @override
  String newVersionMessage(String version, String current) {
    return 'La versione $version è disponibile. Stai usando $current.';
  }

  @override
  String get downloadUpdate => 'Scarica';

  @override
  String get viewReleasePage => 'Vedi pagina release';

  @override
  String get later => 'Più tardi';

  @override
  String get updateCheckFailed => 'Impossibile verificare gli aggiornamenti';

  @override
  String get releaseNotes => 'Note di rilascio';

  @override
  String get showLinkPreviews => 'Mostra anteprime dei link';

  @override
  String get showLinkPreviewsSubtitle =>
      'Mostra schede di anteprima per i link nelle note';

  @override
  String get enableEncryptionTitle => 'Attiva crittografia';

  @override
  String get enableEncryptionMessage =>
      'Le note locali verranno crittografate con la nuova passphrase e ricaricate, sostituendo le copie remote. Le note remote verranno scaricate e decrittografate.';

  @override
  String get disableEncryptionTitle => 'Disattiva crittografia';

  @override
  String get disableEncryptionMessage =>
      'Le note locali verranno ricaricate SENZA crittografia, sostituendo le copie remote crittografate. Le note remote verranno scaricate e salvate localmente.';

  @override
  String get searchNotes => 'Cerca note…';

  @override
  String get noResults => 'Nessun risultato';

  @override
  String get sortBy => 'Ordina per';

  @override
  String get sortByUpdated => 'Ultima modifica';

  @override
  String get sortByCreated => 'Data di creazione';

  @override
  String get sortByCustom => 'Ordine personalizzato';

  @override
  String get ascending => 'Crescente';

  @override
  String get descending => 'Decrescente';

  @override
  String get pin => 'Fissa';

  @override
  String get unpin => 'Rimuovi fissaggio';

  @override
  String get widget => 'WIDGETS';

  @override
  String get widgetBackgroundTransparency =>
      'Trasparenza dello sfondo del widget';

  @override
  String get widgetCardTransparency => 'Trasparenza delle schede';

  @override
  String transparencyPercent(int value) {
    return '$value%';
  }

  @override
  String get maintenanceSection => 'MANUTENZIONE';

  @override
  String get clearOldVersions => 'Elimina versioni precedenti';

  @override
  String get clearOldVersionsSubtitle =>
      'Elimina la cronologia delle versioni salvata su kDrive. La versione attuale di ogni nota viene mantenuta.';

  @override
  String get clearOldVersionsTitle => 'Eliminare le versioni precedenti?';

  @override
  String get clearOldVersionsMessage =>
      'Ogni modifica conserva il contenuto precedente come versione su kDrive. Le versioni precedenti mantengono il contenuto con cui sono state scritte, incluso il testo in chiaro salvato prima di attivare la crittografia. Questa operazione rimuove la cronologia di tutte le note nella cartella selezionata e mantiene solo la versione attuale. Non può essere annullata in kMemo né nell\'app web di kDrive.';

  @override
  String get clearingVersions => 'Eliminazione delle versioni precedenti…';

  @override
  String clearOldVersionsDone(int count) {
    return 'Versioni precedenti rimosse da $count nota/e.';
  }

  @override
  String clearOldVersionsError(String error) {
    return 'Impossibile eliminare le versioni: $error';
  }

  @override
  String get webdavServerUrl => 'URL del server';

  @override
  String get webdavUsername => 'Nome utente';

  @override
  String get webdavPassword => 'Password';

  @override
  String get webdavPasswordKeepHint =>
      'Lascia vuoto per mantenere la password salvata';

  @override
  String get webdavFolderLabel => 'Cartella di destinazione';

  @override
  String get webdavTestConnection => 'Verifica connessione';

  @override
  String get webdavConnectionOk => 'Connessione riuscita';

  @override
  String webdavConnectionFailed(String error) {
    return 'Impossibile connettersi: $error';
  }

  @override
  String get webdavConfigurationSaved => 'Configurazione salvata';

  @override
  String get webdavRemoveConfiguration => 'Rimuovi configurazione';

  @override
  String get webdavMissingFields => 'Compila URL, nome utente e password.';

  @override
  String get save => 'Salva';

  @override
  String get dangerZone => 'ZONA PERICOLOSA';

  @override
  String get deleteAllNotes => 'Elimina tutte le note';

  @override
  String get deleteAllNotesSubtitle =>
      'Rimuove definitivamente tutte le note da questo dispositivo. Sul server non viene eliminato nulla.';

  @override
  String get deleteAllNotesConfirmTitle => 'Eliminare tutte le note?';

  @override
  String get deleteAllNotesConfirmBody =>
      'Tutte le note di questo dispositivo vengono rimosse, comprese quelle archiviate e quelle nel cestino. Non viene inviato nulla al server: le note già sincronizzate restano lì e tornano alla prossima sincronizzazione. Non può essere annullata.';

  @override
  String get deleteAllNotesConfirmAction => 'Elimina tutto';

  @override
  String get allNotesDeleted => 'Tutte le note sono state eliminate.';

  @override
  String get deleteAllData => 'Elimina tutti i dati dell\'app';

  @override
  String get deleteAllDataSubtitle =>
      'Rimuove le note, le impostazioni, la configurazione della sincronizzazione e le cache da questo dispositivo.';

  @override
  String get deleteAllDataConfirmTitle => 'Eliminare tutti i dati dell\'app?';

  @override
  String get deleteAllDataConfirmBody =>
      'Rimuove tutte le note, le impostazioni dell\'app, la configurazione della sincronizzazione (token e passphrase) e le cache locali da questo dispositivo. Le note già sincronizzate restano sul server. Non può essere annullata.';

  @override
  String get deleteAllDataConfirmAction => 'Elimina tutto';

  @override
  String get allDataDeleted => 'Dati dell\'app eliminati.';

  @override
  String get showLastSyncHint =>
      'Mostra l\'ultima sincronizzazione trascinando';

  @override
  String get showLastSyncHintSubtitle =>
      'Mostra data e ora dell\'ultima sincronizzazione mentre trascini la lista verso il basso.';

  @override
  String get notesSettings => 'Note';

  @override
  String get notesSettingsSubtitle => 'Editor e immagini';

  @override
  String get images => 'IMMAGINI';

  @override
  String get imageMaxSize => 'Dimensione massima';

  @override
  String get imageMaxSizeSubtitle =>
      'Le foto più grandi vengono ridimensionate prima di essere allegate.';

  @override
  String get imageResizeMode => 'Foto grandi';

  @override
  String get imageResizeModeSubtitle =>
      'Chiedi mostra il dialogo prima di ridurre.';

  @override
  String get imageResizeAsk => 'Chiedi';

  @override
  String get imageResizeAlways => 'Riduci sempre';

  @override
  String get imageResizeNever => 'Non ridurre mai';

  @override
  String get resizeImageTitle => 'Immagine grande';

  @override
  String resizeImageBody(String width, String height, String max) {
    return 'Stai per allegare un\'immagine grande (${width}x$height pixel). Vuoi ridurla a $max pixel prima di allegarla?';
  }

  @override
  String get resizeImageConfirm => 'Riduci';

  @override
  String get resizeImageKeep => 'Mantieni originale';

  @override
  String get imageAttachFailed => 'Impossibile allegare l\'immagine.';

  @override
  String get imageUnsupported => 'Formato immagine non supportato.';

  @override
  String get imageTooLarge => 'L\'immagine è troppo grande.';
}
