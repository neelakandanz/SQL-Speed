import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'package:sql_speed_core/src/engine/statement_cache.dart';

void main() {
  late Database db;
  late StatementCache cache;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT)');
    cache = StatementCache(db, maxSize: 3);
  });

  tearDown(() {
    cache.dispose();
    db.dispose();
  });

  group('StatementCache', () {
    test('caches and reuses prepared statements', () {
      const sql = 'SELECT * FROM test_table';
      final stmt1 = cache.get(sql);
      final stmt2 = cache.get(sql);
      expect(identical(stmt1, stmt2), isTrue);
      expect(cache.hits, equals(1));
      expect(cache.misses, equals(1));
    });

    test('compiles new statement on cache miss', () {
      const sql1 = 'SELECT * FROM test_table';
      const sql2 = 'SELECT id FROM test_table';
      cache.get(sql1);
      cache.get(sql2);
      expect(cache.size, equals(2));
      expect(cache.misses, equals(2));
    });

    test('evicts LRU when cache is full', () {
      cache.get('SELECT 1');
      cache.get('SELECT 2');
      cache.get('SELECT 3');
      expect(cache.size, equals(3));

      // This should evict 'SELECT 1'
      cache.get('SELECT 4');
      expect(cache.size, equals(3));
    });

    test('hit ratio is calculated correctly', () {
      cache.get('SELECT 1');
      cache.get('SELECT 1');
      cache.get('SELECT 1');
      // 1 miss + 2 hits = 2/3 ratio
      expect(cache.hitRatio, closeTo(0.666, 0.01));
    });

    test('clear removes all cached statements', () {
      cache.get('SELECT 1');
      cache.get('SELECT 2');
      cache.clear();
      expect(cache.size, equals(0));
    });

    test('remove removes specific statement', () {
      cache.get('SELECT 1');
      cache.get('SELECT 2');
      cache.remove('SELECT 1');
      expect(cache.size, equals(1));
    });
  });
}
