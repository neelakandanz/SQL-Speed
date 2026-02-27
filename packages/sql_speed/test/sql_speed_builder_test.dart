import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sql_speed/src/sql_speed_builder.dart';

void main() {
  group('SqlSpeedBuilder', () {
    testWidgets('shows loading state before stream emits',
        (WidgetTester tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: SqlSpeedBuilder<String>(
            stream: controller.stream,
            builder: (context, data, isLoading) {
              if (isLoading) return const Text('Loading');
              return Text(data ?? 'null');
            },
          ),
        ),
      );

      expect(find.text('Loading'), findsOneWidget);
    });

    testWidgets('shows data after stream emits',
        (WidgetTester tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: SqlSpeedBuilder<String>(
            stream: controller.stream,
            builder: (context, data, isLoading) {
              if (isLoading) return const Text('Loading');
              return Text(data ?? 'null');
            },
          ),
        ),
      );

      controller.add('Hello');
      await tester.pump();

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('uses initialData when provided',
        (WidgetTester tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: SqlSpeedBuilder<String>(
            stream: controller.stream,
            initialData: 'Initial',
            builder: (context, data, isLoading) {
              if (isLoading) return const Text('Loading');
              return Text(data ?? 'null');
            },
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('calls errorBuilder on stream error',
        (WidgetTester tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: SqlSpeedBuilder<String>(
            stream: controller.stream,
            builder: (context, data, isLoading) {
              return Text(data ?? 'no data');
            },
            errorBuilder: (context, error) {
              return Text('Error: $error');
            },
          ),
        ),
      );

      controller.addError('something went wrong');
      await tester.pump();

      expect(find.text('Error: something went wrong'), findsOneWidget);
    });

    testWidgets('falls back to builder with null data when error and no errorBuilder',
        (WidgetTester tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: SqlSpeedBuilder<String>(
            stream: controller.stream,
            builder: (context, data, isLoading) {
              if (data == null && !isLoading) return const Text('Error state');
              return Text(data ?? 'loading');
            },
          ),
        ),
      );

      controller.addError('fail');
      await tester.pump();

      expect(find.text('Error state'), findsOneWidget);
    });

    testWidgets('updates when stream emits new values',
        (WidgetTester tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: SqlSpeedBuilder<String>(
            stream: controller.stream,
            builder: (context, data, isLoading) {
              if (isLoading) return const Text('Loading');
              return Text(data ?? 'null');
            },
          ),
        ),
      );

      controller.add('First');
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);

      controller.add('Second');
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('First'), findsNothing);
    });

    testWidgets('works with List type streams',
        (WidgetTester tester) async {
      final controller = StreamController<List<Map<String, Object?>>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: SqlSpeedBuilder<List<Map<String, Object?>>>(
            stream: controller.stream,
            builder: (context, data, isLoading) {
              if (isLoading) return const Text('Loading');
              if (data == null || data.isEmpty) return const Text('Empty');
              return Text('Count: ${data.length}');
            },
          ),
        ),
      );

      expect(find.text('Loading'), findsOneWidget);

      controller.add([
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ]);
      await tester.pump();

      expect(find.text('Count: 2'), findsOneWidget);
    });
  });

  group('SqlSpeedModelBuilder', () {
    testWidgets('shows loading state before stream emits',
        (WidgetTester tester) async {
      final controller = StreamController<List<Map<String, Object?>>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: SqlSpeedModelBuilder<String>(
            stream: controller.stream,
            mapper: (row) => row['name'] as String,
            builder: (context, data, isLoading) {
              if (isLoading) return const Text('Loading');
              return Text('Got ${data?.length ?? 0} items');
            },
          ),
        ),
      );

      expect(find.text('Loading'), findsOneWidget);
    });

    testWidgets('maps rows to model objects',
        (WidgetTester tester) async {
      final controller = StreamController<List<Map<String, Object?>>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: SqlSpeedModelBuilder<String>(
            stream: controller.stream,
            mapper: (row) => row['name'] as String,
            builder: (context, data, isLoading) {
              if (isLoading) return const Text('Loading');
              if (data == null || data.isEmpty) return const Text('Empty');
              return Text(data.join(', '));
            },
          ),
        ),
      );

      controller.add([
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ]);
      await tester.pump();

      expect(find.text('Alice, Bob'), findsOneWidget);
    });

    testWidgets('calls errorBuilder on stream error',
        (WidgetTester tester) async {
      final controller = StreamController<List<Map<String, Object?>>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: SqlSpeedModelBuilder<String>(
            stream: controller.stream,
            mapper: (row) => row['name'] as String,
            builder: (context, data, isLoading) {
              return const Text('builder');
            },
            errorBuilder: (context, error) {
              return Text('Error: $error');
            },
          ),
        ),
      );

      controller.addError('db error');
      await tester.pump();

      expect(find.text('Error: db error'), findsOneWidget);
    });

    testWidgets('falls back to builder on error without errorBuilder',
        (WidgetTester tester) async {
      final controller = StreamController<List<Map<String, Object?>>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: SqlSpeedModelBuilder<String>(
            stream: controller.stream,
            mapper: (row) => row['name'] as String,
            builder: (context, data, isLoading) {
              if (data == null && !isLoading) return const Text('Error state');
              return const Text('other');
            },
          ),
        ),
      );

      controller.addError('fail');
      await tester.pump();

      expect(find.text('Error state'), findsOneWidget);
    });

    testWidgets('updates when stream emits new data',
        (WidgetTester tester) async {
      final controller = StreamController<List<Map<String, Object?>>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: SqlSpeedModelBuilder<String>(
            stream: controller.stream,
            mapper: (row) => row['name'] as String,
            builder: (context, data, isLoading) {
              if (isLoading) return const Text('Loading');
              if (data == null || data.isEmpty) return const Text('Empty');
              return Text(data.join(', '));
            },
          ),
        ),
      );

      controller.add([
        {'name': 'Alice'},
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);

      controller.add([
        {'name': 'Alice'},
        {'name': 'Bob'},
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Alice, Bob'), findsOneWidget);
    });
  });
}
