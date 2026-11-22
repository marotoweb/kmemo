// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get discoveringDrives => 'Descubriendo drives...';

  @override
  String get discoveringFolders => 'Descubriendo carpetas...';

  @override
  String get add => 'Añadir';

  @override
  String get addLink => 'Añadir enlace';

  @override
  String get addImageFromGallery => 'Añadir imagen de la galería';

  @override
  String get addLinkLower => 'Añadir enlace';

  @override
  String get toggleCheckboxes => 'Alternar casillas';

  @override
  String get remoteStorage => 'Almacenamiento remoto';

  @override
  String get archive => 'Archivar';

  @override
  String get archiveScreen => 'Archivo';

  @override
  String get passphrasesDoNotMatch => 'Las passphrases no coinciden';

  @override
  String get cancel => 'Cancelar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get copyToKdrive => 'Copiar a kDrive';

  @override
  String get create => 'Crear';

  @override
  String get createNewFolder => 'Crear nueva carpeta';

  @override
  String get settings => 'Ajustes';

  @override
  String get disableSync => 'Desactivar sincronización';

  @override
  String get kdriveDrive => 'Drive kDrive';

  @override
  String get delete => 'Eliminar';

  @override
  String get deletePermanently => 'Eliminar definitivamente';

  @override
  String get deleteNote => 'Eliminar nota';

  @override
  String get deletePermanently2 => 'Eliminar definitivamente';

  @override
  String get encryptNotes => 'Cifrar notas';

  @override
  String get send => 'Enviar';

  @override
  String get sendFeedback => 'Enviar comentarios';

  @override
  String get chooseKdriveDrive => 'Elegir drive kDrive';

  @override
  String get noteWillBeMovedToTrash =>
      'Esta nota se moverá a la papelera. ¿Continuar?';

  @override
  String get makeCopy => 'Hacer copia';

  @override
  String get makeCopy2 => 'Hacer copia';

  @override
  String get recordAudioNote => 'Grabar nota de audio';

  @override
  String get ignore => 'Ignorar';

  @override
  String get enterFolderName => 'Introduce un nombre de carpeta';

  @override
  String get enterPassphrase => 'Introduce una passphrase';

  @override
  String get clearCheckboxes => 'Limpiar casillas';

  @override
  String get trash => 'Papelera';

  @override
  String get findInNote => 'Buscar en la nota';

  @override
  String get noteArchived => 'Nota archivada';

  @override
  String get noteEncryptedInCloud => 'Nota cifrada en la nube';

  @override
  String get noteRestored => 'Nota restaurada';

  @override
  String get notes => 'Notas';

  @override
  String get couldNotDecrypt => 'No se pudo descifrar';

  @override
  String get ok => 'OK';

  @override
  String get openSource => 'Código abierto';

  @override
  String get encryptionPassphrase => 'Passphrase de cifrado';

  @override
  String get folderCreatedSuccessfully => 'Carpeta creada con éxito';

  @override
  String get removeFromArchive => 'Quitar del archivo';

  @override
  String get sync => 'Sincronizar';

  @override
  String get syncTitle => 'Sincronización';

  @override
  String syncCompletedWithCount(int count) {
    return 'Sincronización completada: $count nota(s) sincronizada(s).';
  }

  @override
  String get syncUpToDate => 'Todo actualizado.';

  @override
  String get theme => 'Tema';

  @override
  String get takePhoto => 'Tomar foto';

  @override
  String get infomaniakToken => 'Token de Infomaniak';

  @override
  String get version => 'Versión';

  @override
  String get lastEdited => 'Última edición';

  @override
  String get undo => 'Deshacer';

  @override
  String get pasteTokenHere => 'Pega el token aquí';

  @override
  String get confirmPassphrase => 'Confirmar passphrase';

  @override
  String get listItem => 'Elemento de lista';

  @override
  String get findText => 'Buscar texto';

  @override
  String get newFolderName => 'Nombre de la nueva carpeta';

  @override
  String get folderName => 'Nombre de carpeta';

  @override
  String get note => 'Nota';

  @override
  String get passphrase => 'Passphrase';

  @override
  String get title => 'Título';

  @override
  String get thisNoteIsEncryptedInCloud =>
      'Esta nota está cifrada en la nube. Introduce la passphrase usada.';

  @override
  String get afterTwoAttempts =>
      'Tras dos intentos no se pudo descifrar la nota. ¿Eliminar la nota remota?';

  @override
  String get drive => 'Drive';

  @override
  String get destinationFolder => 'Carpeta de destino';

  @override
  String get encryption => 'Cifrado';

  @override
  String get active => 'Activa';

  @override
  String get inactive => 'Inactiva';

  @override
  String get lastSync => 'Última sincronización';

  @override
  String get configureRemoteStorage =>
      'Configura un almacenamiento remoto para sincronizar tus notas.';

  @override
  String get generateTokenAtManager =>
      'Genera un token en manager.infomaniak.com';

  @override
  String get noKdriveInAccount =>
      'No hay drive kDrive en esta cuenta. Activa kDrive en manager.infomaniak.com.';

  @override
  String get encryptNotesOnClient =>
      'Cifra las notas en el cliente antes de enviarlas a la nube';

  @override
  String get stepsToConfigure => 'Pasos para configurar:';

  @override
  String get step1EnterToken => '1. Introduce el token de Infomaniak';

  @override
  String get step2SelectDrive => '2. Selecciona el drive kDrive';

  @override
  String get step3SelectFolder => '3. Selecciona la carpeta de destino';

  @override
  String get step4ClickSync =>
      '4. Haz clic en \"Sincronizar ahora\" para guardar la configuración y sincronizar las notas';

  @override
  String get generateTokenWithScopes =>
      'Genera un token en manager.infomaniak.com con los siguientes scopes:';

  @override
  String get definePassphrase =>
      'Define una passphrase para cifrar tus notas. Sin ella los datos no se pueden recuperar.';

  @override
  String get emptyFolder => 'Carpeta vacía';

  @override
  String get trashIsEmpty => 'La papelera está vacía.';

  @override
  String get language => 'IDIOMA';

  @override
  String get appearance => 'APARIENCIA';

  @override
  String get syncSection => 'SINCRONIZACIÓN';

  @override
  String get reportProblem => 'REPORTAR UN PROBLEMA';

  @override
  String get about => 'ACERCA DE';

  @override
  String get noArchivedNotes => 'Ninguna nota archivada.';

  @override
  String get noteRemovedFromArchive => 'Nota retirada del archivo';

  @override
  String get noActiveNotes => 'Ninguna nota activa';

  @override
  String get voiceRecording => 'Grabación de voz';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Oscuro';

  @override
  String get auto => 'Auto';

  @override
  String get syncSubtitle => 'Sincroniza tus notas con kDrive o WebDAV';

  @override
  String remoteOverwritePending(int count) {
    return '$count nota(s) en la carpeta de destino nunca fueron leídas por este dispositivo.';
  }

  @override
  String get remoteOverwriteTitle =>
      '¿Sustituir las notas de la carpeta de destino?';

  @override
  String remoteOverwriteBody(int count) {
    return 'Este dispositivo nunca ha leído $count nota(s) de la carpeta de destino. Sustituirlas sube la versión de este dispositivo sobre esas copias; en kDrive las anteriores quedan en el historial del archivo. Si las copias remotas están cifradas, kMemo pide primero la frase de paso y sigue subiendo cifrado.';
  }

  @override
  String get remoteOverwriteConfirm => 'Sustituir';

  @override
  String get syncPhaseReading => 'Leyendo las notas';

  @override
  String get syncPhaseUploading => 'Enviando las notas';

  @override
  String syncUndecryptableNotes(int count) {
    return 'Algunas notas no se pudieron descifrar ($count). Comprueba la contraseña en los ajustes de sincronización.';
  }

  @override
  String get secretStoreUnavailable =>
      'No se pudo guardar la contraseña en el llavero del sistema. Desbloquea gnome-keyring o KWallet e inténtalo de nuevo.';

  @override
  String get syncBlockedNoPassphrase =>
      'La sincronización está bloqueada: el cifrado está activo pero falta la contraseña. Las notas nuevas se quedan solo en este dispositivo.';

  @override
  String get syncLog => 'Registro de sincronización';

  @override
  String get syncLogSubtitle =>
      'Copia lo que decidió la sincronización (sin el contenido de las notas).';

  @override
  String get syncLogEmpty => 'El registro está vacío. Sincroniza primero.';

  @override
  String get reportBugSubtitle =>
      'Reporta un error, sugiere una función o deja un comentario';

  @override
  String get sharedNote => 'Nota compartida';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get colorsTab => 'Colores (16)';

  @override
  String get imagesTab => 'Imágenes (16)';

  @override
  String get noteSentToTrash => 'Nota enviada a la papelera';

  @override
  String notesArchivedCount(String count) {
    return '$count notas archivadas';
  }

  @override
  String notesSentToTrashCount(String count) {
    return '$count notas enviadas a la papelera';
  }

  @override
  String get lastSyncJustNow => 'Hace un momento';

  @override
  String lastSyncMinutesAgo(String minutes) {
    return 'Hace $minutes min';
  }

  @override
  String lastSyncHoursAgo(String hours) {
    return 'Hace $hours h';
  }

  @override
  String get lastSyncNever => 'Nunca';

  @override
  String syncErrorWithDetail(String error) {
    return 'Error de sincronización: $error';
  }

  @override
  String configSaveError(String error) {
    return 'Error al guardar la configuración: $error';
  }

  @override
  String syncPartialFailure(String count) {
    return 'Sincronización completada, pero $count archivo(s) no se pudieron descifrar. Comprueba que la passphrase es correcta.';
  }

  @override
  String get activeSyncTitle => 'Sincronización activa';

  @override
  String get inactiveSyncTitle => 'Sincronización desactivada';

  @override
  String get configureRemoteSection => 'CONFIGURAR ALMACENAMIENTO REMOTO';

  @override
  String get selectDrive => 'Selecciona un drive';

  @override
  String get syncingNow => 'Sincronizando...';

  @override
  String get syncNowButton => 'Sincronizar ahora';

  @override
  String selectedFolder(String name) {
    return 'Carpeta seleccionada: $name';
  }

  @override
  String get selectFolderToStoreNotes =>
      'Selecciona una carpeta para guardar las notas';

  @override
  String get folderWord => 'Carpeta';

  @override
  String get itemWord => 'Elemento';

  @override
  String folderIdLabel(String id) {
    return 'Carpeta (ID: $id)';
  }

  @override
  String fileIdLabel(String id) {
    return 'Archivo (ID: $id)';
  }

  @override
  String idLabel(String id) {
    return 'ID: $id';
  }

  @override
  String cannotCreateInFile(String type) {
    return 'No se puede crear una carpeta dentro de un archivo (tipo: $type).';
  }

  @override
  String errorListingFolder(String error) {
    return 'Error al listar la carpeta: $error';
  }

  @override
  String createInFolder(String name) {
    return 'Crear dentro de: $name';
  }

  @override
  String errorCreatingFolderIn(String folder, String error) {
    return 'Error al crear la carpeta en \"$folder\": $error';
  }

  @override
  String get scopeDrive => 'Productos kDrive';

  @override
  String get scopeUserInfo => 'Información del perfil';

  @override
  String get scopeAccounts => 'Listar cuentas';

  @override
  String get noValidAccount =>
      'No se ha encontrado ninguna cuenta de Infomaniak válida para este token.';

  @override
  String errorDiscoveringAccounts(String error) {
    return 'Error al detectar cuentas/drives: $error';
  }

  @override
  String get privateFolderEmpty => 'La carpeta Private está vacía.';

  @override
  String errorListingPrivateFolder(String error) {
    return 'Error al listar la carpeta Private: $error';
  }

  @override
  String get restore => 'Restaurar';

  @override
  String imageAttachmentsCount(String count) {
    return 'Adjuntos de imagen ($count)';
  }

  @override
  String updatedOn(String date) {
    return 'Actualizado: $date';
  }

  @override
  String notesUnarchivedCount(String count) {
    return '$count notas retiradas del archivo';
  }

  @override
  String notesRestoredCount(String count) {
    return '$count notas restauradas';
  }

  @override
  String searchCounter(String current, String total) {
    return '$current de $total';
  }

  @override
  String decryptionFailuresCount(String count) {
    return '$count archivo(s) no se pudieron descifrar. Comprueba la passphrase.';
  }

  @override
  String get widgetUntitled => 'Sin título';

  @override
  String get widgetEmptyNote => 'Nota vacía';

  @override
  String get emptyNoteRejected => 'Nota vacía rechazada';

  @override
  String get languageSetting => 'Idioma';

  @override
  String get system => 'Sistema';

  @override
  String get editor => 'EDITOR';

  @override
  String get autoWrapLines => 'Salto de línea automático';

  @override
  String get autoWrapLinesSubtitle =>
      'Divide las líneas largas en títulos y elementos de lista.';

  @override
  String get strikethroughChecked => 'Tachar elementos marcados';

  @override
  String get strikethroughCheckedSubtitle =>
      'Aplica tachado a los elementos de lista marcados como completados.';

  @override
  String get previewLink => 'Vista previa';

  @override
  String get linkCopied => 'Enlace copiado';

  @override
  String get linkPreviewRemoved => 'Vista previa eliminada';

  @override
  String get openLink => 'Abrir URL';

  @override
  String get copyLink => 'Copiar URL';

  @override
  String get removePreview => 'Eliminar';

  @override
  String get openLinkShort => 'Abrir';

  @override
  String get editLink => 'Editar';

  @override
  String get kdriveNotConfigured => 'kDrive no configurado';

  @override
  String get copiedToKdrive => 'Copiado en kDrive';

  @override
  String get copyToKdriveFailed => 'Error al copiar en kDrive';

  @override
  String get copyToCloud => 'Copiar a la nube';

  @override
  String get copyToWebdav => 'Copiar a WebDAV';

  @override
  String get copiedToCloud => 'Copiado en la nube';

  @override
  String get copiedToWebdav => 'Copiado en WebDAV';

  @override
  String get copyToCloudFailed => 'Error al copiar en la nube';

  @override
  String get copyToWebdavFailed => 'Error al copiar en WebDAV';

  @override
  String get cloudNotConfigured =>
      'No hay ningún almacenamiento remoto configurado';

  @override
  String get docxNotEncrypted => 'El archivo .docx no está cifrado.';

  @override
  String get checkForUpdates => 'Buscar actualizaciones';

  @override
  String upToDateMessage(String version) {
    return 'Estás usando la versión más reciente ($version).';
  }

  @override
  String get newVersionAvailable => 'Nueva versión disponible';

  @override
  String newVersionMessage(String version, String current) {
    return 'La versión $version está disponible. Estás usando $current.';
  }

  @override
  String get downloadUpdate => 'Descargar';

  @override
  String get viewReleasePage => 'Ver página de release';

  @override
  String get later => 'Más tarde';

  @override
  String get updateCheckFailed =>
      'No se pudieron verificar las actualizaciones';

  @override
  String get releaseNotes => 'Notas de la versión';

  @override
  String get showLinkPreviews => 'Mostrar vistas previas de enlaces';

  @override
  String get showLinkPreviewsSubtitle =>
      'Mostrar tarjetas de vista previa para enlaces en las notas';

  @override
  String get enableEncryptionTitle => 'Activar cifrado';

  @override
  String get enableEncryptionMessage =>
      'Tus notas locales se cifrarán con la nueva contraseña y se volverán a subir, sustituyendo las copias remotas. Las notas remotas se descargarán y descifrarán.';

  @override
  String get disableEncryptionTitle => 'Desactivar cifrado';

  @override
  String get disableEncryptionMessage =>
      'Tus notas locales se volverán a subir SIN cifrado, sustituyendo las copias remotas cifradas. Las notas remotas se descargarán y se guardarán localmente.';

  @override
  String get searchNotes => 'Buscar notas…';

  @override
  String get noResults => 'Sin resultados';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get sortByUpdated => 'Última modificación';

  @override
  String get sortByCreated => 'Fecha de creación';

  @override
  String get sortByCustom => 'Orden personalizado';

  @override
  String get ascending => 'Ascendente';

  @override
  String get descending => 'Descendente';

  @override
  String get pin => 'Fijar';

  @override
  String get unpin => 'Desfijar';

  @override
  String get widget => 'WIDGETS';

  @override
  String get widgetBackgroundTransparency =>
      'Transparencia del fondo del widget';

  @override
  String get widgetCardTransparency => 'Transparencia de las tarjetas';

  @override
  String transparencyPercent(int value) {
    return '$value%';
  }

  @override
  String get maintenanceSection => 'MANTENIMIENTO';

  @override
  String get clearOldVersions => 'Borrar versiones antiguas';

  @override
  String get clearOldVersionsSubtitle =>
      'Elimina el historial de versiones guardado en kDrive. Se mantiene la versión actual de cada nota.';

  @override
  String get clearOldVersionsTitle => '¿Borrar las versiones antiguas?';

  @override
  String get clearOldVersionsMessage =>
      'Cada cambio guarda el contenido anterior como una versión en kDrive. Las versiones antiguas conservan el contenido con el que se escribieron, incluido el texto sin cifrar guardado antes de activar el cifrado. Esta operación elimina el historial de todas las notas de la carpeta seleccionada y mantiene solo la versión actual. No se puede deshacer en kMemo ni en la aplicación web de kDrive.';

  @override
  String get clearingVersions => 'Borrando versiones antiguas…';

  @override
  String clearOldVersionsDone(int count) {
    return 'Versiones antiguas eliminadas de $count nota(s).';
  }

  @override
  String clearOldVersionsError(String error) {
    return 'No se pudieron borrar las versiones: $error';
  }

  @override
  String get webdavServerUrl => 'URL del servidor';

  @override
  String get webdavUsername => 'Usuario';

  @override
  String get webdavPassword => 'Contraseña';

  @override
  String get webdavPasswordKeepHint =>
      'Déjalo vacío para mantener la contraseña guardada';

  @override
  String get webdavFolderLabel => 'Carpeta de destino';

  @override
  String get webdavTestConnection => 'Probar conexión';

  @override
  String get webdavConnectionOk => 'Conexión establecida';

  @override
  String webdavConnectionFailed(String error) {
    return 'No se pudo conectar: $error';
  }

  @override
  String get webdavConfigurationSaved => 'Configuración guardada';

  @override
  String get webdavRemoveConfiguration => 'Eliminar configuración';

  @override
  String get webdavMissingFields =>
      'Rellena la URL, el usuario y la contraseña.';

  @override
  String get save => 'Guardar';

  @override
  String get dangerZone => 'ZONA DE PELIGRO';

  @override
  String get deleteAllNotes => 'Eliminar todas las notas';

  @override
  String get deleteAllNotesSubtitle =>
      'Elimina definitivamente todas las notas de este dispositivo. En el servidor no se elimina nada.';

  @override
  String get deleteAllNotesConfirmTitle => '¿Eliminar todas las notas?';

  @override
  String get deleteAllNotesConfirmBody =>
      'Todas las notas de este dispositivo se eliminan, incluidas las archivadas y las de la papelera. No se envía nada al servidor: las notas ya sincronizadas permanecen allí y vuelven en la próxima sincronización. No se puede deshacer.';

  @override
  String get deleteAllNotesConfirmAction => 'Eliminar todas';

  @override
  String get allNotesDeleted => 'Se eliminaron todas las notas.';

  @override
  String get deleteAllData => 'Eliminar todos los datos de la aplicación';

  @override
  String get deleteAllDataSubtitle =>
      'Elimina las notas, los ajustes, la configuración de sincronización y las cachés de este dispositivo.';

  @override
  String get deleteAllDataConfirmTitle => '¿Eliminar todos los datos?';

  @override
  String get deleteAllDataConfirmBody =>
      'Esto elimina todas las notas, los ajustes de la aplicación, la configuración de sincronización (token y frase de contraseña) y las cachés locales de este dispositivo. Las notas ya sincronizadas permanecen en el servidor. No se puede deshacer.';

  @override
  String get deleteAllDataConfirmAction => 'Eliminar todo';

  @override
  String get allDataDeleted => 'Datos de la aplicación eliminados.';
}
