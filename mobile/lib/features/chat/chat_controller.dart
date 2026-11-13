import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/session.dart';

final sessionProvider = Provider((ref) => const SessionStore());
final apiProvider = Provider((ref) => ApiClient(ref.watch(sessionProvider)));
final chatProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

class ChatMessage {
  final String role, text;
  final List<int>? audio;
  const ChatMessage(this.role, this.text, [this.audio]);
}

class ChatState {
  final String? conversationId;
  final List<ChatMessage> messages;
  final bool busy;
  final String? error;
  final String? retryText;
  const ChatState({
    this.conversationId,
    this.messages = const [],
    this.busy = false,
    this.error,
    this.retryText,
  });
}

class ChatController extends Notifier<ChatState> {
  CancelToken? _cancel;
  int _generation = 0;
  @override
  ChatState build() {
    ref.onDispose(() {
      _generation++;
      _cancel?.cancel();
    });
    return const ChatState();
  }

  Future<void> open(String id) async {
    if (state.busy) return;
    final data = await ref.read(apiProvider).get('/conversations/$id');
    state = ChatState(
      conversationId: id,
      messages: [
        for (final m in data['messages']) ChatMessage(m['role'], m['content']),
      ],
    );
  }

  void fresh() {
    _generation++;
    _cancel?.cancel();
    state = const ChatState();
  }

  Future<void> send(
    String raw, {
    bool speech = true,
    String script = 'arabic',
  }) async {
    final text = raw.trim();
    if (text.isEmpty || state.busy) return;
    final generation = _generation;
    final previous = state.messages;
    var id = state.conversationId;
    state = ChatState(conversationId: id, messages: previous, busy: true);
    _cancel = CancelToken();
    try {
      final api = ref.read(apiProvider);
      id ??= (await api.post('/conversations', null, _cancel))['id'];
      if (generation != _generation) return;
      final data = await api.post('/chat/messages', {
        'conversation_id': id,
        'text': text,
        'speech': speech,
        'script': script,
      }, _cancel);
      if (generation != _generation) return;
      state = ChatState(
        conversationId: id,
        messages: [
          ...previous,
          ChatMessage('user', text),
          ChatMessage(
            'assistant',
            data['answer']['text'],
            data['audio_base64'] == null
                ? null
                : base64Decode(data['audio_base64']),
          ),
        ],
        error: data['speech_error'] == null
            ? null
            : 'الجواب واجد، ولكن الصوت ما خدمش',
      );
    } catch (error) {
      if (generation != _generation) return;
      state = ChatState(
        conversationId: id,
        messages: previous,
        error: friendlyError(error),
        retryText: text,
      );
    }
  }
}

final scriptProvider = NotifierProvider<ScriptController, String>(
  ScriptController.new,
);

class ScriptController extends Notifier<String> {
  @override
  String build() => 'arabic';
  void select(String value) {
    state = value;
  }
}
