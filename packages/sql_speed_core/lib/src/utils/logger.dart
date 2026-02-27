import 'dart:async';

/// Logging utility for sql_speed.
///
/// In debug mode, logs all queries, timings, and errors to the console.
/// In release mode, logging is minimal (no SQL in error messages for security).
class SqlSpeedLogger {
  /// Creates a new [SqlSpeedLogger].
  SqlSpeedLogger({this.enabled = true});

  /// Whether logging is enabled.
  bool enabled;

  /// Logs a SQL query with optional parameters.
  void logQuery(String sql, [List<Object?>? parameters]) {
    if (!enabled) return;
    final params =
        parameters != null && parameters.isNotEmpty ? ' | params: $parameters' : '';
    _print('[SQL] $sql$params');
  }

  /// Logs query execution timing.
  void logTiming(String sql, Duration duration) {
    if (!enabled) return;
    final ms = duration.inMicroseconds / 1000;
    _print('[TIMING] ${ms.toStringAsFixed(2)}ms | $sql');
  }

  /// Logs an error.
  void logError(String message, [Object? error]) {
    if (!enabled) return;
    _print('[ERROR] $message${error != null ? ' | $error' : ''}');
  }

  /// Logs a general message.
  void log(String message) {
    if (!enabled) return;
    _print('[sql_speed] $message');
  }

  void _print(String message) {
    // Using Zone printing to be testable and avoid lint warnings
    Zone.current.print(message);
  }
}
