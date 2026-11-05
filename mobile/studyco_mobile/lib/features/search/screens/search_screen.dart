import 'package:flutter/material.dart';
import '../../../core/data/academic_catalog.dart';
import '../../../core/widgets/academic_catalog_scope.dart';
import '../../home/widgets/home_bottom_navigation.dart';
import '../../posts/domain/posts_repository.dart';
import '../../posts/widgets/location_catalog_scope.dart';
import '../../posts/screens/create_post_screen.dart';
import '../../posts/screens/post_details_screen.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/navigation/profile_navigation.dart';
import '../domain/post_search.dart';
import '../widgets/search_post_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.repository,
    required this.user,
    this.onHome,
  });
  final VoidCallback? onHome;
  final PostsRepository repository;
  final UserProfile user;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  AcademicCatalog? _academicCatalog;
  String? _department;
  String? _course;
  CoffeeFilter _coffee = CoffeeFilter.all;
  String? _location;
  bool _loading = true;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AcademicCatalogScope.of(context);
    if (_academicCatalog != null && _academicCatalog != next) {
      _department = null;
      _course = null;
    }
    _academicCatalog = next;
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.refresh();
    } catch (_) {
      if (mounted && request == _request) _error = 'İlanlar yüklenemedi.';
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Widget _menu<T>(
    String key,
    String label,
    T value,
    Map<T, String> choices,
    ValueChanged<T?> onChanged,
  ) {
    final colors = Theme.of(context).colorScheme;
    final active = value != null && value != CoffeeFilter.all;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(
        color: active ? colors.secondary : colors.outlineVariant,
      ),
    );
    return SizedBox(
      width:
          128 +
          (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, 24) * 3,
      child: DropdownButtonFormField<T>(
        key: ValueKey('$key-$value'),
        value: value,
        isExpanded: true,
        itemHeight: null,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: colors.primary,
        ),
        style: TextStyle(
          color: colors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          labelStyle: TextStyle(
            color: colors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          fillColor:
              active ? colors.secondary.withValues(alpha: .18) : colors.surface,
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
        selectedItemBuilder:
            (_) =>
                choices.entries
                    .map(
                      (entry) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          !active ? label : entry.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
        items:
            choices.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [Expanded(child: Text(e.value))]),
                    ),
                  ),
                )
                .toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _reset() => setState(() {
    _query.clear();
    _department = null;
    _course = null;
    _coffee = CoffeeFilter.all;
    _location = null;
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 46,
      titleSpacing: 12,
      title: Image.asset(
        'assets/images/studyco_logo.png',
        height: 32,
        semanticLabel: 'StudyCo',
        errorBuilder: (_, _, _) => const Text('StudyCo'),
      ),
    ),
    bottomNavigationBar: HomeBottomNavigation(
      selectedIndex: 2,
      onSelected: (index) {
        if (index == 0) {
          if (widget.onHome != null) {
            widget.onHome!();
          } else {
            Navigator.of(context).pop();
          }
        }
        if (index == 1) {
          Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder:
                  (_) => CreatePostScreen(
                    repository: widget.repository,
                    user: widget.user,
                    onHome: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      if (widget.onHome != null) {
                        widget.onHome!();
                      } else {
                        navigator.pop();
                      }
                    },
                  ),
            ),
          );
        }
        if (index == 3) {
          ProfileNavigation.open(
            context,
            user: widget.user,
            repository: widget.repository,
            sourceIndex: 2,
            onHome: widget.onHome ?? () => Navigator.of(context).pop(),
          );
        }
      },
    ),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: widget.repository,
        builder: (context, _) {
          final posts = widget.repository.posts;
          final catalog = LocationCatalogScope.of(context);
          final selectedLocation = catalog.findByName(_location)?.name;
          final academic = AcademicCatalogScope.of(context);
          final courses = PostSearch.courses(
            posts,
            _department,
            catalog: academic,
          );
          final selectedCourse =
              courses
                  .where(
                    (c) => normalizeSearch(c) == normalizeSearch(_course ?? ''),
                  )
                  .firstOrNull;
          final results = PostSearch(
            query: _query.text,
            department: _department,
            course: selectedCourse,
            coffee: _coffee,
            location: selectedLocation,
          ).apply(posts);
          final active = <String>[
            if (_query.text.trim().isNotEmpty) 'Arama: ${_query.text.trim()}',
            if (_department != null) _department!,
            if (selectedCourse != null) selectedCourse,
            if (_coffee != CoffeeFilter.all) _coffeeLabels[_coffee]!,
            if (selectedLocation != null) selectedLocation,
          ];
          return CustomScrollView(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('search-query'),
                        controller: _query,
                        style: const TextStyle(fontSize: 13),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          hintText: 'Konu ara...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              _query.text.isEmpty
                                  ? null
                                  : IconButton(
                                    tooltip: 'Aramayı temizle',
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setState(_query.clear),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _menu<String?>(
                              'search-location',
                              'Konum',
                              selectedLocation,
                              {
                                null: 'Tümü',
                                for (final location in catalog.names)
                                  location: location,
                              },
                              (value) => setState(() => _location = value),
                            ),
                            const SizedBox(width: 8),
                            _menu<String?>(
                              'search-department',
                              'Bölüm',
                              _department,
                              {
                                null: 'Tümü',
                                for (final d in academic.departmentNames) d: d,
                              },
                              (value) => setState(() {
                                _department = value;
                                _course = null;
                              }),
                            ),
                            const SizedBox(width: 8),
                            _menu<String?>(
                              'search-course',
                              'Ders',
                              selectedCourse,
                              {null: 'Tümü', for (final c in courses) c: c},
                              (value) => setState(() => _course = value),
                            ),
                            const SizedBox(width: 8),
                            _menu(
                              'search-coffee',
                              'Kahve',
                              _coffee,
                              _coffeeLabels,
                              (value) => setState(() => _coffee = value!),
                            ),
                          ],
                        ),
                      ),
                      if (active.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const ValueKey('clear-search-filters'),
                            onPressed: _reset,
                            style: TextButton.styleFrom(
                              textStyle: const TextStyle(fontSize: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: const Size(48, 40),
                            ),
                            child: const Text('Filtreleri temizle'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Tüm İlanlar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${results.length} ilan bulundu',
                              key: const ValueKey('search-result-count'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              else if (results.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Uygun ilan bulunamadı',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final post = results[index];
                      return SearchPostCard(
                        key: ValueKey(post.id),
                        post: post,
                        onOpen: () {
                          FocusScope.of(context).unfocus();
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder:
                                  (_) => PostDetailsScreen(
                                    post: post,
                                    repository: widget.repository,
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    ),
  );

  static const _coffeeLabels = {
    CoffeeFilter.all: 'Tümü',
    CoffeeFilter.free: 'Ücretsiz',
    CoffeeFilter.one: 'En fazla 1 Kahve',
    CoffeeFilter.two: 'En fazla 2 Kahve',
    CoffeeFilter.three: 'En fazla 3 Kahve',
  };
}
