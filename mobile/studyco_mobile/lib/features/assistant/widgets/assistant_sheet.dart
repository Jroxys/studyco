import 'assistant_question_composer.dart';
import 'package:flutter/material.dart';
import '../domain/assistant_repository.dart';
import '../models/assistant_content.dart';

/// Wait for the sheet overlay to be removed before the caller opens a destination.
Future<AssistantDestination?> showAssistantSheet(
  BuildContext context, {
  required AssistantRepository repository,
  required Set<AssistantDestination> availableDestinations,
}) async {
  final navigator = Navigator.of(context);
  final route = ModalBottomSheetRoute<AssistantDestination>(
    settings: const RouteSettings(name: 'studyco-assistant'),
    isScrollControlled: true,
    useSafeArea: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    builder: (sheetContext) {
      final keyboard = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: FractionallySizedBox(
          heightFactor: keyboard > 0 ? 1 : .8,
          child: AssistantSheet(
            repository: repository,
            availableDestinations: Set.unmodifiable(availableDestinations),
          ),
        ),
      );
    },
  );
  final destination = await navigator.push(route);
  await route.completed;
  return destination;
}

class AssistantSheet extends StatefulWidget {
  const AssistantSheet({
    super.key,
    required this.repository,
    required this.availableDestinations,
  });
  final AssistantRepository repository;
  final Set<AssistantDestination> availableDestinations;
  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet> {
  final _scroll = ScrollController();
  final _draft = TextEditingController();
  String? _submittedQuestion, _askError;
  AssistantReply? _reply;
  bool _sending = false;
  AssistantContent? _content;
  AssistantOption? _selected;
  String? _error;
  bool _loading = false;
  bool _closing = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AssistantSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _generation++;
      _loading = false;
      _content = null;
      _selected = null;
      _submittedQuestion = null;
      _askError = null;
      _reply = null;
      _sending = false;
      _draft.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _scroll.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content = await widget.repository.load();
      if (!mounted || generation != _generation) return;
      setState(() => _content = content);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(
        () =>
            _error =
                error is AssistantFailure
                    ? error.message
                    : 'Asistan seçenekleri yüklenemedi. Tekrar deneyebilirsin.',
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _close([AssistantDestination? destination]) {
    if (_closing || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _closing = true);
    Navigator.of(context).pop(destination);
  }

  void _select(AssistantOption? option) {
    if (_sending || _closing) return;
    setState(() {
      _selected = option;
      _submittedQuestion = null;
      _reply = null;
      _askError = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _ask() async {
    if (_sending ||
        _closing ||
        _loading ||
        _content == null ||
        !widget.repository.supportsQuestions) {
      return;
    }
    final original = _draft.text;
    if (original.trim().isEmpty) return;
    final question = validatedAssistantQuestion(original);
    final generation = _generation;
    setState(() {
      _sending = true;
      _askError = null;
      _reply = null;
      _selected = null;
      _submittedQuestion = question;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    try {
      final reply = await widget.repository.ask(question);
      if (!mounted || generation != _generation || _closing) return;
      setState(() {
        _reply = reply;
        if (_draft.text == original) _draft.clear();
      });
      FocusScope.of(context).unfocus();
    } catch (error) {
      if (!mounted || generation != _generation || _closing) return;
      setState(
        () =>
            _askError =
                error is AssistantFailure
                    ? error.message
                    : 'Sorun gönderilemedi. Lütfen tekrar dene.',
      );
    } finally {
      if (mounted && generation == _generation && !_closing) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = _content;
    final question = _submittedQuestion ?? _selected?.title;
    final answer = _reply?.answer ?? _selected?.answer;
    final destinationKey = _reply?.destination ?? _selected?.destination;
    final destination = AssistantDestination.fromKey(destinationKey);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final supported =
        destination != null &&
        widget.availableDestinations.contains(destination);
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder:
            (context, constraints) => Column(
              children: [
                const SizedBox(height: 10),
                ExcludeSemantics(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: colors.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'StudyCo Asistan',
                          maxLines: keyboardVisible ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('assistant-close'),
                        tooltip: 'Asistanı kapat',
                        onPressed: _closing ? null : _close,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (_loading)
                        const Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Asistan seçenekleri yükleniyor',
                          ),
                        ),
                      if (_error != null) ...[
                        Text(_error!, key: const ValueKey('assistant-error')),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                      if (!_loading && _error == null && content != null) ...[
                        if (!widget.repository.supportsQuestions)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Serbest soru hizmeti henüz bağlı değil. Hazır seçenekleri kullanabilirsin.',
                            ),
                          ),
                        if (content.isDemo || _reply?.isDemo == true)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: colors.secondary.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Örnek içerik • Tasarım önizlemesi',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        if (question == null) ...[
                          Text(
                            content.greeting,
                            key: const ValueKey('assistant-greeting'),
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 20),
                          if (content.options.isEmpty)
                            const Text('Henüz seçenek bulunmuyor.'),
                          for (final option in content.options)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  key: ValueKey(
                                    'assistant-option-${option.id}',
                                  ),
                                  onTap:
                                      _sending ? null : () => _select(option),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.help_outline,
                                          color: colors.secondary,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            option.title,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.chevron_right,
                                          color: colors.secondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ] else ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: const ValueKey('assistant-back'),
                              onPressed: _sending ? null : () => _select(null),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Tüm seçenekler'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            question,
                            key: const ValueKey('assistant-question'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_sending)
                            Semantics(
                              liveRegion: true,
                              child: const Text('Yanıt bekleniyor...'),
                            ),
                          if (_askError != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _askError!,
                                key: const ValueKey('assistant-ask-error'),
                                style: TextStyle(color: colors.error),
                              ),
                            ),
                          if (answer != null)
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: colors.outlineVariant,
                                ),
                              ),
                              child: Text(
                                answer,
                                key: const ValueKey('assistant-answer'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (supported)
                            FilledButton.icon(
                              key: const ValueKey('assistant-go'),
                              onPressed:
                                  _closing ? null : () => _close(destination),
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('İlgili Sayfaya Git'),
                            )
                          else if (destinationKey != null)
                            const Text(
                              'Bu yönlendirme şu anda kullanılamıyor. Diğer seçeneklere dönebilirsin.',
                              key: ValueKey('assistant-unavailable'),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .45,
                  ),
                  child: SingleChildScrollView(
                    child: AssistantQuestionComposer(
                      controller: _draft,
                      enabled:
                          !_loading &&
                          _content != null &&
                          _error == null &&
                          widget.repository.supportsQuestions &&
                          !_closing,
                      sending: _sending,
                      onChanged: (_) => setState(() {}),
                      onSend: _ask,
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
