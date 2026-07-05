// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MemosTable extends Memos with TableInfo<$MemosTable, Memo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _remoteFileIdMeta = const VerificationMeta(
    'remoteFileId',
  );
  @override
  late final GeneratedColumn<String> remoteFileId = GeneratedColumn<String>(
    'remote_file_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bgImageIndexMeta = const VerificationMeta(
    'bgImageIndex',
  );
  @override
  late final GeneratedColumn<int> bgImageIndex = GeneratedColumn<int>(
    'bg_image_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  static const VerificationMeta _imageAttachmentsMeta = const VerificationMeta(
    'imageAttachments',
  );
  @override
  late final GeneratedColumn<String> imageAttachments = GeneratedColumn<String>(
    'image_attachments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _audioAttachmentsMeta = const VerificationMeta(
    'audioAttachments',
  );
  @override
  late final GeneratedColumn<String> audioAttachments = GeneratedColumn<String>(
    'audio_attachments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _linkAttachmentsMeta = const VerificationMeta(
    'linkAttachments',
  );
  @override
  late final GeneratedColumn<String> linkAttachments = GeneratedColumn<String>(
    'link_attachments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    title,
    createdAt,
    updatedAt,
    isSynced,
    remoteFileId,
    colorIndex,
    bgImageIndex,
    imageAttachments,
    audioAttachments,
    linkAttachments,
    isArchived,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Memo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('remote_file_id')) {
      context.handle(
        _remoteFileIdMeta,
        remoteFileId.isAcceptableOrUnknown(
          data['remote_file_id']!,
          _remoteFileIdMeta,
        ),
      );
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    if (data.containsKey('bg_image_index')) {
      context.handle(
        _bgImageIndexMeta,
        bgImageIndex.isAcceptableOrUnknown(
          data['bg_image_index']!,
          _bgImageIndexMeta,
        ),
      );
    }
    if (data.containsKey('image_attachments')) {
      context.handle(
        _imageAttachmentsMeta,
        imageAttachments.isAcceptableOrUnknown(
          data['image_attachments']!,
          _imageAttachmentsMeta,
        ),
      );
    }
    if (data.containsKey('audio_attachments')) {
      context.handle(
        _audioAttachmentsMeta,
        audioAttachments.isAcceptableOrUnknown(
          data['audio_attachments']!,
          _audioAttachmentsMeta,
        ),
      );
    }
    if (data.containsKey('link_attachments')) {
      context.handle(
        _linkAttachmentsMeta,
        linkAttachments.isAcceptableOrUnknown(
          data['link_attachments']!,
          _linkAttachmentsMeta,
        ),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  Memo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Memo(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
      remoteFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_file_id'],
      ),
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      bgImageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bg_image_index'],
      )!,
      imageAttachments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_attachments'],
      )!,
      audioAttachments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_attachments'],
      )!,
      linkAttachments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link_attachments'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $MemosTable createAlias(String alias) {
    return $MemosTable(attachedDatabase, alias);
  }
}

