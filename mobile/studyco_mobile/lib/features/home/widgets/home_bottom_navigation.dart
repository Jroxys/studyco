import 'package:flutter/material.dart';

class HomeBottomNavigation extends StatelessWidget {
  const HomeBottomNavigation({
    super.key,
    required this.onSelected,
    this.selectedIndex = 0,
  });
  final ValueChanged<int> onSelected;
  final int selectedIndex;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const labels = ['Ana Sayfa', 'İlan Oluştur', 'Ara', 'Profilim'];
    const icons = [
      Icons.home_filled,
      Icons.add_circle_outline,
      Icons.search,
      Icons.person_outline,
    ];
    return Material(
      color: Color.alphaBlend(
        colors.secondary.withValues(alpha: 0.05),
        colors.surface,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            children: List.generate(
              4,
              (index) => Expanded(
                child: Semantics(
                  selected: index == selectedIndex,
                  button: true,
                  child: InkWell(
                    key: ValueKey('home-nav-$index'),
                    onTap: () => onSelected(index),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            index == selectedIndex
                                ? colors.secondary.withValues(alpha: 0.24)
                                : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icons[index],
                            color:
                                index == selectedIndex
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            labels[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  index == selectedIndex
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
