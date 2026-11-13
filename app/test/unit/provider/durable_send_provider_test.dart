import 'dart:io';

import 'package:locara_app/model/persistence/durable_send_entry.dart';
import 'package:locara_app/provider/durable_send_provider.dart';
import 'package:locara_app/provider/persistence_provider.dart';
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
  group('DurableSendService', () {
    test('transitions in_flight transfers to interrupted on init', () {
      final now = DateTime.now().toUtc();
      final initial = [
        DurableSendEntry(
          transferId: 't1',
          targetDeviceAlias: 'Device A',
          targetFingerprint: 'FP1',
          targetIp: '192.168.1.10',
          targetPort: 53317,
          filePath: '/path/file.txt',
          fileName: 'file.txt',
          fileSize: 1000,
          bytesTransferred: 500,
          status: 'in_flight',
          createdAt: now,
          updatedAt: now,
        ),
        DurableSendEntry(
          transferId: 't2',
          targetDeviceAlias: 'Device B',
          targetFingerprint: 'FP2',
          targetIp: '192.168.1.11',
          targetPort: 53317,
          filePath: '/path/file2.txt',
          fileName: 'file2.txt',
          fileSize: 2000,
          bytesTransferred: 2000,
          status: 'finished',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final fakePersistence = FakePersistenceService(initial);
      final service = Notifier.test(
        notifier: DurableSendService(fakePersistence),
      );

      expect(service.state.length, 2);
      expect(service.state.firstWhere((e) => e.transferId == 't1').status, 'interrupted');
      expect(service.state.firstWhere((e) => e.transferId == 't2').status, 'finished');
      expect(fakePersistence.entries.firstWhere((e) => e.transferId == 't1').status, 'interrupted');
    });

    test('recordTransferStart adds new in_flight transfer and persists', () async {
      final fakePersistence = FakePersistenceService([]);
      final service = Notifier.test(
        notifier: DurableSendService(fakePersistence),
      );

      await service.notifier.recordTransferStart(
        transferId: 't_new',
        targetDeviceAlias: 'Target',
        targetFingerprint: 'FP_TARGET',
        targetIp: '10.0.0.1',
        targetPort: 53317,
        filePath: '/tmp/test.bin',
        fileName: 'test.bin',
        fileSize: 5000,
      );

      expect(service.state.length, 1);
      final entry = service.state.first;
      expect(entry.transferId, 't_new');
      expect(entry.status, 'in_flight');
      expect(entry.bytesTransferred, 0);
      expect(fakePersistence.entries.length, 1);
    });

    test('recordTransferProgress updates bytesTransferred', () async {
      final fakePersistence = FakePersistenceService([]);
      final service = Notifier.test(
        notifier: DurableSendService(fakePersistence),
      );

      await service.notifier.recordTransferStart(
        transferId: 't_prog',
        targetDeviceAlias: 'Target',
        targetFingerprint: 'FP_TARGET',
        targetIp: '10.0.0.1',
        targetPort: 53317,
        filePath: '/tmp/test.bin',
        fileName: 'test.bin',
        fileSize: 5000,
      );

      await service.notifier.recordTransferProgress(
        transferId: 't_prog',
        bytesTransferred: 2500,
      );

      expect(service.state.first.bytesTransferred, 2500);
      expect(fakePersistence.entries.first.bytesTransferred, 2500);
    });

    test('recordTransferFinished marks status as finished', () async {
      final fakePersistence = FakePersistenceService([]);
      final service = Notifier.test(
        notifier: DurableSendService(fakePersistence),
      );

      await service.notifier.recordTransferStart(
        transferId: 't_fin',
        targetDeviceAlias: 'Target',
        targetFingerprint: 'FP_TARGET',
        targetIp: '10.0.0.1',
        targetPort: 53317,
        filePath: '/tmp/test.bin',
        fileName: 'test.bin',
        fileSize: 5000,
      );

      await service.notifier.recordTransferFinished(transferId: 't_fin');

      expect(service.state.first.status, 'finished');
      expect(service.state.first.bytesTransferred, 5000);
      expect(fakePersistence.entries.first.status, 'finished');
    });

    test('recordTransferFailed marks status as failed with error', () async {
      final fakePersistence = FakePersistenceService([]);
      final service = Notifier.test(
        notifier: DurableSendService(fakePersistence),
      );

      await service.notifier.recordTransferStart(
        transferId: 't_fail',
        targetDeviceAlias: 'Target',
        targetFingerprint: 'FP_TARGET',
        targetIp: '10.0.0.1',
        targetPort: 53317,
        filePath: '/tmp/test.bin',
        fileName: 'test.bin',
        fileSize: 5000,
      );

      await service.notifier.recordTransferFailed(
        transferId: 't_fail',
        error: 'Connection reset by peer',
      );

      expect(service.state.first.status, 'failed');
      expect(service.state.first.errorMessage, 'Connection reset by peer');
    });

    test('pruneEntry removes entry from state and persistence', () async {
      final fakePersistence = FakePersistenceService([]);
      final service = Notifier.test(
        notifier: DurableSendService(fakePersistence),
      );

      await service.notifier.recordTransferStart(
        transferId: 't_prune',
        targetDeviceAlias: 'Target',
        targetFingerprint: 'FP_TARGET',
        targetIp: '10.0.0.1',
        targetPort: 53317,
        filePath: '/tmp/test.bin',
        fileName: 'test.bin',
        fileSize: 5000,
      );

      expect(service.state.length, 1);
      await service.notifier.pruneEntry('t_prune');
      expect(service.state.isEmpty, true);
      expect(fakePersistence.entries.isEmpty, true);
    });

    test('verifySourceFile validates existing file size accurately', () {
      final tempFile = File('${Directory.systemTemp.path}/locara_verify_test.tmp');
      tempFile.writeAsStringSync('Hello World');

      final fakePersistence = FakePersistenceService([]);
      final service = Notifier.test(
        notifier: DurableSendService(fakePersistence),
      );

      final validEntry = DurableSendEntry(
        transferId: 'tv',
        targetDeviceAlias: 'A',
        targetFingerprint: 'FP',
        targetIp: '1.1.1.1',
        targetPort: 53317,
        filePath: tempFile.path,
        fileName: 'locara_verify_test.tmp',
        fileSize: 11,
        bytesTransferred: 5,
        status: 'interrupted',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final modifiedEntry = validEntry.copyWith(fileSize: 9999);
      final missingEntry = validEntry.copyWith(filePath: '/nonexistent/path/xyz.tmp');

      expect(service.notifier.verifySourceFile(validEntry), true);
      expect(service.notifier.verifySourceFile(modifiedEntry), false);
      expect(service.notifier.verifySourceFile(missingEntry), false);

      tempFile.deleteSync();
    });
  });
}
