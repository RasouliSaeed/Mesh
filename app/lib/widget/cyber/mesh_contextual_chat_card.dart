import 'package:flutter/material.dart';
import 'package:locara_app/provider/chat_provider.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:refena_flutter/refena_flutter.dart';

class MeshContextualChatCard extends StatefulWidget {
  final String peerAlias;
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;
  final void Function(String message)? onSendMessage;

  const MeshContextualChatCard({
    this.peerAlias = 'DESKTOP-PC',
    this.onClose,
    this.onMinimize,
    this.onSendMessage,
    super.key,
  });

  @override
  State<MeshContextualChatCard> createState() => _MeshContextualChatCardState();
}

class _MeshContextualChatCardState extends State<MeshContextualChatCard> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    widget.onSendMessage?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final chatState = context.watch(chatProvider);
    final messages = chatState.messages;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: LocaraDesignTokens.cardSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LocaraDesignTokens.cardBorderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: LocaraDesignTokens.cardBorderSubtle,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [LocaraDesignTokens.purple, LocaraDesignTokens.primaryBlue],
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isRtl ? 'گفتگو با ${widget.peerAlias}' : 'Chat with ${widget.peerAlias}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.onMinimize != null)
                  InkWell(
                    onTap: widget.onMinimize,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.remove_rounded, color: LocaraDesignTokens.mutedText, size: 16),
                    ),
                  ),
                if (widget.onClose != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, color: LocaraDesignTokens.mutedText, size: 16),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Messages Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (messages.isEmpty) ...[
                  // Representative messages from reference image
                  _buildBubble(
                    text: isRtl ? 'فایل با موفقیت دریافت شد' : 'File received successfully',
                    time: '10:24',
                    isOutgoing: true,
                    statusIcon: Icons.check_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildBubble(
                    text: isRtl ? 'عالیه!' : 'Great!',
                    time: '10:25',
                    isOutgoing: false,
                    showAvatar: true,
                  ),
                ] else ...[
                  ...messages.take(3).map((m) {
                    final isMe = m.isMine;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _buildBubble(
                        text: m.text,
                        time: '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}',
                        isOutgoing: isMe,
                        statusIcon: isMe ? (m.deliveryStatus == MessageDeliveryStatus.read ? Icons.done_all_rounded : Icons.check_rounded) : null,
                        showAvatar: !isMe,
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          // Input Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: LocaraDesignTokens.cardBorderSubtle,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: LocaraDesignTokens.darkNavy.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: LocaraDesignTokens.cardBorderSubtle,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _textController,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: isRtl ? 'پیامی بنویسید...' : 'Type a message...',
                        hintStyle: const TextStyle(color: LocaraDesignTokens.mutedText, fontSize: 12),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _send,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [LocaraDesignTokens.purple, LocaraDesignTokens.primaryBlue],
                      ),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble({
    required String text,
    required String time,
    required bool isOutgoing,
    IconData? statusIcon,
    bool showAvatar = false,
  }) {
    return Align(
      alignment: isOutgoing ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatar && !isOutgoing) ...[
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsetsDirectional.only(end: 6, bottom: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [LocaraDesignTokens.purple, LocaraDesignTokens.cyan],
                ),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 12),
            ),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isOutgoing ? LocaraDesignTokens.primaryBlue.withValues(alpha: 0.85) : LocaraDesignTokens.darkNavy.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isOutgoing ? LocaraDesignTokens.cyan.withValues(alpha: 0.3) : LocaraDesignTokens.cardBorderSubtle,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: const TextStyle(color: LocaraDesignTokens.mutedText, fontSize: 10),
                      ),
                      if (statusIcon != null) ...[
                        const SizedBox(width: 4),
                        Icon(statusIcon, color: LocaraDesignTokens.cyan, size: 12),
                      ],
                    ],
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
