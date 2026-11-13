import 'package:flutter/material.dart';
import 'package:locara_app/config/theme.dart';
import 'package:locara_app/model/recovery/recoverable_transfer.dart';
import 'package:locara_app/provider/network/nearby_devices_provider.dart';
import 'package:locara_app/provider/network/send_provider.dart';
import 'package:locara_app/provider/recovery_contract_provider.dart';
import 'package:locara_app/widget/custom_progress_bar.dart';
import 'package:locara_isolates/util/file_size_helper.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// A UI component that displays recoverable interrupted V3 transfers (both sender and receiver).
///
/// It accurately distinguishes:
/// - Ready to resume (sender transfer with intact file & reachable peer -> active Resume button)
/// - Interrupted / awaiting peer (receiver session waiting for sender, or offline peer -> informative label, no fake button)
/// - Not resumable (missing file/part, expired, or corrupted -> specific reason + safe prune action)
class RecoveryList extends StatelessWidget {
  final bool showHeader;
  final EdgeInsetsGeometry padding;

  const RecoveryList({
    super.key,
    this.showHeader = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final asyncTransfers = context.watch(recoveryContractProvider);
    final transfers = asyncTransfers.data ?? [];

    if (transfers.isEmpty) {
      return const SizedBox.shrink();
    }

    final nearbyDevices = context.watch(nearbyDevicesProvider).allDevices;
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Card(
        color: theme.colorScheme.secondaryContainerIfDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.restore, color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Interrupted Transfers',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${transfers.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Refresh recoverable transfers',
                      onPressed: () => context.notifier(recoveryContractProvider).refresh(),
                    ),
                  ],
                ),
              if (showHeader) const SizedBox(height: 12),
              ...transfers.map((transfer) {
                final isResuming = context.notifier(sendProvider).isTransferResuming(transfer.transferId);
                final isPeerOnline = transfer.peerFingerprint != null && nearbyDevices.containsKey(transfer.peerFingerprint);

                return _RecoveryItem(
                  key: ValueKey(transfer.transferId),
                  transfer: transfer,
                  isResuming: isResuming,
                  isPeerOnline: isPeerOnline,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryItem extends StatelessWidget {
  final RecoverableTransfer transfer;
  final bool isResuming;
  final bool isPeerOnline;

  const _RecoveryItem({
    super.key,
    required this.transfer,
    required this.isResuming,
    required this.isPeerOnline,
  });

  Future<void> _handleResume(BuildContext context) async {
    final success = await context.notifier(sendProvider).resumeTransfer(transfer.transferId);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not resume transfer: target device is unreachable or offline.'),
        ),
      );
    }
  }

  Future<void> _handlePrune(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Transfer Session?'),
        content: Text(
          'Are you sure you want to discard the session for "${transfer.fileName}"? Any partial progress will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context
          .notifier(recoveryContractProvider)
          .pruneTransfer(
            transferId: transfer.transferId,
            direction: transfer.direction,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session for "${transfer.fileName}" discarded.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSender = transfer.direction == RecoverableTransferDirection.send;

    // Determine status badge properties
    final String statusLabel;
    final Color statusColor;
    final String? statusDescription;

    if (!transfer.isResumable) {
      statusLabel = 'Not Resumable';
      statusColor = theme.colorScheme.error;
      statusDescription = transfer.unresumableReason ?? 'Session expired or file data unavailable';
    } else if (!isSender) {
      // Receiver session
      statusLabel = 'Waiting for sender';
      statusColor = Colors.orange;
      statusDescription = 'Inbound transfer awaiting sender reconnection.';
    } else if (isPeerOnline) {
      // Sender session with reachable peer
      statusLabel = 'Ready to resume';
      statusColor = Colors.green;
      statusDescription = null;
    } else {
      // Sender session with offline peer
      statusLabel = 'Waiting for peer';
      statusColor = Colors.orange;
      statusDescription = 'Target device is offline or not discovered yet.';
    }

    final peerText = transfer.peerAlias != null
        ? transfer.peerAlias!
        : (transfer.peerFingerprint != null && transfer.peerFingerprint!.length >= 8
              ? 'Peer (${transfer.peerFingerprint!.substring(0, 8)}...)'
              : 'Unknown peer');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSender ? Icons.upload_file : Icons.download_for_offline,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transfer.fileName,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isSender ? "To" : "From"}: $peerText • ${(transfer.progress * 100).toStringAsFixed(0)}% (${transfer.bytesTransferred.asReadableFileSize} / ${transfer.fileSize.asReadableFileSize})',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  border: Border.all(color: statusColor.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CustomProgressBar(
            progress: transfer.progress,
            color: statusColor,
          ),
          if (statusDescription != null) ...[
            const SizedBox(height: 6),
            Text(
              statusDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: statusColor == theme.colorScheme.error ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Discard session',
                onPressed: isResuming ? null : () => _handlePrune(context),
              ),
              if (isSender && transfer.isResumable) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: isResuming ? null : () => _handleResume(context),
                  icon: isResuming
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: Text(isResuming ? 'Resuming...' : 'Resume'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
