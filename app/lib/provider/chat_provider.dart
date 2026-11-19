import 'dart:convert';
import 'dart:io';

import 'package:locara_isolates/model/device.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('ChatProvider');

enum MessageDeliveryStatus {
  sending,
  delivered,
  read,
  failed,
}

class ChatMessage {
  final String id;
  final int sequenceNumber;
  final String text;
  final bool isMine;
  final Device? sender;
  final DateTime timestamp;
  final MessageDeliveryStatus deliveryStatus;

  ChatMessage({
    String? id,
    required this.sequenceNumber,
    required this.text,
    required this.isMine,
    this.sender,
    required this.timestamp,
    MessageDeliveryStatus? deliveryStatus,
    bool isRead = false,
  }) : id = id ?? '${timestamp.microsecondsSinceEpoch}_${sequenceNumber}_${isMine ? "m" : "t"}',
       deliveryStatus =
           deliveryStatus ?? (isRead ? MessageDeliveryStatus.read : (isMine ? MessageDeliveryStatus.delivered : MessageDeliveryStatus.delivered));

  bool get isRead => deliveryStatus == MessageDeliveryStatus.read;

  ChatMessage copyWith({
    String? id,
    int? sequenceNumber,
    String? text,
    bool? isMine,
    Device? sender,
    DateTime? timestamp,
    MessageDeliveryStatus? deliveryStatus,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      text: text ?? this.text,
      isMine: isMine ?? this.isMine,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      deliveryStatus:
          deliveryStatus ?? (isRead != null ? (isRead ? MessageDeliveryStatus.read : MessageDeliveryStatus.delivered) : this.deliveryStatus),
    );
  }
}

class ChatState {
  final Map<String, List<ChatMessage>> peerMessages;
  final Map<String, int> unreadCounts;
  final Map<String, DateTime> readCursors;
  final Device? currentTarget;

  const ChatState({
    required this.peerMessages,
    required this.unreadCounts,
    required this.readCursors,
    this.currentTarget,
  });

  /// Backward-compatible list of messages for the currently selected peer,
  /// strictly ordered monotonically by sequence number and timestamp.
  List<ChatMessage> get messages {
    if (currentTarget == null) {
      final combined = peerMessages.values.expand((list) => list).toList();
      combined.sort((a, b) {
        final cmp = a.timestamp.compareTo(b.timestamp);
        return cmp != 0 ? cmp : a.sequenceNumber.compareTo(b.sequenceNumber);
      });
      return combined;
    }
    final list = peerMessages[peerKeyFor(currentTarget!)] ?? const [];
    return List<ChatMessage>.from(list)..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
  }

  /// Total unread messages across all active peer sessions.
  int get totalUnreadCount => unreadCounts.values.fold(0, (sum, count) => sum + count);

  int unreadCountFor(Device peer) => unreadCounts[peerKeyFor(peer)] ?? 0;

  DateTime? readCursorFor(Device peer) => readCursors[peerKeyFor(peer)];

  static String peerKeyFor(Device device) {
    if (device.fingerprint.isNotEmpty) {
      return device.fingerprint;
    }
    return device.ip ?? device.alias;
  }
}

class ChatNotifier extends Notifier<ChatState> {
  /// In-memory offline queue for pending P2P read receipts when a peer is disconnected.
  final Map<String, List<String>> _offlineReceiptQueue = {};

  @override
  ChatState init() {
    return const ChatState(
      peerMessages: {},
      unreadCounts: {},
      readCursors: {},
      currentTarget: null,
    );
  }

