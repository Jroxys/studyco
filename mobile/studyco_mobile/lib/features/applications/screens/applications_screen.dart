import '../../reviews/widgets/review_request_action.dart';
import 'package:flutter/material.dart';
import '../../posts/domain/posts_repository.dart';
import '../../posts/models/post.dart';
import '../../profile/models/user_profile.dart';
import '../domain/applications_repository.dart';
import '../models/application.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({
    super.key,
    required this.postsRepository,
    required this.repository,
    required this.user,
    this.onBrowse,
    this.incoming = false,
  });
  final PostsRepository postsRepository;
  final ApplicationsRepository? repository;
  final UserProfile user;
  final VoidCallback? onBrowse;
  final bool incoming;

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  ApplicationFilter _filter = ApplicationFilter.all;
  bool _loading = true;
  String? _error;
  final _responding = <String>{};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.incoming) {
        await widget.repository?.refreshIncoming(
          ownerId: widget.user.postsOwnerId,
        );
      } else {
        await widget.repository?.refresh(applicantId: widget.user.postsOwnerId);
      }
    } catch (_) {
      if (mounted) _error = 'Başvurular yüklenemedi. Lütfen tekrar deneyin.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Application application) {
    final source = widget.repository;
    if (source == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => _ApplicationDetailsSheet(
            applicationId: application.id,
            incoming: widget.incoming,
            repository: source,
            postsRepository: widget.postsRepository,
            user: widget.user,
          ),
    );
  }

  Future<void> _respond(Application application, bool accept) async {
    if (_responding.contains(application.id)) return;
    setState(() => _responding.add(application.id));
    try {
      final message = await _decide(
        context,
        widget.repository!,
        application.id,
        widget.user.postsOwnerId,
        accept,
      );
      if (mounted && message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_decisionError(error))));
      }
    } finally {
      if (mounted) setState(() => _responding.remove(application.id));
    }
  }

  Widget _empty(String message, {bool retry = false}) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.onPrimary,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.secondary.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    retry
                        ? Icons.wifi_off_rounded
                        : Icons.mark_email_unread_outlined,
                    size: 36,
                    color: colors.secondary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  retry
                      ? 'Bir sorun oluştu'
                      : widget.incoming
                      ? 'Başvurular burada görünecek'
                      : 'Yeni bir başlangıç yap',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5, color: colors.onSurfaceVariant),
                ),
                if (retry || widget.onBrowse != null) ...[
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: retry ? _load : widget.onBrowse,
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(
                        retry ? 'Tekrar Dene' : 'İlanlara Göz At',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filters() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const style = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);
        var labelWidth = 0.0;
        for (final filter in ApplicationFilter.values) {
          final painter = TextPainter(
            text: TextSpan(text: filter.label, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          if (painter.width > labelWidth) labelWidth = painter.width;
          painter.dispose();
        }
        final columns =
            (constraints.maxWidth - gap * 3) / 4 >= labelWidth + 16
                ? 4
                : (constraints.maxWidth - gap) / 2 >= labelWidth + 16
                ? 2
                : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final colors = Theme.of(context).colorScheme;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final filter in ApplicationFilter.values)
              SizedBox(
                width: width,
                child: Semantics(
                  selected: _filter == filter,
                  child: OutlinedButton(
                    key: ValueKey('application-filter-${filter.name}'),
                    onPressed: () => setState(() => _filter = filter),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 12,
                      ),
                      foregroundColor: colors.primary,
                      backgroundColor:
                          _filter == filter
                              ? colors.secondary.withValues(alpha: .18)
                              : colors.onPrimary,
                      side: BorderSide(
                        color:
                            _filter == filter
                                ? colors.secondary
                                : colors.outlineVariant,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: style,
                    ),
                    child: Text(filter.label, textAlign: TextAlign.center),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _list() {
    if (_loading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SliverToBoxAdapter(child: _empty(_error!, retry: true));
    }
    final source = widget.repository;
    if (source == null) {
      return SliverToBoxAdapter(
        child: _empty('Başvurular şu anda görüntülenemiyor.'),
      );
    }
    final all =
        widget.incoming
            ? source.forOwner(widget.user.postsOwnerId)
            : source.forApplicant(widget.user.postsOwnerId);
    final filtered = all.where(_filter.matches).toList();
    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: _empty(
          all.isEmpty
              ? widget.incoming
                  ? 'İlanlarına henüz başvuru yapılmadı. Başvurular geldiğinde buradan yönetebilirsin.'
                  : 'İlgini çeken bir ders bul, ilk başvurunu yap.'
              : 'Bu filtrede başvurun bulunmuyor.',
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final application = filtered[index];
          final post = _findPost(widget.postsRepository, application.postId);
          final colors = Theme.of(context).colorScheme;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              color: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('application-${application.id}'),
                onTap: () => _open(application),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _applicationTitle(post, application),
                              style: const TextStyle(
                                fontSize: 19,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colors.secondary.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: colors.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _StatusBadge(application: application),
                      const SizedBox(height: 16),
                      _PostInformation(
                        post: post,
                        application: application,
                        incoming: widget.incoming,
                      ),
                      if (widget.incoming)
                        _ApplicationDecisionButtons(
                          application: application,
                          repository: source,
                          ownerId: widget.user.postsOwnerId,
                          busy: _responding.contains(application.id),
                          surface: 'card',
                          onAccept: () => _respond(application, true),
                          onReject: () => _respond(application, false),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Color.alphaBlend(
        Theme.of(context).colorScheme.secondary.withValues(alpha: .06),
        Theme.of(context).colorScheme.surface,
      ),
      title: Text(
        widget.incoming ? 'Gelen Başvurular' : 'Başvurularım',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
            key: const ValueKey('applications-scroll'),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Text(
                        widget.incoming
                            ? 'İlanlarına yapılan başvuruları buradan yönet.'
                            : 'Başka kullanıcıların ilanlarına yaptığın başvurular.',
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                    _filters(),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([
                  widget.repository,
                  widget.postsRepository,
                ]),
                builder: (_, _) => _list(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Post? _findPost(PostsRepository repository, String id) {
  final matches = repository.posts.where((post) => post.id == id);
  return matches.isEmpty ? null : matches.first;
}

String _text(String? value, String fallback) =>
    value?.trim().isNotEmpty == true ? value! : fallback;

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.application});
  final Application application;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color =
        application.isLocallyCancelled
            ? colors.onSurfaceVariant
            : switch (application.status) {
              ApplicationStatus.pending => const Color(0xFF855300),
              ApplicationStatus.accepted => const Color(0xFF226043),
              ApplicationStatus.rejected => colors.error,
              ApplicationStatus.autoCancelled ||
              ApplicationStatus.unknown => colors.onSurfaceVariant,
            };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Text(
          application.statusLabel,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

String _applicationTitle(Post? post, Application application) => _text(
  post?.title,
  _text(application.listing?.topic, 'İlan artık görüntülenemiyor.'),
);

/// Shared metadata for sent/received cards and both detail panels.
class _PostInformation extends StatelessWidget {
  const _PostInformation({
    required this.post,
    required this.application,
    this.incoming = false,
    this.detailed = false,
  });
  final Post? post;
  final Application application;
  final bool incoming;
  final bool detailed;
  Widget _row(BuildContext context, IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(height: 1.4))),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final start = post?.startsAt ?? application.listing?.startAt;
    final end = post?.endsAt ?? application.listing?.endAt;
    final tokens =
        application.agreedTokenAmount ?? application.listing?.tokenPrice;
    final offer =
        tokens == null
            ? post?.offerLabel ?? 'Ders karşılığı bilgisi mevcut değil.'
            : tokens == 0
            ? 'Ücretsiz'
            : '$tokens Token';
    String time(DateTime value) {
      final date = value.toLocal();
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    String date(DateTime value) {
      final d = value.toLocal();
      return '${d.day}/${d.month}/${d.year}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          context,
          Icons.person_outline,
          incoming
              ? _text(
                application.applicant?.displayName,
                'Öğrenci bilgisi mevcut değil.',
              )
              : _text(
                post?.authorName,
                _text(
                  application.teacher?.displayName,
                  'İlan sahibi bilgisi mevcut değil.',
                ),
              ),
        ),
        if (detailed || incoming)
          _row(
            context,
            Icons.sell_outlined,
            'Konu: ${_text(post?.topic, _text(application.listing?.topic, 'Belirtilmemiş'))}',
          ),
        _row(
          context,
          Icons.calendar_month_outlined,
          start == null ? 'Tarih bilgisi mevcut değil.' : date(start),
        ),
        _row(
          context,
          Icons.schedule,
          start == null || end == null
              ? 'Saat bilgisi mevcut değil.'
              : '${time(start)} – ${DateUtils.isSameDay(start.toLocal(), end.toLocal()) ? '' : '${date(end)} '}${time(end)}',
        ),
        _row(
          context,
          Icons.location_on_outlined,
          _text(post?.location, 'Konum bilgisi mevcut değil.'),
        ),
        if (detailed)
          _row(
            context,
            Icons.notes_outlined,
            _text(post?.description, 'Açıklama belirtilmemiş.'),
          ),
        if (detailed || incoming)
          _row(context, Icons.local_cafe_outlined, offer),
        if (detailed && application.createdAt != null)
          _row(
            context,
            Icons.event_note_outlined,
            'Başvuru tarihi: ${date(application.createdAt!)} ${time(application.createdAt!)}',
          ),
        if (detailed && application.respondedAt != null)
          _row(
            context,
            Icons.update,
            'Yanıt tarihi: ${date(application.respondedAt!)} ${time(application.respondedAt!)}',
          ),
        if (detailed && application.studentCompletedAt != null)
          _row(
            context,
            Icons.task_alt,
            'Öğrenci onayı: ${date(application.studentCompletedAt!)} ${time(application.studentCompletedAt!)}',
          ),
        if (detailed && application.teacherCompletedAt != null)
          _row(
            context,
            Icons.task_alt,
            'İlan sahibi onayı: ${date(application.teacherCompletedAt!)} ${time(application.teacherCompletedAt!)}',
          ),
        if (detailed && application.confirmationDeadlineAt != null)
          _row(
            context,
            Icons.schedule,
            'Onay son tarihi: ${date(application.confirmationDeadlineAt!)} ${time(application.confirmationDeadlineAt!)}',
          ),
        if (detailed && application.settledAt != null)
          _row(
            context,
            Icons.receipt_long_outlined,
            'Sonuçlandırma tarihi: ${date(application.settledAt!)}',
          ),
        if (detailed &&
            application.completionStatus != null &&
            application.studentCompletedAt == null &&
            application.teacherCompletedAt == null)
          _row(
            context,
            Icons.info_outline,
            'Ders onay bilgileri henüz doğrulanmadı.',
          ),
      ],
    );
  }
}

String _decisionError(Object error) =>
    error is ApplicationFailure
        ? error.message
        : 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
Future<String?> _decide(
  BuildContext context,
  ApplicationsRepository source,
  String id,
  String ownerId,
  bool accept,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(accept ? 'Başvuruyu Kabul Et' : 'Başvuruyu Reddet'),
          content: Text(
            accept
                ? 'Bu başvuruyu kabul etmek istiyor musun? Aynı ilana gelen diğer bekleyen başvurular otomatik iptal edilecektir.'
                : 'Bu başvuruyu reddetmek istiyor musun?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(accept ? 'Kabul Et' : 'Reddet'),
            ),
          ],
        ),
  );
  if (confirmed != true || !context.mounted) return null;
  if (accept) {
    await source.accept(id, ownerId: ownerId);
  } else {
    await source.reject(id, ownerId: ownerId);
  }
  return accept ? 'Başvuru kabul edildi.' : 'Başvuru reddedildi.';
}

class _ApplicationDecisionButtons extends StatelessWidget {
  const _ApplicationDecisionButtons({
    required this.application,
    required this.repository,
    required this.ownerId,
    required this.busy,
    required this.surface,
    required this.onAccept,
    required this.onReject,
  });
  final Application application;
  final ApplicationsRepository repository;
  final String ownerId;
  final bool busy;
  final String surface;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  @override
  Widget build(BuildContext context) {
    if (!application.isPending) return const SizedBox.shrink();
    final accept = repository.canAccept(application, ownerId: ownerId);
    final reject = repository.canReject(application, ownerId: ownerId);
    if (!accept && !reject) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FilledButton(
              key: ValueKey('$surface-accept-${application.id}'),
              onPressed: busy || !accept ? null : onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: colors.secondary,
                foregroundColor: colors.primary,
                elevation: 0,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Kabul Et', textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              key: ValueKey('$surface-reject-${application.id}'),
              onPressed: busy || !reject ? null : onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                backgroundColor: colors.onPrimary,
                side: BorderSide(color: colors.error),
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Reddet', textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationDetailsSheet extends StatefulWidget {
  const _ApplicationDetailsSheet({
    required this.applicationId,
    required this.incoming,
    required this.repository,
    required this.postsRepository,
    required this.user,
  });
  final String applicationId;
  final bool incoming;
  final ApplicationsRepository repository;
  final PostsRepository postsRepository;
  final UserProfile user;
  @override
  State<_ApplicationDetailsSheet> createState() =>
      _ApplicationDetailsSheetState();
}

class _ApplicationDetailsSheetState extends State<_ApplicationDetailsSheet> {
  bool _busy = false;
  String? _notice;
  Future<void> _respond(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await _decide(
        context,
        widget.repository,
        widget.applicationId,
        widget.user.postsOwnerId,
        accept,
      );
      if (mounted && message != null) _message(message);
    } catch (error) {
      if (mounted) _message(_decisionError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    // Disable duplicate dialogs too; cancellation itself is still repository-authorized.
    setState(() => _busy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Başvurumu İptal Et'),
            content: const Text(
              'Bu başvurunu iptal etmek istediğine emin misin?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Başvurumu İptal Et'),
              ),
            ],
          ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _busy = false);
      return;
    }
    try {
      await widget.repository.cancel(
        widget.applicationId,
        applicantId: widget.user.postsOwnerId,
      );
      if (mounted) {
        _message('Başvurun iptal edildi.');
      }
    } on ApplicationFailure catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('Başvuru iptal edilemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) => setState(() => _notice = text);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: FractionallySizedBox(
      heightFactor: .88,
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            widget.repository,
            widget.postsRepository,
          ]),
          builder: (context, _) {
            final scoped =
                widget.incoming
                    ? widget.repository.forOwner(widget.user.postsOwnerId)
                    : widget.repository.forApplicant(widget.user.postsOwnerId);
            final application =
                scoped.any((item) => item.id == widget.applicationId)
                    ? widget.repository.getForUser(
                      widget.applicationId,
                      userId: widget.user.postsOwnerId,
                    )
                    : null;
            final post =
                application == null
                    ? null
                    : _findPost(widget.postsRepository, application.postId);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Başvuru Detayı',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      20 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (application == null)
                          const Text('Başvuru artık görüntülenemiyor.')
                        else ...[
                          Text(
                            _applicationTitle(post, application),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _StatusBadge(application: application),
                          const SizedBox(height: 20),
                          Divider(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            height: 1,
                          ),
                          const SizedBox(height: 20),
                          _PostInformation(
                            post: post,
                            application: application,
                            incoming: widget.incoming,
                            detailed: true,
                          ),
                          const SizedBox(height: 12),
                          if (_notice != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _notice!,
                                key: const ValueKey('application-notice'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ReviewRequestAction(
                            application: application,
                            user: widget.user,
                            lessonTitle: _applicationTitle(post, application),
                          ),
                          if (widget.incoming)
                            _ApplicationDecisionButtons(
                              application: application,
                              repository: widget.repository,
                              ownerId: widget.user.postsOwnerId,
                              busy: _busy,
                              surface: 'detail',
                              onAccept: () => _respond(true),
                              onReject: () => _respond(false),
                            ),
                          if (!widget.incoming &&
                              widget.repository.canCancel(
                                application,
                                applicantId: widget.user.postsOwnerId,
                              ))
                            OutlinedButton(
                              key: const ValueKey('cancel-application'),
                              onPressed: _busy ? null : _cancel,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _busy ? 'İşlem sürüyor…' : 'Başvurumu İptal Et',
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
