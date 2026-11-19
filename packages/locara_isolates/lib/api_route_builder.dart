import 'package:locara_isolates/model/device.dart';

const _meshBasePath = '/api/mesh';
const _locaraBasePath = '/api/locara';

/// Type-safe API paths supporting both modern Mesh routes and legacy fallback.
enum ApiRoute {
  info('info'),
  register('register'),
  prepareUpload('prepare-upload', 'send-request'),
  upload('upload', 'send'),
  cancel('cancel'),
  show('show'),
  prepareDownload('prepare-download'),
  download('download'),
  ;

  const ApiRoute(String path, [String? legacy])
      : v1 = '$_locaraBasePath/v1/${legacy ?? path}',
        v2 = '$_locaraBasePath/v2/$path',
        meshV2 = '$_meshBasePath/v2/$path',
        meshV3 = '$_meshBasePath/v3/$path',
        _rawPath = path;

  final String _rawPath;

  /// The server url for legacy v1
  final String v1;

  /// The server url for legacy v2
  final String v2;

  /// The modern Mesh v2 route
  final String meshV2;

  /// The modern Mesh v3 route
  final String meshV3;

  /// The client url for connecting to a peer.
  /// Set [preferMesh] to true to route to the modern Mesh API,
  /// falling back to legacy paths when communicating with older nodes.
  String target(Device target, {Map<String, String>? query, bool preferMesh = false}) {
    final route = switch (target.version) {
      '1.0' => v1,
      '3.0' => preferMesh ? meshV3 : '$_locaraBasePath/v3/$_rawPath',
      _ => preferMesh ? meshV2 : v2,
    };
    return Uri(
      scheme: target.https ? 'https' : 'http',
      host: target.ip,
      port: target.port,
      path: route,
      queryParameters: query,
    ).toString();
  }

  /// The client url for polling/raw checks
  String targetRaw(String ip, int port, bool https, String version, {bool preferMesh = false}) {
    final protocol = https ? 'https' : 'http';
    final route = switch (version) {
      '1.0' => v1,
      '3.0' => preferMesh ? meshV3 : '$_locaraBasePath/v3/$_rawPath',
      _ => preferMesh ? meshV2 : v2,
    };
    return '$protocol://$ip:$port$route';
  }
}
