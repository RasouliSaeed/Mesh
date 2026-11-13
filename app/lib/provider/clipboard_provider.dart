import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:locara_app/gen/strings.g.dart';
import 'package:locara_app/model/cross_file.dart';
import 'package:locara_app/provider/chat_provider.dart';
import 'package:locara_app/provider/network/send_provider.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_isolates/model/device.dart';
import 'package:locara_isolates/model/file_type.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Provides universal clipboard synchronization utilities across local devices.
class ClipboardSyncService {
  /// Reads current system clipboard text.
  static Future<String?> readText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (_) {
      return null;
    }
  }

  /// Copies text to the system clipboard and displays a feedback toast.
  static Future<void> copyToClipboard(
    BuildContext context,
    String text, {
    String? message,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      try {
        final feedback = message ?? t.general.copiedToClipboard;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              feedback,
              style: const TextStyle(color: LocaraDesignTokens.primaryText),
            ),
            backgroundColor: LocaraDesignTokens.darkNavy,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (_) {}
    }
  }

  /// Reads the current system clipboard and directly sends it to the target device
  /// as an end-to-end encrypted text message / clipboard payload.
  static Future<bool> sendClipboard({
    required BuildContext context,
    required Device target,
  }) async {
    final ref = context.ref;
    final text = await readText();
    if (text == null || text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'هیچ متنی در کلیپ‌بورد سیستم موجود نیست.',
              style: TextStyle(color: LocaraDesignTokens.primaryText),
            ),
            backgroundColor: LocaraDesignTokens.darkNavy,
          ),
        );
      }
      return false;
    }

    final bytes = utf8.encode(text);
    final file = CrossFile(
      name: text,
      fileType: FileType.text,
      size: bytes.length,
      thumbnail: null,
      asset: null,
      path: null,
      bytes: bytes,
      lastModified: null,
      lastAccessed: null,
    );

    ref.notifier(chatProvider).setTarget(target);
    ref.notifier(chatProvider).addMessage(text, isMine: true);

    await ref.notifier(sendProvider).startSession(
          target: target,
          files: [file],
          background: true,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'متن کلیپ‌بورد به ${target.alias} ارسال شد.',
            style: const TextStyle(color: LocaraDesignTokens.cyan),
          ),
          backgroundColor: LocaraDesignTokens.darkNavy,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return true;
  }
}
