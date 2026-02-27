import 'package:flutter/widgets.dart';

/// A convenience widget that combines StreamBuilder with sql_speed streams.
///
/// Automatically manages the stream subscription and provides loading state.
///
/// ```dart
/// SqlSpeedBuilder<List<Map<String, Object?>>>(
///   stream: db.watch('SELECT * FROM users WHERE active = 1'),
///   builder: (context, data, isLoading) {
///     if (isLoading) return CircularProgressIndicator();
///     return ListView(
///       children: data!.map((u) => Text(u['name'] as String)).toList(),
///     );
///   },
/// )
/// ```
class SqlSpeedBuilder<T> extends StatelessWidget {
  /// Creates a new [SqlSpeedBuilder].
  const SqlSpeedBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.errorBuilder,
    this.initialData,
  });

  /// The reactive query stream to listen to.
  final Stream<T> stream;

  /// Builder called with the latest data.
  ///
  /// - `data` is null during initial loading.
  /// - `isLoading` is true when waiting for the first emission.
  final Widget Function(BuildContext context, T? data, bool isLoading) builder;

  /// Optional builder for error states.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Optional initial data to show before the first stream emission.
  final T? initialData;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (errorBuilder != null) {
            return errorBuilder!(context, snapshot.error!);
          }
          return builder(context, null, false);
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return builder(context, null, true);
        }

        return builder(context, snapshot.data, false);
      },
    );
  }
}

/// A typed convenience widget that maps query results to model objects.
///
/// ```dart
/// SqlSpeedModelBuilder<UserModel>(
///   stream: db.watch('SELECT * FROM users'),
///   mapper: (row) => UserModel.fromMap(row),
///   builder: (context, users, isLoading) {
///     if (isLoading) return CircularProgressIndicator();
///     return ListView.builder(
///       itemCount: users!.length,
///       itemBuilder: (ctx, i) => Text(users[i].name),
///     );
///   },
/// )
/// ```
class SqlSpeedModelBuilder<T> extends StatelessWidget {
  /// Creates a new [SqlSpeedModelBuilder].
  const SqlSpeedModelBuilder({
    super.key,
    required this.stream,
    required this.mapper,
    required this.builder,
    this.errorBuilder,
  });

  /// The reactive query stream.
  final Stream<List<Map<String, Object?>>> stream;

  /// Maps a row map to a model instance.
  final T Function(Map<String, Object?> row) mapper;

  /// Builder called with the mapped model list.
  final Widget Function(BuildContext context, List<T>? data, bool isLoading)
      builder;

  /// Optional builder for error states.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, Object?>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (errorBuilder != null) {
            return errorBuilder!(context, snapshot.error!);
          }
          return builder(context, null, false);
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return builder(context, null, true);
        }

        final models = snapshot.data?.map(mapper).toList();
        return builder(context, models, false);
      },
    );
  }
}
