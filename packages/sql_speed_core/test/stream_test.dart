import 'dart:async';

import 'package:test/test.dart';

import 'package:sql_speed_core/src/stream/stream_manager.dart';
import 'package:sql_speed_core/src/stream/table_tracker.dart';
import 'package:sql_speed_core/src/stream/change_debouncer.dart';

void main() {
  group('TableTracker', () {
    late TableTracker tracker;

    setUp(() {
      tracker = TableTracker();
    });

    test('registers stream table dependencies', () {
      tracker.register(1, 'SELECT * FROM users');
      expect(tracker.getTablesForStream(1), contains('users'));
    });

    test('maps table to streams', () {
      tracker.register(1, 'SELECT * FROM users');
      tracker.register(2, 'SELECT * FROM users WHERE active = 1');
      expect(tracker.getStreamsForTable('users'), containsAll([1, 2]));
    });

    test('unregisters stream', () {
      tracker.register(1, 'SELECT * FROM users');
      tracker.unregister(1);
      expect(tracker.getStreamsForTable('users'), isEmpty);
      expect(tracker.activeStreamCount, equals(0));
    });

    test('uses manual tables when provided', () {
      tracker.register(1, 'complex sql', tables: ['users', 'posts']);
      expect(tracker.getTablesForStream(1), containsAll(['users', 'posts']));
    });

    test('isTableWatched returns correct values', () {
      tracker.register(1, 'SELECT * FROM users');
      expect(tracker.isTableWatched('users'), isTrue);
      expect(tracker.isTableWatched('posts'), isFalse);
    });

    test('handles JOINs correctly', () {
      tracker.register(
        1,
        'SELECT * FROM users JOIN posts ON users.id = posts.user_id',
      );
      expect(tracker.getTablesForStream(1), containsAll(['users', 'posts']));
      expect(tracker.getStreamsForTable('users'), contains(1));
      expect(tracker.getStreamsForTable('posts'), contains(1));
    });
  });

  group('ChangeDebouncerPool', () {
    late ChangeDebouncerPool debouncer;

    setUp(() {
      debouncer = ChangeDebouncerPool(
        duration: const Duration(milliseconds: 50),
      );
    });

    tearDown(() {
      debouncer.dispose();
    });

    test('debounces rapid calls', () async {
      var callCount = 0;
      debouncer.debounce(1, () => callCount++);
      debouncer.debounce(1, () => callCount++);
      debouncer.debounce(1, () => callCount++);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(callCount, equals(1)); // Only last one fires
    });

    test('fires callback after delay', () async {
      var called = false;
      debouncer.debounce(1, () => called = true);

      expect(called, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(called, isTrue);
    });

    test('cancel prevents callback', () async {
      var called = false;
      debouncer.debounce(1, () => called = true);
      debouncer.cancel(1);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(called, isFalse);
    });

    test('different stream IDs debounce independently', () async {
      var count1 = 0;
      var count2 = 0;
      debouncer.debounce(1, () => count1++);
      debouncer.debounce(2, () => count2++);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(count1, equals(1));
      expect(count2, equals(1));
    });
  });

  group('StreamManager', () {
    late StreamManager manager;

    setUp(() {
      manager = StreamManager(
        debounceDuration: const Duration(milliseconds: 20),
      );
    });

    tearDown(() {
      manager.dispose();
    });

    test('emits initial query result', () async {
      final stream = manager.watch(
        queryFn: () async => [
          {'id': 1, 'name': 'Alice'}
        ],
        sql: 'SELECT * FROM users',
      );

      final result = await stream.first;
      expect(result, hasLength(1));
      expect(result.first['name'], equals('Alice'));
    });

    test('re-emits when table changes', () async {
      var queryCount = 0;
      final stream = manager.watch(
        queryFn: () async {
          queryCount++;
          return [
            {'count': queryCount}
          ];
        },
        sql: 'SELECT * FROM users',
      );

      final results = <List<Map<String, Object?>>>[];
      final sub = stream.listen(results.add);

      // Wait for initial emission
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(results, hasLength(1));

      // Trigger table change
      manager.onTableChanged('users');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(results, hasLength(2));

      await sub.cancel();
    });

    test('tracks active stream count', () async {
      final stream1 = manager.watch(
        queryFn: () async => [],
        sql: 'SELECT * FROM users',
      );
      final stream2 = manager.watch(
        queryFn: () async => [],
        sql: 'SELECT * FROM posts',
      );

      final sub1 = stream1.listen((_) {});
      final sub2 = stream2.listen((_) {});

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(manager.activeCount, equals(2));

      await sub1.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(manager.activeCount, equals(1));

      await sub2.cancel();
    });
  });
}
