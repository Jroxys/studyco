import 'package:flutter/foundation.dart';
import '../domain/assistant_repository.dart';
import '../models/assistant_content.dart';

class InMemoryAssistantRepository extends AssistantRepository {
  const InMemoryAssistantRepository(
    this.content, {
    this.enableQuestions = false,
    this.responseDelay = const Duration(milliseconds: 350),
  });
  final bool enableQuestions;
  final Duration responseDelay;
  @override
  bool get supportsQuestions => enableQuestions;
  @override
  Future<AssistantReply> ask(String question) async {
    if (!supportsQuestions) return super.ask(question);
    final text = validatedAssistantQuestion(question);
    await Future<void>.delayed(responseDelay);
    // Demo-only equality; no interpretation, fuzzy search or language model.
    for (final option in content.options) {
      if (option.title.trim().toLowerCase() == text.toLowerCase()) {
        return AssistantReply(
          answer: option.answer,
          destination: option.destination,
          isDemo: true,
        );
      }
    }
    return const AssistantReply(
      answer:
          'Şu anda bu soruya yanıt veremiyorum. Hazır sorulardan birini seçerek devam edebilirsin.',
      isDemo: true,
    );
  }

  final AssistantContent content;
  @override
  Future<AssistantContent> load() async => content;

  /// Design fixtures only; the content owner supplies the actual questions/answers.
  static final preview = InMemoryAssistantRepository(
    AssistantContent(
      greeting:
          'Merhaba! StudyCo içinde yolunu bulmana yardımcı olacak bir seçenek seç.',
      isDemo: true,
      options: const [
        AssistantOption(
          id: 'preview-search',
          title: 'Ders ilanlarını nerede bulabilirim?',
          answer:
              'Bu, tasarım için hazırlanmış örnek bir yanıttır. Ara ekranını bu seçenekten açabilirsin.',
          destination: 'search',
        ),
        AssistantOption(
          id: 'preview-applications',
          title: 'Başvurularımı nereden görebilirim?',
          answer:
              'Bu örnek yönlendirme Başvurularım ekranını açar. Gerçek açıklama içerik ekibi tarafından sağlanacak.',
          destination: 'applications',
        ),
        AssistantOption(
          id: 'preview-messages',
          title: 'Sohbetlerime nasıl ulaşabilirim?',
          answer:
              'Bu, Mesajlar ekranına yönlendirmeyi denemek için örnek bir yanıttır.',
          destination: 'messages',
        ),
        AssistantOption(
          id: 'preview-about',
          title: 'Bu panel nasıl çalışıyor?',
          answer:
              'Hazır seçeneklerden birini seçerek yanıtı burada görebilirsin. Bunlar yalnızca tasarım örnekleridir; gerçek asistan içeriği henüz bağlanmadı.',
        ),
      ],
    ),
    enableQuestions: kDebugMode && const bool.fromEnvironment('HOME_PREVIEW'),
  );
}
