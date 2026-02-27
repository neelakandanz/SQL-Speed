import 'package:sql_speed/sql_speed.dart';

/// Benchmarks for INSERT operations.
class InsertBenchmark {
  static Future<String> singleInsert() async {
    final db = await SqlSpeed.open(
      path: ':memory:',
      version: 1,
      onCreate: (db, v) async {
        await db.execute(
          'CREATE TABLE bench (id INTEGER PRIMARY KEY, name TEXT, value INTEGER)',
        );
      },
    );

    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      await db.insert(
        'INSERT INTO bench (name, value) VALUES (?, ?)',
        ['item_$i', i],
      );
    }
    stopwatch.stop();

    await db.close();
    final avg = (stopwatch.elapsedMicroseconds / 100).toStringAsFixed(1);
    return 'Single insert (avg of 100): ${avg}us';
  }

  static Future<String> batchInsert1000() async {
    final db = await SqlSpeed.open(
      path: ':memory:',
      version: 1,
      onCreate: (db, v) async {
        await db.execute(
          'CREATE TABLE bench (id INTEGER PRIMARY KEY, name TEXT, value INTEGER)',
        );
      },
    );

    final stopwatch = Stopwatch()..start();
    await db.batch((batch) {
      for (var i = 0; i < 1000; i++) {
        batch.insert(
          'INSERT INTO bench (name, value) VALUES (?, ?)',
          ['item_$i', i],
        );
      }
    });
    stopwatch.stop();

    await db.close();
    return 'Batch insert 1,000 rows: ${stopwatch.elapsedMilliseconds}ms';
  }
}
