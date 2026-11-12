import 'package:flutter/material.dart';
import '../models/review.dart';
import 'rating_stars.dart';

class RatingSummary extends StatelessWidget {
  const RatingSummary({
    super.key,
    required this.statistics,
    this.title = 'Genel Değerlendirme Puanım',
    this.loading = false,
    this.unavailable = false,
    this.loadedCount = 0,
  });
  final ReviewStatistics? statistics;
  final String title;
  final bool loading;
  final bool unavailable;
  final int loadedCount;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stats = statistics;
    return Container(
      key: const ValueKey('rating-summary'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.onPrimary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Text('Puan bilgisi yükleniyor…')
          else if (unavailable)
            const Text('Puan bilgisi şu anda görüntülenemiyor.')
          else if (stats == null) ...[
            const Text(
              'Genel puan için tüm değerlendirmeler yüklenmeli.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Şu ana kadar $loadedCount değerlendirme yüklendi.',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ] else if (stats.count == 0)
            const Text('Henüz değerlendirme yok')
          else
            Wrap(
              spacing: 18,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  stats.average!.toStringAsFixed(1),
                  key: const ValueKey('review-average'),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RatingStars(rating: stats.average!),
                    const SizedBox(height: 8),
                    Text(
                      'Toplam ${stats.count} değerlendirme',
                      key: const ValueKey('review-total'),
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
