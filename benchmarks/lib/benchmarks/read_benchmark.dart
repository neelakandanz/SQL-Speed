import 'package:sql_speed/sql_speed.dart';

/// Benchmarks for SELECT/read operations.
class ReadBenchmark {
  static Future<String> singleRead() async {
    final db = await SqlSpeed.open(
      path: ':memory:',
      version: 1,
      onCreate: (db, v) async {
        await db.execute(
          'CREATE TABLE bench (id INTEGER PRIMARY KEY, name TEXT, value INTEGER)',
        );
        // Seed data
        for (var i = 0; i < 100; i++) {
          await db.insert(
            'INSERT INTO bench (name, value) VALUES (?, ?)',
            ['item_$i', i],
          );
        }
      },
    );

    final stopwatch = Stopwatch()..start();
    for (var i = 1; i <= 100; i++) {
      await db.query('SELECT * FROM bench WHERE id = ?', [i]);
    }
    stopwatch.stop();

    await db.close();
    final avg = (stopwatch.elapsedMicroseconds / 100).toStringAsFixed(1);
    return 'Single read by PK (avg of 100): ${avg}us';
  }

  static Future<String> bulkRead1000() async {
    final db = await SqlSpeed.open(
      path: ':memory:',
      version: 1,
      onCreate: (db, v) async {
        await db.execute(
          'CREATE TABLE bench (id INTEGER PRIMARY KEY, name TEXT, value INTEGER)',
        );
        for (var i = 0; i < 1000; i++) {
          await db.insert(
            'INSERT INTO bench (name, value) VALUES (?, ?)',
            ['item_$i', i],
          );
        }
      },
    );

    final stopwatch = Stopwatch()..start();
    await db.query('SELECT * FROM bench');
    stopwatch.stop();

    await db.close();
    return 'Bulk read 1,000 rows: ${stopwatch.elapsedMilliseconds}ms';
  }
}
