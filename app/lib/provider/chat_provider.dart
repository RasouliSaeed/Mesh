import 'package:localsend_isolates/model/device.dart';
import 'package:refena_flutter/refena_flutter.dart';

class ChatMessage {
  final String text;
  final bool isMine;
  final Device? sender;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isMine,
    this.sender,
    required this.timestamp,
  });
}

class ChatState {
  final List<ChatMessage> messages;
  final Device? currentTarget;

  ChatState(this.messages, this.currentTarget);
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState init() {
    return ChatState([], null);
  }

  void addMessage(String text, {required bool isMine, Device? sender}) {
    state = ChatState([
      ...state.messages,
      ChatMessage(
        text: text,
        isMine: isMine,
        sender: sender,
        timestamp: DateTime.now(),
      ),
    ], sender ?? state.currentTarget);
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
