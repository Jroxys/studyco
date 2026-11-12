import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/posts/models/post.dart';
import 'package:studyco_mobile/features/posts/screens/create_post_screen.dart';
import 'package:studyco_mobile/features/posts/screens/post_details_screen.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';
import 'package:studyco_mobile/features/profile/screens/my_posts_screen.dart';
import 'package:studyco_mobile/features/profile/screens/profile_screen.dart';

const user = UserProfile(
  id: 'me',
  firstName: 'Ada',
  department: 'Test',
  campus: 'Test',
);
Post post(String id, {String? owner = 'me', bool past = false, String? title}) {
  final day = DateTime.now().add(Duration(days: past ? -2 : 2));
  final date = DateTime(day.year, day.month, day.day, 14);
  return Post(
    id: id,
    authorId: owner,
    title: title ?? id,
    topic: 'Konu',
    authorName: 'Ada',
    createdAt: date,
    startsAt: date,
    endsAt: date.add(const Duration(hours: 1)),
    location: 'Study',
    type: PostType.tutoring,
    subject: PostSubject.general,
    offer: PostOffer.free,
  );
}

class FailingRepository extends InMemoryPostsRepository {
  FailingRepository(List<Post> posts) : super(initialPosts: posts);
  @override
  Future<void> deletePost(String id, {required String ownerId}) async =>
      throw StateError('failed');
}

class PendingDeleteRepository extends InMemoryPostsRepository {
  PendingDeleteRepository(List<Post> posts) : super(initialPosts: posts);
  final pending = Completer<void>();
  @override
  Future<void> deletePost(String id, {required String ownerId}) async {
    await pending.future;
    await super.deletePost(id, ownerId: ownerId);
  }
}

class FailedUpdateRepository extends InMemoryPostsRepository {
  FailedUpdateRepository(List<Post> posts) : super(initialPosts: posts);
  @override
  Future<void> updatePost(Post post, {required String ownerId}) async =>
      throw StateError('failed');
}

class ExpiringRepository extends InMemoryPostsRepository {
  ExpiringRepository() : super(initialPosts: [post('mine')]);
  bool expired = false;
  @override
  List<Post> get posts => expired ? [post('mine', past: true)] : super.posts;
  void expire() {
    expired = true;
    notifyListeners();
  }
}

