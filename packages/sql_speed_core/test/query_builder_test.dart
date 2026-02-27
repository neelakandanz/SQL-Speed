import 'package:test/test.dart';

import 'package:sql_speed_core/src/query_builder/select_builder.dart';
import 'package:sql_speed_core/src/query_builder/insert_builder.dart';
import 'package:sql_speed_core/src/query_builder/update_builder.dart';
import 'package:sql_speed_core/src/query_builder/delete_builder.dart';

void main() {
  // Dummy executor that captures the SQL
  Future<List<Map<String, Object?>>> dummyQueryExecutor(
    String sql,
    List<Object?>? params,
  ) async {
    return [];
  }

  Future<int> dummyIntExecutor(String sql, List<Object?>? params) async {
    return 0;
  }

  group('SelectBuilder', () {
    test('builds simple SELECT', () {
      final builder = SelectBuilder('users', executor: dummyQueryExecutor);
      expect(builder.buildSql(), equals('SELECT * FROM users'));
    });

    test('builds SELECT with specific columns', () {
      final builder = SelectBuilder(
        'users',
        columns: ['name', 'age'],
        executor: dummyQueryExecutor,
      );
      expect(builder.buildSql(), equals('SELECT name, age FROM users'));
    });

    test('builds SELECT with WHERE', () {
      final builder = SelectBuilder('users', executor: dummyQueryExecutor)
          .where('age > ?', [25]);
      expect(builder.buildSql(), equals('SELECT * FROM users WHERE age > ?'));
      expect(builder.buildParams(), equals([25]));
    });

    test('builds SELECT with ORDER BY', () {
      final builder = SelectBuilder('users', executor: dummyQueryExecutor)
          .orderBy('name');
      expect(
        builder.buildSql(),
        equals('SELECT * FROM users ORDER BY name ASC'),
      );
    });

    test('builds SELECT with ORDER BY DESC', () {
      final builder = SelectBuilder('users', executor: dummyQueryExecutor)
          .orderBy('name', descending: true);
      expect(
        builder.buildSql(),
        equals('SELECT * FROM users ORDER BY name DESC'),
      );
    });

    test('builds SELECT with LIMIT and OFFSET', () {
      final builder = SelectBuilder('users', executor: dummyQueryExecutor)
          .limit(10)
          .offset(20);
      expect(
        builder.buildSql(),
        equals('SELECT * FROM users LIMIT 10 OFFSET 20'),
      );
    });

    test('builds SELECT with GROUP BY and HAVING', () {
      final builder = SelectBuilder(
        'orders',
        columns: ['user_id', 'SUM(total) as total_spent'],
        executor: dummyQueryExecutor,
      ).groupBy('user_id').having('total_spent > ?', [500]);

      expect(
        builder.buildSql(),
        equals(
          'SELECT user_id, SUM(total) as total_spent FROM orders '
          'GROUP BY user_id HAVING total_spent > ?',
        ),
      );
      expect(builder.buildParams(), equals([500]));
    });

    test('builds SELECT with JOIN', () {
      final builder = SelectBuilder('orders', executor: dummyQueryExecutor)
          .join('users', on: 'orders.user_id = users.id');
      expect(
        builder.buildSql(),
        equals(
          'SELECT * FROM orders INNER JOIN users ON orders.user_id = users.id',
        ),
      );
    });

    test('builds SELECT with LEFT JOIN', () {
      final builder = SelectBuilder('orders', executor: dummyQueryExecutor)
          .leftJoin('users', on: 'orders.user_id = users.id');
      expect(
        builder.buildSql(),
        equals(
          'SELECT * FROM orders LEFT JOIN users ON orders.user_id = users.id',
        ),
      );
    });

    test('builds SELECT DISTINCT', () {
      final builder =
          SelectBuilder('users', executor: dummyQueryExecutor).distinct();
      expect(builder.buildSql(), equals('SELECT DISTINCT * FROM users'));
    });

    test('builds complex query with all clauses', () {
      final builder = SelectBuilder(
        'orders',
        columns: ['user_id', 'COUNT(*) as order_count'],
        executor: dummyQueryExecutor,
      )
          .join('users', on: 'orders.user_id = users.id')
          .where('users.active = ?', [1])
          .groupBy('user_id')
          .having('order_count > ?', [5])
          .orderBy('order_count', descending: true)
          .limit(10);

      final sql = builder.buildSql();
      expect(sql, contains('SELECT user_id, COUNT(*) as order_count'));
      expect(sql, contains('FROM orders'));
      expect(sql, contains('INNER JOIN users ON orders.user_id = users.id'));
      expect(sql, contains('WHERE users.active = ?'));
      expect(sql, contains('GROUP BY user_id'));
      expect(sql, contains('HAVING order_count > ?'));
      expect(sql, contains('ORDER BY order_count DESC'));
      expect(sql, contains('LIMIT 10'));
    });
  });

  group('InsertBuilder', () {
    test('builds INSERT', () {
      final builder = InsertBuilder('users', executor: dummyIntExecutor)
          .values({'name': 'Alice', 'age': 30});
      expect(
        builder.buildSql(),
        equals('INSERT INTO users (name, age) VALUES (?, ?)'),
      );
      expect(builder.buildParams(), equals(['Alice', 30]));
    });

    test('builds INSERT OR REPLACE', () {
      final builder = InsertBuilder('users', executor: dummyIntExecutor)
          .orReplace()
          .values({'name': 'Alice', 'age': 30});
      expect(
        builder.buildSql(),
        equals('INSERT OR REPLACE INTO users (name, age) VALUES (?, ?)'),
      );
    });

    test('builds INSERT OR IGNORE', () {
      final builder = InsertBuilder('users', executor: dummyIntExecutor)
          .orIgnore()
          .values({'name': 'Alice', 'age': 30});
      expect(
        builder.buildSql(),
        equals('INSERT OR IGNORE INTO users (name, age) VALUES (?, ?)'),
      );
    });

    test('throws if no values provided', () {
      final builder = InsertBuilder('users', executor: dummyIntExecutor);
      expect(() => builder.buildSql(), throwsArgumentError);
    });
  });

  group('UpdateBuilder', () {
    test('builds UPDATE', () {
      final builder = UpdateBuilder('users', executor: dummyIntExecutor)
          .set({'age': 31}).where('name = ?', ['Alice']);
      expect(
        builder.buildSql(),
        equals('UPDATE users SET age = ? WHERE name = ?'),
      );
      expect(builder.buildParams(), equals([31, 'Alice']));
    });

    test('builds UPDATE with multiple columns', () {
      final builder = UpdateBuilder('users', executor: dummyIntExecutor)
          .set({'name': 'Bob', 'age': 25});
      expect(
        builder.buildSql(),
        equals('UPDATE users SET name = ?, age = ?'),
      );
    });

    test('throws if no values provided', () {
      final builder = UpdateBuilder('users', executor: dummyIntExecutor);
      expect(() => builder.buildSql(), throwsArgumentError);
    });
  });

  group('DeleteBuilder', () {
    test('builds DELETE', () {
      final builder = DeleteBuilder('users', executor: dummyIntExecutor)
          .where('id = ?', [5]);
      expect(
        builder.buildSql(),
        equals('DELETE FROM users WHERE id = ?'),
      );
      expect(builder.buildParams(), equals([5]));
    });

    test('builds DELETE without WHERE', () {
      final builder = DeleteBuilder('users', executor: dummyIntExecutor);
      expect(builder.buildSql(), equals('DELETE FROM users'));
    });
  });
}
