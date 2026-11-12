import 'package:flutter/material.dart';
import '../models/review.dart';
import 'rating_stars.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});
  final Review review;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = review.createdAt.toLocal();
    final comment = review.comment?.trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.onPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.secondary.withValues(alpha: .12),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: colors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewer.displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}/${date.month}/${date.year}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RatingStars(rating: review.rating.toDouble()),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              comment,
              key: ValueKey('review-comment-${review.id}'),
              style: const TextStyle(fontSize: 15, height: 1.55),
            ),
          ],
        ],
      ),
    );
  }
}
