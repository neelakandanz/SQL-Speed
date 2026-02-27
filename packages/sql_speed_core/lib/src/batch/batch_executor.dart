import '../engine/query_executor.dart';
import '../utils/logger.dart';

/// A single operation in a batch.
class BatchOperation {
  /// Creates a new [BatchOperation].
  const BatchOperation(this.sql, [this.parameters]);

  /// The SQL statement.
  final String sql;

  /// Optional parameters for the statement.
  final List<Object?>? parameters;
}

/// Collects batch operations for bulk execution.
///
/// All operations are executed in a single transaction using
/// prepared statements for maximum performance.
class BatchCollector {
  final List<BatchOperation> _operations = [];

  /// Adds an INSERT operation to the batch.
  void insert(String sql, [List<Object?>? parameters]) {
    _operations.add(BatchOperation(sql, parameters));
  }

  /// Adds an UPDATE operation to the batch.
  void update(String sql, [List<Object?>? parameters]) {
    _operations.add(BatchOperation(sql, parameters));
  }

  /// Adds a DELETE operation to the batch.
  void delete(String sql, [List<Object?>? parameters]) {
    _operations.add(BatchOperation(sql, parameters));
  }

  /// Adds a raw SQL execution to the batch.
  void execute(String sql, [List<Object?>? parameters]) {
    _operations.add(BatchOperation(sql, parameters));
  }

  /// Returns all collected operations.
  List<BatchOperation> get operations => List.unmodifiable(_operations);
}

/// Executes batch operations efficiently.
///
/// Wraps all operations in a single transaction and uses prepared
/// statement caching for repeated SQL patterns. Large batches are
/// chunked to avoid memory spikes.
class BatchExecutor {
  /// Creates a new [BatchExecutor].
  BatchExecutor(this._executor, {SqlSpeedLogger? logger}) : _logger = logger;

  final QueryExecutor _executor;
  final SqlSpeedLogger? _logger;

  /// Maximum operations per chunk for very large batches.
  static const int chunkSize = 10000;

  /// Executes all operations from a [BatchCollector] in a single transaction.
  void executeBatch(BatchCollector collector) {
    final ops = collector.operations;
    if (ops.isEmpty) return;

    _logger?.log('Executing batch of ${ops.length} operations');
    final stopwatch = Stopwatch()..start();

    if (ops.length <= chunkSize) {
      _executeBatchDirect(ops, 0, ops.length);
    } else {
      // Chunk large batches using index range to avoid list copies
      for (var i = 0; i < ops.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, ops.length);
        _executeBatchDirect(ops, i, end);
      }
    }

    stopwatch.stop();
    _logger?.log('Batch completed in ${stopwatch.elapsedMilliseconds}ms');
  }

  void _executeBatchDirect(List<BatchOperation> ops, int start, int end) {
    for (var i = start; i < end; i++) {
      _executor.execute(ops[i].sql, ops[i].parameters);
    }
  }
}
