import 'package:flutter/foundation.dart';
import '../models/conversation.dart';

class MessagesFailure implements Exception {
  const MessagesFailure(
    this.message, {
    this.code = 'UNKNOWN',
    this.deliveryUncertain = false,
  });
  final String message, code;
  final bool deliveryUncertain;
}

class MessagePage<T> {
  MessagePage({required Iterable<T> items, this.nextCursor})
    : items = List.unmodifiable(items);
  final List<T> items;
  final String? nextCursor;
}

abstract class MessagesRepository extends ChangeNotifier {
  String get userId;

  /// Null means that a complete, confirmed total is unavailable. Never sum a partial page.
  int? get confirmedUnreadTotal => null;
  bool get isActive => true;

  /// Optional latest confirmed projection; adapters update it only after server success.
  Conversation? cachedConversation(String id) => null;
  Future<MessagePage<Conversation>> fetchConversations({
    int limit = 20,
    String? cursor,
  });
  Future<MessagePage<Message>> fetchMessages(
    String conversationId, {
    int limit = 20,
    String? cursor,
  });
  Future<Message> sendMessage(String conversationId, String body);
  Future<void> markRead(String conversationId);

  /// There is no GET conversation-by-ID endpoint: adapters must search authorized pages.
  Future<Conversation> findConversation(String id) async {
    if (id.trim().isEmpty) {
      throw const MessagesFailure('Geçersiz konuşma kimliği.');
    }
    String? cursor;
    final seen = <String>{};
    do {
      final page = await fetchConversations(cursor: cursor);
      for (final item in page.items) {
        if (item.id == id) return item;
      }
      cursor = page.nextCursor;
      if (cursor != null && !seen.add(cursor)) {
        throw const MessagesFailure('Konuşma sayfaları yüklenemedi.');
      }
    } while (cursor != null);
    throw const MessagesFailure(
      'Konuşma bulunamadı veya bu konuşmaya erişimin yok.',
      code: 'NOT_A_PARTICIPANT',
    );
  }
}

String validatedMessage(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty || trimmed.length > 2000) {
    throw const MessagesFailure(
      'Mesaj boş olamaz ve 2000 karakteri aşamaz.',
      code: 'VALIDATION_ERROR',
    );
  }
  return trimmed;
}

void validateMessageQuery(int limit) {
  if (limit < 1 || limit > 50) {
    throw const MessagesFailure('Sayfa boyutu 1–50 arasında olmalı.');
  }
}

String messagesError(Object error, String fallback) =>
    error is MessagesFailure ? error.message : fallback;
