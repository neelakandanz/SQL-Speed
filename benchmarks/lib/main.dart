import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sql_speed/sql_speed.dart';

import 'benchmarks/insert_benchmark.dart';
import 'benchmarks/read_benchmark.dart';
import 'benchmarks/bulk_benchmark.dart';

void main() {
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sql_speed Benchmarks',
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      home: const BenchmarkScreen(),
    );
  }
}

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  final _results = <String>[];
  bool _running = false;
  bool _useSyncMode = true;

  Future<void> _runBenchmarks() async {
    setState(() {
      _running = true;
      _results.clear();
    });

    // --- Warm-up phase ---
    _addResult('Warming up...');
    await _warmUp();
    // Let GC settle
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _results.clear();
    _addResult(
        'Mode: ${_useSyncMode ? "SYNC (direct FFI)" : "ISOLATE (background)"}');
    _addResult('');

    // Open benchmark database
    final db = await SqlSpeed.open(
      path: ':memory:',
      version: 1,
      useSynchronousMode: _useSyncMode,
    );

    try {
      // Insert benchmarks
      _addResult('--- INSERT BENCHMARKS ---');
      _addResult(await InsertBenchmark.singleInsert(db));
      await _gcPause();
      _addResult(await InsertBenchmark.batchInsert1000(db));
      await _gcPause();

      // Read benchmarks
      _addResult('--- READ BENCHMARKS ---');
      _addResult(await ReadBenchmark.singleRead(db));
      await _gcPause();
      _addResult(await ReadBenchmark.bulkRead1000(db));
      await _gcPause();

      // Bulk benchmarks
      _addResult('--- BULK BENCHMARKS ---');
      _addResult(await BulkBenchmark.insert10000(db));
    } finally {
      await db.close();
    }

    setState(() => _running = false);
  }

  /// Warm-up: runs a throwaway benchmark to prime JIT/ART compiler
  Future<void> _warmUp() async {
    final db = await SqlSpeed.open(
      path: ':memory:',
      version: 1,
      useSynchronousMode: _useSyncMode,
      onCreate: (db, v) async {
        await db.execute(
          'CREATE TABLE warmup (id INTEGER PRIMARY KEY, name TEXT, value INTEGER)',
        );
      },
    );

    for (var i = 0; i < 50; i++) {
      await db.insert(
        'INSERT INTO warmup (name, value) VALUES (?, ?)',
        ['warm_$i', i],
      );
    }
    await db.query('SELECT * FROM warmup');
    await db.close();
  }

  /// Brief pause to let GC settle between benchmarks
  Future<void> _gcPause() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  void _addResult(String result) {
    setState(() => _results.add(result));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('sql_speed Benchmarks')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: _running ? null : _runBenchmarks,
                  child: Text(_running ? 'Running...' : 'Run Benchmarks'),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: Text(_useSyncMode ? 'SYNC' : 'ISOLATE'),
                  selected: _useSyncMode,
                  onSelected: _running
                      ? null
                      : (val) => setState(() => _useSyncMode = val),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _results[index],
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
