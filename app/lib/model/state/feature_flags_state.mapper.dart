// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'feature_flags_state.dart';

class FeatureFlagsStateMapper extends ClassMapperBase<FeatureFlagsState> {
  FeatureFlagsStateMapper._();

  static FeatureFlagsStateMapper? _instance;
  static FeatureFlagsStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = FeatureFlagsStateMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'FeatureFlagsState';

  static bool _$webRtc(FeatureFlagsState v) => v.webRtc;
  static const Field<FeatureFlagsState, bool> _f$webRtc = Field(
    'webRtc',
    _$webRtc,
  );
  static bool _$quic(FeatureFlagsState v) => v.quic;
  static const Field<FeatureFlagsState, bool> _f$quic = Field('quic', _$quic);
  static bool _$wifiDirect(FeatureFlagsState v) => v.wifiDirect;
  static const Field<FeatureFlagsState, bool> _f$wifiDirect = Field(
    'wifiDirect',
    _$wifiDirect,
  );
  static bool _$hotspot(FeatureFlagsState v) => v.hotspot;
  static const Field<FeatureFlagsState, bool> _f$hotspot = Field(
    'hotspot',
    _$hotspot,
  );
  static bool _$messaging(FeatureFlagsState v) => v.messaging;
  static const Field<FeatureFlagsState, bool> _f$messaging = Field(
    'messaging',
    _$messaging,
  );
  static bool _$clipboard(FeatureFlagsState v) => v.clipboard;
  static const Field<FeatureFlagsState, bool> _f$clipboard = Field(
    'clipboard',
    _$clipboard,
  );
  static bool _$sharedFolders(FeatureFlagsState v) => v.sharedFolders;
  static const Field<FeatureFlagsState, bool> _f$sharedFolders = Field(
    'sharedFolders',
    _$sharedFolders,
  );
  static bool _$diagnostics(FeatureFlagsState v) => v.diagnostics;
  static const Field<FeatureFlagsState, bool> _f$diagnostics = Field(
    'diagnostics',
    _$diagnostics,
  );
  static bool _$experimental(FeatureFlagsState v) => v.experimental;
  static const Field<FeatureFlagsState, bool> _f$experimental = Field(
    'experimental',
    _$experimental,
  );

  @override
  final MappableFields<FeatureFlagsState> fields = const {
    #webRtc: _f$webRtc,
    #quic: _f$quic,
    #wifiDirect: _f$wifiDirect,
    #hotspot: _f$hotspot,
    #messaging: _f$messaging,
    #clipboard: _f$clipboard,
    #sharedFolders: _f$sharedFolders,
    #diagnostics: _f$diagnostics,
    #experimental: _f$experimental,
  };

  static FeatureFlagsState _instantiate(DecodingData data) {
    return FeatureFlagsState(
      webRtc: data.dec(_f$webRtc),
      quic: data.dec(_f$quic),
      wifiDirect: data.dec(_f$wifiDirect),
      hotspot: data.dec(_f$hotspot),
      messaging: data.dec(_f$messaging),
      clipboard: data.dec(_f$clipboard),
      sharedFolders: data.dec(_f$sharedFolders),
      diagnostics: data.dec(_f$diagnostics),
      experimental: data.dec(_f$experimental),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static FeatureFlagsState fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<FeatureFlagsState>(map);
  }

  static FeatureFlagsState deserialize(String json) {
    return ensureInitialized().decodeJson<FeatureFlagsState>(json);
  }
}

mixin FeatureFlagsStateMappable {
  String serialize() {
    return FeatureFlagsStateMapper.ensureInitialized()
        .encodeJson<FeatureFlagsState>(this as FeatureFlagsState);
  }

  Map<String, dynamic> toJson() {
    return FeatureFlagsStateMapper.ensureInitialized()
        .encodeMap<FeatureFlagsState>(this as FeatureFlagsState);
  }

  FeatureFlagsStateCopyWith<
    FeatureFlagsState,
    FeatureFlagsState,
    FeatureFlagsState
  >
  get copyWith =>
      _FeatureFlagsStateCopyWithImpl<FeatureFlagsState, FeatureFlagsState>(
        this as FeatureFlagsState,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return FeatureFlagsStateMapper.ensureInitialized().stringifyValue(
      this as FeatureFlagsState,
    );
  }

  @override
  bool operator ==(Object other) {
    return FeatureFlagsStateMapper.ensureInitialized().equalsValue(
      this as FeatureFlagsState,
      other,
    );
  }

  @override
  int get hashCode {
    return FeatureFlagsStateMapper.ensureInitialized().hashValue(
      this as FeatureFlagsState,
    );
  }
}

extension FeatureFlagsStateValueCopy<$R, $Out>
    on ObjectCopyWith<$R, FeatureFlagsState, $Out> {
  FeatureFlagsStateCopyWith<$R, FeatureFlagsState, $Out>
  get $asFeatureFlagsState => $base.as(
    (v, t, t2) => _FeatureFlagsStateCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class FeatureFlagsStateCopyWith<
  $R,
  $In extends FeatureFlagsState,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    bool? webRtc,
    bool? quic,
    bool? wifiDirect,
    bool? hotspot,
    bool? messaging,
    bool? clipboard,
    bool? sharedFolders,
    bool? diagnostics,
    bool? experimental,
  });
  FeatureFlagsStateCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _FeatureFlagsStateCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, FeatureFlagsState, $Out>
    implements FeatureFlagsStateCopyWith<$R, FeatureFlagsState, $Out> {
  _FeatureFlagsStateCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<FeatureFlagsState> $mapper =
      FeatureFlagsStateMapper.ensureInitialized();
  @override
  $R call({
    bool? webRtc,
    bool? quic,
    bool? wifiDirect,
    bool? hotspot,
    bool? messaging,
    bool? clipboard,
    bool? sharedFolders,
    bool? diagnostics,
    bool? experimental,
  }) => $apply(
    FieldCopyWithData({
      if (webRtc != null) #webRtc: webRtc,
      if (quic != null) #quic: quic,
      if (wifiDirect != null) #wifiDirect: wifiDirect,
      if (hotspot != null) #hotspot: hotspot,
      if (messaging != null) #messaging: messaging,
      if (clipboard != null) #clipboard: clipboard,
      if (sharedFolders != null) #sharedFolders: sharedFolders,
      if (diagnostics != null) #diagnostics: diagnostics,
      if (experimental != null) #experimental: experimental,
    }),
  );
  @override
  FeatureFlagsState $make(CopyWithData data) => FeatureFlagsState(
    webRtc: data.get(#webRtc, or: $value.webRtc),
    quic: data.get(#quic, or: $value.quic),
    wifiDirect: data.get(#wifiDirect, or: $value.wifiDirect),
    hotspot: data.get(#hotspot, or: $value.hotspot),
    messaging: data.get(#messaging, or: $value.messaging),
    clipboard: data.get(#clipboard, or: $value.clipboard),
    sharedFolders: data.get(#sharedFolders, or: $value.sharedFolders),
    diagnostics: data.get(#diagnostics, or: $value.diagnostics),
    experimental: data.get(#experimental, or: $value.experimental),
  );

  @override
  FeatureFlagsStateCopyWith<$R2, FeatureFlagsState, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _FeatureFlagsStateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

