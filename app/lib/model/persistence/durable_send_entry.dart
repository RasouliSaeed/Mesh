import 'package:dart_mappable/dart_mappable.dart';

part 'durable_send_entry.mapper.dart';

@MappableClass()
class DurableSendEntry with DurableSendEntryMappable {
  final String transferId;
  final String targetDeviceAlias;
  final String targetFingerprint;
  final String targetIp;
  final int targetPort;
  final String filePath;
  final String fileName;
  final int fileSize;
  final int bytesTransferred;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? errorMessage;

  const DurableSendEntry({
    required this.transferId,
    required this.targetDeviceAlias,
    required this.targetFingerprint,
    required this.targetIp,
    required this.targetPort,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.bytesTransferred,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.errorMessage,
  });

  static const fromJson = DurableSendEntryMapper.fromJson;
}
