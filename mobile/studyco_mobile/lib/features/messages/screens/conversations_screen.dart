import 'package:flutter/material.dart';
import '../domain/messages_repository.dart';
import '../models/conversation.dart';
import '../widgets/message_widgets.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    super.key,
    required this.repository,
    required this.userId,
  });
  final MessagesRepository? repository;
  final String? userId;
  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _scroll = ScrollController();
  List<Conversation> _items = [];
  String? _cursor, _error;
  bool _loading = false;
  int _generation = 0;
  MessagesRepository? get _source =>
      widget.repository?.userId == widget.userId &&
              widget.repository?.isActive == true
          ? widget.repository
          : null;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ConversationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.userId != widget.userId) {
      _generation++;
      _items = [];
      _cursor = null;
      _loading = false;
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading || (more && _cursor == null)) return;
    if (!more && _scroll.hasClients) _scroll.jumpTo(0);
    final source = _source;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (source == null) {
        throw const MessagesFailure(
          'Mesajlar için doğrulanmış kullanıcı ve veri kaynağı gerekli.',
        );
      }
      final page = await source.fetchConversations(
        cursor: more ? _cursor : null,
      );
      if (!mounted || generation != _generation || source != _source) return;
      final byId = {
        if (more)
          for (final c in _items) c.id: c,
        for (final c in page.items) c.id: c,
      };
      setState(() {
        _items = byId.values.toList();
        _cursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _error = messagesError(
                error,
                'Konuşmalar yüklenemedi. Tekrar dene.',
              ),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(Conversation conversation) async {
    final source = _source;
    if (source == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => ChatScreen(
              repository: source,
              userId: widget.userId!,
              conversationId: conversation.id,
            ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mesajlar'),
      actions: [
        IconButton(
          tooltip: 'Konuşmaları yenile',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.repository ?? const AlwaysStoppedAnimation(0),
        builder:
            (context, _) => RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (_error != null) ...[
                    Text(_error!, key: const ValueKey('conversations-error')),
                    TextButton(
                      onPressed:
                          _loading
                              ? null
                              : () => _load(
                                more: _items.isNotEmpty && _cursor != null,
                              ),
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                  if (!_loading && _error == null && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Henüz konuşman yok. Başvurun kabul edildiğinde sohbet burada görünecek.',
                      ),
                    ),
                  for (final c in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ConversationCard(
                        key: ValueKey('conversation-${c.id}'),
                        conversation: _source?.cachedConversation(c.id) ?? c,
                        onTap: () => _open(c),
                      ),
                    ),
                  if (_cursor != null)
                    TextButton(
                      onPressed: _loading ? null : () => _load(more: true),
                      child: const Text('Daha Fazla Yükle'),
                    ),
                ],
              ),
            ),
      ),
    ),
  );
}
