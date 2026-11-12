import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/applications/data/in_memory_applications_repository.dart';
import 'package:studyco_mobile/features/applications/data/request_dto.dart';
import 'package:studyco_mobile/features/applications/domain/applications_repository.dart';
import 'package:studyco_mobile/features/applications/models/application.dart';
import 'package:studyco_mobile/features/applications/screens/applications_screen.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';

final end = DateTime.utc(2035);
final fixture = previewConfirmableApplication(
  now: end.add(const Duration(hours: 1)),
);
final student = sampleHomeUser.postsOwnerId;
final teacher = previewCompletionTeacher.postsOwnerId;

class DelayedConfirmations extends InMemoryApplicationsRepository {
  DelayedConfirmations({
    required super.postsRepository,
    required super.initialApplications,
  });

  final response = Completer<Application>();
  int calls = 0;

  @override
  Future<Application> confirmLesson(String id, {required String userId}) {
    calls++;
    return response.future;
  }
}

void main() {
  late InMemoryPostsRepository posts;
  late DateTime now;

  setUp(() {
    posts = InMemoryPostsRepository();
    now = end;
  });
  tearDown(() => posts.dispose());

  InMemoryApplicationsRepository repository([Application? request]) {
    final source = InMemoryApplicationsRepository(
      postsRepository: posts,
      initialApplications: [request ?? fixture],
      clock: () => now,
    );
    addTearDown(source.dispose);
    return source;
  }

  test(
    'two distinct approvals are atomic, idempotent and preserve ACCEPTED',
    () async {
      final source = repository();
      var changes = 0;
      source.addListener(() => changes++);
      final first = await source.confirmLesson(fixture.id, userId: student);
      expect(first.studentCompletedAt, now);
      expect(first.teacherCompletedAt, isNull);
      expect(
        first.lessonCompletionStatus,
        LessonCompletionStatus.awaitingConfirmation,
      );
      expect(first.isCompletedLesson, isFalse);
      now = end.add(const Duration(hours: 1));
      expect(
        await source.confirmLesson(fixture.id, userId: student),
        same(first),
      );
      expect(changes, 1);
      final second = await source.confirmLesson(fixture.id, userId: teacher);
      expect(second.studentCompletedAt, end);
      expect(second.teacherCompletedAt, now);
      expect(second.status, ApplicationStatus.accepted);
      expect(second.lessonCompletionStatus, LessonCompletionStatus.completed);
      expect(second.isCompletedLesson, isTrue);
      expect(second.settledAt, isNull);
      expect(source.forOwner(teacher).single, same(second));
      expect(source.forApplicant(student).single, same(second));
      expect(
        await source.confirmLesson(fixture.id, userId: teacher),
        same(second),
      );
      expect(changes, 2);
    },
  );

  test(
    'teacher can confirm first; elapsed time never settles the local record',
    () async {
      final source = repository();
      final first = await source.confirmLesson(fixture.id, userId: teacher);
      expect(first.teacherCompletedAt, end);
      expect(first.studentCompletedAt, isNull);
      now = end.add(const Duration(hours: 24));
      await expectLater(
        source.confirmLesson(fixture.id, userId: student),
        throwsA(isA<ApplicationFailure>()),
      );
      expect(
        await source.confirmLesson(fixture.id, userId: teacher),
        same(first),
      );
      await source.refreshIncoming(ownerId: teacher);
      expect(source.forOwner(teacher).single, same(first));
    },
  );

  test(
    'rejects early, outsider, expired, non-accepted, terminal and missing data',
    () async {
      Future<void> denied(
        InMemoryApplicationsRepository source, {
        String? actor,
      }) async {
        final before = source.applications.single;
        await expectLater(
          source.confirmLesson(fixture.id, userId: actor ?? student),
          throwsA(isA<ApplicationFailure>()),
        );
        expect(source.applications.single, same(before));
      }

      final source = repository();
      now = end.subtract(const Duration(microseconds: 1));
      await denied(source);
      now = end;
      await denied(source, actor: 'outsider');
      await denied(
        repository(fixture.copyWith(status: ApplicationStatus.pending)),
      );
      for (final status in [
        LessonCompletionStatus.manualReview,
        LessonCompletionStatus.completed,
      ]) {
        await denied(
          repository(fixture.copyWith(lessonCompletionStatus: status)),
        );
      }
      await denied(
        repository(
          Application(
            id: fixture.id,
            postId: fixture.postId,
            applicantId: student,
            teacherId: teacher,
            listing: fixture.listing,
            status: ApplicationStatus.accepted,
            completionStatus: 'AWAITING_CONFIRMATION',
          ),
        ),
      );
      now = end.add(const Duration(hours: 24));
      await denied(source);
    },
  );

  test('DTO keeps server deadline, roles, timestamps and typed state', () {
    final application = RequestDto.fromJson({
      'id': fixture.id,
      'status': 'ACCEPTED',
      'completionStatus': 'MANUAL_REVIEW',
      'studentCompletedAt': end.toIso8601String(),
      'confirmationDeadlineAt':
          end.add(const Duration(hours: 24)).toIso8601String(),
      'settledAt': null,
      'listing': {'id': fixture.postId, 'endAt': end.toIso8601String()},
      'counterpart': {'id': student},
    }).toDomain(role: RequestRole.teacher, currentUserId: teacher);
    expect(application.applicantId, student);
    expect(application.teacherId, teacher);
    expect(application.status, ApplicationStatus.accepted);
    expect(
      application.lessonCompletionStatus,
      LessonCompletionStatus.manualReview,
    );
    expect(application.studentCompletedAt, end);
    expect(
      application.confirmationDeadlineAt,
      end.add(const Duration(hours: 24)),
    );
    expect(application.isCompletedLesson, isFalse);
  });

  Future<void> open(
    WidgetTester tester,
    InMemoryApplicationsRepository source,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!,
            ),
        home: ApplicationsScreen(
          postsRepository: posts,
          repository: source,
          user: sampleHomeUser,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final item = find.byKey(ValueKey('application-${fixture.id}'));
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'small sheet preserves data on failure and blocks duplicate submits',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 610));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = DelayedConfirmations(
        postsRepository: posts,
        initialApplications: [previewConfirmableApplication()],
      );
      addTearDown(source.dispose);
      await open(tester, source);
      final button = find.byKey(const ValueKey('confirm-lesson'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(source.calls, 0);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(source.calls, 1);
      source.response.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ders onayı kaydedilemedi. Lütfen tekrar dene.'),
        findsOneWidget,
      );
      expect(source.applications.single.studentCompletedAt, isNull);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('manual review shows status without confirmation or review', (
    tester,
  ) async {
    final source = repository(
      fixture.copyWith(
        lessonCompletionStatus: LessonCompletionStatus.manualReview,
      ),
    );
    await open(tester, source);
    expect(find.text('Ders Durumu: İnceleme Bekleniyor'), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-lesson')), findsNothing);
    expect(find.text('Değerlendir'), findsNothing);
  });
}
