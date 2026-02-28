import 'package:sql_speed/sql_speed.dart';

/// Benchmarks for SELECT/read operations.
class ReadBenchmark {
  /// Single read by PK benchmark using a shared [db] instance.
  static Future<String> singleRead(SqlSpeedDatabase db,
      {int iterations = 3}) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS bench_read '
      '(id INTEGER PRIMARY KEY, name TEXT, value INTEGER)',
    );
    await db.execute('DELETE FROM bench_read');

    // Seed data
    await db.batch((batch) {
      for (var i = 0; i < 100; i++) {
        batch.insert(
          'INSERT INTO bench_read (name, value) VALUES (?, ?)',
          ['item_$i', i],
        );
      }
    });

    final times = <double>[];

    for (var iter = 0; iter < iterations; iter++) {
      final stopwatch = Stopwatch()..start();
      for (var i = 1; i <= 100; i++) {
        await db.query('SELECT * FROM bench_read WHERE id = ?', [i]);
      }
      stopwatch.stop();
      times.add(stopwatch.elapsedMicroseconds / 100);
    }

    times.sort();
    final median = times[times.length ~/ 2].toStringAsFixed(1);
    return 'Single read by PK (avg of 100, median of $iterations runs): ${median}us';
  }

  /// Bulk read 1000 rows benchmark.
  static Future<String> bulkRead1000(SqlSpeedDatabase db,
      {int iterations = 3}) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS bench_bulk_read '
      '(id INTEGER PRIMARY KEY, name TEXT, value INTEGER)',
    );
    await db.execute('DELETE FROM bench_bulk_read');

    // Seed data
    await db.batch((batch) {
      for (var i = 0; i < 1000; i++) {
        batch.insert(
          'INSERT INTO bench_bulk_read (name, value) VALUES (?, ?)',
          ['item_$i', i],
        );
      }
    });

    final times = <int>[];

    for (var iter = 0; iter < iterations; iter++) {
      final stopwatch = Stopwatch()..start();
      await db.query('SELECT * FROM bench_bulk_read');
      stopwatch.stop();
      times.add(stopwatch.elapsedMilliseconds);
    }

    times.sort();
    return 'Bulk read 1,000 rows (median of $iterations runs): ${times[times.length ~/ 2]}ms';
  }
}
