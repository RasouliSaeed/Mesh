enum RecoverableTransferDirection {
  send,
  receive,
}

class RecoverableTransfer {
  final String transferId;
  final RecoverableTransferDirection direction;
  final String fileName;
  final int fileSize;
  final int bytesTransferred;
  final double progress;
  final String? peerAlias;
  final String? peerFingerprint;
  final String? localPath;
  final bool isResumable;
  final String? unresumableReason;
  final DateTime lastUpdated;

  const RecoverableTransfer({
    required this.transferId,
    required this.direction,
    required this.fileName,
    required this.fileSize,
    required this.bytesTransferred,
    required this.progress,
    this.peerAlias,
    this.peerFingerprint,
    this.localPath,
    required this.isResumable,
    this.unresumableReason,
    required this.lastUpdated,
  });
}
