import 'package:sql_speed/sql_speed.dart';

/// Benchmarks for INSERT operations.
class InsertBenchmark {
  /// Single insert benchmark using a shared [db] instance.
  /// Returns average microseconds per insert over [iterations] runs.
  static Future<String> singleInsert(SqlSpeedDatabase db,
      {int iterations = 3}) async {
    // Prepare table
    await db.execute(
      'CREATE TABLE IF NOT EXISTS bench_insert '
      '(id INTEGER PRIMARY KEY, name TEXT, value INTEGER)',
    );
    await db.execute('DELETE FROM bench_insert');

    final times = <double>[];

    for (var iter = 0; iter < iterations; iter++) {
      await db.execute('DELETE FROM bench_insert');

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        await db.insert(
          'INSERT INTO bench_insert (name, value) VALUES (?, ?)',
          ['item_$i', i],
        );
      }
      stopwatch.stop();
      times.add(stopwatch.elapsedMicroseconds / 100);
    }

    // Take median
    times.sort();
    final median = times[times.length ~/ 2].toStringAsFixed(1);
    return 'Single insert (avg of 100, median of $iterations runs): ${median}us';
  }

  /// Batch insert 1000 rows benchmark.
  static Future<String> batchInsert1000(SqlSpeedDatabase db,
      {int iterations = 3}) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS bench_batch1k '
      '(id INTEGER PRIMARY KEY, name TEXT, value INTEGER)',
    );

    final times = <int>[];

    for (var iter = 0; iter < iterations; iter++) {
      await db.execute('DELETE FROM bench_batch1k');

      final stopwatch = Stopwatch()..start();
      await db.batch((batch) {
        for (var i = 0; i < 1000; i++) {
          batch.insert(
            'INSERT INTO bench_batch1k (name, value) VALUES (?, ?)',
            ['item_$i', i],
          );
        }
      });
      stopwatch.stop();
      times.add(stopwatch.elapsedMilliseconds);
    }

    times.sort();
    return 'Batch insert 1,000 rows (median of $iterations runs): ${times[times.length ~/ 2]}ms';
  }
}
