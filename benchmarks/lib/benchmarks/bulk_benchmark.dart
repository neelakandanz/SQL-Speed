import 'package:sql_speed/sql_speed.dart';

/// Benchmarks for bulk/batch operations.
class BulkBenchmark {
  static Future<String> insert10000() async {
    final db = await SqlSpeed.open(
      path: ':memory:',
      version: 1,
      onCreate: (db, v) async {
        await db.execute(
          'CREATE TABLE bench (id INTEGER PRIMARY KEY, name TEXT, value INTEGER, extra TEXT)',
        );
      },
    );

    final stopwatch = Stopwatch()..start();
    await db.batch((batch) {
      for (var i = 0; i < 10000; i++) {
        batch.insert(
          'INSERT INTO bench (name, value, extra) VALUES (?, ?, ?)',
          ['item_$i', i, 'extra data for item $i'],
        );
      }
    });
    stopwatch.stop();

    // Verify
    final count = await db.query('SELECT COUNT(*) as c FROM bench');
    final rowCount = count.first['c'] as int;

    await db.close();
    return 'Batch insert 10,000 rows: ${stopwatch.elapsedMilliseconds}ms (verified: $rowCount rows)';
  }
}
