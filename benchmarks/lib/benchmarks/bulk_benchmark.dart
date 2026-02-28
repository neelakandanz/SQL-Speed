import 'package:sql_speed/sql_speed.dart';

/// Benchmarks for bulk/batch operations.
class BulkBenchmark {
  /// Batch insert 10,000 rows benchmark.
  static Future<String> insert10000(SqlSpeedDatabase db,
      {int iterations = 3}) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS bench_bulk '
      '(id INTEGER PRIMARY KEY, name TEXT, value INTEGER, extra TEXT)',
    );

    final times = <int>[];

    for (var iter = 0; iter < iterations; iter++) {
      await db.execute('DELETE FROM bench_bulk');

      final stopwatch = Stopwatch()..start();
      await db.batch((batch) {
        for (var i = 0; i < 10000; i++) {
          batch.insert(
            'INSERT INTO bench_bulk (name, value, extra) VALUES (?, ?, ?)',
            ['item_$i', i, 'extra data for item $i'],
          );
        }
      });
      stopwatch.stop();
      times.add(stopwatch.elapsedMilliseconds);
    }

    // Verify
    final count = await db.query('SELECT COUNT(*) as c FROM bench_bulk');
    final rowCount = count.first['c'] as int;

    times.sort();
    return 'Batch insert 10,000 rows (median of $iterations runs): '
        '${times[times.length ~/ 2]}ms (verified: $rowCount rows)';
  }
}
