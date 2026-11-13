import 'package:flutter/material.dart';
import '../screens/chat_screen.dart';
import 'messages_repository_scope.dart';

abstract final class ConversationNavigation {
  static Future<void> open(
    BuildContext context, {
    required String? userId,
    required String? conversationId,
  }) async {
    final source = MessagesRepositoryScope.forUser(context, userId);
    if (source == null ||
        conversationId == null ||
        conversationId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konuşma bulunamadı veya bu konuşmaya erişimin yok.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => ChatScreen(
              repository: source,
              userId: userId!,
              conversationId: conversationId,
            ),
      ),
    );
  }
}
