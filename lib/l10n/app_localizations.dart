import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pt'),
  ];

  /// No description provided for @discoveringDrives.
  ///
  /// In pt, this message translates to:
  /// **'A descobrir drives...'**
  String get discoveringDrives;

  /// No description provided for @discoveringFolders.
  ///
  /// In pt, this message translates to:
  /// **'A descobrir pastas...'**
  String get discoveringFolders;

  /// No description provided for @add.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar'**
  String get add;

  /// No description provided for @addLink.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Link'**
  String get addLink;

  /// No description provided for @addImageFromGallery.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar imagem da galeria'**
  String get addImageFromGallery;

  /// No description provided for @addLinkLower.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar link'**
  String get addLinkLower;

  /// No description provided for @toggleCheckboxes.
  ///
  /// In pt, this message translates to:
  /// **'Alternar para Caixas de verificação'**
  String get toggleCheckboxes;

  /// No description provided for @remoteStorage.
  ///
  /// In pt, this message translates to:
  /// **'Armazenamento remoto'**
  String get remoteStorage;

  /// No description provided for @archive.
  ///
  /// In pt, this message translates to:
  /// **'Arquivar'**
  String get archive;

  /// No description provided for @archiveScreen.
  ///
  /// In pt, this message translates to:
  /// **'Arquivo'**
  String get archiveScreen;

  /// No description provided for @passphrasesDoNotMatch.
  ///
  /// In pt, this message translates to:
  /// **'As passphrases não coincidem'**
  String get passphrasesDoNotMatch;

  /// No description provided for @cancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// No description provided for @copyToKdrive.
  ///
  /// In pt, this message translates to:
  /// **'Copiar para kDrive'**
  String get copyToKdrive;

  /// No description provided for @create.
  ///
  /// In pt, this message translates to:
  /// **'Criar'**
  String get create;

  /// No description provided for @createNewFolder.
  ///
  /// In pt, this message translates to:
  /// **'Criar nova pasta'**
  String get createNewFolder;

  /// No description provided for @settings.
  ///
  /// In pt, this message translates to:
  /// **'Definições'**
  String get settings;

  /// No description provided for @disableSync.
  ///
  /// In pt, this message translates to:
  /// **'Desativar sincronização'**
  String get disableSync;

  /// No description provided for @kdriveDrive.
  ///
  /// In pt, this message translates to:
  /// **'Drive kDrive'**
  String get kdriveDrive;

  /// No description provided for @delete.
  ///
  /// In pt, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @deletePermanently.
  ///
  /// In pt, this message translates to:
  /// **'Eliminar definitivamente'**
  String get deletePermanently;

  /// No description provided for @deleteNote.
  ///
  /// In pt, this message translates to:
  /// **'Eliminar nota'**
  String get deleteNote;

  /// No description provided for @deletePermanently2.
  ///
  /// In pt, this message translates to:
  /// **'Eliminar permanentemente'**
  String get deletePermanently2;

  /// No description provided for @encryptNotes.
  ///
  /// In pt, this message translates to:
  /// **'Encriptar notas'**
  String get encryptNotes;

  /// No description provided for @send.
  ///
  /// In pt, this message translates to:
  /// **'Enviar'**
  String get send;

  /// No description provided for @sendFeedback.
  ///
  /// In pt, this message translates to:
  /// **'Enviar feedback'**
  String get sendFeedback;

  /// No description provided for @chooseKdriveDrive.
  ///
  /// In pt, this message translates to:
  /// **'Escolher drive kDrive'**
  String get chooseKdriveDrive;

  /// No description provided for @noteWillBeMovedToTrash.
  ///
  /// In pt, this message translates to:
  /// **'Esta nota será movida para a lixeira. Deseja continuar?'**
  String get noteWillBeMovedToTrash;

  /// No description provided for @makeCopy.
  ///
  /// In pt, this message translates to:
  /// **'Fazer copia'**
  String get makeCopy;

  /// No description provided for @makeCopy2.
  ///
  /// In pt, this message translates to:
  /// **'Fazer cópia'**
  String get makeCopy2;

  /// No description provided for @recordAudioNote.
  ///
  /// In pt, this message translates to:
  /// **'Gravar nota de áudio'**
  String get recordAudioNote;

  /// No description provided for @ignore.
  ///
  /// In pt, this message translates to:
  /// **'Ignorar'**
  String get ignore;

  /// No description provided for @enterFolderName.
  ///
  /// In pt, this message translates to:
  /// **'Insira um nome para a pasta'**
  String get enterFolderName;

  /// No description provided for @enterPassphrase.
  ///
  /// In pt, this message translates to:
  /// **'Insira uma passphrase'**
  String get enterPassphrase;

  /// No description provided for @clearCheckboxes.
  ///
  /// In pt, this message translates to:
  /// **'Limpar caixas de verificação'**
  String get clearCheckboxes;

  /// No description provided for @trash.
  ///
  /// In pt, this message translates to:
  /// **'Lixeira'**
  String get trash;

  /// No description provided for @findInNote.
  ///
  /// In pt, this message translates to:
  /// **'Localizar na nota'**
  String get findInNote;

  /// No description provided for @noteArchived.
  ///
  /// In pt, this message translates to:
  /// **'Nota arquivada'**
  String get noteArchived;

  /// No description provided for @noteEncryptedInCloud.
  ///
  /// In pt, this message translates to:
  /// **'Nota encriptada na nuvem'**
  String get noteEncryptedInCloud;

  /// No description provided for @noteRestored.
  ///
  /// In pt, this message translates to:
  /// **'Nota restaurada'**
  String get noteRestored;

  /// No description provided for @notes.
  ///
  /// In pt, this message translates to:
  /// **'Notas'**
  String get notes;

  /// No description provided for @couldNotDecrypt.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível desencriptar'**
  String get couldNotDecrypt;

  /// No description provided for @ok.
  ///
  /// In pt, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @openSource.
  ///
  /// In pt, this message translates to:
  /// **'Open source'**
  String get openSource;

  /// No description provided for @encryptionPassphrase.
  ///
  /// In pt, this message translates to:
  /// **'Passphrase de encriptação'**
  String get encryptionPassphrase;

  /// No description provided for @folderCreatedSuccessfully.
  ///
  /// In pt, this message translates to:
  /// **'Pasta criada com sucesso'**
  String get folderCreatedSuccessfully;

  /// No description provided for @removeFromArchive.
  ///
  /// In pt, this message translates to:
  /// **'Remover do arquivo'**
  String get removeFromArchive;

  /// No description provided for @sync.
  ///
  /// In pt, this message translates to:
  /// **'Sincronizar'**
  String get sync;

  /// No description provided for @syncTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sincronização'**
  String get syncTitle;

  /// No description provided for @syncCompletedWithCount.
  ///
  /// In pt, this message translates to:
  /// **'Sincronização concluída: {count} nota(s) sincronizada(s).'**
  String syncCompletedWithCount(int count);

  /// No description provided for @theme.
  ///
  /// In pt, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @takePhoto.
  ///
  /// In pt, this message translates to:
  /// **'Tirar foto'**
  String get takePhoto;

  /// No description provided for @infomaniakToken.
  ///
  /// In pt, this message translates to:
  /// **'Token da Infomaniak'**
  String get infomaniakToken;

  /// No description provided for @version.
  ///
  /// In pt, this message translates to:
  /// **'Versão'**
  String get version;

  /// No description provided for @lastEdited.
  ///
  /// In pt, this message translates to:
  /// **'Última edição'**
  String get lastEdited;

  /// No description provided for @undo.
  ///
  /// In pt, this message translates to:
  /// **'Anular'**
  String get undo;

  /// No description provided for @pasteTokenHere.
  ///
  /// In pt, this message translates to:
  /// **'Cole o token aqui'**
  String get pasteTokenHere;

  /// No description provided for @confirmPassphrase.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar passphrase'**
  String get confirmPassphrase;

  /// No description provided for @listItem.
  ///
  /// In pt, this message translates to:
  /// **'Item de lista'**
  String get listItem;

  /// No description provided for @findText.
  ///
  /// In pt, this message translates to:
  /// **'Localizar texto'**
  String get findText;

  /// No description provided for @newFolderName.
  ///
  /// In pt, this message translates to:
  /// **'Nome da nova pasta'**
  String get newFolderName;

  /// No description provided for @folderName.
  ///
  /// In pt, this message translates to:
  /// **'Nome da pasta'**
  String get folderName;

  /// No description provided for @note.
  ///
  /// In pt, this message translates to:
  /// **'Nota'**
  String get note;

  /// No description provided for @passphrase.
  ///
  /// In pt, this message translates to:
  /// **'Passphrase'**
  String get passphrase;

  /// No description provided for @title.
  ///
  /// In pt, this message translates to:
  /// **'Título'**
  String get title;

  /// No description provided for @thisNoteIsEncryptedInCloud.
  ///
  /// In pt, this message translates to:
  /// **'Esta nota está encriptada na nuvem. Insira a passphrase usada para a encriptar.'**
  String get thisNoteIsEncryptedInCloud;

  /// No description provided for @afterTwoAttempts.
  ///
  /// In pt, this message translates to:
  /// **'Após duas tentativas, a nota não pôde ser desencriptada. Pretende eliminar a nota remota?'**
  String get afterTwoAttempts;

  /// No description provided for @drive.
  ///
  /// In pt, this message translates to:
  /// **'Drive'**
  String get drive;

  /// No description provided for @destinationFolder.
  ///
  /// In pt, this message translates to:
  /// **'Pasta de destino'**
  String get destinationFolder;

  /// No description provided for @encryption.
  ///
  /// In pt, this message translates to:
  /// **'Encriptação'**
  String get encryption;

  /// No description provided for @active.
  ///
  /// In pt, this message translates to:
  /// **'Ativa'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In pt, this message translates to:
  /// **'Inativa'**
  String get inactive;

  /// No description provided for @lastSync.
  ///
  /// In pt, this message translates to:
  /// **'Última sincronização'**
  String get lastSync;

  /// No description provided for @configureRemoteStorage.
  ///
  /// In pt, this message translates to:
  /// **'Configure um armazenamento remoto para sincronizar as suas notas.'**
  String get configureRemoteStorage;

  /// No description provided for @generateTokenAtManager.
  ///
  /// In pt, this message translates to:
  /// **'Gere um token em manager.infomaniak.com'**
  String get generateTokenAtManager;

  /// No description provided for @noKdriveInAccount.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum drive kDrive nesta conta. Ative o kDrive em manager.infomaniak.com.'**
  String get noKdriveInAccount;

  /// No description provided for @encryptNotesOnClient.
  ///
  /// In pt, this message translates to:
  /// **'Encripta as notas no cliente antes de enviar para a nuvem'**
  String get encryptNotesOnClient;

  /// No description provided for @stepsToConfigure.
  ///
  /// In pt, this message translates to:
  /// **'Passos para configurar:'**
  String get stepsToConfigure;

  /// No description provided for @step1EnterToken.
  ///
  /// In pt, this message translates to:
  /// **'1. Insira o token da Infomaniak'**
  String get step1EnterToken;

  /// No description provided for @step2SelectDrive.
  ///
  /// In pt, this message translates to:
  /// **'2. Selecione o drive kDrive'**
  String get step2SelectDrive;

  /// No description provided for @step3SelectFolder.
  ///
  /// In pt, this message translates to:
  /// **'3. Selecione a pasta de destino'**
  String get step3SelectFolder;

  /// No description provided for @step4ClickSync.
  ///
  /// In pt, this message translates to:
  /// **'4. Carregue em \"Sincronizar agora\" para guardar a configuração e sincronizar as notas'**
  String get step4ClickSync;

  /// No description provided for @generateTokenWithScopes.
  ///
  /// In pt, this message translates to:
  /// **'Gere um token em manager.infomaniak.com com os seguintes scopes:'**
  String get generateTokenWithScopes;

  /// No description provided for @definePassphrase.
  ///
  /// In pt, this message translates to:
  /// **'Defina uma passphrase para encriptar as suas notas. Sem ela, não será possível recuperar os dados.'**
  String get definePassphrase;

  /// No description provided for @emptyFolder.
  ///
  /// In pt, this message translates to:
  /// **'Pasta vazia'**
  String get emptyFolder;

  /// No description provided for @trashIsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'A lixeira está vazia.'**
  String get trashIsEmpty;

  /// No description provided for @language.
  ///
  /// In pt, this message translates to:
  /// **'IDIOMA'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In pt, this message translates to:
  /// **'APARÊNCIA'**
  String get appearance;

  /// No description provided for @syncSection.
  ///
  /// In pt, this message translates to:
  /// **'SINCRONIZAÇÃO'**
  String get syncSection;

  /// No description provided for @reportProblem.
  ///
  /// In pt, this message translates to:
  /// **'REPORTAR PROBLEMA'**
  String get reportProblem;

  /// No description provided for @about.
  ///
  /// In pt, this message translates to:
  /// **'SOBRE'**
  String get about;

  /// No description provided for @noArchivedNotes.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma nota arquivada.'**
  String get noArchivedNotes;

  /// No description provided for @noteRemovedFromArchive.
  ///
  /// In pt, this message translates to:
  /// **'Nota retirada do arquivo'**
  String get noteRemovedFromArchive;

  /// No description provided for @noActiveNotes.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma nota ativa'**
  String get noActiveNotes;

  /// No description provided for @voiceRecording.
  ///
  /// In pt, this message translates to:
  /// **'Gravação de voz'**
  String get voiceRecording;

  /// No description provided for @light.
  ///
  /// In pt, this message translates to:
  /// **'Claro'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In pt, this message translates to:
  /// **'Escuro'**
  String get dark;

  /// No description provided for @auto.
  ///
  /// In pt, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @syncSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Sincronize as suas notas com kDrive ou WebDAV'**
  String get syncSubtitle;

  /// No description provided for @reportBugSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Reporte um bug, sugira uma funcionalidade, ou deixe um comentário'**
  String get reportBugSubtitle;

  /// No description provided for @sharedNote.
  ///
  /// In pt, this message translates to:
  /// **'Nota partilhada'**
  String get sharedNote;

  /// No description provided for @colorsTab.
  ///
  /// In pt, this message translates to:
  /// **'Cores (16)'**
  String get colorsTab;

  /// No description provided for @imagesTab.
  ///
  /// In pt, this message translates to:
  /// **'Imagens (16)'**
  String get imagesTab;

  /// No description provided for @noteSentToTrash.
  ///
  /// In pt, this message translates to:
  /// **'Nota enviada para a lixeira'**
  String get noteSentToTrash;

  /// No description provided for @notesArchivedCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} notas arquivadas'**
  String notesArchivedCount(String count);

  /// No description provided for @notesSentToTrashCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} notas enviadas para a lixeira'**
  String notesSentToTrashCount(String count);

  /// No description provided for @lastSyncJustNow.
  ///
  /// In pt, this message translates to:
  /// **'Agora há pouco'**
  String get lastSyncJustNow;

  /// No description provided for @lastSyncMinutesAgo.
  ///
  /// In pt, this message translates to:
  /// **'Há {minutes} min'**
  String lastSyncMinutesAgo(String minutes);

  /// No description provided for @lastSyncHoursAgo.
  ///
  /// In pt, this message translates to:
  /// **'Há {hours} h'**
  String lastSyncHoursAgo(String hours);

  /// No description provided for @lastSyncNever.
  ///
  /// In pt, this message translates to:
  /// **'Nunca'**
  String get lastSyncNever;

  /// No description provided for @syncErrorWithDetail.
  ///
  /// In pt, this message translates to:
  /// **'Erro de sincronização: {error}'**
  String syncErrorWithDetail(String error);

  /// No description provided for @configSaveError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao guardar configuração: {error}'**
  String configSaveError(String error);

  /// No description provided for @syncPartialFailure.
  ///
  /// In pt, this message translates to:
  /// **'Sincronização concluída, mas {count} ficheiro(s) não puderam ser desencriptados. Verifique se a passphrase está correta.'**
  String syncPartialFailure(String count);

  /// No description provided for @activeSyncTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sincronização ativa'**
  String get activeSyncTitle;

  /// No description provided for @inactiveSyncTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sincronização desativada'**
  String get inactiveSyncTitle;

  /// No description provided for @configureRemoteSection.
  ///
  /// In pt, this message translates to:
  /// **'CONFIGURAR ARMAZENAMENTO REMOTO'**
  String get configureRemoteSection;

  /// No description provided for @selectDrive.
  ///
  /// In pt, this message translates to:
  /// **'Selecione um drive'**
  String get selectDrive;

  /// No description provided for @syncingNow.
  ///
  /// In pt, this message translates to:
  /// **'A sincronizar...'**
  String get syncingNow;

  /// No description provided for @syncNowButton.
  ///
  /// In pt, this message translates to:
  /// **'Sincronizar agora'**
  String get syncNowButton;

  /// No description provided for @selectedFolder.
  ///
  /// In pt, this message translates to:
  /// **'Pasta selecionada: {name}'**
  String selectedFolder(String name);

  /// No description provided for @selectFolderToStoreNotes.
  ///
  /// In pt, this message translates to:
  /// **'Selecione uma pasta para guardar as notas'**
  String get selectFolderToStoreNotes;

  /// No description provided for @folderWord.
  ///
  /// In pt, this message translates to:
  /// **'Pasta'**
  String get folderWord;

  /// No description provided for @itemWord.
  ///
  /// In pt, this message translates to:
  /// **'Item'**
  String get itemWord;

  /// No description provided for @folderIdLabel.
  ///
  /// In pt, this message translates to:
  /// **'Pasta (ID: {id})'**
  String folderIdLabel(String id);

  /// No description provided for @fileIdLabel.
  ///
  /// In pt, this message translates to:
  /// **'Ficheiro (ID: {id})'**
  String fileIdLabel(String id);

  /// No description provided for @idLabel.
  ///
  /// In pt, this message translates to:
  /// **'ID: {id}'**
  String idLabel(String id);

  /// No description provided for @cannotCreateInFile.
  ///
  /// In pt, this message translates to:
  /// **'Não é possível criar pasta dentro de um ficheiro (tipo: {type}).'**
  String cannotCreateInFile(String type);

  /// No description provided for @errorListingFolder.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao listar pasta: {error}'**
  String errorListingFolder(String error);

  /// No description provided for @createInFolder.
  ///
  /// In pt, this message translates to:
  /// **'Criar dentro de: {name}'**
  String createInFolder(String name);

  /// No description provided for @errorCreatingFolderIn.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao criar pasta em \"{folder}\": {error}'**
  String errorCreatingFolderIn(String folder, String error);

  /// No description provided for @scopeDrive.
  ///
  /// In pt, this message translates to:
  /// **'Produtos kDrive'**
  String get scopeDrive;

  /// No description provided for @scopeUserInfo.
  ///
  /// In pt, this message translates to:
  /// **'Informações do perfil'**
  String get scopeUserInfo;

  /// No description provided for @scopeAccounts.
  ///
  /// In pt, this message translates to:
  /// **'Listar contas'**
  String get scopeAccounts;

  /// No description provided for @noValidAccount.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma conta Infomaniak válida encontrada para este token.'**
  String get noValidAccount;

  /// No description provided for @errorDiscoveringAccounts.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao descobrir contas/drives: {error}'**
  String errorDiscoveringAccounts(String error);

  /// No description provided for @privateFolderEmpty.
  ///
  /// In pt, this message translates to:
  /// **'A pasta Private está vazia.'**
  String get privateFolderEmpty;

  /// No description provided for @errorListingPrivateFolder.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao listar pasta Private: {error}'**
  String errorListingPrivateFolder(String error);

  /// No description provided for @restore.
  ///
  /// In pt, this message translates to:
  /// **'Restaurar'**
  String get restore;

  /// No description provided for @imageAttachmentsCount.
  ///
  /// In pt, this message translates to:
  /// **'Anexos de imagem ({count})'**
  String imageAttachmentsCount(String count);

  /// No description provided for @updatedOn.
  ///
  /// In pt, this message translates to:
  /// **'Atualizado: {date}'**
  String updatedOn(String date);

  /// No description provided for @notesUnarchivedCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} notas retiradas do arquivo'**
  String notesUnarchivedCount(String count);

  /// No description provided for @notesRestoredCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} notas restauradas'**
  String notesRestoredCount(String count);

  /// No description provided for @searchCounter.
  ///
  /// In pt, this message translates to:
  /// **'{current} de {total}'**
  String searchCounter(String current, String total);

  /// No description provided for @decryptionFailuresCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} ficheiro(s) não puderam ser desencriptados. Verifique a passphrase.'**
  String decryptionFailuresCount(String count);

  /// No description provided for @widgetUntitled.
  ///
  /// In pt, this message translates to:
  /// **'Sem título'**
  String get widgetUntitled;

  /// No description provided for @widgetEmptyNote.
  ///
  /// In pt, this message translates to:
  /// **'Nota vazia'**
  String get widgetEmptyNote;

  /// No description provided for @emptyNoteRejected.
  ///
  /// In pt, this message translates to:
  /// **'Nota vazia rejeitada'**
  String get emptyNoteRejected;

  /// No description provided for @languageSetting.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get languageSetting;

  /// No description provided for @system.
  ///
  /// In pt, this message translates to:
  /// **'Sistema'**
  String get system;

  /// No description provided for @editor.
  ///
  /// In pt, this message translates to:
  /// **'EDITOR'**
  String get editor;

  /// No description provided for @autoWrapLines.
  ///
  /// In pt, this message translates to:
  /// **'Quebra de linha automática'**
  String get autoWrapLines;

  /// No description provided for @autoWrapLinesSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Quebra linhas longas em títulos e itens de lista.'**
  String get autoWrapLinesSubtitle;

  /// No description provided for @strikethroughChecked.
  ///
  /// In pt, this message translates to:
  /// **'Rasurar texto de itens marcados'**
  String get strikethroughChecked;

  /// No description provided for @strikethroughCheckedSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Aplica tachado aos itens de lista marcados como concluídos.'**
  String get strikethroughCheckedSubtitle;

  /// No description provided for @previewLink.
  ///
  /// In pt, this message translates to:
  /// **'Pré-visualizar'**
  String get previewLink;

  /// No description provided for @linkCopied.
  ///
  /// In pt, this message translates to:
  /// **'Link copiado'**
  String get linkCopied;

  /// No description provided for @linkPreviewRemoved.
  ///
  /// In pt, this message translates to:
  /// **'Pré-visualização removida'**
  String get linkPreviewRemoved;

  /// No description provided for @openLink.
  ///
  /// In pt, this message translates to:
  /// **'Abrir URL'**
  String get openLink;

  /// No description provided for @copyLink.
  ///
  /// In pt, this message translates to:
  /// **'Copiar URL'**
  String get copyLink;

  /// No description provided for @removePreview.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get removePreview;

  /// No description provided for @openLinkShort.
  ///
  /// In pt, this message translates to:
  /// **'Abrir'**
  String get openLinkShort;

  /// No description provided for @editLink.
  ///
  /// In pt, this message translates to:
  /// **'Editar'**
  String get editLink;

  /// No description provided for @kdriveNotConfigured.
  ///
  /// In pt, this message translates to:
  /// **'kDrive não está configurado'**
  String get kdriveNotConfigured;

  /// No description provided for @copiedToKdrive.
  ///
  /// In pt, this message translates to:
  /// **'Copiado para kDrive'**
  String get copiedToKdrive;

  /// No description provided for @copyToKdriveFailed.
  ///
  /// In pt, this message translates to:
  /// **'Falha ao copiar para kDrive'**
  String get copyToKdriveFailed;

  /// No description provided for @checkForUpdates.
  ///
  /// In pt, this message translates to:
  /// **'Verificar atualizações'**
  String get checkForUpdates;

  /// No description provided for @upToDateMessage.
  ///
  /// In pt, this message translates to:
  /// **'Está a usar a versão mais recente ({version}).'**
  String upToDateMessage(String version);

  /// No description provided for @newVersionAvailable.
  ///
  /// In pt, this message translates to:
  /// **'Nova versão disponível'**
  String get newVersionAvailable;

  /// No description provided for @newVersionMessage.
  ///
  /// In pt, this message translates to:
  /// **'A versão {version} está disponível. Está a usar a {current}.'**
  String newVersionMessage(String version, String current);

  /// No description provided for @downloadUpdate.
  ///
  /// In pt, this message translates to:
  /// **'Transferir'**
  String get downloadUpdate;

  /// No description provided for @viewReleasePage.
  ///
  /// In pt, this message translates to:
  /// **'Ver página da release'**
  String get viewReleasePage;

  /// No description provided for @later.
  ///
  /// In pt, this message translates to:
  /// **'Mais tarde'**
  String get later;

  /// No description provided for @updateCheckFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível verificar atualizações'**
  String get updateCheckFailed;

  /// No description provided for @releaseNotes.
  ///
  /// In pt, this message translates to:
  /// **'Notas da release'**
  String get releaseNotes;

  /// No description provided for @showLinkPreviews.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar pré-visualizações de links'**
  String get showLinkPreviews;

  /// No description provided for @showLinkPreviewsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Mostra cartões de pré-visualização para links nas notas'**
  String get showLinkPreviewsSubtitle;

  /// No description provided for @enableEncryptionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ativar encriptação'**
  String get enableEncryptionTitle;

  /// No description provided for @enableEncryptionMessage.
  ///
  /// In pt, this message translates to:
  /// **'As notas locais serão encriptadas com a nova passphrase e reenviadas, substituindo as cópias remotas. As notas remotas serão descarregadas e desencriptadas.'**
  String get enableEncryptionMessage;

  /// No description provided for @disableEncryptionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Desativar encriptação'**
  String get disableEncryptionTitle;

  /// No description provided for @disableEncryptionMessage.
  ///
  /// In pt, this message translates to:
  /// **'As notas locais serão reenviadas SEM encriptação, substituindo as cópias remotas encriptadas. As notas remotas serão descarregadas e guardadas localmente.'**
  String get disableEncryptionMessage;

  /// No description provided for @searchNotes.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisar notas…'**
  String get searchNotes;

  /// No description provided for @noResults.
  ///
  /// In pt, this message translates to:
  /// **'Sem resultados'**
  String get noResults;

  /// No description provided for @sortBy.
  ///
  /// In pt, this message translates to:
  /// **'Ordenar por'**
  String get sortBy;

  /// No description provided for @sortByUpdated.
  ///
  /// In pt, this message translates to:
  /// **'Última alteração'**
  String get sortByUpdated;

  /// No description provided for @sortByCreated.
  ///
  /// In pt, this message translates to:
  /// **'Data de criação'**
  String get sortByCreated;

  /// No description provided for @sortByCustom.
  ///
  /// In pt, this message translates to:
  /// **'Ordem personalizada'**
  String get sortByCustom;

  /// No description provided for @ascending.
  ///
  /// In pt, this message translates to:
  /// **'Ascendente'**
  String get ascending;

  /// No description provided for @descending.
  ///
  /// In pt, this message translates to:
  /// **'Descendente'**
  String get descending;

  /// No description provided for @pin.
  ///
  /// In pt, this message translates to:
  /// **'Fixar'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In pt, this message translates to:
  /// **'Desafixar'**
  String get unpin;

  /// No description provided for @widget.
  ///
  /// In pt, this message translates to:
  /// **'WIDGETS'**
  String get widget;

  /// No description provided for @widgetBackgroundTransparency.
  ///
  /// In pt, this message translates to:
  /// **'Transparência do fundo do widget'**
  String get widgetBackgroundTransparency;

  /// No description provided for @widgetCardTransparency.
  ///
  /// In pt, this message translates to:
  /// **'Transparência dos cards'**
  String get widgetCardTransparency;

  /// No description provided for @transparencyPercent.
  ///
  /// In pt, this message translates to:
  /// **'{value}%'**
  String transparencyPercent(int value);

  /// No description provided for @maintenanceSection.
  ///
  /// In pt, this message translates to:
  /// **'MANUTENÇÃO'**
  String get maintenanceSection;

  /// No description provided for @clearOldVersions.
  ///
  /// In pt, this message translates to:
  /// **'Limpar versões antigas'**
  String get clearOldVersions;

  /// No description provided for @clearOldVersionsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Apaga o histórico de versões guardado no kDrive. A versão atual de cada nota é mantida.'**
  String get clearOldVersionsSubtitle;

  /// No description provided for @clearOldVersionsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Limpar versões antigas?'**
  String get clearOldVersionsTitle;

  /// No description provided for @clearOldVersionsMessage.
  ///
  /// In pt, this message translates to:
  /// **'Cada alteração guarda o conteúdo anterior como uma versão no kDrive. As versões antigas mantêm o conteúdo com que foram escritas, incluindo texto simples guardado antes de ativar a encriptação. Esta operação remove o histórico de todas as notas da pasta selecionada e mantém apenas a versão atual. Não pode ser desfeita no kMemo nem na aplicação web do kDrive.'**
  String get clearOldVersionsMessage;

  /// No description provided for @clearingVersions.
  ///
  /// In pt, this message translates to:
  /// **'A limpar versões antigas…'**
  String get clearingVersions;

  /// No description provided for @clearOldVersionsDone.
  ///
  /// In pt, this message translates to:
  /// **'Versões antigas removidas de {count} nota(s).'**
  String clearOldVersionsDone(int count);

  /// No description provided for @clearOldVersionsError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível limpar as versões: {error}'**
  String clearOldVersionsError(String error);

  /// No description provided for @webdavServerUrl.
  ///
  /// In pt, this message translates to:
  /// **'URL do servidor'**
  String get webdavServerUrl;

  /// No description provided for @webdavUsername.
  ///
  /// In pt, this message translates to:
  /// **'Utilizador'**
  String get webdavUsername;

  /// No description provided for @webdavPassword.
  ///
  /// In pt, this message translates to:
  /// **'Palavra-passe'**
  String get webdavPassword;

  /// No description provided for @webdavPasswordKeepHint.
  ///
  /// In pt, this message translates to:
  /// **'Deixe vazio para manter a palavra-passe guardada'**
  String get webdavPasswordKeepHint;

  /// No description provided for @webdavFolderLabel.
  ///
  /// In pt, this message translates to:
  /// **'Pasta de destino'**
  String get webdavFolderLabel;

  /// No description provided for @webdavTestConnection.
  ///
  /// In pt, this message translates to:
  /// **'Testar ligação'**
  String get webdavTestConnection;

  /// No description provided for @webdavConnectionOk.
  ///
  /// In pt, this message translates to:
  /// **'Ligação estabelecida'**
  String get webdavConnectionOk;

  /// No description provided for @webdavConnectionFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível ligar: {error}'**
  String webdavConnectionFailed(String error);

  /// No description provided for @webdavConfigurationSaved.
  ///
  /// In pt, this message translates to:
  /// **'Configuração guardada'**
  String get webdavConfigurationSaved;

  /// No description provided for @webdavRemoveConfiguration.
  ///
  /// In pt, this message translates to:
  /// **'Remover configuração'**
  String get webdavRemoveConfiguration;

  /// No description provided for @webdavMissingFields.
  ///
  /// In pt, this message translates to:
  /// **'Preencha o URL, o utilizador e a palavra-passe.'**
  String get webdavMissingFields;

  /// No description provided for @save.
  ///
  /// In pt, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @webdavServerUrlHint.
  ///
  /// In pt, this message translates to:
  /// **'Sem http/https — assume https. Ex.: cloud.example.com/remote.php/dav'**
  String get webdavServerUrlHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
