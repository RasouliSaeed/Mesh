import 'dart:async';
import 'dart:io';

import 'package:locara_app/model/persistence/durable_send_entry.dart';
import 'package:locara_app/provider/persistence_provider.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('DurableSendProvider');

final durableSendProvider = NotifierProvider<DurableSendService, List<DurableSendEntry>>((ref) {
  return DurableSendService(ref.read(persistenceProvider));
});

class DurableSendService extends Notifier<List<DurableSendEntry>> {
  final PersistenceService _persistence;

  DurableSendService(this._persistence);

  @override
  List<DurableSendEntry> init() {
    final rawEntries = _persistence.getDurableSendTransfers();
    bool modified = false;

    // Transition any 'in_flight' transfers to 'interrupted' across cold start
    final initialEntries = rawEntries.map((entry) {
      if (entry.status == 'in_flight') {
        modified = true;
        return entry.copyWith(
          status: 'interrupted',
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return entry;
    }).toList();

    if (modified) {
      unawaited(_persistence.setDurableSendTransfers(initialEntries));
      _logger.info('Marked in-flight durable send transfers as interrupted on startup');
    }

    return initialEntries;
  }

  /// Records the start of a V3 file transfer.
  Future<void> recordTransferStart({
    required String transferId,
    required String targetDeviceAlias,
    required String targetFingerprint,
    required String targetIp,
    required int targetPort,
    required String filePath,
    required String fileName,
    required int fileSize,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = state.where((e) => e.transferId == transferId).firstOrNull;
    final newEntry = DurableSendEntry(
      transferId: transferId,
      targetDeviceAlias: targetDeviceAlias,
      targetFingerprint: targetFingerprint,
      targetIp: targetIp,
      targetPort: targetPort,
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      bytesTransferred: existing?.bytesTransferred ?? 0,
      status: 'in_flight',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final updated = [
      ...state.where((e) => e.transferId != transferId),
      newEntry,
    ];
    state = updated;
    await _persistence.setDurableSendTransfers(updated);
  }

  /// Records transfer progress update.
  Future<void> recordTransferProgress({
    required String transferId,
    required int bytesTransferred,
  }) async {
    final updated = state.map((entry) {
      if (entry.transferId == transferId) {
        return entry.copyWith(
          bytesTransferred: bytesTransferred,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return entry;
    }).toList();

    state = updated;
    await _persistence.setDurableSendTransfers(updated);
  }

  /// Records successful transfer completion.
  Future<void> recordTransferFinished({
    required String transferId,
  }) async {
    final updated = state.map((entry) {
      if (entry.transferId == transferId) {
        return entry.copyWith(
          status: 'finished',
          bytesTransferred: entry.fileSize,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return entry;
    }).toList();

    state = updated;
    await _persistence.setDurableSendTransfers(updated);
  }

  /// Records transfer failure or error.
  Future<void> recordTransferFailed({
    required String transferId,
    required String error,
  }) async {
    final updated = state.map((entry) {
      if (entry.transferId == transferId) {
        return entry.copyWith(
          status: 'failed',
          errorMessage: error,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return entry;
    }).toList();

    state = updated;
    await _persistence.setDurableSendTransfers(updated);
  }

  /// Prunes an entry from persistent tracking.
  Future<void> pruneEntry(String transferId) async {
    final updated = state.where((e) => e.transferId != transferId).toList();
    state = updated;
    await _persistence.setDurableSendTransfers(updated);
  }

  /// Verifies whether the source file for a transfer is still present and valid on disk.
  bool verifySourceFile(DurableSendEntry entry) {
    try {
      final file = File(entry.filePath);
      if (!file.existsSync()) {
        return false;
      }
      if (entry.fileSize > 0 && file.lengthSync() != entry.fileSize) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
