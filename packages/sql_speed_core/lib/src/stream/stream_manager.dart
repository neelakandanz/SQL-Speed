import 'dart:async';

import 'change_debouncer.dart';
import 'table_tracker.dart';

/// Callback to execute a query and return results.
typedef QueryCallback = Future<List<Map<String, Object?>>> Function();

/// Manages all active reactive stream queries.
///
/// When a table changes (via update hook), the stream manager identifies
/// affected streams, debounces rapid changes, re-runs the queries, and
/// emits new results to the stream controllers.
class StreamManager {
  /// Creates a new [StreamManager].
  StreamManager({
    Duration debounceDuration = const Duration(milliseconds: 16),
  })  : _tracker = TableTracker(),
        _debouncer = ChangeDebouncerPool(duration: debounceDuration);

  final TableTracker _tracker;
  final ChangeDebouncerPool _debouncer;
  final Map<int, _ActiveStream> _streams = {};
  int _nextStreamId = 0;

  /// Creates a reactive stream for the given SQL query.
  ///
  /// The stream immediately emits the first query result, then
  /// re-emits whenever the watched tables change.
  ///
  /// [queryFn] executes the query and returns results.
  /// [sql] is the SQL string, used for table dependency detection.
  /// [tables] optionally overrides auto-detected table dependencies.
  Stream<List<Map<String, Object?>>> watch({
    required QueryCallback queryFn,
    required String sql,
    List<String>? tables,
  }) {
    final streamId = _nextStreamId++;
    late StreamController<List<Map<String, Object?>>> controller;

    controller = StreamController<List<Map<String, Object?>>>(
      onListen: () async {
        // Register table dependencies
        _tracker.register(streamId, sql, tables: tables);

        // Emit first result immediately
        try {
          final result = await queryFn();
          if (!controller.isClosed) {
            controller.add(result);
          }
        } catch (e, st) {
          if (!controller.isClosed) {
            controller.addError(e, st);
          }
        }
      },
      onCancel: () {
        _tracker.unregister(streamId);
        _debouncer.cancel(streamId);
        _streams.remove(streamId);
        controller.close();
      },
    );

    _streams[streamId] = _ActiveStream(
      id: streamId,
      controller: controller,
      queryFn: queryFn,
    );

    return controller.stream;
  }

  /// Notifies the stream manager that a table has changed.
  ///
  /// Called by the SQLite update hook. Identifies affected streams
  /// and schedules debounced re-queries.
  void onTableChanged(String tableName) {
    final affectedStreams = _tracker.getStreamsForTable(tableName);

    for (final streamId in affectedStreams) {
      final stream = _streams[streamId];
      if (stream == null || stream.controller.isClosed) continue;

      _debouncer.debounce(streamId, () => _requery(stream));
    }
  }

  /// Re-runs a stream's query and emits the new result.
  Future<void> _requery(_ActiveStream stream) async {
    try {
      final result = await stream.queryFn();
      if (!stream.controller.isClosed) {
        stream.controller.add(result);
      }
    } catch (e, st) {
      if (!stream.controller.isClosed) {
        stream.controller.addError(e, st);
      }
    }
  }

  /// Returns the number of active streams.
  int get activeCount => _streams.length;

  /// Disposes all streams and cleans up resources.
  void dispose() {
    _debouncer.dispose();
    for (final stream in _streams.values) {
      stream.controller.close();
    }
    _streams.clear();
    _tracker.clear();
  }
}

class _ActiveStream {
  const _ActiveStream({
    required this.id,
    required this.controller,
    required this.queryFn,
  });

  final int id;
  final StreamController<List<Map<String, Object?>>> controller;
  final QueryCallback queryFn;
}
