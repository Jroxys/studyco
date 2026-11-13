import 'package:flutter/material.dart';
import '../domain/messages_repository.dart';
import '../models/conversation.dart';
import '../widgets/message_widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.repository,
    required this.userId,
    required this.conversationId,
  });
  final MessagesRepository repository;
  final String userId, conversationId;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  Conversation? _conversation;
  List<Message> _messages = [];
  String? _cursor, _error, _readError, _sendError;
  bool _loading = false, _sending = false, _reading = false;
  int _generation = 0;
  bool get _authorized =>
      widget.repository.isActive && widget.repository.userId == widget.userId;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.userId != widget.userId ||
        oldWidget.conversationId != widget.conversationId) {
      _generation++;
      _conversation = null;
      _messages = [];
      _cursor = null;
      _loading = false;
      _sending = false;
      _reading = false;
      _draft.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading || _sending || (more && _cursor == null)) return;
    if (!more && _scroll.hasClients) _scroll.jumpTo(0);
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_authorized) {
        throw const MessagesFailure(
          'Bu konuşmaya erişimin yok.',
          code: 'NOT_A_PARTICIPANT',
        );
      }
      final conversation = await widget.repository.findConversation(
        widget.conversationId,
      );
      if (!mounted || generation != _generation || !_authorized) return;
      final page = await widget.repository.fetchMessages(
        widget.conversationId,
        cursor: more ? _cursor : null,
      );
      if (!mounted || generation != _generation || !_authorized) return;
      setState(() {
        _conversation = conversation;
        _messages = mergeMessages(more ? _messages : const [], page.items);
        _cursor = page.nextCursor;
      });
      await _read();
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _error = messagesError(
                error,
                'Mesajlar yüklenemedi. Tekrar dene.',
              ),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _read() async {
    if (_reading || !_authorized || _conversation == null) return;
    final generation = _generation;
    setState(() {
      _reading = true;
      _readError = null;
    });
    try {
      await widget.repository.markRead(widget.conversationId);
      if (!mounted || generation != _generation || !_authorized) return;
      // Refresh the projection, preserving server timestamps rather than guessing readAt.
      final page = await widget.repository.fetchMessages(widget.conversationId);
      if (mounted && generation == _generation && _authorized) {
        setState(() => _messages = mergeMessages(_messages, page.items));
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _readError = messagesError(
                error,
                'Mesajlar okundu olarak işaretlenemedi.',
              ),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _reading = false);
      }
    }
  }

  Future<void> _send() async {
    if (_sending || _loading || !_authorized || _conversation == null) return;
    final generation = _generation;
    final original = _draft.text;
    String text;
    try {
      text = validatedMessage(original);
    } catch (error) {
      setState(() => _sendError = messagesError(error, 'Geçersiz mesaj.'));
      return;
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final message = await widget.repository.sendMessage(
        widget.conversationId,
        text,
      );
      if (!mounted || generation != _generation || !_authorized) return;
      setState(() {
        _messages = mergeMessages(_messages, [message]);
        if (_draft.text == original) _draft.clear();
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _sendError =
                  '${messagesError(error, 'Gönderim sonucu doğrulanamadı.')} '
                  'Yeniden göndermeden önce sohbeti yenileyip sonucu kontrol et.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    return Scaffold(
      appBar: AppBar(
        title:
            conversation == null
                ? const Text('Sohbet')
                : Row(
                  children: [
                    ConversationAvatar(conversation: conversation),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conversation.counterpart.displayName ?? 'Kullanıcı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            conversation.topic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        actions: [
          IconButton(
            tooltip: 'Mesajları yenile',
            onPressed: _loading || _sending ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) _notice(_error!, () => _load()),
            if (_readError != null)
              _notice(_readError!, _reading ? null : _read),
            Expanded(
              child:
                  _messages.isEmpty
                      ? Center(
                        child: Text(
                          !_loading && conversation != null
                              ? 'Henüz mesaj yok. İlk mesajı sen yaz.'
                              : '',
                        ),
                      )
                      : ListView.builder(
                        key: const ValueKey('chat-messages'),
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _messages.length + (_cursor != null ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return TextButton(
                              onPressed:
                                  _loading ? null : () => _load(more: true),
                              child: const Text('Eski Mesajları Yükle'),
                            );
                          }
                          final message = _messages[index];
                          return MessageBubble(
                            key: ValueKey('message-${message.id}'),
                            message: message,
                            isOwn: message.senderId == widget.userId,
                          );
                        },
                      ),
            ),
            if (conversation != null && _authorized)
              Flexible(
                flex: 0,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_sendError != null)
                          Text(
                            _sendError!,
                            key: const ValueKey('send-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('message-draft'),
                                controller: _draft,
                                enabled: !_sending,
                                minLines: 1,
                                maxLines: 3,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                decoration: const InputDecoration(
                                  hintText: 'Mesajını yaz…',
                                  contentPadding: EdgeInsets.all(12),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              key: const ValueKey('send-message'),
                              tooltip: 'Gönder',
                              onPressed:
                                  _sending ||
                                          _loading ||
                                          _draft.text.trim().isEmpty ||
                                          _draft.text.trim().length > 2000
                                      ? null
                                      : _send,
                              icon:
                                  _sending
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(Icons.send),
                            ),
                          ],
                        ),
                        if (_draft.text.trim().length > 2000)
                          const Text('Mesaj en fazla 2000 karakter olabilir.'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _notice(String text, VoidCallback? retry) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        Expanded(child: Text(text)),
        TextButton(onPressed: retry, child: const Text('Tekrar Dene')),
      ],
    ),
  );
}
