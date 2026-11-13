import 'package:flutter/services.dart';
import 'package:locara_isolates/model/device.dart';
import 'package:locara_isolates/rust/api/cancel.dart';
import 'package:locara_isolates/rust/api/http.dart';
import 'package:locara_isolates/src/isolate/child/http_provider.dart';
import 'package:locara_isolates/src/isolate/child/main.dart';
import 'package:locara_isolates/src/isolate/child/sync_provider.dart';
import 'package:locara_isolates/src/isolate/dto/send_to_isolate_data.dart';
import 'package:locara_isolates/src/task/upload/http_upload.dart';
import 'package:locara_isolates/src/task/upload/http_upload_v3.dart';
import 'package:locara_isolates/util/android_channel.dart';
import 'package:locara_isolates/util/rust.dart';
import 'package:pool/pool.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:typed_isolates/typed_isolates.dart';

/// How many files of a [HttpUploadFilesTask] are uploaded in parallel.
const _concurrency = 2;

/// How often a single file is uploaded at most when the receiver keeps
/// rejecting it with a checksum mismatch (HTTP 422).
/// Must not exceed MAX_UPLOAD_ATTEMPTS of the Rust server which stops
/// accepting retries at some point.
const _maxUploadAttempts = 3;

sealed class BaseHttpUploadTask {}

class HttpUploadFile {
  final String remoteFileToken;
  final String fileId;
  final String? filePath;
  final List<int>? fileBytes;
  final int fileSize;

  HttpUploadFile({
    required this.remoteFileToken,
    required this.fileId,
    required this.filePath,
    required this.fileBytes,
    required this.fileSize,
  });
}

/// Uploads a list of files as one isolate task.
///
/// This task is intended to replace the file scheduling loop in the parent
/// isolate. Up to [_concurrency] files are uploaded in parallel and progress
/// is reported across the complete list.
class HttpUploadFilesTask implements BaseHttpUploadTask {
  final String? remoteSessionId;
  final List<HttpUploadFile> files;
  final Device device;

  HttpUploadFilesTask({
    required this.remoteSessionId,
    required this.files,
    required this.device,
  });
}

class HttpUploadFileV3 {
  final String transferId;
  final String filePath;
  final int fileSize;

  HttpUploadFileV3({
    required this.transferId,
    required this.filePath,
    required this.fileSize,
  });
}

/// Uploads a list of files using the V3 chunked protocol.
class HttpUploadFilesV3Task implements BaseHttpUploadTask {
  final List<HttpUploadFileV3> files;
  final Device device;
  final RsTransferConfigV3? config;

  HttpUploadFilesV3Task({
    required this.files,
    required this.device,
    this.config,
  });
}

class HttpUploadCancelTask implements BaseHttpUploadTask {
  final int taskId;

  HttpUploadCancelTask({required this.taskId});
}

/// A message sent from the upload isolate to the main isolate
/// reporting the state of a single file of a [HttpUploadFilesTask] or [HttpUploadFilesV3Task].
sealed class HttpUploadEvent {
  final String fileId;

  HttpUploadEvent({required this.fileId});
}

/// The upload of the file has started.
class HttpUploadFileStartedEvent extends HttpUploadEvent {
  HttpUploadFileStartedEvent({required super.fileId});
}

/// The upload progress of the file in the range [0, 1].
class HttpUploadFileProgressEvent extends HttpUploadEvent {
  final double progress;
  final int? bytesTransferred;
  final int? totalBytes;

  HttpUploadFileProgressEvent({
    required super.fileId,
    required this.progress,
    this.bytesTransferred,
    this.totalBytes,
  });
}

/// The file has been uploaded successfully.
class HttpUploadFileFinishedEvent extends HttpUploadEvent {
  final RsTransferResultV3? result;

  HttpUploadFileFinishedEvent({
    required super.fileId,
    this.result,
  });
}

/// The upload of the file has failed. The next file is still uploaded.
class HttpUploadFileFailedEvent extends HttpUploadEvent {
  final String error;

  HttpUploadFileFailedEvent({
    required super.fileId,
    required this.error,
  });
}

/// Map of cancel tokens for each task.
/// Task ID -> CancelToken
final _cancelTokenProvider = Provider((ref) => <int, RsCancellationToken>{});

Future<void> setupHttpUploadIsolate(
  Stream<SendToIsolateData<IsolateTask<BaseHttpUploadTask>>> receiveFromMain,
  void Function(IsolateTaskStreamResult<HttpUploadEvent>) sendToMain,
  InitialData initialData,
) async {
  await setupChildIsolateHelper(
    debugLabel: 'HttpUploadIsolate',
    receiveFromMain: receiveFromMain,
    sendToMain: sendToMain,
    initialData: initialData,
    init: (ref) async {
      // Initialize the platform method channel so getFileDescriptorAndroid
      // (used to resolve "content://" files) works inside this isolate.
      BackgroundIsolateBinaryMessenger.ensureInitialized(
        ref.read(syncProvider).rootIsolateToken as RootIsolateToken,
      );
    },
    handler: (ref, task) async {
      switch (task.data) {
        case HttpUploadFilesTask uploadTask:
          await _handleUploadV2(ref, task.id, uploadTask, sendToMain);
          return;
        case HttpUploadFilesV3Task uploadTask:
          await _handleUploadV3(ref, task.id, uploadTask, sendToMain);
          return;
        case HttpUploadCancelTask cancelTask:
          final cancelToken = ref.read(_cancelTokenProvider)[cancelTask.taskId];
          cancelToken?.cancel();
          ref.read(_cancelTokenProvider).remove(cancelTask.taskId);
          return;
      }
    },
  );
}

