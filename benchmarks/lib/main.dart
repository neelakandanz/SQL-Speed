import 'package:flutter/material.dart';

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

  Future<void> _runBenchmarks() async {
    setState(() {
      _running = true;
      _results.clear();
    });

    // Insert benchmarks
    _addResult('--- INSERT BENCHMARKS ---');
    _addResult(await InsertBenchmark.singleInsert());
    _addResult(await InsertBenchmark.batchInsert1000());

    // Read benchmarks
    _addResult('--- READ BENCHMARKS ---');
    _addResult(await ReadBenchmark.singleRead());
    _addResult(await ReadBenchmark.bulkRead1000());

    // Bulk benchmarks
    _addResult('--- BULK BENCHMARKS ---');
    _addResult(await BulkBenchmark.insert10000());

    setState(() => _running = false);
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
            child: FilledButton(
              onPressed: _running ? null : _runBenchmarks,
              child: Text(_running ? 'Running...' : 'Run Benchmarks'),
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
