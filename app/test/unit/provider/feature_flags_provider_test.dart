import 'package:locara_app/provider/feature_flags_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureFlagsProvider', () {
    test('Should initialize with correct defaults', () {
      final ref = RefenaContainer();
      final state = ref.read(featureFlagsProvider);

      expect(state.webRtc, isFalse);
      expect(state.quic, isFalse);
      expect(state.messaging, isTrue); // Stable feature
      expect(state.experimental, isFalse);
    });

    test('Should update flags correctly', () {
      final ref = RefenaContainer();

      ref.notifier(featureFlagsProvider).setFlag(webRtc: true, experimental: true);

      final state = ref.read(featureFlagsProvider);
      expect(state.webRtc, isTrue);
      expect(state.experimental, isTrue);
      expect(state.quic, isFalse); // Should remain unchanged
    });
  });
}
