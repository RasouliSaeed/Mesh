import 'package:dart_mappable/dart_mappable.dart';

part 'feature_flags_state.mapper.dart';

@MappableClass()
class FeatureFlagsState with FeatureFlagsStateMappable {
  final bool webRtc;
  final bool quic;
  final bool wifiDirect;
  final bool hotspot;
  final bool messaging;
  final bool clipboard;
  final bool sharedFolders;
  final bool diagnostics;
  final bool experimental;

  const FeatureFlagsState({
    required this.webRtc,
    required this.quic,
    required this.wifiDirect,
    required this.hotspot,
    required this.messaging,
    required this.clipboard,
    required this.sharedFolders,
    required this.diagnostics,
    required this.experimental,
  });
}
