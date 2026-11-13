import '../models/assistant_content.dart';

class AssistantFailure implements Exception {
  const AssistantFailure(this.message);
  final String message;
}

/// Content and question seam; no identity, transport or navigation side effects.
abstract class AssistantRepository {
  const AssistantRepository();
  Future<AssistantContent> load();

  /// Existing content-only providers can keep questions disabled until integration.
  bool get supportsQuestions => false;
  Future<AssistantReply> ask(String question) => Future.error(
    const AssistantFailure('Serbest soru hizmeti henüz bağlı değil.'),
  );
}

String validatedAssistantQuestion(String question) {
  final trimmed = question.trim();
  if (trimmed.isEmpty) throw const AssistantFailure('Lütfen bir soru yaz.');
  return trimmed;
}
