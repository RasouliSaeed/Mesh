import 'dart:io';

import 'package:locara_app/model/persistence/durable_send_entry.dart';
import 'package:locara_app/model/recovery/recoverable_transfer.dart';
import 'package:locara_app/provider/durable_send_provider.dart';
import 'package:locara_app/provider/persistence_provider.dart';
import 'package:locara_app/provider/recovery_contract_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:test/fake.dart';
import 'package:test/test.dart';

class FakePersistenceService extends Fake implements PersistenceService {
  List<DurableSendEntry> entries;

  FakePersistenceService([List<DurableSendEntry>? initial]) : entries = initial ?? [];

  @override
  List<DurableSendEntry> getDurableSendTransfers() => entries;

  @override
  Future<void> setDurableSendTransfers(List<DurableSendEntry> newEntries) async {
    entries = newEntries;
  }
}

void main() {
  group('RecoveryContractService', () {
    test('aggregates interrupted and failed sender entries correctly', () async {
      final tempFile = File('${Directory.systemTemp.path}/recovery_contract_test.tmp');
      tempFile.writeAsStringSync('recovery test data');

      final now = DateTime.now().toUtc();
      final initialEntries = [
        DurableSendEntry(
          transferId: 'send_interrupted_1',
          targetDeviceAlias: 'Receiver Phone',
          targetFingerprint: 'FP_REC_1',
          targetIp: '192.168.1.50',
          targetPort: 53317,
          filePath: tempFile.path,
          fileName: 'recovery_contract_test.tmp',
          fileSize: 18,
          bytesTransferred: 9,
          status: 'interrupted',
          createdAt: now.subtract(const Duration(minutes: 10)),
          updatedAt: now.subtract(const Duration(minutes: 5)),
        ),
        DurableSendEntry(
          transferId: 'send_failed_missing_file',
          targetDeviceAlias: 'Receiver Tablet',
          targetFingerprint: 'FP_REC_2',
          targetIp: '192.168.1.51',
          targetPort: 53317,
          filePath: '/nonexistent/missing_file.bin',
          fileName: 'missing_file.bin',
          fileSize: 1000,
          bytesTransferred: 200,
          status: 'failed',
          createdAt: now.subtract(const Duration(minutes: 20)),
          updatedAt: now.subtract(const Duration(minutes: 15)),
          errorMessage: 'Connection lost',
        ),
        DurableSendEntry(
          transferId: 'send_finished_ignored',
          targetDeviceAlias: 'Receiver Desktop',
          targetFingerprint: 'FP_REC_3',
          targetIp: '192.168.1.52',
          targetPort: 53317,
          filePath: tempFile.path,
          fileName: 'finished.bin',
          fileSize: 500,
          bytesTransferred: 500,
          status: 'finished',
          createdAt: now.subtract(const Duration(hours: 1)),
          updatedAt: now.subtract(const Duration(minutes: 50)),
        ),
      ];

      final fakePersistence = FakePersistenceService(initialEntries);

      final container = RefenaContainer(
        overrides: [
          persistenceProvider.overrideWithValue(fakePersistence),
        ],
      );

      final contractState = await container.notifier(recoveryContractProvider).future;

      // Only interrupted and failed transfers appear in recovery contract
      expect(contractState.length, 2);

      final transfer1 = contractState.firstWhere((t) => t.transferId == 'send_interrupted_1');
      expect(transfer1.direction, RecoverableTransferDirection.send);
      expect(transfer1.fileName, 'recovery_contract_test.tmp');
      expect(transfer1.fileSize, 18);
      expect(transfer1.bytesTransferred, 9);
      expect(transfer1.progress, 0.5);
      expect(transfer1.isResumable, true);
      expect(transfer1.unresumableReason, isNull);
      expect(transfer1.peerAlias, 'Receiver Phone');

      final transfer2 = contractState.firstWhere((t) => t.transferId == 'send_failed_missing_file');
      expect(transfer2.direction, RecoverableTransferDirection.send);
      expect(transfer2.isResumable, false);
      expect(transfer2.unresumableReason, contains('missing or modified'));

      tempFile.deleteSync();
    });

    test('pruneTransfer removes send entry and refreshes', () async {
      final now = DateTime.now().toUtc();
      final initialEntries = [
        DurableSendEntry(
          transferId: 'to_prune',
          targetDeviceAlias: 'Receiver Phone',
          targetFingerprint: 'FP',
          targetIp: '1.1.1.1',
          targetPort: 53317,
          filePath: '/fake.bin',
          fileName: 'fake.bin',
          fileSize: 100,
          bytesTransferred: 50,
          status: 'interrupted',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final fakePersistence = FakePersistenceService(initialEntries);

      final container = RefenaContainer(
        overrides: [
          persistenceProvider.overrideWithValue(fakePersistence),
        ],
      );

      final initialState = await container.notifier(recoveryContractProvider).future;
      expect(initialState.length, 1);

      await container.notifier(recoveryContractProvider).pruneTransfer(
            transferId: 'to_prune',
            direction: RecoverableTransferDirection.send,
          );

      final updatedState = await container.notifier(recoveryContractProvider).future;
      expect(updatedState.isEmpty, true);
      expect(fakePersistence.entries.isEmpty, true);
    });

    test('reactively updates when durableSendProvider changes', () async {
      final fakePersistence = FakePersistenceService([]);

      final container = RefenaContainer(
        overrides: [
          persistenceProvider.overrideWithValue(fakePersistence),
        ],
      );

      final initial = await container.notifier(recoveryContractProvider).future;
      expect(initial.isEmpty, true);

      // Record a new failed transfer in durableSendProvider
      await container.notifier(durableSendProvider).recordTransferStart(
            transferId: 'reactive_1',
            targetDeviceAlias: 'Tablet',
            targetFingerprint: 'FP_TAB',
            targetIp: '1.2.3.4',
            targetPort: 53317,
            filePath: '/nonexistent/file.txt',
            fileName: 'file.txt',
            fileSize: 100,
          );

      await container.notifier(durableSendProvider).recordTransferFailed(
            transferId: 'reactive_1',
            error: 'Network drop',
          );

      // Wait a microtask / tick for stream subscription to trigger refresh
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final updated = await container.notifier(recoveryContractProvider).future;
      expect(updated.length, 1);
      expect(updated.first.transferId, 'reactive_1');
      expect(updated.first.isResumable, false); // source missing
      expect(updated.first.unresumableReason, contains('missing or modified'));

      // Complete / finish the transfer in durableSendProvider -> should vanish from recovery
      await container.notifier(durableSendProvider).recordTransferFinished(
            transferId: 'reactive_1',
          );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final finishedState = await container.notifier(recoveryContractProvider).future;
      expect(finishedState.isEmpty, true);
    });
  });
}
