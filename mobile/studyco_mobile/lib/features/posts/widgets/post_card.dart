import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/post.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, required this.onOpen});
  // Offer-specific reference colors; the app brand palette stays unchanged.
  static const _coffeeBackground = Color(0xFFFFF7E6);
  static const _coffeeForeground = Color(0xFF855300);
  static const _coffeeBorder = Color(0xFFFFD79A);
  final Post post;
  final VoidCallback onOpen;

  // Match the card's wrapping text and fixed spacing without truncating content.
  static double requiredHeight(BuildContext context, Post post, double width) {
    final baseStyle = DefaultTextStyle.of(context).style;
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Card padding (24) plus its two border edges (2).
    final contentWidth = math.max(1.0, width - 26);

    double textHeight(
      String value,
      double availableWidth,
      double fontSize,
      FontWeight weight,
    ) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: baseStyle.merge(
            TextStyle(fontSize: fontSize, fontWeight: weight),
          ),
        ),
        textDirection: direction,
        textScaler: textScaler,
      )..layout(maxWidth: math.max(1.0, availableWidth));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    // Preserve the trailing header space and label padding/border.
    final typeHeight = textHeight(
      post.typeLabel,
      contentWidth - 68,
      12,
      FontWeight.w600,
    );
    final titleHeight = textHeight(
      post.title,
      contentWidth,
      15,
      FontWeight.w700,
    );
    final authorHeight = textHeight(
      post.authorName,
      contentWidth - 28,
      12,
      FontWeight.w500,
    );
    final dateHeight = textHeight(
      post.dateLabel,
      contentWidth - 20,
      12,
      FontWeight.w500,
    );
    final locationHeight = textHeight(
      post.location,
      contentWidth - 20,
      12,
      FontWeight.w500,
    );
    // Detail button/gap (38), label padding/border (12), optional coffee icon (16).
    final offerHeight = textHeight(
      post.offerLabel,
      contentWidth - 50 - (post.offer == PostOffer.coffee ? 16 : 0),
      12,
      FontWeight.w600,
    );
    return (26 +
            math.max(48.0, typeHeight + 10) +
            8 +
            titleHeight +
            8 +
            math.max(22.0, authorHeight) +
            20 +
            math.max(16.0, dateHeight) +
            6 +
            math.max(16.0, locationHeight) +
            16 +
            math.max(34.0, offerHeight + 10) +
            4)
        .ceilToDouble();
  }

  Widget _text(String value, {TextStyle? style}) =>
      Tooltip(message: value, child: Text(value, softWrap: true, style: style));
  Widget _metadata(BuildContext context, IconData icon, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
      const SizedBox(width: 4),
      Expanded(
        child: _text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.primary.withValues(alpha: 0.75),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = Color.alphaBlend(
      colors.secondary.withValues(alpha: 0.13),
      colors.onPrimary,
    );
    final accent = Color.alphaBlend(
      colors.primary.withValues(alpha: 0.45),
      colors.secondary,
    );
    final coffee = post.offer == PostOffer.coffee;
    final offerTint = coffee ? _coffeeBackground : tint;
    final offerColor = coffee ? _coffeeForeground : AppColors.primary;
    final tutoring = post.type == PostType.tutoring;
    return Semantics(
      button: true,
      child: GestureDetector(
        key: ValueKey('open-card-${post.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: Container(
          key: ValueKey('post-${post.id}'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.onPrimary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.035),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tutoring ? accent : tint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              tutoring
                                  ? accent
                                  : colors.secondary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: _text(
                        post.typeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              tutoring ? colors.onPrimary : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32, height: 36),
                ],
              ),
              const SizedBox(height: 8),
              const Spacer(),
              _text(
                post.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Spacer(),
              Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: tint,
                    child: Text(
                      post.authorName.isEmpty
                          ? '?'
                          : post.authorName.characters.first,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _text(
                      post.authorName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
              Divider(
                height: 20,
                color: colors.primary.withValues(alpha: 0.07),
              ),
              _metadata(context, Icons.schedule_outlined, post.dateLabel),
              const SizedBox(height: 6),
              _metadata(context, Icons.location_on_outlined, post.location),
              const Spacer(),
              Divider(
                height: 16,
                color: colors.primary.withValues(alpha: 0.07),
              ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: offerTint,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              coffee
                                  ? _coffeeBorder
                                  : colors.secondary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (post.offer == PostOffer.coffee) ...[
                            Icon(
                              Icons.local_cafe_outlined,
                              size: 13,
                              color: offerColor,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Expanded(
                            child: _text(
                              post.offerLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: offerColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 32,
                    height: 34,
                    child: IconButton(
                      key: ValueKey('open-${post.id}'),
                      tooltip: 'İlan detayı: ${post.title}',
                      onPressed: onOpen,
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: tint,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(Icons.arrow_forward, size: 20, color: accent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
