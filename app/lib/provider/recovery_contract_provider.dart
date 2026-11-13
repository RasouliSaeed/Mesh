import 'dart:async';

import 'package:locara_app/model/recovery/recoverable_transfer.dart';
import 'package:locara_app/provider/durable_send_provider.dart';
import 'package:locara_isolates/isolate.dart';
import 'package:refena_flutter/refena_flutter.dart';

final recoveryContractProvider = AsyncNotifierProvider<RecoveryContractService, List<RecoverableTransfer>>((ref) {
  return RecoveryContractService();
});

class RecoveryContractService extends AsyncNotifier<List<RecoverableTransfer>> {
  StreamSubscription? _durableSendSub;

  /// Exposes the underlying future for awaiting state resolution.
  @override
  Future<List<RecoverableTransfer>> get future => super.future;

  @override
  Future<List<RecoverableTransfer>> init() async {
    _durableSendSub ??= ref.stream(durableSendProvider).listen((_) {
      unawaited(refresh());
    });
    return _fetchRecoverableTransfers();
  }

  @override
  void dispose() {
    // ignore: discarded_futures
    _durableSendSub?.cancel();
    _durableSendSub = null;
    super.dispose();
  }

  Future<List<RecoverableTransfer>> _fetchRecoverableTransfers() async {
    final List<RecoverableTransfer> results = [];

    // 1. Recoverable receiver sessions from Rust core disk metadata
    try {
      final v3ReceiverSessions = await listActiveV3Sessions();
      for (final s in v3ReceiverSessions) {
        final fileSize = s.fileSize.toInt();
        final bytesTransferred = s.bytesTransferred.toInt();
        final progress = fileSize > 0 ? (bytesTransferred / fileSize).clamp(0.0, 1.0) : 0.0;
        final lastUpdatedSec = s.lastUpdatedAt.toInt();
        final lastUpdated = lastUpdatedSec > 0
            ? DateTime.fromMillisecondsSinceEpoch(lastUpdatedSec * 1000, isUtc: true)
            : DateTime.now().toUtc();

        results.add(
          RecoverableTransfer(
            transferId: s.transferId,
            direction: RecoverableTransferDirection.receive,
            fileName: s.fileName ?? s.transferId,
            fileSize: fileSize,
            bytesTransferred: bytesTransferred,
            progress: progress,
            peerAlias: null,
            peerFingerprint: s.authenticatedPeerBinding,
            localPath: null,
            isResumable: s.isResumable,
            unresumableReason: s.unresumableReason,
            lastUpdated: lastUpdated,
          ),
        );
      }
    } catch (_) {
      // Discard or log if Rust bridge is unavailable in test environment
    }

    // 2. Recoverable sender sessions from persistent durable sender state
    final durableSenderState = ref.read(durableSendProvider);
    final durableSenderService = ref.notifier(durableSendProvider);

    for (final entry in durableSenderState) {
      if (entry.status == 'interrupted' || entry.status == 'failed') {
        final isValidSource = durableSenderService.verifySourceFile(entry);
        final progress = entry.fileSize > 0
            ? (entry.bytesTransferred / entry.fileSize).clamp(0.0, 1.0)
            : 0.0;

        results.add(
          RecoverableTransfer(
            transferId: entry.transferId,
            direction: RecoverableTransferDirection.send,
            fileName: entry.fileName,
            fileSize: entry.fileSize,
            bytesTransferred: entry.bytesTransferred,
            progress: progress,
            peerAlias: entry.targetDeviceAlias,
            peerFingerprint: entry.targetFingerprint,
            localPath: entry.filePath,
            isResumable: isValidSource,
            unresumableReason: isValidSource ? null : 'Source file missing or modified on disk',
            lastUpdated: entry.updatedAt,
          ),
        );
      }
    }

    // Sort newest first
    results.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return results;
  }

  /// Refreshes the recoverable transfers list.
  Future<List<RecoverableTransfer>> refresh() {
    return setState((_) => _fetchRecoverableTransfers());
  }

  /// Prunes a transfer from recovery tracking.
  Future<void> pruneTransfer({
    required String transferId,
    required RecoverableTransferDirection direction,
  }) async {
    if (direction == RecoverableTransferDirection.receive) {
      await pruneV3Session(transferId: transferId);
    } else {
      await ref.notifier(durableSendProvider).pruneEntry(transferId);
    }
    await refresh();
  }
}