Future<void> _handleUploadV2(
  Ref ref,
  int taskId,
  HttpUploadFilesTask uploadTask,
  void Function(IsolateTaskStreamResult<HttpUploadEvent>) sendToMain,
) async {
  // One client for the whole task: pinned to the receiver, so no file
  // content can be streamed to a different peer, and shared by all files
  // of the task so the connection is reused.
  final client = ref.read(httpProvider).pinnedTo(uploadTask.device.fingerprint);

  final cancelToken = createCancellationToken();
  ref.read(_cancelTokenProvider).putIfAbsent(taskId, () => cancelToken);
  try {
    await Pool(_concurrency).forEach<HttpUploadFile, void>(uploadTask.files, (file) async {
      if (!ref.read(_cancelTokenProvider).containsKey(taskId)) {
        // the task was canceled, do not upload the remaining files
        return;
      }

      sendToMain(
        IsolateTaskStreamResult.event(
          id: taskId,
          data: HttpUploadFileStartedEvent(fileId: file.fileId),
        ),
      );

      try {
        final filePath = file.filePath;
        final isContentUri = filePath?.startsWith('content://') ?? false;

        for (var attempt = 1; ; attempt++) {
          // The file descriptor is consumed by the upload, so a fresh one
          // is needed for every attempt.
          final fileDescriptor = isContentUri ? await getFileDescriptorAndroid(uri: filePath!) : null;

          try {
            await ref
                .read(httpUploadProvider)
                .upload(
                  client: client,
                  stream: filePath == null && file.fileBytes != null ? Stream.value(file.fileBytes!) : null,
                  path: !isContentUri ? filePath : null,
                  fileDescriptor: fileDescriptor,
                  contentLength: file.fileSize,
                  target: uploadTask.device,
                  remoteSessionId: uploadTask.remoteSessionId,
                  fileId: file.fileId,
                  token: file.remoteFileToken,
                  onSendProgress: (progress) {
                    sendToMain(
                      IsolateTaskStreamResult.event(
                        id: taskId,
                        data: HttpUploadFileProgressEvent(
                          fileId: file.fileId,
                          progress: progress,
                        ),
                      ),
                    );
                  },
                  cancelToken: cancelToken,
                );
            break;
          } on RsHttpClientError_StatusCode catch (e) {
            if (e.status != 422 || attempt >= _maxUploadAttempts) {
              rethrow;
            }
            // The receiver discarded the file because its checksum did not
            // match (e.g. the file changed while being read). Send it again.
          }
        }

        sendToMain(
          IsolateTaskStreamResult.event(
            id: taskId,
            data: HttpUploadFileFinishedEvent(fileId: file.fileId),
          ),
        );
      } catch (e) {
        sendToMain(
          IsolateTaskStreamResult.event(
            id: taskId,
            data: HttpUploadFileFailedEvent(
              fileId: file.fileId,
              error: e.humanErrorMessage,
            ),
          ),
        );
      }
    }).drain<void>();

    sendToMain(
      IsolateTaskStreamResult.done(
        id: taskId,
      ),
    );
  } finally {
    ref.read(_cancelTokenProvider).remove(taskId);
  }
}

Future<void> _handleUploadV3(
  Ref ref,
  int taskId,
  HttpUploadFilesV3Task uploadTask,
  void Function(IsolateTaskStreamResult<HttpUploadEvent>) sendToMain,
) async {
  final client = ref.read(httpProvider).pinnedToV3(uploadTask.device.fingerprint);

  final cancelToken = createCancellationToken();
  ref.read(_cancelTokenProvider).putIfAbsent(taskId, () => cancelToken);
  try {
    await Pool(1).forEach<HttpUploadFileV3, void>(uploadTask.files, (file) async {
      if (!ref.read(_cancelTokenProvider).containsKey(taskId)) {
        return;
      }

      sendToMain(
        IsolateTaskStreamResult.event(
          id: taskId,
          data: HttpUploadFileStartedEvent(fileId: file.transferId),
        ),
      );

      try {
        final result = await ref
            .read(httpUploadV3Provider)
            .transfer(
              client: client,
              target: uploadTask.device,
              transferId: file.transferId,
              filePath: file.filePath,
              config: uploadTask.config,
              onProgress: (bytesTransferred, totalBytes, progress) {
                sendToMain(
                  IsolateTaskStreamResult.event(
                    id: taskId,
                    data: HttpUploadFileProgressEvent(
                      fileId: file.transferId,
                      progress: progress,
                      bytesTransferred: bytesTransferred,
                      totalBytes: totalBytes,
                    ),
                  ),
                );
              },
              cancelToken: cancelToken,
            );

        sendToMain(
          IsolateTaskStreamResult.event(
            id: taskId,
            data: HttpUploadFileFinishedEvent(
              fileId: file.transferId,
              result: result,
            ),
          ),
        );
      } catch (e) {
        sendToMain(
          IsolateTaskStreamResult.event(
            id: taskId,
            data: HttpUploadFileFailedEvent(
              fileId: file.transferId,
              error: e.humanErrorMessage,
            ),
          ),
        );
      }
    }).drain<void>();

    sendToMain(
      IsolateTaskStreamResult.done(
        id: taskId,
      ),
    );
  } finally {
    ref.read(_cancelTokenProvider).remove(taskId);
  }
}
