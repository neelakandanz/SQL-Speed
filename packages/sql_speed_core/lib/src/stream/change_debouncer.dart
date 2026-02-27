import 'dart:async';

/// Debounces rapid table change notifications.
///
/// When bulk inserts trigger many change events, the debouncer
/// ensures stream queries are only re-executed once per frame
/// (default: 16ms at 60fps).
class ChangeDebouncerPool {
  /// Creates a new [ChangeDebouncerPool] with the given debounce [duration].
  ChangeDebouncerPool({
    this.duration = const Duration(milliseconds: 16),
  });

  /// The debounce duration. Defaults to 16ms (one frame at 60fps).
  final Duration duration;

  final Map<int, _DebouncedCallback> _debouncers = {};

  /// Schedules a callback for the given [streamId].
  ///
  /// If called again before the debounce window expires,
  /// the previous callback is cancelled and a new one is scheduled.
  void debounce(int streamId, void Function() callback) {
    _debouncers[streamId]?.timer.cancel();
    _debouncers[streamId] = _DebouncedCallback(
      timer: Timer(duration, () {
        _debouncers.remove(streamId);
        callback();
      }),
    );
  }

  /// Cancels the debounced callback for the given [streamId].
  void cancel(int streamId) {
    _debouncers[streamId]?.timer.cancel();
    _debouncers.remove(streamId);
  }

  /// Cancels all debounced callbacks.
  void cancelAll() {
    for (final entry in _debouncers.values) {
      entry.timer.cancel();
    }
    _debouncers.clear();
  }

  /// Disposes the debouncer pool.
  void dispose() {
    cancelAll();
  }
}

class _DebouncedCallback {
  const _DebouncedCallback({required this.timer});
  final Timer timer;
}