  /// Adds a chat message in RAM with monotonic sequence numbering and ID deduplication.
  void addMessage(
    String text, {
    required bool isMine,
    String? id,
    int? sequenceNumber,
    Device? sender,
    Device? target,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    final peer = isMine ? (target ?? state.currentTarget) : sender;
    if (peer == null) {
      return;
    }

    final key = ChatState.peerKeyFor(peer);
    final existing = state.peerMessages[key] ?? [];

    // Deduplication by message ID
    if (id != null && existing.any((m) => m.id == id)) {
      _logger.info('Duplicate message ID $id ignored');
      return;
    }

    final now = DateTime.now();
    final nextSeq = sequenceNumber ?? (existing.isEmpty ? 1 : existing.last.sequenceNumber + 1);

    final isTargetActive = state.currentTarget != null && ChatState.peerKeyFor(state.currentTarget!) == key;
    final initialStatus =
        deliveryStatus ??
        (isMine ? MessageDeliveryStatus.delivered : (isTargetActive ? MessageDeliveryStatus.read : MessageDeliveryStatus.delivered));

    final newMessage = ChatMessage(
      id: id,
      sequenceNumber: nextSeq,
      text: text,
      isMine: isMine,
      sender: sender ?? peer,
      timestamp: now,
      deliveryStatus: initialStatus,
    );

    final updatedList = [...existing, newMessage]..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    final updatedMessages = Map<String, List<ChatMessage>>.from(state.peerMessages);
    updatedMessages[key] = updatedList;

    final updatedUnread = Map<String, int>.from(state.unreadCounts);
    if (!isMine && initialStatus != MessageDeliveryStatus.read) {
      updatedUnread[key] = (updatedUnread[key] ?? 0) + 1;
    }

    final updatedCursors = Map<String, DateTime>.from(state.readCursors);
    if (isTargetActive) {
      updatedCursors[key] = now;
    }

    state = ChatState(
      peerMessages: updatedMessages,
      unreadCounts: updatedUnread,
      readCursors: updatedCursors,
      currentTarget: state.currentTarget ?? peer,
    );
  }

  /// Marks a specific message as read in response to viewport visibility
  /// and triggers a background P2P read receipt to the peer.
  void markMessageInViewport(ChatMessage message, Device peer) {
    if (message.isMine || message.deliveryStatus == MessageDeliveryStatus.read) {
      return;
    }

    final key = ChatState.peerKeyFor(peer);
    final existing = state.peerMessages[key];
    if (existing == null) return;

    final updatedList = existing.map((m) {
      if (m.id == message.id) {
        return m.copyWith(deliveryStatus: MessageDeliveryStatus.read);
      }
      return m;
    }).toList();

    final updatedMessages = Map<String, List<ChatMessage>>.from(state.peerMessages);
    updatedMessages[key] = updatedList;

    final updatedUnread = Map<String, int>.from(state.unreadCounts);
    final count = updatedUnread[key] ?? 0;
    if (count > 0) {
      updatedUnread[key] = count - 1;
    }

    state = ChatState(
      peerMessages: updatedMessages,
      unreadCounts: updatedUnread,
      readCursors: state.readCursors,
      currentTarget: state.currentTarget,
    );

    // Queue and dispatch P2P read receipt
    _queueAndSendReadReceipt(peer, message.id);
  }

  /// Updates delivery status of an outbound message (e.g. delivered -> read)
  void updateMessageStatus(String peerKey, String messageId, MessageDeliveryStatus status) {
    final existing = state.peerMessages[peerKey];
    if (existing == null) return;

    final updatedList = existing.map((m) {
      if (m.id == messageId) {
        return m.copyWith(deliveryStatus: status);
      }
      return m;
    }).toList();

    final updatedMessages = Map<String, List<ChatMessage>>.from(state.peerMessages);
    updatedMessages[keyFor(peerKey)] = updatedList;

    state = ChatState(
      peerMessages: updatedMessages,
      unreadCounts: state.unreadCounts,
      readCursors: state.readCursors,
      currentTarget: state.currentTarget,
    );
  }

  String keyFor(String key) => key;

  void setTarget(Device? target) {
    if (target == null) {
      state = ChatState(
        peerMessages: state.peerMessages,
        unreadCounts: state.unreadCounts,
        readCursors: state.readCursors,
        currentTarget: null,
      );
      return;
    }

    final key = ChatState.peerKeyFor(target);
    final updatedUnread = Map<String, int>.from(state.unreadCounts);
    updatedUnread[key] = 0;

    final updatedCursors = Map<String, DateTime>.from(state.readCursors);
    updatedCursors[key] = DateTime.now();

    final updatedMessages = Map<String, List<ChatMessage>>.from(state.peerMessages);
    if (updatedMessages.containsKey(key)) {
      updatedMessages[key] = updatedMessages[key]!.map((m) => m.copyWith(deliveryStatus: MessageDeliveryStatus.read)).toList();
    }

    state = ChatState(
      peerMessages: updatedMessages,
      unreadCounts: updatedUnread,
      readCursors: updatedCursors,
      currentTarget: target,
    );

    flushOfflineReceipts(target);
  }

  void markAsRead(Device peer) {
    final key = ChatState.peerKeyFor(peer);
    final updatedUnread = Map<String, int>.from(state.unreadCounts);
    updatedUnread[key] = 0;

    final updatedCursors = Map<String, DateTime>.from(state.readCursors);
    updatedCursors[key] = DateTime.now();

    final updatedMessages = Map<String, List<ChatMessage>>.from(state.peerMessages);
    if (updatedMessages.containsKey(key)) {
      final unreadIds = <String>[];
      updatedMessages[key] = updatedMessages[key]!.map((m) {
        if (!m.isMine && m.deliveryStatus != MessageDeliveryStatus.read) {
          unreadIds.add(m.id);
          return m.copyWith(deliveryStatus: MessageDeliveryStatus.read);
        }
        return m;
      }).toList();

      for (final id in unreadIds) {
        _queueAndSendReadReceipt(peer, id);
      }
    }

    state = ChatState(
      peerMessages: updatedMessages,
      unreadCounts: updatedUnread,
      readCursors: updatedCursors,
      currentTarget: state.currentTarget,
    );
  }

  void clearSession(Device peer) {
    final key = ChatState.peerKeyFor(peer);
    final updatedMessages = Map<String, List<ChatMessage>>.from(state.peerMessages)..remove(key);
    final updatedUnread = Map<String, int>.from(state.unreadCounts)..remove(key);
    final updatedCursors = Map<String, DateTime>.from(state.readCursors)..remove(key);
    _offlineReceiptQueue.remove(key);

    state = ChatState(
      peerMessages: updatedMessages,
      unreadCounts: updatedUnread,
      readCursors: updatedCursors,
      currentTarget: state.currentTarget != null && ChatState.peerKeyFor(state.currentTarget!) == key ? null : state.currentTarget,
    );
  }

  void clearAllSessions() {
    _offlineReceiptQueue.clear();
    state = const ChatState(
      peerMessages: {},
      unreadCounts: {},
      readCursors: {},
      currentTarget: null,
    );
  }

  /// P2P Read Receipt delivery with Offline Queueing
  void _queueAndSendReadReceipt(Device peer, String messageId) {
    final key = ChatState.peerKeyFor(peer);
    final queue = _offlineReceiptQueue.putIfAbsent(key, () => []);
    if (!queue.contains(messageId)) {
      queue.add(messageId);
    }
    _dispatchOfflineReceipts(peer);
  }

  void flushOfflineReceipts(Device peer) {
    _dispatchOfflineReceipts(peer);
  }

  void _dispatchOfflineReceipts(Device peer) async {
    final key = ChatState.peerKeyFor(peer);
    final queue = _offlineReceiptQueue[key];
    if (queue == null || queue.isEmpty) {
      return;
    }

    final messageIdsToSend = List<String>.from(queue);
    final url = Uri(
      scheme: peer.https ? 'https' : 'http',
      host: peer.ip,
      port: peer.port,
      path: '/api/mesh/v2/chat/receipt',
    );

    HttpClient? client;
    try {
      client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'messageIds': messageIdsToSend,
          'receiptType': 'read',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        queue.removeWhere((id) => messageIdsToSend.contains(id));
        _logger.info('Dispatched ${messageIdsToSend.length} read receipt(s) to ${peer.alias}');
      }
    } catch (e) {
      _logger.fine('Peer ${peer.alias} offline or receipt endpoint not reachable; queued');
    } finally {
      client?.close();
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
