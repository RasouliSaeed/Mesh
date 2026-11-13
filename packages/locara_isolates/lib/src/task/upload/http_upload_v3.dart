import 'dart:async';
import 'package:locara_isolates/model/device.dart';
import 'package:locara_isolates/rust/api/cancel.dart';
import 'package:locara_isolates/rust/api/http.dart';
import 'package:locara_isolates/util/rust.dart';
import 'package:refena_flutter/refena_flutter.dart';

final httpUploadV3Provider = ViewProvider((ref) => const HttpUploadV3Service());

class HttpUploadV3Service {
  const HttpUploadV3Service();

  /// Orchestrates a V3 chunked transfer of a file through the Rust FFI bridge.
  Future<RsTransferResultV3> transfer({
    required RsHttpClient client,
    required Device target,
    required String transferId,
    required String filePath,
    RsTransferConfigV3? config,
    required void Function(int bytesTransferred, int totalBytes, double progress) onProgress,
    required RsCancellationToken cancelToken,
  }) async {
    final transferConfig =
        config ??
        RsTransferConfigV3(
          chunkSize: BigInt.from(1048576), // 1 MiB default
          maxConcurrency: 1,
          maxRetries: 3,
          retryBaseDelayMs: 200,
          retryMaxDelayMs: 2000,
          verifyChunkHashes: true,
        );

    final completer = Completer<RsTransferResultV3>();

    final subscription = client
        .transferV3(
          protocol: target.getProtocolType(),
          ip: target.ip!,
          port: target.port,
          publicKey: null,
          transferId: transferId,
          filePath: filePath,
          config: transferConfig,
          cancelToken: cancelToken,
        )
        .listen(
          (event) {
            event.when(
              progress: (bytesTransferred, totalBytes, progress) {
                onProgress(bytesTransferred.toInt(), totalBytes.toInt(), progress);
              },
              success: (result) {
                if (!completer.isCompleted) {
                  completer.complete(result);
                }
              },
              failed: (error) {
                if (!completer.isCompleted) {
                  completer.completeError(error);
                }
              },
            );
          },
          onError: (e, st) {
            if (!completer.isCompleted) {
              completer.completeError(e, st);
            }
          },
          onDone: () {
            if (!completer.isCompleted) {
              completer.completeError(
                const RsTransferErrorV3.unexpected(
                  message: 'Transfer stream closed without a terminal outcome event',
                ),
              );
            }
          },
          cancelOnError: true,
        );

    try {
      return await completer.future;
    } finally {
      await subscription.cancel();
    }
  }
}