Future<void> mount(WidgetTester tester, InMemoryPostsRepository repo) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MyPostsScreen(repository: repo, user: user),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'repository checks ownership and notifies only for successful mutations',
    () async {
      final repo = InMemoryPostsRepository(initialPosts: [post('one')]);
      var changes = 0;
      repo.addListener(() => changes++);
      await expectLater(
        repo.deletePost('one', ownerId: 'other'),
        throwsStateError,
      );
      expect(repo.posts, hasLength(1));
      expect(changes, 0);
      await repo.updatePost(post('one', title: 'Updated'), ownerId: 'me');
      expect(repo.posts.single.title, 'Updated');
      expect(changes, 1);
      await repo.deletePost('one', ownerId: 'me');
      expect(repo.posts, isEmpty);
      expect(changes, 2);
      await expectLater(
        repo.updatePost(post('one'), ownerId: 'me'),
        throwsStateError,
      );
    },
  );
  testWidgets(
    'own active and past posts are separated; names do not grant ownership',
    (tester) async {
      await mount(
        tester,
        InMemoryPostsRepository(
          initialPosts: [
            post('mine'),
            post('past', past: true),
            post('other', owner: 'other'),
            post('legacy', owner: null),
          ],
        ),
      );
      expect(find.text('mine'), findsOneWidget);
      expect(find.text('other'), findsNothing);
      expect(find.text('legacy'), findsNothing);
      await tester.tap(find.text('Geçmiş İlanlar'));
      await tester.pumpAndSettle();
      expect(find.text('past'), findsOneWidget);
    },
  );
  testWidgets('cancel preserves post; confirm deletes after success', (
    tester,
  ) async {
    final repo = InMemoryPostsRepository(initialPosts: [post('mine')]);
    await mount(tester, repo);
    await tester.tap(find.text('İlanı Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(repo.posts, hasLength(1));
    await tester.tap(find.text('İlanı Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'İlanı Sil'));
    await tester.pumpAndSettle();
    expect(repo.posts, isEmpty);
    expect(find.text('Henüz aktif ilanın yok.'), findsOneWidget);
  });
  testWidgets('failed delete preserves post and reports Turkish error', (
    tester,
  ) async {
    final repo = FailingRepository([post('mine')]);
    await mount(tester, repo);
    await tester.tap(find.text('İlanı Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'İlanı Sil'));
    await tester.pumpAndSettle();
    expect(repo.posts, hasLength(1));
    expect(
      find.text('İlan silinemedi. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
  });
  testWidgets('edit prefills existing form and saves shared repository', (
    tester,
  ) async {
    final repo = InMemoryPostsRepository(initialPosts: [post('mine')]);
    await mount(tester, repo);
    await tester.tap(find.text('İlanı Düzenle'));
    await tester.pumpAndSettle();
    expect(find.byType(CreatePostScreen), findsOneWidget);
    expect(find.text('mine'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('post-manual-title')),
      'Yeni başlık',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('publish-post')));
    await tester.tap(find.byKey(const ValueKey('publish-post')));
    await tester.pumpAndSettle();
    expect(repo.posts.single.title, 'Yeni başlık');
    expect(repo.posts.single.id, 'mine');
    await tester.tap(find.text('Yeni başlık'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('apply-post')), findsNothing);
  });
  testWidgets('profile opens My Posts with the shared repository', (
    tester,
  ) async {
    final repo = InMemoryPostsRepository(initialPosts: [post('mine')]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProfileScreen(
          user: user,
          repository: repo,
          onDestination: (_) {},
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('profile-posts')));
    await tester.tap(find.byKey(const ValueKey('profile-posts')));
    await tester.pumpAndSettle();
    expect(find.byType(MyPostsScreen), findsOneWidget);
    expect(find.text('mine'), findsOneWidget);
  });
  testWidgets('pending deletion keeps listing visible until success', (
    tester,
  ) async {
    final repo = PendingDeleteRepository([post('mine')]);
    await mount(tester, repo);
    await tester.tap(find.text('İlanı Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'İlanı Sil'));
    await tester.pumpAndSettle();
    expect(repo.posts, hasLength(1));
    expect(find.text('mine'), findsOneWidget);
    expect(find.text('Siliniyor…'), findsOneWidget);
    repo.pending.complete();
    await tester.pumpAndSettle();
    expect(repo.posts, isEmpty);
  });
  testWidgets('failed update retains form input and original listing', (
    tester,
  ) async {
    final repo = FailedUpdateRepository([post('mine')]);
    await mount(tester, repo);
    await tester.tap(find.text('İlanı Düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('post-manual-title')),
      'Taslak',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('publish-post')));
    await tester.tap(find.byKey(const ValueKey('publish-post')));
    await tester.pumpAndSettle();
    expect(repo.posts.single.title, 'mine');
    expect(find.byType(CreatePostScreen), findsOneWidget);
    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('post-manual-title')),
    );
    expect(field.controller!.text, 'Taslak');
    expect(
      find.text('İlan güncellenemedi. Bilgileriniz korundu; tekrar deneyin.'),
      findsOneWidget,
    );
  });
  test(
    'expiry includes the exact end instant and does not imply completion',
    () {
      final item = post('past', past: true);
      expect(
        item.isExpiredAt(item.endsAt.subtract(const Duration(microseconds: 1))),
        isFalse,
      );
      expect(item.isExpiredAt(item.endsAt), isTrue);
      expect(
        item.isExpiredAt(item.endsAt.add(const Duration(seconds: 1))),
        isTrue,
      );
    },
  );
  test(
    'repository rejects past deletion and moving a past listing into the future',
    () async {
      final original = post('past', past: true);
      final repo = InMemoryPostsRepository(initialPosts: [original]);
      var notifications = 0;
      repo.addListener(() => notifications++);
      await expectLater(
        repo.deletePost('past', ownerId: 'me'),
        throwsStateError,
      );
      await expectLater(
        repo.updatePost(post('past'), ownerId: 'me'),
        throwsStateError,
      );
      expect(repo.posts.single, same(original));
      expect(notifications, 0);
    },
  );
  testWidgets(
    'past cards show expiry and details without any management actions',
    (tester) async {
      await mount(
        tester,
        InMemoryPostsRepository(initialPosts: [post('old', past: true)]),
      );
      await tester.tap(find.text('Geçmiş İlanlar'));
      await tester.pumpAndSettle();
      expect(find.text('Süresi Doldu'), findsOneWidget);
      expect(find.text('Tamamlandı'), findsNothing);
      expect(find.text('İlanı Düzenle'), findsNothing);
      expect(find.text('İlanı Sil'), findsNothing);
      await tester.tap(find.text('old'));
      await tester.pumpAndSettle();
      expect(find.byType(PostDetailsScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('apply-post')), findsNothing);
      expect(find.text('İlanı Düzenle'), findsNothing);
      expect(find.text('İlanı Sil'), findsNothing);
    },
  );
  testWidgets('past details opened outside My Posts cannot apply either', (
    tester,
  ) async {
    final item = post('old', past: true, owner: 'other');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PostDetailsScreen(
          post: item,
          repository: InMemoryPostsRepository(initialPosts: [item]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('apply-post')), findsNothing);
  });
  testWidgets(
    'opening a past listing directly in the edit route is read only',
    (tester) async {
      final item = post('old', past: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CreatePostScreen(
            initialPost: item,
            user: user,
            repository: InMemoryPostsRepository(initialPosts: [item]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PostDetailsScreen), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byKey(const ValueKey('publish-post')), findsNothing);
    },
  );
  testWidgets('expiry while delete confirmation is open cancels the mutation', (
    tester,
  ) async {
    final repo = ExpiringRepository();
    await mount(tester, repo);
    await tester.tap(find.text('İlanı Sil'));
    await tester.pumpAndSettle();
    repo.expire();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'İlanı Sil'));
    await tester.pumpAndSettle();
    expect(repo.posts, hasLength(1));
    expect(find.text('İlan silindi.'), findsNothing);
    expect(
      find.text(
        'İlan artık yönetilemiyor. Geçmiş ilanlar yalnızca görüntülenebilir.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('expiry while the edit form is open blocks save', (tester) async {
    final repo = ExpiringRepository();
    await mount(tester, repo);
    await tester.tap(find.text('İlanı Düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('post-manual-title')),
      'Changed',
    );
    repo.expire();
    await tester.ensureVisible(find.byKey(const ValueKey('publish-post')));
    await tester.tap(find.byKey(const ValueKey('publish-post')));
    await tester.pumpAndSettle();
    expect(repo.posts.single.title, 'mine');
    expect(
      find.text('Geçmiş veya kaldırılmış ilanlar düzenlenemez.'),
      findsOneWidget,
    );
  });
  testWidgets('narrow screen and large text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
        home: MyPostsScreen(
          repository: InMemoryPostsRepository(
            initialPosts: [
              post('long', title: 'Uzun bir ders başlığı ve ders konusu'),
            ],
          ),
          user: user,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
