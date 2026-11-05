import 'package:flutter/material.dart';
import '../../../core/data/academic_catalog.dart';
import '../../../core/widgets/academic_catalog_scope.dart';
import '../data/department_courses.dart';
import '../widgets/location_catalog_scope.dart';
import '../../home/widgets/home_bottom_navigation.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/navigation/profile_navigation.dart';
import '../domain/posts_repository.dart';
import '../models/post.dart';
import '../validation/create_post_validators.dart';
import '../widgets/post_location_field.dart';
import '../../search/screens/search_screen.dart';
import 'post_details_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({
    super.key,
    required this.repository,
    required this.user,
    this.onHome,
    this.initialPost,
  });
  final PostsRepository repository;
  final UserProfile user;
  final VoidCallback? onHome;
  final Post? initialPost;
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static int _sequence = 0;
  final _form = GlobalKey<FormState>();
  final _courseKey = GlobalKey<FormFieldState<DepartmentCourse>>();
  final _manualTitle = TextEditingController();
  final _topic = TextEditingController();
  final _description = TextEditingController();
  String? _location;
  AcademicCatalog? _academicCatalog;
  String? _department;
  DepartmentCourse? _course;
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  int? _coffee;
  bool _busy = false;
  String? _scheduleError;
  String? _offerError;

  bool get _editing => widget.initialPost != null;
  @override
  void initState() {
    super.initState();
    final post = widget.initialPost;
    if (post == null) return;
    _manualTitle.text = post.title;
    _topic.text = post.topic ?? '';
    _description.text = post.description ?? '';
    _location = post.location;
    _date = DateUtils.dateOnly(post.startsAt);
    _start = TimeOfDay.fromDateTime(post.startsAt);
    _end = TimeOfDay.fromDateTime(post.endsAt);
    _coffee = post.offer == PostOffer.free ? 0 : post.coffeeCount;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AcademicCatalogScope.of(context);
    if (!_editing && _academicCatalog != null && _academicCatalog != next) {
      _department = null;
      _course = null;
      _manualTitle.clear();
      _courseKey.currentState?.didChange(null);
    }
    _academicCatalog = next;
  }

  @override
  void dispose() {
    for (final controller in [_manualTitle, _topic, _description]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _scheduleUnchanged {
    final original = widget.initialPost;
    return original != null &&
        DateUtils.isSameDay(_date, original.startsAt) &&
        _start == TimeOfDay.fromDateTime(original.startsAt) &&
        _end == TimeOfDay.fromDateTime(original.endsAt);
  }

  DateTime? _combine(TimeOfDay? time) =>
      _scheduleUnchanged
          ? (time == _start
              ? widget.initialPost!.startsAt
              : widget.initialPost!.endsAt)
          : _date == null || time == null
          ? null
          : DateTime(
            _date!.year,
            _date!.month,
            _date!.day,
            time.hour,
            time.minute,
          );

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _validateSchedule() {
    final original = widget.initialPost;
    if (original != null &&
        _combine(_start) == original.startsAt &&
        _combine(_end) == original.endsAt) {
      _scheduleError = null;
      return;
    }
    _scheduleError = CreatePostValidators.schedule(
      _combine(_start),
      _combine(_end),
    );
  }

  Future<void> _pickDate() async {
    if (_busy) return;
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _date != null && !_date!.isBefore(today) ? _date : today,
      firstDate: today,
      lastDate: DateTime(today.year + 5, 12, 31),
      helpText: 'Ders tarihi',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (!mounted || selected == null || _busy) return;
    setState(() {
      _date = selected;
      if (_scheduleError != null) _validateSchedule();
    });
  }

  Future<void> _pickTime(bool start) async {
    if (_busy) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: (start ? _start : _end) ?? TimeOfDay.now(),
      helpText: start ? 'Başlangıç saati' : 'Bitiş saati',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (!mounted || selected == null || _busy) return;
    setState(() {
      if (start) {
        _start = selected;
      } else {
        _end = selected;
      }
      if (_scheduleError != null) _validateSchedule();
    });
  }

  Future<void> _publish() async {
    if (_busy || !mounted) return;
    if (_editing) {
      try {
        widget.repository.requireMutablePost(
          widget.initialPost!.id,
          ownerId: widget.user.postsOwnerId,
        );
      } on StateError {
        _message('Geçmiş veya kaldırılmış ilanlar düzenlenemez.');
        return;
      }
    }
    final valid = _form.currentState!.validate();
    setState(() {
      _validateSchedule();
      _offerError = _coffee == null ? 'Ders karşılığını seçin.' : null;
    });
    if (!valid ||
        _scheduleError != null ||
        _offerError != null ||
        LocationCatalogScope.of(context).findByName(_location) == null) {
      return;
    }
    setState(() => _busy = true);
    FocusScope.of(context).unfocus();
    final original = widget.initialPost;
    final createdAt = original?.createdAt ?? DateTime.now().toUtc();
    var id = 'local-${createdAt.microsecondsSinceEpoch}-${_sequence++}';
    while (widget.repository.posts.any((post) => post.id == id)) {
      id = 'local-${createdAt.microsecondsSinceEpoch}-${_sequence++}';
    }
    final post = Post(
      id: original?.id ?? id,
      status: original?.status ?? PostStatus.published,
      rawServerStatus: original?.rawServerStatus,
      authorId: original?.authorId ?? widget.user.postsOwnerId,
      applicationCount: original?.applicationCount,
      title:
          _editing || _course!.isOther
              ? _manualTitle.text.trim()
              : _course!.title,
      department: _editing ? original!.department : _department!,
      topic: _topic.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      authorName: original?.authorName ?? widget.user.firstName,
      createdAt: createdAt,
      startsAt: _combine(_start)!,
      endsAt: _combine(_end)!,
      location: LocationCatalogScope.of(context).findByName(_location)!.name,
      type: PostType.tutoring,
      subject: _editing ? original!.subject : _course!.subject,
      offer: _coffee == 0 ? PostOffer.free : PostOffer.coffee,
      coffeeCount: _coffee!,
    );
    try {
      if (_editing) {
        if (!widget.repository.supportsFullPostEditing) {
          throw UnsupportedError('Güncelleme desteklenmiyor.');
        }
        await widget.repository.updatePost(
          post,
          ownerId: widget.user.postsOwnerId,
        );
      } else {
        await widget.repository.addPost(post);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message(
        _editing
            ? 'İlan güncellenemedi. Bilgileriniz korundu; tekrar deneyin.'
            : 'İlan eklenemedi. Bilgileriniz korundu; tekrar deneyin.',
      );
    }
  }

  Widget _section(IconData icon, String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    IconData? icon,
    bool required = true,
    int lines = 1,
    String? hintText,
  }) => Padding(
    key: ValueKey('container-$key'),
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      validator: required ? CreatePostValidators.requiredText : null,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 5,
      textInputAction:
          lines == 1 ? TextInputAction.next : TextInputAction.newline,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
    ),
  );

  Widget _picker(
    String key,
    String label,
    String? value,
    IconData icon,
    VoidCallback action,
  ) => OutlinedButton(
    key: ValueKey(key),
    onPressed: _busy ? null : action,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      backgroundColor: Theme.of(context).colorScheme.onPrimary,
    ),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(value ?? label, softWrap: true)),
      ],
    ),
  );

  Widget _offer(int count) {
    final colors = Theme.of(context).colorScheme;
    final selected = _coffee == count;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('offer-$count'),
        onTap:
            _busy
                ? null
                : () => setState(() {
                  _coffee = count;
                  _offerError = null;
                }),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                selected
                    ? colors.secondary.withValues(alpha: 0.12)
                    : colors.onPrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colors.secondary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                count == 0
                    ? Icons.volunteer_activism_outlined
                    : Icons.coffee_outlined,
                color: colors.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 0 ? 'Ücretsiz' : '$count Kahve',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      const [
                        'Gönüllü destek',
                        'Filtre / Çay',
                        'Önerilen oran',
                        'Kapsamlı etüt',
                      ][count],
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: colors.primary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: selected ? colors.secondary : colors.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialPost?.isExpiredAt(DateTime.now()) == true) {
      return PostDetailsScreen(
        post: widget.initialPost!,
        repository: widget.repository,
        user: widget.user,
      );
    }
    final catalog = LocationCatalogScope.of(context);
    final academic = AcademicCatalogScope.of(context);
    final colors = Theme.of(context).colorScheme;
    // Readability changes are scoped to this form, not the shared app theme.
    final formTheme = Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.copyWith(
        titleMedium: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 15,
          height: 1.35,
          color: colors.primary,
        ),
      ),
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
        labelStyle: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          color: colors.primary.withValues(alpha: 0.9),
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colors.primary,
        ),
        hintStyle: TextStyle(
          fontSize: 14,
          height: 1.35,
          color: colors.primary.withValues(alpha: 0.8),
        ),
        helperStyle: TextStyle(
          fontSize: 13,
          height: 1.3,
          color: colors.primary.withValues(alpha: 0.85),
        ),
        errorStyle: TextStyle(fontSize: 13, color: colors.error),
      ),
    );
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color.alphaBlend(
            colors.secondary.withValues(alpha: 0.06),
            colors.surface,
          ),
          leading: IconButton(
            tooltip: 'Geri',
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Row(
            children: [
              Image.asset(
                'assets/images/studyco_logo.png',
                width: 72,
                height: 32,
                fit: BoxFit.contain,
                semanticLabel: 'StudyCo logosu',
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'StudyCo',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Bilgi',
              onPressed:
                  _busy
                      ? null
                      : () => _message(
                        'İlanlar yalnızca bu oturumda tutulur. Kahve seçenekleri semboliktir.',
                      ),
              icon: const Icon(Icons.info_outline),
            ),
            IconButton(
              tooltip: 'Bildirimler',
              onPressed:
                  _busy
                      ? null
                      : () => _message(
                        'Bildirimler ekranı henüz kullanıma açık değil.',
                      ),
              icon: const Icon(Icons.notifications_outlined),
            ),
          ],
        ),
        bottomNavigationBar:
            _editing
                ? null
                : IgnorePointer(
                  ignoring: _busy,
                  child: HomeBottomNavigation(
                    selectedIndex: 1,
                    onSelected: (index) {
                      if (_busy || index == 1) return;
                      if (index == 0) {
                        if (widget.onHome != null) {
                          widget.onHome!();
                        } else {
                          Navigator.of(context).pop();
                        }
                        return;
                      }
                      if (index == 2) {
                        final navigator = Navigator.of(context);
                        navigator.push<void>(
                          MaterialPageRoute(
                            builder:
                                (_) => SearchScreen(
                                  repository: widget.repository,
                                  user: widget.user,
                                  onHome: () {
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
                        return;
                      }
                      ProfileNavigation.open(
                        context,
                        user: widget.user,
                        repository: widget.repository,
                        sourceIndex: 1,
                        onHome:
                            widget.onHome ?? () => Navigator.of(context).pop(),
                      );
                    },
                  ),
                ),
        body: Theme(
          data: formTheme,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Form(
                key: _form,
                child: AbsorbPointer(
                  absorbing: _busy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '●  AKADEMİK PAYLAŞIM AĞI',
                        style: TextStyle(
                          color: colors.primary.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _editing ? 'İlanı Düzenle' : 'İlan Oluştur',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _editing
                            ? 'İlan bilgilerini güncelle.'
                            : 'Bilgilerini doldur, özel ders ilanını kampüsle paylaş.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: colors.primary.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        key: const ValueKey('create-user-card'),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        decoration: BoxDecoration(
                          color: colors.onPrimary,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.28),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: colors.secondary.withValues(
                                alpha: 0.12,
                              ),
                              child: Icon(
                                Icons.person_outline,
                                color: colors.primary,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.user.firstName,
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'İlan Sahibi',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.25,
                                      fontWeight: FontWeight.w600,
                                      color: colors.primary.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${widget.user.university} • ${widget.user.department}',
                                    style: TextStyle(
                                      color: colors.primary.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 14,
                                      height: 1.25,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _section(
                        Icons.menu_book_outlined,
                        'Ders & İçerik Bilgileri',
                      ),
                      if (_editing)
                        _field(
                          'post-manual-title',
                          'İlan başlığı / ders *',
                          _manualTitle,
                          icon: Icons.school_outlined,
                        ),
                      if (!_editing) ...[
                        KeyedSubtree(
                          key: ObjectKey(academic),
                          child: DropdownButtonFormField<String>(
                            key: const ValueKey('post-department'),
                            value: _department,
                            isExpanded: true,
                            itemHeight: null,
                            menuMaxHeight: 360,
                            decoration: const InputDecoration(
                              labelText: 'İlgili Bölüm *',
                            ),
                            items: academic.departmentNames
                                .map(
                                  (department) => DropdownMenuItem(
                                    value: department,
                                    child: Text(department),
                                  ),
                                )
                                .toList(growable: false),
                            selectedItemBuilder:
                                (context) => academic.departmentNames
                                    .map(
                                      (department) => Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          department,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                            validator:
                                (value) =>
                                    academic.findDepartment(value) == null
                                        ? 'İlgili bölümü seçin.'
                                        : null,
                            onChanged:
                                _busy
                                    ? null
                                    : (value) {
                                      if (_department == value ||
                                          academic.findDepartment(value) ==
                                              null) {
                                        return;
                                      }
                                      setState(() {
                                        _department = value;
                                        _course = null;
                                        _manualTitle.clear();
                                        _courseKey.currentState?.didChange(
                                          null,
                                        );
                                      });
                                    },
                          ),
                        ),
                        const SizedBox(height: 16),
                        KeyedSubtree(
                          key: const ValueKey('post-course'),
                          child: DropdownButtonFormField<DepartmentCourse>(
                            key: _courseKey,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Ders *',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            disabledHint: Text(
                              _department == null
                                  ? 'Önce ilgili bölümü seçin'
                                  : 'Ders listesi henüz hazır değil',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.35,
                                color: colors.primary.withValues(alpha: 0.8),
                              ),
                            ),
                            items: academic
                                .coursesFor(_department, includeOther: true)
                                .map(
                                  (course) => DropdownMenuItem(
                                    value: course,
                                    child: Text(course.title),
                                  ),
                                )
                                .toList(growable: false),
                            validator: (value) {
                              if (_department == null) {
                                return 'Önce ilgili bölümü seçin.';
                              }
                              if (academic
                                  .coursesFor(_department, includeOther: true)
                                  .isEmpty) {
                                return 'Bu bölümün dersleri henüz tanımlanmadı.';
                              }
                              if (value == null ||
                                  !academic
                                      .coursesFor(
                                        _department,
                                        includeOther: true,
                                      )
                                      .contains(value)) {
                                return 'Bu bölüme ait bir ders seçin.';
                              }
                              return null;
                            },
                            onChanged:
                                _busy ||
                                        academic
                                            .coursesFor(
                                              _department,
                                              includeOther: true,
                                            )
                                            .isEmpty
                                    ? null
                                    : (value) => setState(() {
                                      _course = value;
                                      _manualTitle.clear();
                                    }),
                          ),
                        ),
                        if (_department != null &&
                            academic
                                .coursesFor(_department, includeOther: true)
                                .isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Bu bölümün dersleri henüz tanımlanmadı. Ders listesi hazır olduğunda ilan oluşturabilirsiniz.',
                            ),
                          ),
                        if (_course != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Ana Sayfa kategorisi: ${switch (_course!.subject) {
                                PostSubject.coding => 'Yazılım & Kodlama',
                                PostSubject.mathematics => 'Matematik',
                                PostSubject.general => 'Tümü',
                              }}',
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (_course?.isOther == true)
                          _field(
                            'post-manual-title',
                            'Ders adını yazın *',
                            _manualTitle,
                            icon: Icons.school_outlined,
                          ),
                      ],
                      _field(
                        'post-topic',
                        'Konu *',
                        _topic,
                        icon: Icons.sell_outlined,
                        hintText: 'Örn. Bağlı Listeler ve İkili Arama Ağaçları',
                      ),
                      _field(
                        'post-description',
                        'Açıklama (isteğe bağlı)',
                        _description,
                        required: false,
                        lines: 3,
                      ),
                      _section(Icons.calendar_month_outlined, 'Tarih ve Saat'),
                      _picker(
                        'post-date',
                        'Tarih *',
                        _date == null
                            ? null
                            : '${_date!.day}/${_date!.month}/${_date!.year}',
                        Icons.calendar_today_outlined,
                        _pickDate,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _picker(
                              'post-start',
                              'Başlangıç saati *',
                              _start?.format(context),
                              Icons.schedule,
                              () => _pickTime(true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _picker(
                              'post-end',
                              'Bitiş saati *',
                              _end?.format(context),
                              Icons.schedule,
                              () => _pickTime(false),
                            ),
                          ),
                        ],
                      ),
                      if (_scheduleError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _scheduleError!,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      _section(Icons.location_on_outlined, 'Buluşma Konumu'),
                      PostLocationField(
                        key: const ValueKey('location-section'),
                        value: catalog.findByName(_location)?.name,
                        locationOptions: catalog.names,
                        locationsAreTemporary: catalog.isTemporary,
                        enabled: !_busy,
                        onLocationChanged: (value) {
                          if (_busy || catalog.findByName(value) == null) {
                            return;
                          }
                          setState(
                            () => _location = catalog.findByName(value)!.name,
                          );
                        },
                      ),
                      _section(Icons.coffee_outlined, 'Ders Karşılığı'),
                      Text(
                        'Bu özel ders için sembolik karşılığını seç.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: colors.primary.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (var row = 0; row < 2; row++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _offer(row * 2)),
                              const SizedBox(width: 12),
                              Expanded(child: _offer(row * 2 + 1)),
                            ],
                          ),
                        ),
                      if (_offerError != null)
                        Text(
                          _offerError!,
                          style: TextStyle(color: colors.error),
                        ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const ValueKey('publish-post'),
                        onPressed:
                            _busy ||
                                    (_editing &&
                                        !widget
                                            .repository
                                            .supportsFullPostEditing)
                                ? null
                                : _publish,
                        style: FilledButton.styleFrom(
                          backgroundColor: Color.alphaBlend(
                            colors.primary.withValues(alpha: 0.45),
                            colors.secondary,
                          ),
                        ),
                        icon:
                            _busy
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.send_outlined),
                        label: Text(
                          _editing
                              ? (_busy ? 'Kaydediliyor…' : 'Kaydet')
                              : (_busy ? 'Ekleniyor…' : 'İlanı Yayınla'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'İlan yalnızca bu oturumda saklanır; sunucuya kalıcı yayın yapılmaz. Kahve seçenekleri semboliktir.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: colors.primary.withValues(alpha: 0.85),
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
    );
  }
}
