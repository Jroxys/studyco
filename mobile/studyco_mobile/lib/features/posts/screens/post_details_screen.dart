import 'package:flutter/material.dart';
import '../models/post.dart';
import '../domain/posts_repository.dart';

/// Read-only detail view, reusable by Home and future Search routes.
/// The caller passes the selected Post itself; no sample data or repository copy.
class PostDetailsScreen extends StatelessWidget {
  const PostDetailsScreen({
    super.key,
    required this.post,
    required this.repository,
  });
  final Post post;
  final PostsRepository repository;

  String _date(DateTime date) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  void _apply(BuildContext context) {
    // No application, match or conversation is created. Replace at integration
    // time with the approved application flow, never direct messaging.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Başvuru işlemi henüz kullanıma hazır değil.'),
        ),
      );
  }

  Widget _information(
    BuildContext context,
    String label,
    String value, {
    String? key,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: key == null ? null : ValueKey(key),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.primary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 15, height: 1.4, color: colors.primary),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children, {
    String? key,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: key == null ? null : ValueKey(key),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: colors.onPrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasDescription = post.description?.trim().isNotEmpty ?? false;
    final hasDepartment = post.department?.trim().isNotEmpty ?? false;
    final hasTopic = post.topic?.trim().isNotEmpty ?? false;
    final endIsSameDay = DateUtils.isSameDay(post.startsAt, post.endsAt);
    final timeRange =
        '${_time(post.startsAt)}–${endIsSameDay ? _time(post.endsAt) : '${_date(post.endsAt)} ${_time(post.endsAt)}'}';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.alphaBlend(
          colors.secondary.withValues(alpha: 0.06),
          colors.surface,
        ),
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'İlan Detayları',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: FilledButton(
            key: const ValueKey('apply-post'),
            onPressed: () => _apply(context),
            child: const Text('Başvur'),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          key: const ValueKey('post-details-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          children: [
            Container(
              key: const ValueKey('detail-summary'),
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colors.onPrimary,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final type = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.secondary.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          post.typeLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      );
                      final offer = Text(
                        post.offerLabel,
                        key: const ValueKey('detail-offer'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      );
                      if (constraints.maxWidth < 360 &&
                          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(alignment: Alignment.centerLeft, child: type),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: offer,
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: type),
                          const SizedBox(width: 12),
                          Flexible(child: offer),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    post.title,
                    key: const ValueKey('detail-title'),
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  if (hasTopic)
                    Padding(
                      key: const ValueKey('detail-topic'),
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Konu: ${post.topic!}',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  if (hasDepartment)
                    Padding(
                      key: const ValueKey('detail-department'),
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        post.department!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: colors.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              key: const ValueKey('detail-owner'),
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colors.onPrimary,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colors.secondary.withValues(alpha: 0.12),
                    child: Icon(Icons.person_outline, color: colors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          key: const ValueKey('detail-author'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'İlan Sahibi',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.primary.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (hasDescription)
              _section(
                context,
                'Ders Açıklaması',
                Icons.notes_outlined,
                [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      post.description!,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
                key: 'detail-description',
              ),
            _section(context, 'Tarih ve Saat', Icons.calendar_month_outlined, [
              LayoutBuilder(
                builder: (context, constraints) {
                  final date = _information(
                    context,
                    'Tarih',
                    _date(post.startsAt),
                    key: 'detail-date',
                  );
                  final time = _information(
                    context,
                    'Saat',
                    timeRange,
                    key: 'detail-time',
                  );
                  if (constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [date, time],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: date),
                      const SizedBox(width: 16),
                      Expanded(child: time),
                    ],
                  );
                },
              ),
            ]),
            _section(context, 'Buluşma Konumu', Icons.location_on_outlined, [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  post.location,
                  key: const ValueKey('detail-location'),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: colors.primary,
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