class Memo extends DataClass implements Insertable<Memo> {
  final String uuid;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String? remoteFileId;
  final int colorIndex;
  final int bgImageIndex;
  final String imageAttachments;
  final String audioAttachments;
  final String linkAttachments;
  final bool isArchived;
  final bool isDeleted;
  const Memo({
    required this.uuid,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
    this.remoteFileId,
    required this.colorIndex,
    required this.bgImageIndex,
    required this.imageAttachments,
    required this.audioAttachments,
    required this.linkAttachments,
    required this.isArchived,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_synced'] = Variable<bool>(isSynced);
    if (!nullToAbsent || remoteFileId != null) {
      map['remote_file_id'] = Variable<String>(remoteFileId);
    }
    map['color_index'] = Variable<int>(colorIndex);
    map['bg_image_index'] = Variable<int>(bgImageIndex);
    map['image_attachments'] = Variable<String>(imageAttachments);
    map['audio_attachments'] = Variable<String>(audioAttachments);
    map['link_attachments'] = Variable<String>(linkAttachments);
    map['is_archived'] = Variable<bool>(isArchived);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  MemosCompanion toCompanion(bool nullToAbsent) {
    return MemosCompanion(
      uuid: Value(uuid),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isSynced: Value(isSynced),
      remoteFileId: remoteFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteFileId),
      colorIndex: Value(colorIndex),
      bgImageIndex: Value(bgImageIndex),
      imageAttachments: Value(imageAttachments),
      audioAttachments: Value(audioAttachments),
      linkAttachments: Value(linkAttachments),
      isArchived: Value(isArchived),
      isDeleted: Value(isDeleted),
    );
  }

  factory Memo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Memo(
      uuid: serializer.fromJson<String>(json['uuid']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      remoteFileId: serializer.fromJson<String?>(json['remoteFileId']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      bgImageIndex: serializer.fromJson<int>(json['bgImageIndex']),
      imageAttachments: serializer.fromJson<String>(json['imageAttachments']),
      audioAttachments: serializer.fromJson<String>(json['audioAttachments']),
      linkAttachments: serializer.fromJson<String>(json['linkAttachments']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isSynced': serializer.toJson<bool>(isSynced),
      'remoteFileId': serializer.toJson<String?>(remoteFileId),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'bgImageIndex': serializer.toJson<int>(bgImageIndex),
      'imageAttachments': serializer.toJson<String>(imageAttachments),
      'audioAttachments': serializer.toJson<String>(audioAttachments),
      'linkAttachments': serializer.toJson<String>(linkAttachments),
      'isArchived': serializer.toJson<bool>(isArchived),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  Memo copyWith({
    String? uuid,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    Value<String?> remoteFileId = const Value.absent(),
    int? colorIndex,
    int? bgImageIndex,
    String? imageAttachments,
    String? audioAttachments,
    String? linkAttachments,
    bool? isArchived,
    bool? isDeleted,
  }) => Memo(
    uuid: uuid ?? this.uuid,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isSynced: isSynced ?? this.isSynced,
    remoteFileId: remoteFileId.present ? remoteFileId.value : this.remoteFileId,
    colorIndex: colorIndex ?? this.colorIndex,
    bgImageIndex: bgImageIndex ?? this.bgImageIndex,
    imageAttachments: imageAttachments ?? this.imageAttachments,
    audioAttachments: audioAttachments ?? this.audioAttachments,
    linkAttachments: linkAttachments ?? this.linkAttachments,
    isArchived: isArchived ?? this.isArchived,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  Memo copyWithCompanion(MemosCompanion data) {
    return Memo(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      remoteFileId: data.remoteFileId.present
          ? data.remoteFileId.value
          : this.remoteFileId,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      bgImageIndex: data.bgImageIndex.present
          ? data.bgImageIndex.value
          : this.bgImageIndex,
      imageAttachments: data.imageAttachments.present
          ? data.imageAttachments.value
          : this.imageAttachments,
      audioAttachments: data.audioAttachments.present
          ? data.audioAttachments.value
          : this.audioAttachments,
      linkAttachments: data.linkAttachments.present
          ? data.linkAttachments.value
          : this.linkAttachments,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Memo(')
          ..write('uuid: $uuid, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('remoteFileId: $remoteFileId, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('bgImageIndex: $bgImageIndex, ')
          ..write('imageAttachments: $imageAttachments, ')
          ..write('audioAttachments: $audioAttachments, ')
          ..write('linkAttachments: $linkAttachments, ')
          ..write('isArchived: $isArchived, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    title,
    createdAt,
    updatedAt,
    isSynced,
    remoteFileId,
    colorIndex,
    bgImageIndex,
    imageAttachments,
    audioAttachments,
    linkAttachments,
    isArchived,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Memo &&
          other.uuid == this.uuid &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isSynced == this.isSynced &&
          other.remoteFileId == this.remoteFileId &&
          other.colorIndex == this.colorIndex &&
          other.bgImageIndex == this.bgImageIndex &&
          other.imageAttachments == this.imageAttachments &&
          other.audioAttachments == this.audioAttachments &&
          other.linkAttachments == this.linkAttachments &&
          other.isArchived == this.isArchived &&
          other.isDeleted == this.isDeleted);
}

class MemosCompanion extends UpdateCompanion<Memo> {
  final Value<String> uuid;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isSynced;
  final Value<String?> remoteFileId;
  final Value<int> colorIndex;
  final Value<int> bgImageIndex;
  final Value<String> imageAttachments;
  final Value<String> audioAttachments;
  final Value<String> linkAttachments;
  final Value<bool> isArchived;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const MemosCompanion({
    this.uuid = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.remoteFileId = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.bgImageIndex = const Value.absent(),
    this.imageAttachments = const Value.absent(),
    this.audioAttachments = const Value.absent(),
    this.linkAttachments = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemosCompanion.insert({
    required String uuid,
    this.title = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.isSynced = const Value.absent(),
    this.remoteFileId = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.bgImageIndex = const Value.absent(),
    this.imageAttachments = const Value.absent(),
    this.audioAttachments = const Value.absent(),
    this.linkAttachments = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Memo> custom({
    Expression<String>? uuid,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isSynced,
    Expression<String>? remoteFileId,
    Expression<int>? colorIndex,
    Expression<int>? bgImageIndex,
    Expression<String>? imageAttachments,
    Expression<String>? audioAttachments,
    Expression<String>? linkAttachments,
    Expression<bool>? isArchived,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isSynced != null) 'is_synced': isSynced,
      if (remoteFileId != null) 'remote_file_id': remoteFileId,
      if (colorIndex != null) 'color_index': colorIndex,
      if (bgImageIndex != null) 'bg_image_index': bgImageIndex,
      if (imageAttachments != null) 'image_attachments': imageAttachments,
      if (audioAttachments != null) 'audio_attachments': audioAttachments,
      if (linkAttachments != null) 'link_attachments': linkAttachments,
      if (isArchived != null) 'is_archived': isArchived,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemosCompanion copyWith({
    Value<String>? uuid,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isSynced,
    Value<String?>? remoteFileId,
    Value<int>? colorIndex,
    Value<int>? bgImageIndex,
    Value<String>? imageAttachments,
    Value<String>? audioAttachments,
    Value<String>? linkAttachments,
    Value<bool>? isArchived,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return MemosCompanion(
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      remoteFileId: remoteFileId ?? this.remoteFileId,
      colorIndex: colorIndex ?? this.colorIndex,
      bgImageIndex: bgImageIndex ?? this.bgImageIndex,
      imageAttachments: imageAttachments ?? this.imageAttachments,
      audioAttachments: audioAttachments ?? this.audioAttachments,
      linkAttachments: linkAttachments ?? this.linkAttachments,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (remoteFileId.present) {
      map['remote_file_id'] = Variable<String>(remoteFileId.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (bgImageIndex.present) {
      map['bg_image_index'] = Variable<int>(bgImageIndex.value);
    }
    if (imageAttachments.present) {
      map['image_attachments'] = Variable<String>(imageAttachments.value);
    }
    if (audioAttachments.present) {
      map['audio_attachments'] = Variable<String>(audioAttachments.value);
    }
    if (linkAttachments.present) {
      map['link_attachments'] = Variable<String>(linkAttachments.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemosCompanion(')
          ..write('uuid: $uuid, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('remoteFileId: $remoteFileId, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('bgImageIndex: $bgImageIndex, ')
          ..write('imageAttachments: $imageAttachments, ')
          ..write('audioAttachments: $audioAttachments, ')
          ..write('linkAttachments: $linkAttachments, ')
          ..write('isArchived: $isArchived, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlocksTable extends Blocks with TableInfo<$BlocksTable, Block> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoUuidMeta = const VerificationMeta(
    'memoUuid',
  );
  @override
  late final GeneratedColumn<String> memoUuid = GeneratedColumn<String>(
    'memo_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memos (uuid) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<BlockType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BlockType>($BlocksTable.$convertertype);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
  content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  ).withConverter<Map<String, dynamic>>($BlocksTable.$convertercontent);
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    memoUuid,
    type,
    content,
    sortOrder,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Block> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('memo_uuid')) {
      context.handle(
        _memoUuidMeta,
        memoUuid.isAcceptableOrUnknown(data['memo_uuid']!, _memoUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_memoUuidMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Block map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Block(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      memoUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo_uuid'],
      )!,
      type: $BlocksTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      content: $BlocksTable.$convertercontent.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}content'],
        )!,
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $BlocksTable createAlias(String alias) {
    return $BlocksTable(attachedDatabase, alias);
  }

  static TypeConverter<BlockType, String> $convertertype =
      const BlockTypeConverter();
  static TypeConverter<Map<String, dynamic>, String> $convertercontent =
      const MapConverter();
}

class Block extends DataClass implements Insertable<Block> {
  final int id;
  final String uuid;
  final String memoUuid;
  final BlockType type;
  final Map<String, dynamic> content;
  final int sortOrder;
  final bool isDeleted;
  const Block({
    required this.id,
    required this.uuid,
    required this.memoUuid,
    required this.type,
    required this.content,
    required this.sortOrder,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['memo_uuid'] = Variable<String>(memoUuid);
    {
      map['type'] = Variable<String>($BlocksTable.$convertertype.toSql(type));
    }
    {
      map['content'] = Variable<String>(
        $BlocksTable.$convertercontent.toSql(content),
      );
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  BlocksCompanion toCompanion(bool nullToAbsent) {
    return BlocksCompanion(
      id: Value(id),
      uuid: Value(uuid),
      memoUuid: Value(memoUuid),
      type: Value(type),
      content: Value(content),
      sortOrder: Value(sortOrder),
      isDeleted: Value(isDeleted),
    );
  }

  factory Block.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Block(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      memoUuid: serializer.fromJson<String>(json['memoUuid']),
      type: serializer.fromJson<BlockType>(json['type']),
      content: serializer.fromJson<Map<String, dynamic>>(json['content']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'memoUuid': serializer.toJson<String>(memoUuid),
      'type': serializer.toJson<BlockType>(type),
      'content': serializer.toJson<Map<String, dynamic>>(content),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  Block copyWith({
    int? id,
    String? uuid,
    String? memoUuid,
    BlockType? type,
    Map<String, dynamic>? content,
    int? sortOrder,
    bool? isDeleted,
  }) => Block(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    memoUuid: memoUuid ?? this.memoUuid,
    type: type ?? this.type,
    content: content ?? this.content,
    sortOrder: sortOrder ?? this.sortOrder,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  Block copyWithCompanion(BlocksCompanion data) {
    return Block(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      memoUuid: data.memoUuid.present ? data.memoUuid.value : this.memoUuid,
      type: data.type.present ? data.type.value : this.type,
      content: data.content.present ? data.content.value : this.content,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Block(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('memoUuid: $memoUuid, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, uuid, memoUuid, type, content, sortOrder, isDeleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Block &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.memoUuid == this.memoUuid &&
          other.type == this.type &&
          other.content == this.content &&
          other.sortOrder == this.sortOrder &&
          other.isDeleted == this.isDeleted);
}

class BlocksCompanion extends UpdateCompanion<Block> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> memoUuid;
  final Value<BlockType> type;
  final Value<Map<String, dynamic>> content;
  final Value<int> sortOrder;
  final Value<bool> isDeleted;
  const BlocksCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.memoUuid = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  BlocksCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String memoUuid,
    required BlockType type,
    this.content = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : uuid = Value(uuid),
       memoUuid = Value(memoUuid),
       type = Value(type);
  static Insertable<Block> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? memoUuid,
    Expression<String>? type,
    Expression<String>? content,
    Expression<int>? sortOrder,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (memoUuid != null) 'memo_uuid': memoUuid,
      if (type != null) 'type': type,
      if (content != null) 'content': content,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  BlocksCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? memoUuid,
    Value<BlockType>? type,
    Value<Map<String, dynamic>>? content,
    Value<int>? sortOrder,
    Value<bool>? isDeleted,
  }) {
    return BlocksCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      memoUuid: memoUuid ?? this.memoUuid,
      type: type ?? this.type,
      content: content ?? this.content,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (memoUuid.present) {
      map['memo_uuid'] = Variable<String>(memoUuid.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $BlocksTable.$convertertype.toSql(type.value),
      );
    }
    if (content.present) {
      map['content'] = Variable<String>(
        $BlocksTable.$convertercontent.toSql(content.value),
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlocksCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('memoUuid: $memoUuid, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MemosTable memos = $MemosTable(this);
  late final $BlocksTable blocks = $BlocksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [memos, blocks];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'memos',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('blocks', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MemosTableCreateCompanionBuilder =
    MemosCompanion Function({
      required String uuid,
      Value<String> title,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> isSynced,
      Value<String?> remoteFileId,
      Value<int> colorIndex,
      Value<int> bgImageIndex,
      Value<String> imageAttachments,
      Value<String> audioAttachments,
      Value<String> linkAttachments,
      Value<bool> isArchived,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$MemosTableUpdateCompanionBuilder =
    MemosCompanion Function({
      Value<String> uuid,
      Value<String> title,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isSynced,
      Value<String?> remoteFileId,
      Value<int> colorIndex,
      Value<int> bgImageIndex,
      Value<String> imageAttachments,
      Value<String> audioAttachments,
      Value<String> linkAttachments,
      Value<bool> isArchived,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

final class $$MemosTableReferences
    extends BaseReferences<_$AppDatabase, $MemosTable, Memo> {
  $$MemosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BlocksTable, List<Block>> _blocksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.blocks,
    aliasName: 'memos__uuid__blocks__memo_uuid',
  );

  $$BlocksTableProcessedTableManager get blocksRefs {
    final manager = $$BlocksTableTableManager(
      $_db,
      $_db.blocks,
    ).filter((f) => f.memoUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_blocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MemosTableFilterComposer extends Composer<_$AppDatabase, $MemosTable> {
  $$MemosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteFileId => $composableBuilder(
    column: $table.remoteFileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bgImageIndex => $composableBuilder(
    column: $table.bgImageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageAttachments => $composableBuilder(
    column: $table.imageAttachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioAttachments => $composableBuilder(
    column: $table.audioAttachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkAttachments => $composableBuilder(
    column: $table.linkAttachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> blocksRefs(
    Expression<bool> Function($$BlocksTableFilterComposer f) f,
  ) {
    final $$BlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.blocks,
      getReferencedColumn: (t) => t.memoUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BlocksTableFilterComposer(
            $db: $db,
            $table: $db.blocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemosTableOrderingComposer
    extends Composer<_$AppDatabase, $MemosTable> {
  $$MemosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteFileId => $composableBuilder(
    column: $table.remoteFileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bgImageIndex => $composableBuilder(
    column: $table.bgImageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageAttachments => $composableBuilder(
    column: $table.imageAttachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioAttachments => $composableBuilder(
    column: $table.audioAttachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkAttachments => $composableBuilder(
    column: $table.linkAttachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemosTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemosTable> {
  $$MemosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<String> get remoteFileId => $composableBuilder(
    column: $table.remoteFileId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bgImageIndex => $composableBuilder(
    column: $table.bgImageIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageAttachments => $composableBuilder(
    column: $table.imageAttachments,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioAttachments => $composableBuilder(
    column: $table.audioAttachments,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkAttachments => $composableBuilder(
    column: $table.linkAttachments,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  Expression<T> blocksRefs<T extends Object>(
    Expression<T> Function($$BlocksTableAnnotationComposer a) f,
  ) {
    final $$BlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.blocks,
      getReferencedColumn: (t) => t.memoUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.blocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemosTable,
          Memo,
          $$MemosTableFilterComposer,
          $$MemosTableOrderingComposer,
          $$MemosTableAnnotationComposer,
          $$MemosTableCreateCompanionBuilder,
          $$MemosTableUpdateCompanionBuilder,
          (Memo, $$MemosTableReferences),
          Memo,
          PrefetchHooks Function({bool blocksRefs})
        > {
  $$MemosTableTableManager(_$AppDatabase db, $MemosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<String?> remoteFileId = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int> bgImageIndex = const Value.absent(),
                Value<String> imageAttachments = const Value.absent(),
                Value<String> audioAttachments = const Value.absent(),
                Value<String> linkAttachments = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemosCompanion(
                uuid: uuid,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isSynced: isSynced,
                remoteFileId: remoteFileId,
                colorIndex: colorIndex,
                bgImageIndex: bgImageIndex,
                imageAttachments: imageAttachments,
                audioAttachments: audioAttachments,
                linkAttachments: linkAttachments,
                isArchived: isArchived,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<String> title = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> isSynced = const Value.absent(),
                Value<String?> remoteFileId = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int> bgImageIndex = const Value.absent(),
                Value<String> imageAttachments = const Value.absent(),
                Value<String> audioAttachments = const Value.absent(),
                Value<String> linkAttachments = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemosCompanion.insert(
                uuid: uuid,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isSynced: isSynced,
                remoteFileId: remoteFileId,
                colorIndex: colorIndex,
                bgImageIndex: bgImageIndex,
                imageAttachments: imageAttachments,
                audioAttachments: audioAttachments,
                linkAttachments: linkAttachments,
                isArchived: isArchived,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$MemosTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({blocksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (blocksRefs) db.blocks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (blocksRefs)
                    await $_getPrefetchedData<Memo, $MemosTable, Block>(
                      currentTable: table,
                      referencedTable: $$MemosTableReferences._blocksRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$MemosTableReferences(db, table, p0).blocksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.memoUuid == item.uuid),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MemosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemosTable,
      Memo,
      $$MemosTableFilterComposer,
      $$MemosTableOrderingComposer,
      $$MemosTableAnnotationComposer,
      $$MemosTableCreateCompanionBuilder,
      $$MemosTableUpdateCompanionBuilder,
      (Memo, $$MemosTableReferences),
      Memo,
      PrefetchHooks Function({bool blocksRefs})
    >;
typedef $$BlocksTableCreateCompanionBuilder =
    BlocksCompanion Function({
      Value<int> id,
      required String uuid,
      required String memoUuid,
      required BlockType type,
      Value<Map<String, dynamic>> content,
      Value<int> sortOrder,
      Value<bool> isDeleted,
    });
typedef $$BlocksTableUpdateCompanionBuilder =
    BlocksCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> memoUuid,
      Value<BlockType> type,
      Value<Map<String, dynamic>> content,
      Value<int> sortOrder,
      Value<bool> isDeleted,
    });

final class $$BlocksTableReferences
    extends BaseReferences<_$AppDatabase, $BlocksTable, Block> {
  $$BlocksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MemosTable _memoUuidTable(_$AppDatabase db) =>
      db.memos.createAlias('blocks__memo_uuid__memos__uuid');

  $$MemosTableProcessedTableManager get memoUuid {
    final $_column = $_itemColumn<String>('memo_uuid')!;

    final manager = $$MemosTableTableManager(
      $_db,
      $_db.memos,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memoUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BlocksTableFilterComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BlockType, BlockType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<
    Map<String, dynamic>,
    Map<String, dynamic>,
    String
  >
  get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$MemosTableFilterComposer get memoUuid {
    final $$MemosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoUuid,
      referencedTable: $db.memos,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemosTableFilterComposer(
            $db: $db,
            $table: $db.memos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemosTableOrderingComposer get memoUuid {
    final $$MemosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoUuid,
      referencedTable: $db.memos,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemosTableOrderingComposer(
            $db: $db,
            $table: $db.memos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BlockType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, dynamic>, String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$MemosTableAnnotationComposer get memoUuid {
    final $$MemosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoUuid,
      referencedTable: $db.memos,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemosTableAnnotationComposer(
            $db: $db,
            $table: $db.memos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlocksTable,
          Block,
          $$BlocksTableFilterComposer,
          $$BlocksTableOrderingComposer,
          $$BlocksTableAnnotationComposer,
          $$BlocksTableCreateCompanionBuilder,
          $$BlocksTableUpdateCompanionBuilder,
          (Block, $$BlocksTableReferences),
          Block,
          PrefetchHooks Function({bool memoUuid})
        > {
  $$BlocksTableTableManager(_$AppDatabase db, $BlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> memoUuid = const Value.absent(),
                Value<BlockType> type = const Value.absent(),
                Value<Map<String, dynamic>> content = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => BlocksCompanion(
                id: id,
                uuid: uuid,
                memoUuid: memoUuid,
                type: type,
                content: content,
                sortOrder: sortOrder,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String memoUuid,
                required BlockType type,
                Value<Map<String, dynamic>> content = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => BlocksCompanion.insert(
                id: id,
                uuid: uuid,
                memoUuid: memoUuid,
                type: type,
                content: content,
                sortOrder: sortOrder,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BlocksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({memoUuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (memoUuid) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memoUuid,
                                referencedTable: $$BlocksTableReferences
                                    ._memoUuidTable(db),
                                referencedColumn: $$BlocksTableReferences
                                    ._memoUuidTable(db)
                                    .uuid,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlocksTable,
      Block,
      $$BlocksTableFilterComposer,
      $$BlocksTableOrderingComposer,
      $$BlocksTableAnnotationComposer,
      $$BlocksTableCreateCompanionBuilder,
      $$BlocksTableUpdateCompanionBuilder,
      (Block, $$BlocksTableReferences),
      Block,
      PrefetchHooks Function({bool memoUuid})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MemosTableTableManager get memos =>
      $$MemosTableTableManager(_db, _db.memos);
  $$BlocksTableTableManager get blocks =>
      $$BlocksTableTableManager(_db, _db.blocks);
}
