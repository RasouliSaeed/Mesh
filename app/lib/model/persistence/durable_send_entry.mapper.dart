// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'durable_send_entry.dart';

class DurableSendEntryMapper extends ClassMapperBase<DurableSendEntry> {
  DurableSendEntryMapper._();

  static DurableSendEntryMapper? _instance;
  static DurableSendEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DurableSendEntryMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'DurableSendEntry';

  static String _$transferId(DurableSendEntry v) => v.transferId;
  static const Field<DurableSendEntry, String> _f$transferId = Field(
    'transferId',
    _$transferId,
  );
  static String _$targetDeviceAlias(DurableSendEntry v) => v.targetDeviceAlias;
  static const Field<DurableSendEntry, String> _f$targetDeviceAlias = Field(
    'targetDeviceAlias',
    _$targetDeviceAlias,
  );
  static String _$targetFingerprint(DurableSendEntry v) => v.targetFingerprint;
  static const Field<DurableSendEntry, String> _f$targetFingerprint = Field(
    'targetFingerprint',
    _$targetFingerprint,
  );
  static String _$targetIp(DurableSendEntry v) => v.targetIp;
  static const Field<DurableSendEntry, String> _f$targetIp = Field(
    'targetIp',
    _$targetIp,
  );
  static int _$targetPort(DurableSendEntry v) => v.targetPort;
  static const Field<DurableSendEntry, int> _f$targetPort = Field(
    'targetPort',
    _$targetPort,
  );
  static String _$filePath(DurableSendEntry v) => v.filePath;
  static const Field<DurableSendEntry, String> _f$filePath = Field(
    'filePath',
    _$filePath,
  );
  static String _$fileName(DurableSendEntry v) => v.fileName;
  static const Field<DurableSendEntry, String> _f$fileName = Field(
    'fileName',
    _$fileName,
  );
  static int _$fileSize(DurableSendEntry v) => v.fileSize;
  static const Field<DurableSendEntry, int> _f$fileSize = Field(
    'fileSize',
    _$fileSize,
  );
  static int _$bytesTransferred(DurableSendEntry v) => v.bytesTransferred;
  static const Field<DurableSendEntry, int> _f$bytesTransferred = Field(
    'bytesTransferred',
    _$bytesTransferred,
  );
  static String _$status(DurableSendEntry v) => v.status;
  static const Field<DurableSendEntry, String> _f$status = Field(
    'status',
    _$status,
  );
  static DateTime _$createdAt(DurableSendEntry v) => v.createdAt;
  static const Field<DurableSendEntry, DateTime> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
  );
  static DateTime _$updatedAt(DurableSendEntry v) => v.updatedAt;
  static const Field<DurableSendEntry, DateTime> _f$updatedAt = Field(
    'updatedAt',
    _$updatedAt,
  );
  static String? _$errorMessage(DurableSendEntry v) => v.errorMessage;
  static const Field<DurableSendEntry, String> _f$errorMessage = Field(
    'errorMessage',
    _$errorMessage,
    opt: true,
  );

  @override
  final MappableFields<DurableSendEntry> fields = const {
    #transferId: _f$transferId,
    #targetDeviceAlias: _f$targetDeviceAlias,
    #targetFingerprint: _f$targetFingerprint,
    #targetIp: _f$targetIp,
    #targetPort: _f$targetPort,
    #filePath: _f$filePath,
    #fileName: _f$fileName,
    #fileSize: _f$fileSize,
    #bytesTransferred: _f$bytesTransferred,
    #status: _f$status,
    #createdAt: _f$createdAt,
    #updatedAt: _f$updatedAt,
    #errorMessage: _f$errorMessage,
  };

  static DurableSendEntry _instantiate(DecodingData data) {
    return DurableSendEntry(
      transferId: data.dec(_f$transferId),
      targetDeviceAlias: data.dec(_f$targetDeviceAlias),
      targetFingerprint: data.dec(_f$targetFingerprint),
      targetIp: data.dec(_f$targetIp),
      targetPort: data.dec(_f$targetPort),
      filePath: data.dec(_f$filePath),
      fileName: data.dec(_f$fileName),
      fileSize: data.dec(_f$fileSize),
      bytesTransferred: data.dec(_f$bytesTransferred),
      status: data.dec(_f$status),
      createdAt: data.dec(_f$createdAt),
      updatedAt: data.dec(_f$updatedAt),
      errorMessage: data.dec(_f$errorMessage),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DurableSendEntry fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DurableSendEntry>(map);
  }

  static DurableSendEntry deserialize(String json) {
    return ensureInitialized().decodeJson<DurableSendEntry>(json);
  }
}

