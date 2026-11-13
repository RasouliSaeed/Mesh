// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'http.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RsHttpClientError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsHttpClientError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RsHttpClientError()';
}


}

/// @nodoc
class $RsHttpClientErrorCopyWith<$Res>  {
$RsHttpClientErrorCopyWith(RsHttpClientError _, $Res Function(RsHttpClientError) __);
}


/// Adds pattern-matching-related methods to [RsHttpClientError].
extension RsHttpClientErrorPatterns on RsHttpClientError {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RsHttpClientError_StatusCode value)?  statusCode,TResult Function( RsHttpClientError_Reqwest value)?  reqwest,TResult Function( RsHttpClientError_Json value)?  json,TResult Function( RsHttpClientError_Io value)?  io,TResult Function( RsHttpClientError_Other value)?  other,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RsHttpClientError_StatusCode() when statusCode != null:
return statusCode(_that);case RsHttpClientError_Reqwest() when reqwest != null:
return reqwest(_that);case RsHttpClientError_Json() when json != null:
return json(_that);case RsHttpClientError_Io() when io != null:
return io(_that);case RsHttpClientError_Other() when other != null:
return other(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RsHttpClientError_StatusCode value)  statusCode,required TResult Function( RsHttpClientError_Reqwest value)  reqwest,required TResult Function( RsHttpClientError_Json value)  json,required TResult Function( RsHttpClientError_Io value)  io,required TResult Function( RsHttpClientError_Other value)  other,}){
final _that = this;
switch (_that) {
case RsHttpClientError_StatusCode():
return statusCode(_that);case RsHttpClientError_Reqwest():
return reqwest(_that);case RsHttpClientError_Json():
return json(_that);case RsHttpClientError_Io():
return io(_that);case RsHttpClientError_Other():
return other(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RsHttpClientError_StatusCode value)?  statusCode,TResult? Function( RsHttpClientError_Reqwest value)?  reqwest,TResult? Function( RsHttpClientError_Json value)?  json,TResult? Function( RsHttpClientError_Io value)?  io,TResult? Function( RsHttpClientError_Other value)?  other,}){
final _that = this;
switch (_that) {
case RsHttpClientError_StatusCode() when statusCode != null:
return statusCode(_that);case RsHttpClientError_Reqwest() when reqwest != null:
return reqwest(_that);case RsHttpClientError_Json() when json != null:
return json(_that);case RsHttpClientError_Io() when io != null:
return io(_that);case RsHttpClientError_Other() when other != null:
return other(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int status,  String? message)?  statusCode,TResult Function( String field0)?  reqwest,TResult Function( String field0)?  json,TResult Function( String field0)?  io,TResult Function( String field0)?  other,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RsHttpClientError_StatusCode() when statusCode != null:
return statusCode(_that.status,_that.message);case RsHttpClientError_Reqwest() when reqwest != null:
return reqwest(_that.field0);case RsHttpClientError_Json() when json != null:
return json(_that.field0);case RsHttpClientError_Io() when io != null:
return io(_that.field0);case RsHttpClientError_Other() when other != null:
return other(_that.field0);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int status,  String? message)  statusCode,required TResult Function( String field0)  reqwest,required TResult Function( String field0)  json,required TResult Function( String field0)  io,required TResult Function( String field0)  other,}) {final _that = this;
switch (_that) {
case RsHttpClientError_StatusCode():
return statusCode(_that.status,_that.message);case RsHttpClientError_Reqwest():
return reqwest(_that.field0);case RsHttpClientError_Json():
return json(_that.field0);case RsHttpClientError_Io():
return io(_that.field0);case RsHttpClientError_Other():
return other(_that.field0);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int status,  String? message)?  statusCode,TResult? Function( String field0)?  reqwest,TResult? Function( String field0)?  json,TResult? Function( String field0)?  io,TResult? Function( String field0)?  other,}) {final _that = this;
switch (_that) {
case RsHttpClientError_StatusCode() when statusCode != null:
return statusCode(_that.status,_that.message);case RsHttpClientError_Reqwest() when reqwest != null:
return reqwest(_that.field0);case RsHttpClientError_Json() when json != null:
return json(_that.field0);case RsHttpClientError_Io() when io != null:
return io(_that.field0);case RsHttpClientError_Other() when other != null:
return other(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class RsHttpClientError_StatusCode extends RsHttpClientError {
  const RsHttpClientError_StatusCode({required this.status, this.message}): super._();
  

 final  int status;
 final  String? message;

/// Create a copy of RsHttpClientError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsHttpClientError_StatusCodeCopyWith<RsHttpClientError_StatusCode> get copyWith => _$RsHttpClientError_StatusCodeCopyWithImpl<RsHttpClientError_StatusCode>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsHttpClientError_StatusCode&&(identical(other.status, status) || other.status == status)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,status,message);

@override
String toString() {
  return 'RsHttpClientError.statusCode(status: $status, message: $message)';
}


}

/// @nodoc
abstract mixin class $RsHttpClientError_StatusCodeCopyWith<$Res> implements $RsHttpClientErrorCopyWith<$Res> {
  factory $RsHttpClientError_StatusCodeCopyWith(RsHttpClientError_StatusCode value, $Res Function(RsHttpClientError_StatusCode) _then) = _$RsHttpClientError_StatusCodeCopyWithImpl;
@useResult
$Res call({
 int status, String? message
});




}
/// @nodoc
class _$RsHttpClientError_StatusCodeCopyWithImpl<$Res>
    implements $RsHttpClientError_StatusCodeCopyWith<$Res> {
  _$RsHttpClientError_StatusCodeCopyWithImpl(this._self, this._then);

  final RsHttpClientError_StatusCode _self;
  final $Res Function(RsHttpClientError_StatusCode) _then;

/// Create a copy of RsHttpClientError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? status = null,Object? message = freezed,}) {
  return _then(RsHttpClientError_StatusCode(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class RsHttpClientError_Reqwest extends RsHttpClientError {
  const RsHttpClientError_Reqwest(this.field0): super._();
  

 final  String field0;

/// Create a copy of RsHttpClientError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsHttpClientError_ReqwestCopyWith<RsHttpClientError_Reqwest> get copyWith => _$RsHttpClientError_ReqwestCopyWithImpl<RsHttpClientError_Reqwest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsHttpClientError_Reqwest&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'RsHttpClientError.reqwest(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $RsHttpClientError_ReqwestCopyWith<$Res> implements $RsHttpClientErrorCopyWith<$Res> {
  factory $RsHttpClientError_ReqwestCopyWith(RsHttpClientError_Reqwest value, $Res Function(RsHttpClientError_Reqwest) _then) = _$RsHttpClientError_ReqwestCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$RsHttpClientError_ReqwestCopyWithImpl<$Res>
    implements $RsHttpClientError_ReqwestCopyWith<$Res> {
  _$RsHttpClientError_ReqwestCopyWithImpl(this._self, this._then);

  final RsHttpClientError_Reqwest _self;
  final $Res Function(RsHttpClientError_Reqwest) _then;

/// Create a copy of RsHttpClientError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(RsHttpClientError_Reqwest(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsHttpClientError_Json extends RsHttpClientError {
  const RsHttpClientError_Json(this.field0): super._();
  

 final  String field0;

/// Create a copy of RsHttpClientError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsHttpClientError_JsonCopyWith<RsHttpClientError_Json> get copyWith => _$RsHttpClientError_JsonCopyWithImpl<RsHttpClientError_Json>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsHttpClientError_Json&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'RsHttpClientError.json(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $RsHttpClientError_JsonCopyWith<$Res> implements $RsHttpClientErrorCopyWith<$Res> {
  factory $RsHttpClientError_JsonCopyWith(RsHttpClientError_Json value, $Res Function(RsHttpClientError_Json) _then) = _$RsHttpClientError_JsonCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$RsHttpClientError_JsonCopyWithImpl<$Res>
    implements $RsHttpClientError_JsonCopyWith<$Res> {
  _$RsHttpClientError_JsonCopyWithImpl(this._self, this._then);

  final RsHttpClientError_Json _self;
  final $Res Function(RsHttpClientError_Json) _then;

/// Create a copy of RsHttpClientError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(RsHttpClientError_Json(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsHttpClientError_Io extends RsHttpClientError {
  const RsHttpClientError_Io(this.field0): super._();
  

 final  String field0;

/// Create a copy of RsHttpClientError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsHttpClientError_IoCopyWith<RsHttpClientError_Io> get copyWith => _$RsHttpClientError_IoCopyWithImpl<RsHttpClientError_Io>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsHttpClientError_Io&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'RsHttpClientError.io(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $RsHttpClientError_IoCopyWith<$Res> implements $RsHttpClientErrorCopyWith<$Res> {
  factory $RsHttpClientError_IoCopyWith(RsHttpClientError_Io value, $Res Function(RsHttpClientError_Io) _then) = _$RsHttpClientError_IoCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$RsHttpClientError_IoCopyWithImpl<$Res>
    implements $RsHttpClientError_IoCopyWith<$Res> {
  _$RsHttpClientError_IoCopyWithImpl(this._self, this._then);

  final RsHttpClientError_Io _self;
  final $Res Function(RsHttpClientError_Io) _then;

/// Create a copy of RsHttpClientError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(RsHttpClientError_Io(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsHttpClientError_Other extends RsHttpClientError {
  const RsHttpClientError_Other(this.field0): super._();
  

 final  String field0;

/// Create a copy of RsHttpClientError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsHttpClientError_OtherCopyWith<RsHttpClientError_Other> get copyWith => _$RsHttpClientError_OtherCopyWithImpl<RsHttpClientError_Other>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsHttpClientError_Other&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'RsHttpClientError.other(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $RsHttpClientError_OtherCopyWith<$Res> implements $RsHttpClientErrorCopyWith<$Res> {
  factory $RsHttpClientError_OtherCopyWith(RsHttpClientError_Other value, $Res Function(RsHttpClientError_Other) _then) = _$RsHttpClientError_OtherCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$RsHttpClientError_OtherCopyWithImpl<$Res>
    implements $RsHttpClientError_OtherCopyWith<$Res> {
  _$RsHttpClientError_OtherCopyWithImpl(this._self, this._then);

  final RsHttpClientError_Other _self;
  final $Res Function(RsHttpClientError_Other) _then;

/// Create a copy of RsHttpClientError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(RsHttpClientError_Other(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$RsTransferErrorV3 {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferErrorV3);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RsTransferErrorV3()';
}


}

/// @nodoc
class $RsTransferErrorV3CopyWith<$Res>  {
$RsTransferErrorV3CopyWith(RsTransferErrorV3 _, $Res Function(RsTransferErrorV3) __);
}


/// Adds pattern-matching-related methods to [RsTransferErrorV3].
extension RsTransferErrorV3Patterns on RsTransferErrorV3 {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RsTransferErrorV3_InvalidConfiguration value)?  invalidConfiguration,TResult Function( RsTransferErrorV3_UnsupportedSource value)?  unsupportedSource,TResult Function( RsTransferErrorV3_SourceChanged value)?  sourceChanged,TResult Function( RsTransferErrorV3_NetworkOrTimeout value)?  networkOrTimeout,TResult Function( RsTransferErrorV3_PeerIdentityMismatch value)?  peerIdentityMismatch,TResult Function( RsTransferErrorV3_Conflict value)?  conflict,TResult Function( RsTransferErrorV3_IntegrityVerificationFailed value)?  integrityVerificationFailed,TResult Function( RsTransferErrorV3_DestinationCollision value)?  destinationCollision,TResult Function( RsTransferErrorV3_InsufficientStorage value)?  insufficientStorage,TResult Function( RsTransferErrorV3_Cancelled value)?  cancelled,TResult Function( RsTransferErrorV3_Unexpected value)?  unexpected,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RsTransferErrorV3_InvalidConfiguration() when invalidConfiguration != null:
return invalidConfiguration(_that);case RsTransferErrorV3_UnsupportedSource() when unsupportedSource != null:
return unsupportedSource(_that);case RsTransferErrorV3_SourceChanged() when sourceChanged != null:
return sourceChanged(_that);case RsTransferErrorV3_NetworkOrTimeout() when networkOrTimeout != null:
return networkOrTimeout(_that);case RsTransferErrorV3_PeerIdentityMismatch() when peerIdentityMismatch != null:
return peerIdentityMismatch(_that);case RsTransferErrorV3_Conflict() when conflict != null:
return conflict(_that);case RsTransferErrorV3_IntegrityVerificationFailed() when integrityVerificationFailed != null:
return integrityVerificationFailed(_that);case RsTransferErrorV3_DestinationCollision() when destinationCollision != null:
return destinationCollision(_that);case RsTransferErrorV3_InsufficientStorage() when insufficientStorage != null:
return insufficientStorage(_that);case RsTransferErrorV3_Cancelled() when cancelled != null:
return cancelled(_that);case RsTransferErrorV3_Unexpected() when unexpected != null:
return unexpected(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RsTransferErrorV3_InvalidConfiguration value)  invalidConfiguration,required TResult Function( RsTransferErrorV3_UnsupportedSource value)  unsupportedSource,required TResult Function( RsTransferErrorV3_SourceChanged value)  sourceChanged,required TResult Function( RsTransferErrorV3_NetworkOrTimeout value)  networkOrTimeout,required TResult Function( RsTransferErrorV3_PeerIdentityMismatch value)  peerIdentityMismatch,required TResult Function( RsTransferErrorV3_Conflict value)  conflict,required TResult Function( RsTransferErrorV3_IntegrityVerificationFailed value)  integrityVerificationFailed,required TResult Function( RsTransferErrorV3_DestinationCollision value)  destinationCollision,required TResult Function( RsTransferErrorV3_InsufficientStorage value)  insufficientStorage,required TResult Function( RsTransferErrorV3_Cancelled value)  cancelled,required TResult Function( RsTransferErrorV3_Unexpected value)  unexpected,}){
final _that = this;
switch (_that) {
case RsTransferErrorV3_InvalidConfiguration():
return invalidConfiguration(_that);case RsTransferErrorV3_UnsupportedSource():
return unsupportedSource(_that);case RsTransferErrorV3_SourceChanged():
return sourceChanged(_that);case RsTransferErrorV3_NetworkOrTimeout():
return networkOrTimeout(_that);case RsTransferErrorV3_PeerIdentityMismatch():
return peerIdentityMismatch(_that);case RsTransferErrorV3_Conflict():
return conflict(_that);case RsTransferErrorV3_IntegrityVerificationFailed():
return integrityVerificationFailed(_that);case RsTransferErrorV3_DestinationCollision():
return destinationCollision(_that);case RsTransferErrorV3_InsufficientStorage():
return insufficientStorage(_that);case RsTransferErrorV3_Cancelled():
return cancelled(_that);case RsTransferErrorV3_Unexpected():
return unexpected(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RsTransferErrorV3_InvalidConfiguration value)?  invalidConfiguration,TResult? Function( RsTransferErrorV3_UnsupportedSource value)?  unsupportedSource,TResult? Function( RsTransferErrorV3_SourceChanged value)?  sourceChanged,TResult? Function( RsTransferErrorV3_NetworkOrTimeout value)?  networkOrTimeout,TResult? Function( RsTransferErrorV3_PeerIdentityMismatch value)?  peerIdentityMismatch,TResult? Function( RsTransferErrorV3_Conflict value)?  conflict,TResult? Function( RsTransferErrorV3_IntegrityVerificationFailed value)?  integrityVerificationFailed,TResult? Function( RsTransferErrorV3_DestinationCollision value)?  destinationCollision,TResult? Function( RsTransferErrorV3_InsufficientStorage value)?  insufficientStorage,TResult? Function( RsTransferErrorV3_Cancelled value)?  cancelled,TResult? Function( RsTransferErrorV3_Unexpected value)?  unexpected,}){
final _that = this;
switch (_that) {
case RsTransferErrorV3_InvalidConfiguration() when invalidConfiguration != null:
return invalidConfiguration(_that);case RsTransferErrorV3_UnsupportedSource() when unsupportedSource != null:
return unsupportedSource(_that);case RsTransferErrorV3_SourceChanged() when sourceChanged != null:
return sourceChanged(_that);case RsTransferErrorV3_NetworkOrTimeout() when networkOrTimeout != null:
return networkOrTimeout(_that);case RsTransferErrorV3_PeerIdentityMismatch() when peerIdentityMismatch != null:
return peerIdentityMismatch(_that);case RsTransferErrorV3_Conflict() when conflict != null:
return conflict(_that);case RsTransferErrorV3_IntegrityVerificationFailed() when integrityVerificationFailed != null:
return integrityVerificationFailed(_that);case RsTransferErrorV3_DestinationCollision() when destinationCollision != null:
return destinationCollision(_that);case RsTransferErrorV3_InsufficientStorage() when insufficientStorage != null:
return insufficientStorage(_that);case RsTransferErrorV3_Cancelled() when cancelled != null:
return cancelled(_that);case RsTransferErrorV3_Unexpected() when unexpected != null:
return unexpected(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String message)?  invalidConfiguration,TResult Function( String message)?  unsupportedSource,TResult Function( String message)?  sourceChanged,TResult Function( String message)?  networkOrTimeout,TResult Function( String message)?  peerIdentityMismatch,TResult Function( String message)?  conflict,TResult Function( String message)?  integrityVerificationFailed,TResult Function( String message)?  destinationCollision,TResult Function( String message)?  insufficientStorage,TResult Function()?  cancelled,TResult Function( String message)?  unexpected,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RsTransferErrorV3_InvalidConfiguration() when invalidConfiguration != null:
return invalidConfiguration(_that.message);case RsTransferErrorV3_UnsupportedSource() when unsupportedSource != null:
return unsupportedSource(_that.message);case RsTransferErrorV3_SourceChanged() when sourceChanged != null:
return sourceChanged(_that.message);case RsTransferErrorV3_NetworkOrTimeout() when networkOrTimeout != null:
return networkOrTimeout(_that.message);case RsTransferErrorV3_PeerIdentityMismatch() when peerIdentityMismatch != null:
return peerIdentityMismatch(_that.message);case RsTransferErrorV3_Conflict() when conflict != null:
return conflict(_that.message);case RsTransferErrorV3_IntegrityVerificationFailed() when integrityVerificationFailed != null:
return integrityVerificationFailed(_that.message);case RsTransferErrorV3_DestinationCollision() when destinationCollision != null:
return destinationCollision(_that.message);case RsTransferErrorV3_InsufficientStorage() when insufficientStorage != null:
return insufficientStorage(_that.message);case RsTransferErrorV3_Cancelled() when cancelled != null:
return cancelled();case RsTransferErrorV3_Unexpected() when unexpected != null:
return unexpected(_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String message)  invalidConfiguration,required TResult Function( String message)  unsupportedSource,required TResult Function( String message)  sourceChanged,required TResult Function( String message)  networkOrTimeout,required TResult Function( String message)  peerIdentityMismatch,required TResult Function( String message)  conflict,required TResult Function( String message)  integrityVerificationFailed,required TResult Function( String message)  destinationCollision,required TResult Function( String message)  insufficientStorage,required TResult Function()  cancelled,required TResult Function( String message)  unexpected,}) {final _that = this;
switch (_that) {
case RsTransferErrorV3_InvalidConfiguration():
return invalidConfiguration(_that.message);case RsTransferErrorV3_UnsupportedSource():
return unsupportedSource(_that.message);case RsTransferErrorV3_SourceChanged():
return sourceChanged(_that.message);case RsTransferErrorV3_NetworkOrTimeout():
return networkOrTimeout(_that.message);case RsTransferErrorV3_PeerIdentityMismatch():
return peerIdentityMismatch(_that.message);case RsTransferErrorV3_Conflict():
return conflict(_that.message);case RsTransferErrorV3_IntegrityVerificationFailed():
return integrityVerificationFailed(_that.message);case RsTransferErrorV3_DestinationCollision():
return destinationCollision(_that.message);case RsTransferErrorV3_InsufficientStorage():
return insufficientStorage(_that.message);case RsTransferErrorV3_Cancelled():
return cancelled();case RsTransferErrorV3_Unexpected():
return unexpected(_that.message);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String message)?  invalidConfiguration,TResult? Function( String message)?  unsupportedSource,TResult? Function( String message)?  sourceChanged,TResult? Function( String message)?  networkOrTimeout,TResult? Function( String message)?  peerIdentityMismatch,TResult? Function( String message)?  conflict,TResult? Function( String message)?  integrityVerificationFailed,TResult? Function( String message)?  destinationCollision,TResult? Function( String message)?  insufficientStorage,TResult? Function()?  cancelled,TResult? Function( String message)?  unexpected,}) {final _that = this;
switch (_that) {
case RsTransferErrorV3_InvalidConfiguration() when invalidConfiguration != null:
return invalidConfiguration(_that.message);case RsTransferErrorV3_UnsupportedSource() when unsupportedSource != null:
return unsupportedSource(_that.message);case RsTransferErrorV3_SourceChanged() when sourceChanged != null:
return sourceChanged(_that.message);case RsTransferErrorV3_NetworkOrTimeout() when networkOrTimeout != null:
return networkOrTimeout(_that.message);case RsTransferErrorV3_PeerIdentityMismatch() when peerIdentityMismatch != null:
return peerIdentityMismatch(_that.message);case RsTransferErrorV3_Conflict() when conflict != null:
return conflict(_that.message);case RsTransferErrorV3_IntegrityVerificationFailed() when integrityVerificationFailed != null:
return integrityVerificationFailed(_that.message);case RsTransferErrorV3_DestinationCollision() when destinationCollision != null:
return destinationCollision(_that.message);case RsTransferErrorV3_InsufficientStorage() when insufficientStorage != null:
return insufficientStorage(_that.message);case RsTransferErrorV3_Cancelled() when cancelled != null:
return cancelled();case RsTransferErrorV3_Unexpected() when unexpected != null:
return unexpected(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class RsTransferErrorV3_InvalidConfiguration extends RsTransferErrorV3 {
  const RsTransferErrorV3_InvalidConfiguration({required this.message}): super._();
  

 final  String message;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferErrorV3_InvalidConfigurationCopyWith<RsTransferErrorV3_InvalidConfiguration> get copyWith => _$RsTransferErrorV3_InvalidConfigurationCopyWithImpl<RsTransferErrorV3_InvalidConfiguration>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferErrorV3_InvalidConfiguration&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'RsTransferErrorV3.invalidConfiguration(message: $message)';
}


}

/// @nodoc
abstract mixin class $RsTransferErrorV3_InvalidConfigurationCopyWith<$Res> implements $RsTransferErrorV3CopyWith<$Res> {
  factory $RsTransferErrorV3_InvalidConfigurationCopyWith(RsTransferErrorV3_InvalidConfiguration value, $Res Function(RsTransferErrorV3_InvalidConfiguration) _then) = _$RsTransferErrorV3_InvalidConfigurationCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$RsTransferErrorV3_InvalidConfigurationCopyWithImpl<$Res>
    implements $RsTransferErrorV3_InvalidConfigurationCopyWith<$Res> {
  _$RsTransferErrorV3_InvalidConfigurationCopyWithImpl(this._self, this._then);

  final RsTransferErrorV3_InvalidConfiguration _self;
  final $Res Function(RsTransferErrorV3_InvalidConfiguration) _then;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(RsTransferErrorV3_InvalidConfiguration(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsTransferErrorV3_UnsupportedSource extends RsTransferErrorV3 {
  const RsTransferErrorV3_UnsupportedSource({required this.message}): super._();
  

 final  String message;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferErrorV3_UnsupportedSourceCopyWith<RsTransferErrorV3_UnsupportedSource> get copyWith => _$RsTransferErrorV3_UnsupportedSourceCopyWithImpl<RsTransferErrorV3_UnsupportedSource>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferErrorV3_UnsupportedSource&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'RsTransferErrorV3.unsupportedSource(message: $message)';
}


}

/// @nodoc
abstract mixin class $RsTransferErrorV3_UnsupportedSourceCopyWith<$Res> implements $RsTransferErrorV3CopyWith<$Res> {
  factory $RsTransferErrorV3_UnsupportedSourceCopyWith(RsTransferErrorV3_UnsupportedSource value, $Res Function(RsTransferErrorV3_UnsupportedSource) _then) = _$RsTransferErrorV3_UnsupportedSourceCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$RsTransferErrorV3_UnsupportedSourceCopyWithImpl<$Res>
    implements $RsTransferErrorV3_UnsupportedSourceCopyWith<$Res> {
  _$RsTransferErrorV3_UnsupportedSourceCopyWithImpl(this._self, this._then);

  final RsTransferErrorV3_UnsupportedSource _self;
  final $Res Function(RsTransferErrorV3_UnsupportedSource) _then;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(RsTransferErrorV3_UnsupportedSource(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsTransferErrorV3_SourceChanged extends RsTransferErrorV3 {
  const RsTransferErrorV3_SourceChanged({required this.message}): super._();
  

 final  String message;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferErrorV3_SourceChangedCopyWith<RsTransferErrorV3_SourceChanged> get copyWith => _$RsTransferErrorV3_SourceChangedCopyWithImpl<RsTransferErrorV3_SourceChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferErrorV3_SourceChanged&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'RsTransferErrorV3.sourceChanged(message: $message)';
}


}

/// @nodoc
abstract mixin class $RsTransferErrorV3_SourceChangedCopyWith<$Res> implements $RsTransferErrorV3CopyWith<$Res> {
  factory $RsTransferErrorV3_SourceChangedCopyWith(RsTransferErrorV3_SourceChanged value, $Res Function(RsTransferErrorV3_SourceChanged) _then) = _$RsTransferErrorV3_SourceChangedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$RsTransferErrorV3_SourceChangedCopyWithImpl<$Res>
    implements $RsTransferErrorV3_SourceChangedCopyWith<$Res> {
  _$RsTransferErrorV3_SourceChangedCopyWithImpl(this._self, this._then);

  final RsTransferErrorV3_SourceChanged _self;
  final $Res Function(RsTransferErrorV3_SourceChanged) _then;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(RsTransferErrorV3_SourceChanged(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsTransferErrorV3_NetworkOrTimeout extends RsTransferErrorV3 {
  const RsTransferErrorV3_NetworkOrTimeout({required this.message}): super._();
  

 final  String message;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferErrorV3_NetworkOrTimeoutCopyWith<RsTransferErrorV3_NetworkOrTimeout> get copyWith => _$RsTransferErrorV3_NetworkOrTimeoutCopyWithImpl<RsTransferErrorV3_NetworkOrTimeout>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferErrorV3_NetworkOrTimeout&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'RsTransferErrorV3.networkOrTimeout(message: $message)';
}


}

/// @nodoc
abstract mixin class $RsTransferErrorV3_NetworkOrTimeoutCopyWith<$Res> implements $RsTransferErrorV3CopyWith<$Res> {
  factory $RsTransferErrorV3_NetworkOrTimeoutCopyWith(RsTransferErrorV3_NetworkOrTimeout value, $Res Function(RsTransferErrorV3_NetworkOrTimeout) _then) = _$RsTransferErrorV3_NetworkOrTimeoutCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$RsTransferErrorV3_NetworkOrTimeoutCopyWithImpl<$Res>
    implements $RsTransferErrorV3_NetworkOrTimeoutCopyWith<$Res> {
  _$RsTransferErrorV3_NetworkOrTimeoutCopyWithImpl(this._self, this._then);

  final RsTransferErrorV3_NetworkOrTimeout _self;
  final $Res Function(RsTransferErrorV3_NetworkOrTimeout) _then;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(RsTransferErrorV3_NetworkOrTimeout(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsTransferErrorV3_PeerIdentityMismatch extends RsTransferErrorV3 {
  const RsTransferErrorV3_PeerIdentityMismatch({required this.message}): super._();
  

 final  String message;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferErrorV3_PeerIdentityMismatchCopyWith<RsTransferErrorV3_PeerIdentityMismatch> get copyWith => _$RsTransferErrorV3_PeerIdentityMismatchCopyWithImpl<RsTransferErrorV3_PeerIdentityMismatch>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferErrorV3_PeerIdentityMismatch&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'RsTransferErrorV3.peerIdentityMismatch(message: $message)';
}


}

/// @nodoc
abstract mixin class $RsTransferErrorV3_PeerIdentityMismatchCopyWith<$Res> implements $RsTransferErrorV3CopyWith<$Res> {
  factory $RsTransferErrorV3_PeerIdentityMismatchCopyWith(RsTransferErrorV3_PeerIdentityMismatch value, $Res Function(RsTransferErrorV3_PeerIdentityMismatch) _then) = _$RsTransferErrorV3_PeerIdentityMismatchCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$RsTransferErrorV3_PeerIdentityMismatchCopyWithImpl<$Res>
    implements $RsTransferErrorV3_PeerIdentityMismatchCopyWith<$Res> {
  _$RsTransferErrorV3_PeerIdentityMismatchCopyWithImpl(this._self, this._then);

  final RsTransferErrorV3_PeerIdentityMismatch _self;
  final $Res Function(RsTransferErrorV3_PeerIdentityMismatch) _then;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(RsTransferErrorV3_PeerIdentityMismatch(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsTransferErrorV3_Conflict extends RsTransferErrorV3 {
  const RsTransferErrorV3_Conflict({required this.message}): super._();
  

 final  String message;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferErrorV3_ConflictCopyWith<RsTransferErrorV3_Conflict> get copyWith => _$RsTransferErrorV3_ConflictCopyWithImpl<RsTransferErrorV3_Conflict>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferErrorV3_Conflict&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'RsTransferErrorV3.conflict(message: $message)';
}


}

/// @nodoc
abstract mixin class $RsTransferErrorV3_ConflictCopyWith<$Res> implements $RsTransferErrorV3CopyWith<$Res> {
  factory $RsTransferErrorV3_ConflictCopyWith(RsTransferErrorV3_Conflict value, $Res Function(RsTransferErrorV3_Conflict) _then) = _$RsTransferErrorV3_ConflictCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$RsTransferErrorV3_ConflictCopyWithImpl<$Res>
    implements $RsTransferErrorV3_ConflictCopyWith<$Res> {
  _$RsTransferErrorV3_ConflictCopyWithImpl(this._self, this._then);

  final RsTransferErrorV3_Conflict _self;
  final $Res Function(RsTransferErrorV3_Conflict) _then;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(RsTransferErrorV3_Conflict(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsTransferErrorV3_IntegrityVerificationFailed extends RsTransferErrorV3 {
  const RsTransferErrorV3_IntegrityVerificationFailed({required this.message}): super._();
  

 final  String message;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferErrorV3_IntegrityVerificationFailedCopyWith<RsTransferErrorV3_IntegrityVerificationFailed> get copyWith => _$RsTransferErrorV3_IntegrityVerificationFailedCopyWithImpl<RsTransferErrorV3_IntegrityVerificationFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferErrorV3_IntegrityVerificationFailed&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'RsTransferErrorV3.integrityVerificationFailed(message: $message)';
}


}

/// @nodoc
abstract mixin class $RsTransferErrorV3_IntegrityVerificationFailedCopyWith<$Res> implements $RsTransferErrorV3CopyWith<$Res> {
  factory $RsTransferErrorV3_IntegrityVerificationFailedCopyWith(RsTransferErrorV3_IntegrityVerificationFailed value, $Res Function(RsTransferErrorV3_IntegrityVerificationFailed) _then) = _$RsTransferErrorV3_IntegrityVerificationFailedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$RsTransferErrorV3_IntegrityVerificationFailedCopyWithImpl<$Res>
    implements $RsTransferErrorV3_IntegrityVerificationFailedCopyWith<$Res> {
  _$RsTransferErrorV3_IntegrityVerificationFailedCopyWithImpl(this._self, this._then);

  final RsTransferErrorV3_IntegrityVerificationFailed _self;
  final $Res Function(RsTransferErrorV3_IntegrityVerificationFailed) _then;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(RsTransferErrorV3_IntegrityVerificationFailed(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsTransferErrorV3_DestinationCollision extends RsTransferErrorV3 {
  const RsTransferErrorV3_DestinationCollision({required this.message}): super._();
  

 final  String message;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferErrorV3_DestinationCollisionCopyWith<RsTransferErrorV3_DestinationCollision> get copyWith => _$RsTransferErrorV3_DestinationCollisionCopyWithImpl<RsTransferErrorV3_DestinationCollision>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferErrorV3_DestinationCollision&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'RsTransferErrorV3.destinationCollision(message: $message)';
}


}

/// @nodoc
abstract mixin class $RsTransferErrorV3_DestinationCollisionCopyWith<$Res> implements $RsTransferErrorV3CopyWith<$Res> {
  factory $RsTransferErrorV3_DestinationCollisionCopyWith(RsTransferErrorV3_DestinationCollision value, $Res Function(RsTransferErrorV3_DestinationCollision) _then) = _$RsTransferErrorV3_DestinationCollisionCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$RsTransferErrorV3_DestinationCollisionCopyWithImpl<$Res>
    implements $RsTransferErrorV3_DestinationCollisionCopyWith<$Res> {
  _$RsTransferErrorV3_DestinationCollisionCopyWithImpl(this._self, this._then);

  final RsTransferErrorV3_DestinationCollision _self;
  final $Res Function(RsTransferErrorV3_DestinationCollision) _then;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(RsTransferErrorV3_DestinationCollision(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsTransferErrorV3_InsufficientStorage extends RsTransferErrorV3 {
  const RsTransferErrorV3_InsufficientStorage({required this.message}): super._();
  

 final  String message;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferErrorV3_InsufficientStorageCopyWith<RsTransferErrorV3_InsufficientStorage> get copyWith => _$RsTransferErrorV3_InsufficientStorageCopyWithImpl<RsTransferErrorV3_InsufficientStorage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferErrorV3_InsufficientStorage&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'RsTransferErrorV3.insufficientStorage(message: $message)';
}


}

/// @nodoc
abstract mixin class $RsTransferErrorV3_InsufficientStorageCopyWith<$Res> implements $RsTransferErrorV3CopyWith<$Res> {
  factory $RsTransferErrorV3_InsufficientStorageCopyWith(RsTransferErrorV3_InsufficientStorage value, $Res Function(RsTransferErrorV3_InsufficientStorage) _then) = _$RsTransferErrorV3_InsufficientStorageCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$RsTransferErrorV3_InsufficientStorageCopyWithImpl<$Res>
    implements $RsTransferErrorV3_InsufficientStorageCopyWith<$Res> {
  _$RsTransferErrorV3_InsufficientStorageCopyWithImpl(this._self, this._then);

  final RsTransferErrorV3_InsufficientStorage _self;
  final $Res Function(RsTransferErrorV3_InsufficientStorage) _then;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(RsTransferErrorV3_InsufficientStorage(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsTransferErrorV3_Cancelled extends RsTransferErrorV3 {
  const RsTransferErrorV3_Cancelled(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferErrorV3_Cancelled);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RsTransferErrorV3.cancelled()';
}


}




/// @nodoc


class RsTransferErrorV3_Unexpected extends RsTransferErrorV3 {
  const RsTransferErrorV3_Unexpected({required this.message}): super._();
  

 final  String message;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferErrorV3_UnexpectedCopyWith<RsTransferErrorV3_Unexpected> get copyWith => _$RsTransferErrorV3_UnexpectedCopyWithImpl<RsTransferErrorV3_Unexpected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferErrorV3_Unexpected&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'RsTransferErrorV3.unexpected(message: $message)';
}


}

/// @nodoc
abstract mixin class $RsTransferErrorV3_UnexpectedCopyWith<$Res> implements $RsTransferErrorV3CopyWith<$Res> {
  factory $RsTransferErrorV3_UnexpectedCopyWith(RsTransferErrorV3_Unexpected value, $Res Function(RsTransferErrorV3_Unexpected) _then) = _$RsTransferErrorV3_UnexpectedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$RsTransferErrorV3_UnexpectedCopyWithImpl<$Res>
    implements $RsTransferErrorV3_UnexpectedCopyWith<$Res> {
  _$RsTransferErrorV3_UnexpectedCopyWithImpl(this._self, this._then);

  final RsTransferErrorV3_Unexpected _self;
  final $Res Function(RsTransferErrorV3_Unexpected) _then;

/// Create a copy of RsTransferErrorV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(RsTransferErrorV3_Unexpected(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$RsTransferEventV3 {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferEventV3);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RsTransferEventV3()';
}


}

/// @nodoc
class $RsTransferEventV3CopyWith<$Res>  {
$RsTransferEventV3CopyWith(RsTransferEventV3 _, $Res Function(RsTransferEventV3) __);
}


/// Adds pattern-matching-related methods to [RsTransferEventV3].
extension RsTransferEventV3Patterns on RsTransferEventV3 {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RsTransferEventV3_Progress value)?  progress,TResult Function( RsTransferEventV3_Success value)?  success,TResult Function( RsTransferEventV3_Failed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RsTransferEventV3_Progress() when progress != null:
return progress(_that);case RsTransferEventV3_Success() when success != null:
return success(_that);case RsTransferEventV3_Failed() when failed != null:
return failed(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RsTransferEventV3_Progress value)  progress,required TResult Function( RsTransferEventV3_Success value)  success,required TResult Function( RsTransferEventV3_Failed value)  failed,}){
final _that = this;
switch (_that) {
case RsTransferEventV3_Progress():
return progress(_that);case RsTransferEventV3_Success():
return success(_that);case RsTransferEventV3_Failed():
return failed(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RsTransferEventV3_Progress value)?  progress,TResult? Function( RsTransferEventV3_Success value)?  success,TResult? Function( RsTransferEventV3_Failed value)?  failed,}){
final _that = this;
switch (_that) {
case RsTransferEventV3_Progress() when progress != null:
return progress(_that);case RsTransferEventV3_Success() when success != null:
return success(_that);case RsTransferEventV3_Failed() when failed != null:
return failed(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( BigInt bytesTransferred,  BigInt totalBytes,  double progress)?  progress,TResult Function( RsTransferResultV3 result)?  success,TResult Function( RsTransferErrorV3 error)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RsTransferEventV3_Progress() when progress != null:
return progress(_that.bytesTransferred,_that.totalBytes,_that.progress);case RsTransferEventV3_Success() when success != null:
return success(_that.result);case RsTransferEventV3_Failed() when failed != null:
return failed(_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( BigInt bytesTransferred,  BigInt totalBytes,  double progress)  progress,required TResult Function( RsTransferResultV3 result)  success,required TResult Function( RsTransferErrorV3 error)  failed,}) {final _that = this;
switch (_that) {
case RsTransferEventV3_Progress():
return progress(_that.bytesTransferred,_that.totalBytes,_that.progress);case RsTransferEventV3_Success():
return success(_that.result);case RsTransferEventV3_Failed():
return failed(_that.error);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( BigInt bytesTransferred,  BigInt totalBytes,  double progress)?  progress,TResult? Function( RsTransferResultV3 result)?  success,TResult? Function( RsTransferErrorV3 error)?  failed,}) {final _that = this;
switch (_that) {
case RsTransferEventV3_Progress() when progress != null:
return progress(_that.bytesTransferred,_that.totalBytes,_that.progress);case RsTransferEventV3_Success() when success != null:
return success(_that.result);case RsTransferEventV3_Failed() when failed != null:
return failed(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class RsTransferEventV3_Progress extends RsTransferEventV3 {
  const RsTransferEventV3_Progress({required this.bytesTransferred, required this.totalBytes, required this.progress}): super._();
  

 final  BigInt bytesTransferred;
 final  BigInt totalBytes;
 final  double progress;

/// Create a copy of RsTransferEventV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferEventV3_ProgressCopyWith<RsTransferEventV3_Progress> get copyWith => _$RsTransferEventV3_ProgressCopyWithImpl<RsTransferEventV3_Progress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferEventV3_Progress&&(identical(other.bytesTransferred, bytesTransferred) || other.bytesTransferred == bytesTransferred)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode => Object.hash(runtimeType,bytesTransferred,totalBytes,progress);

@override
String toString() {
  return 'RsTransferEventV3.progress(bytesTransferred: $bytesTransferred, totalBytes: $totalBytes, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $RsTransferEventV3_ProgressCopyWith<$Res> implements $RsTransferEventV3CopyWith<$Res> {
  factory $RsTransferEventV3_ProgressCopyWith(RsTransferEventV3_Progress value, $Res Function(RsTransferEventV3_Progress) _then) = _$RsTransferEventV3_ProgressCopyWithImpl;
@useResult
$Res call({
 BigInt bytesTransferred, BigInt totalBytes, double progress
});




}
/// @nodoc
class _$RsTransferEventV3_ProgressCopyWithImpl<$Res>
    implements $RsTransferEventV3_ProgressCopyWith<$Res> {
  _$RsTransferEventV3_ProgressCopyWithImpl(this._self, this._then);

  final RsTransferEventV3_Progress _self;
  final $Res Function(RsTransferEventV3_Progress) _then;

/// Create a copy of RsTransferEventV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bytesTransferred = null,Object? totalBytes = null,Object? progress = null,}) {
  return _then(RsTransferEventV3_Progress(
bytesTransferred: null == bytesTransferred ? _self.bytesTransferred : bytesTransferred // ignore: cast_nullable_to_non_nullable
as BigInt,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as BigInt,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class RsTransferEventV3_Success extends RsTransferEventV3 {
  const RsTransferEventV3_Success({required this.result}): super._();
  

 final  RsTransferResultV3 result;

/// Create a copy of RsTransferEventV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferEventV3_SuccessCopyWith<RsTransferEventV3_Success> get copyWith => _$RsTransferEventV3_SuccessCopyWithImpl<RsTransferEventV3_Success>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferEventV3_Success&&(identical(other.result, result) || other.result == result));
}


@override
int get hashCode => Object.hash(runtimeType,result);

@override
String toString() {
  return 'RsTransferEventV3.success(result: $result)';
}


}

/// @nodoc
abstract mixin class $RsTransferEventV3_SuccessCopyWith<$Res> implements $RsTransferEventV3CopyWith<$Res> {
  factory $RsTransferEventV3_SuccessCopyWith(RsTransferEventV3_Success value, $Res Function(RsTransferEventV3_Success) _then) = _$RsTransferEventV3_SuccessCopyWithImpl;
@useResult
$Res call({
 RsTransferResultV3 result
});




}
/// @nodoc
class _$RsTransferEventV3_SuccessCopyWithImpl<$Res>
    implements $RsTransferEventV3_SuccessCopyWith<$Res> {
  _$RsTransferEventV3_SuccessCopyWithImpl(this._self, this._then);

  final RsTransferEventV3_Success _self;
  final $Res Function(RsTransferEventV3_Success) _then;

/// Create a copy of RsTransferEventV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? result = null,}) {
  return _then(RsTransferEventV3_Success(
result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as RsTransferResultV3,
  ));
}


}

/// @nodoc


class RsTransferEventV3_Failed extends RsTransferEventV3 {
  const RsTransferEventV3_Failed({required this.error}): super._();
  

 final  RsTransferErrorV3 error;

/// Create a copy of RsTransferEventV3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsTransferEventV3_FailedCopyWith<RsTransferEventV3_Failed> get copyWith => _$RsTransferEventV3_FailedCopyWithImpl<RsTransferEventV3_Failed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsTransferEventV3_Failed&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'RsTransferEventV3.failed(error: $error)';
}


}

/// @nodoc
abstract mixin class $RsTransferEventV3_FailedCopyWith<$Res> implements $RsTransferEventV3CopyWith<$Res> {
  factory $RsTransferEventV3_FailedCopyWith(RsTransferEventV3_Failed value, $Res Function(RsTransferEventV3_Failed) _then) = _$RsTransferEventV3_FailedCopyWithImpl;
@useResult
$Res call({
 RsTransferErrorV3 error
});


$RsTransferErrorV3CopyWith<$Res> get error;

}
/// @nodoc
class _$RsTransferEventV3_FailedCopyWithImpl<$Res>
    implements $RsTransferEventV3_FailedCopyWith<$Res> {
  _$RsTransferEventV3_FailedCopyWithImpl(this._self, this._then);

  final RsTransferEventV3_Failed _self;
  final $Res Function(RsTransferEventV3_Failed) _then;

/// Create a copy of RsTransferEventV3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(RsTransferEventV3_Failed(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as RsTransferErrorV3,
  ));
}

/// Create a copy of RsTransferEventV3
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RsTransferErrorV3CopyWith<$Res> get error {
  
  return $RsTransferErrorV3CopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

/// @nodoc
mixin _$RsUploadEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsUploadEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RsUploadEvent()';
}


}

/// @nodoc
class $RsUploadEventCopyWith<$Res>  {
$RsUploadEventCopyWith(RsUploadEvent _, $Res Function(RsUploadEvent) __);
}


/// Adds pattern-matching-related methods to [RsUploadEvent].
extension RsUploadEventPatterns on RsUploadEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RsUploadEvent_Progress value)?  progress,TResult Function( RsUploadEvent_Failed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RsUploadEvent_Progress() when progress != null:
return progress(_that);case RsUploadEvent_Failed() when failed != null:
return failed(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RsUploadEvent_Progress value)  progress,required TResult Function( RsUploadEvent_Failed value)  failed,}){
final _that = this;
switch (_that) {
case RsUploadEvent_Progress():
return progress(_that);case RsUploadEvent_Failed():
return failed(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RsUploadEvent_Progress value)?  progress,TResult? Function( RsUploadEvent_Failed value)?  failed,}){
final _that = this;
switch (_that) {
case RsUploadEvent_Progress() when progress != null:
return progress(_that);case RsUploadEvent_Failed() when failed != null:
return failed(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( double progress)?  progress,TResult Function( RsHttpClientError error)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RsUploadEvent_Progress() when progress != null:
return progress(_that.progress);case RsUploadEvent_Failed() when failed != null:
return failed(_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( double progress)  progress,required TResult Function( RsHttpClientError error)  failed,}) {final _that = this;
switch (_that) {
case RsUploadEvent_Progress():
return progress(_that.progress);case RsUploadEvent_Failed():
return failed(_that.error);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( double progress)?  progress,TResult? Function( RsHttpClientError error)?  failed,}) {final _that = this;
switch (_that) {
case RsUploadEvent_Progress() when progress != null:
return progress(_that.progress);case RsUploadEvent_Failed() when failed != null:
return failed(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class RsUploadEvent_Progress extends RsUploadEvent {
  const RsUploadEvent_Progress({required this.progress}): super._();
  

 final  double progress;

/// Create a copy of RsUploadEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsUploadEvent_ProgressCopyWith<RsUploadEvent_Progress> get copyWith => _$RsUploadEvent_ProgressCopyWithImpl<RsUploadEvent_Progress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsUploadEvent_Progress&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode => Object.hash(runtimeType,progress);

@override
String toString() {
  return 'RsUploadEvent.progress(progress: $progress)';
}


}

/// @nodoc
abstract mixin class $RsUploadEvent_ProgressCopyWith<$Res> implements $RsUploadEventCopyWith<$Res> {
  factory $RsUploadEvent_ProgressCopyWith(RsUploadEvent_Progress value, $Res Function(RsUploadEvent_Progress) _then) = _$RsUploadEvent_ProgressCopyWithImpl;
@useResult
$Res call({
 double progress
});




}
/// @nodoc
class _$RsUploadEvent_ProgressCopyWithImpl<$Res>
    implements $RsUploadEvent_ProgressCopyWith<$Res> {
  _$RsUploadEvent_ProgressCopyWithImpl(this._self, this._then);

  final RsUploadEvent_Progress _self;
  final $Res Function(RsUploadEvent_Progress) _then;

/// Create a copy of RsUploadEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? progress = null,}) {
  return _then(RsUploadEvent_Progress(
progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class RsUploadEvent_Failed extends RsUploadEvent {
  const RsUploadEvent_Failed({required this.error}): super._();
  

 final  RsHttpClientError error;

/// Create a copy of RsUploadEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsUploadEvent_FailedCopyWith<RsUploadEvent_Failed> get copyWith => _$RsUploadEvent_FailedCopyWithImpl<RsUploadEvent_Failed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsUploadEvent_Failed&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'RsUploadEvent.failed(error: $error)';
}


}

/// @nodoc
abstract mixin class $RsUploadEvent_FailedCopyWith<$Res> implements $RsUploadEventCopyWith<$Res> {
  factory $RsUploadEvent_FailedCopyWith(RsUploadEvent_Failed value, $Res Function(RsUploadEvent_Failed) _then) = _$RsUploadEvent_FailedCopyWithImpl;
@useResult
$Res call({
 RsHttpClientError error
});


$RsHttpClientErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$RsUploadEvent_FailedCopyWithImpl<$Res>
    implements $RsUploadEvent_FailedCopyWith<$Res> {
  _$RsUploadEvent_FailedCopyWithImpl(this._self, this._then);

  final RsUploadEvent_Failed _self;
  final $Res Function(RsUploadEvent_Failed) _then;

/// Create a copy of RsUploadEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(RsUploadEvent_Failed(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as RsHttpClientError,
  ));
}

/// Create a copy of RsUploadEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RsHttpClientErrorCopyWith<$Res> get error {
  
  return $RsHttpClientErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

// dart format on
