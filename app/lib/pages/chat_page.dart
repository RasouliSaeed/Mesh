import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:locara_app/model/cross_file.dart';
import 'package:locara_app/provider/chat_provider.dart';
import 'package:locara_app/provider/clipboard_provider.dart';
import 'package:locara_app/provider/network/send_provider.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_app/widget/design/mesh_state_views.dart';
import 'package:locara_isolates/model/file_type.dart';
import 'package:refena_flutter/refena_flutter.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage(BuildContext context) async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    final target = context.ref.read(chatProvider).currentTarget;
    if (target != null) {
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

      context.ref.notifier(chatProvider).addMessage(text, isMine: true);
      _controller.clear();

      await context.ref
          .notifier(sendProvider)
          .startSession(
            target: target,
            files: [file],
            background: true,
          );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مخاطبی برای ارسال پیام انتخاب نشده است. لطفاً ابتدا دستگاه مقصد را مشخص کنید.'),
          backgroundColor: LocaraDesignTokens.darkNavy,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = context.ref.watch(chatProvider);
    final currentTarget = chatState.currentTarget;

    return Scaffold(
      backgroundColor: LocaraDesignTokens.deepNavy,
      appBar: AppBar(
        backgroundColor: LocaraDesignTokens.darkNavy,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'پیام‌های محلی',
              style: TextStyle(
                color: LocaraDesignTokens.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (currentTarget != null)
              Text(
                'متصل به ${currentTarget.alias}',
                style: const TextStyle(
                  color: LocaraDesignTokens.cyan,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          if (currentTarget != null)
            IconButton(
              icon: const Icon(Icons.content_paste_go_rounded, color: LocaraDesignTokens.cyan),
              tooltip: 'ارسال فوری محتوای کلیپ‌بورد',
              onPressed: () => ClipboardSyncService.sendClipboard(
                context: context,
                target: currentTarget,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.messages.isEmpty
                ? const LocaraEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'گفتگوی محلی',
                    description: 'پیام‌های ارسالی در بستر امن شبکه محلی و به صورت مستقیم بین دو دستگاه تبادل می‌شوند.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LocaraDesignTokens.spacing16,
                      vertical: LocaraDesignTokens.spacing12,
                    ),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      return Align(
                        alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: InkWell(
                          onTap: () => ClipboardSyncService.copyToClipboard(context, message.text),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: message.isMine ? LocaraDesignTokens.primaryGradient : null,
                              color: message.isMine ? null : LocaraDesignTokens.cardSurfaceLight,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(message.isMine ? 16 : 4),
                                bottomRight: Radius.circular(message.isMine ? 4 : 16),
                              ),
                              border: message.isMine
                                  ? null
                                  : Border.all(
                                      color: LocaraDesignTokens.cardBorderSubtle,
                                      width: 1,
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!message.isMine && message.sender != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      message.sender!.alias,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: LocaraDesignTokens.cyan,
                                      ),
                                    ),
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        message.text,
                                        style: const TextStyle(
                                          color: LocaraDesignTokens.primaryText,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 13,
                                      color: message.isMine ? Colors.white.withValues(alpha: 0.6) : LocaraDesignTokens.mutedText,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: LocaraDesignTokens.darkNavy,
              border: Border(
                top: BorderSide(
                  color: LocaraDesignTokens.cardBorderSubtle,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: LocaraDesignTokens.cardSurface,
                        borderRadius: LocaraDesignTokens.borderRadiusLarge,
                        border: Border.all(
                          color: LocaraDesignTokens.cardBorderSubtle,
                          width: 1.2,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(
                          color: LocaraDesignTokens.primaryText,
                          fontSize: 14,
                        ),
                        cursorColor: LocaraDesignTokens.cyan,
                        decoration: InputDecoration(
                          hintText: 'پیام خود را بنویسید...',
                          hintStyle: const TextStyle(
                            color: LocaraDesignTokens.mutedText,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste_rounded, color: LocaraDesignTokens.cyan, size: 20),
                            tooltip: 'جای‌گذاری از کلیپ‌بورد',
                            onPressed: () async {
                              final text = await ClipboardSyncService.readText();
                              if (text != null && text.isNotEmpty) {
                                _controller.text = text;
                                _controller.selection = TextSelection.fromPosition(
                                  TextPosition(offset: text.length),
                                );
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('هیچ متنی در کلیپ‌بورد موجود نیست.'),
                                      backgroundColor: LocaraDesignTokens.darkNavy,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _sendMessage(context),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LocaraDesignTokens.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: LocaraDesignTokens.primaryBlue.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
