import 'package:flutter/material.dart';
import 'package:locara_app/model/persistence/receive_history_entry.dart';
import 'package:locara_app/provider/receive_history_provider.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_isolates/model/file_type.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum HistoryFilter { all, incoming, outgoing }

class MeshContextualHistoryCard extends StatefulWidget {
  final double? width;
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;
  final void Function(ReceiveHistoryEntry entry)? onOpenEntry;

  const MeshContextualHistoryCard({
    this.width,
    this.onClose,
    this.onMinimize,
    this.onOpenEntry,
    super.key,
  });

  @override
  State<MeshContextualHistoryCard> createState() => _MeshContextualHistoryCardState();
}

class _MeshContextualHistoryCardState extends State<MeshContextualHistoryCard> {
  HistoryFilter _filter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final history = context.watch(receiveHistoryProvider);

    return Container(
      width: widget.width,
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
                Expanded(
                  child: Text(
                    isRtl ? 'تاریخچه انتقال' : 'Transfer History',
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

          // Filter Chips Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildFilterChip(
                  label: isRtl ? 'همه' : 'All',
                  isSelected: _filter == HistoryFilter.all,
                  onTap: () => setState(() => _filter = HistoryFilter.all),
                ),
                _buildFilterChip(
                  label: isRtl ? 'دریافتی' : 'Incoming',
                  isSelected: _filter == HistoryFilter.incoming,
                  onTap: () => setState(() => _filter = HistoryFilter.incoming),
                ),
                _buildFilterChip(
                  label: isRtl ? 'ارسالی' : 'Outgoing',
                  isSelected: _filter == HistoryFilter.outgoing,
                  onTap: () => setState(() => _filter = HistoryFilter.outgoing),
                ),
              ],
            ),
          ),

          // Items List
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (history.isEmpty) ...[
                  // Representative history items from reference image
                  _buildHistoryItem(
                    fileName: 'photo.jpg',
                    status: isRtl ? 'دریافت شده • ۲.۴ مگابایت' : 'Received • 2.4 MB',
                    time: '10:20',
                    icon: Icons.image_rounded,
                    iconColor: LocaraDesignTokens.success,
                    iconBgColor: LocaraDesignTokens.success.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 8),
                  _buildHistoryItem(
                    fileName: 'project.zip',
                    status: isRtl ? 'ارسال شده • ۱۸.۷ مگابایت' : 'Sent • 18.7 MB',
                    time: '10:18',
                    icon: Icons.archive_rounded,
                    iconColor: LocaraDesignTokens.purple,
                    iconBgColor: LocaraDesignTokens.purple.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 8),
                  _buildHistoryItem(
                    fileName: 'design.pdf',
                    status: isRtl ? 'دریافت شده • ۱.۲ مگابایت' : 'Received • 1.2 MB',
                    time: '10:15',
                    icon: Icons.picture_as_pdf_rounded,
                    iconColor: LocaraDesignTokens.error,
                    iconBgColor: LocaraDesignTokens.error.withValues(alpha: 0.15),
                  ),
                ] else ...[
                  ...history.take(3).map((e) {
                    final isImage = e.fileType == FileType.image;
                    final isPdf = e.fileName.toLowerCase().endsWith('.pdf');
                    final icon = isImage ? Icons.image_rounded : (isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded);
                    final iconColor = isImage ? LocaraDesignTokens.success : (isPdf ? LocaraDesignTokens.error : LocaraDesignTokens.cyan);
                    final sizeMb = (e.fileSize / (1024 * 1024)).toStringAsFixed(1);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildHistoryItem(
                        fileName: e.fileName,
                        status: isRtl ? 'دریافت شده • $sizeMb مگابایت' : 'Received • $sizeMb MB',
                        time: '${e.timestamp.hour.toString().padLeft(2, '0')}:${e.timestamp.minute.toString().padLeft(2, '0')}',
                        icon: icon,
                        iconColor: iconColor,
                        iconBgColor: iconColor.withValues(alpha: 0.15),
                        onTap: () => widget.onOpenEntry?.call(e),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? LocaraDesignTokens.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? LocaraDesignTokens.purple : LocaraDesignTokens.cardBorderSubtle,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : LocaraDesignTokens.secondaryText,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem({
    required String fileName,
    required String status,
    required String time,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: LocaraDesignTokens.darkNavy.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: LocaraDesignTokens.cardBorderSubtle,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBgColor,
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: const TextStyle(
                      color: LocaraDesignTokens.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: const TextStyle(
                color: LocaraDesignTokens.mutedText,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
