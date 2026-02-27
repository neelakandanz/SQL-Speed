import '../utils/sql_parser.dart';

/// Tracks which tables each active stream query depends on.
///
/// When a table changes, the tracker can identify all streams that
/// need to be re-executed.
class TableTracker {
  /// Map of stream ID → set of table names the stream depends on.
  final Map<int, Set<String>> _streamTables = {};

  /// Map of table name → set of stream IDs watching that table.
  final Map<String, Set<int>> _tableStreams = {};

  /// Registers a stream's table dependencies.
  ///
  /// If [tables] is provided, those are used directly.
  /// Otherwise, tables are auto-detected by parsing [sql].
  void register(int streamId, String sql, {List<String>? tables}) {
    final tableDeps =
        tables?.map((t) => t.toLowerCase()).toSet() ?? SqlParser.extractTables(sql);

    _streamTables[streamId] = tableDeps;

    for (final table in tableDeps) {
      _tableStreams.putIfAbsent(table, () => {}).add(streamId);
    }
  }

  /// Unregisters a stream and removes its table dependencies.
  void unregister(int streamId) {
    final tables = _streamTables.remove(streamId);
    if (tables == null) return;

    for (final table in tables) {
      _tableStreams[table]?.remove(streamId);
      if (_tableStreams[table]?.isEmpty ?? false) {
        _tableStreams.remove(table);
      }
    }
  }

  /// Returns the set of stream IDs that depend on the given [table].
  Set<int> getStreamsForTable(String table) {
    return _tableStreams[table.toLowerCase()] ?? {};
  }

  /// Returns the set of tables that the given [streamId] depends on.
  Set<String> getTablesForStream(int streamId) {
    return _streamTables[streamId] ?? {};
  }

  /// Returns true if any active stream depends on the given [table].
  bool isTableWatched(String table) {
    return _tableStreams.containsKey(table.toLowerCase()) &&
        _tableStreams[table.toLowerCase()]!.isNotEmpty;
  }

  /// Returns the number of active streams.
  int get activeStreamCount => _streamTables.length;

  /// Clears all tracked streams and tables.
  void clear() {
    _streamTables.clear();
    _tableStreams.clear();
  }
}