mixin DurableSendEntryMappable {
  String serialize() {
    return DurableSendEntryMapper.ensureInitialized()
        .encodeJson<DurableSendEntry>(this as DurableSendEntry);
  }

  Map<String, dynamic> toJson() {
    return DurableSendEntryMapper.ensureInitialized()
        .encodeMap<DurableSendEntry>(this as DurableSendEntry);
  }

  DurableSendEntryCopyWith<DurableSendEntry, DurableSendEntry, DurableSendEntry>
  get copyWith =>
      _DurableSendEntryCopyWithImpl<DurableSendEntry, DurableSendEntry>(
        this as DurableSendEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return DurableSendEntryMapper.ensureInitialized().stringifyValue(
      this as DurableSendEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return DurableSendEntryMapper.ensureInitialized().equalsValue(
      this as DurableSendEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return DurableSendEntryMapper.ensureInitialized().hashValue(
      this as DurableSendEntry,
    );
  }
}

extension DurableSendEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DurableSendEntry, $Out> {
  DurableSendEntryCopyWith<$R, DurableSendEntry, $Out>
  get $asDurableSendEntry =>
      $base.as((v, t, t2) => _DurableSendEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DurableSendEntryCopyWith<$R, $In extends DurableSendEntry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? transferId,
    String? targetDeviceAlias,
    String? targetFingerprint,
    String? targetIp,
    int? targetPort,
    String? filePath,
    String? fileName,
    int? fileSize,
    int? bytesTransferred,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? errorMessage,
  });
  DurableSendEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _DurableSendEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DurableSendEntry, $Out>
    implements DurableSendEntryCopyWith<$R, DurableSendEntry, $Out> {
  _DurableSendEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DurableSendEntry> $mapper =
      DurableSendEntryMapper.ensureInitialized();
  @override
  $R call({
    String? transferId,
    String? targetDeviceAlias,
    String? targetFingerprint,
    String? targetIp,
    int? targetPort,
    String? filePath,
    String? fileName,
    int? fileSize,
    int? bytesTransferred,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? errorMessage = $none,
  }) => $apply(
    FieldCopyWithData({
      if (transferId != null) #transferId: transferId,
      if (targetDeviceAlias != null) #targetDeviceAlias: targetDeviceAlias,
      if (targetFingerprint != null) #targetFingerprint: targetFingerprint,
      if (targetIp != null) #targetIp: targetIp,
      if (targetPort != null) #targetPort: targetPort,
      if (filePath != null) #filePath: filePath,
      if (fileName != null) #fileName: fileName,
      if (fileSize != null) #fileSize: fileSize,
      if (bytesTransferred != null) #bytesTransferred: bytesTransferred,
      if (status != null) #status: status,
      if (createdAt != null) #createdAt: createdAt,
      if (updatedAt != null) #updatedAt: updatedAt,
      if (errorMessage != $none) #errorMessage: errorMessage,
    }),
  );
  @override
  DurableSendEntry $make(CopyWithData data) => DurableSendEntry(
    transferId: data.get(#transferId, or: $value.transferId),
    targetDeviceAlias: data.get(
      #targetDeviceAlias,
      or: $value.targetDeviceAlias,
    ),
    targetFingerprint: data.get(
      #targetFingerprint,
      or: $value.targetFingerprint,
    ),
    targetIp: data.get(#targetIp, or: $value.targetIp),
    targetPort: data.get(#targetPort, or: $value.targetPort),
    filePath: data.get(#filePath, or: $value.filePath),
    fileName: data.get(#fileName, or: $value.fileName),
    fileSize: data.get(#fileSize, or: $value.fileSize),
    bytesTransferred: data.get(#bytesTransferred, or: $value.bytesTransferred),
    status: data.get(#status, or: $value.status),
    createdAt: data.get(#createdAt, or: $value.createdAt),
    updatedAt: data.get(#updatedAt, or: $value.updatedAt),
    errorMessage: data.get(#errorMessage, or: $value.errorMessage),
  );

  @override
  DurableSendEntryCopyWith<$R2, DurableSendEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DurableSendEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

