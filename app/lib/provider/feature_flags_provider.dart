import 'package:locara_app/model/state/feature_flags_state.dart';
import 'package:refena_flutter/refena_flutter.dart';

final featureFlagsProvider = NotifierProvider<FeatureFlagsNotifier, FeatureFlagsState>((ref) {
  return FeatureFlagsNotifier();
});

class FeatureFlagsNotifier extends Notifier<FeatureFlagsState> {
  @override
  FeatureFlagsState init() {
    return const FeatureFlagsState(
      webRtc: false,
      quic: false,
      wifiDirect: false,
      hotspot: false,
      messaging: true, // Messaging is currently stable
      clipboard: true, // Universal E2EE shared clipboard enabled
      sharedFolders: false,
      diagnostics: false,
      experimental: false,
    );
  }

  void setFlag({
    bool? webRtc,
    bool? quic,
    bool? wifiDirect,
    bool? hotspot,
    bool? messaging,
    bool? clipboard,
    bool? sharedFolders,
    bool? diagnostics,
    bool? experimental,
  }) {
    state = state.copyWith(
      webRtc: webRtc,
      quic: quic,
      wifiDirect: wifiDirect,
      hotspot: hotspot,
      messaging: messaging,
      clipboard: clipboard,
      sharedFolders: sharedFolders,
      diagnostics: diagnostics,
      experimental: experimental,
    );
  }
}
