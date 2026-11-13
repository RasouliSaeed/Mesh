import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locara_app/provider/chat_provider.dart';
import 'package:locara_app/provider/clipboard_provider.dart';
import 'package:locara_app/provider/feature_flags_provider.dart';
import 'package:locara_isolates/model/device.dart';
import 'package:refena_flutter/refena_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeatureFlags Clipboard', () {
    test('clipboard flag is enabled by default for universal sync', () {
      final ref = RefenaContainer();
      final flags = ref.read(featureFlagsProvider);
      expect(flags.clipboard, isTrue);
    });
  });

  group('ChatProvider with Target', () {
    test('setTarget updates the current recipient device', () {
      final ref = RefenaContainer();
      const testDevice = Device(
        signalingId: null,
        ip: '192.168.1.50',
        version: '1.0',
        port: 53317,
        https: true,
        fingerprint: 'abcd1234ef',
        alias: 'Office Laptop',
        deviceModel: 'ThinkPad',
        deviceType: DeviceType.desktop,
        download: true,
        channels: [],
      );

      expect(ref.read(chatProvider).currentTarget, isNull);

      ref.notifier(chatProvider).setTarget(testDevice);
      expect(ref.read(chatProvider).currentTarget?.alias, equals('Office Laptop'));

      ref.notifier(chatProvider).addMessage('Hello from clipboard test', isMine: true);
      final messages = ref.read(chatProvider).messages;
      expect(messages.length, 1);
      expect(messages.first.text, equals('Hello from clipboard test'));
      expect(messages.first.isMine, isTrue);
    });
  });

  group('ClipboardSyncService', () {
    testWidgets('copyToClipboard copies string to Clipboard system service', (tester) async {
      String? mockClipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            mockClipboardText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          if (methodCall.method == 'Clipboard.getData') {
            return {'text': mockClipboardText};
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => ClipboardSyncService.copyToClipboard(
                    context,
                    'https://locara.app/test-link',
                    message: 'Copied!',
                  ),
                  child: const Text('Copy'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(mockClipboardText, equals('https://locara.app/test-link'));
    });
  });
}
