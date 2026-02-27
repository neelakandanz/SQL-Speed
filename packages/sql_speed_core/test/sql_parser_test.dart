import 'package:test/test.dart';

import 'package:sql_speed_core/src/utils/sql_parser.dart';

void main() {
  group('SqlParser.extractTables', () {
    test('extracts table from simple SELECT', () {
      final tables = SqlParser.extractTables('SELECT * FROM users');
      expect(tables, contains('users'));
    });

    test('extracts table from SELECT with WHERE', () {
      final tables =
          SqlParser.extractTables('SELECT * FROM users WHERE age > 25');
      expect(tables, contains('users'));
    });

    test('extracts tables from JOIN', () {
      final tables = SqlParser.extractTables(
        'SELECT * FROM users JOIN posts ON users.id = posts.user_id',
      );
      expect(tables, containsAll(['users', 'posts']));
    });

    test('extracts tables from LEFT JOIN', () {
      final tables = SqlParser.extractTables(
        'SELECT * FROM users LEFT JOIN orders ON users.id = orders.user_id',
      );
      expect(tables, containsAll(['users', 'orders']));
    });

    test('extracts table from INSERT INTO', () {
      final tables = SqlParser.extractTables(
        'INSERT INTO users (name, age) VALUES (?, ?)',
      );
      expect(tables, contains('users'));
    });

    test('extracts table from UPDATE', () {
      final tables = SqlParser.extractTables(
        'UPDATE users SET name = ? WHERE id = ?',
      );
      expect(tables, contains('users'));
    });

    test('extracts table from DELETE', () {
      final tables = SqlParser.extractTables('DELETE FROM users WHERE id = ?');
      expect(tables, contains('users'));
    });

    test('extracts multiple tables from subquery', () {
      final tables = SqlParser.extractTables(
        'SELECT * FROM users WHERE id IN (SELECT user_id FROM orders)',
      );
      expect(tables, containsAll(['users', 'orders']));
    });

    test('extracts tables from multi-line SQL', () {
      final tables = SqlParser.extractTables('''
        SELECT u.name, p.title
        FROM users u
        JOIN posts p ON u.id = p.user_id
        WHERE u.active = 1
      ''');
      expect(tables, containsAll(['users', 'posts']));
    });

    test('returns lowercase table names', () {
      final tables = SqlParser.extractTables('SELECT * FROM Users');
      expect(tables, contains('users'));
    });

    test('does not include SQL keywords as table names', () {
      final tables = SqlParser.extractTables('SELECT * FROM users');
      expect(tables, isNot(contains('select')));
      expect(tables, isNot(contains('from')));
    });

    test('handles CREATE TABLE', () {
      final tables = SqlParser.extractTables(
        'CREATE TABLE users (id INTEGER PRIMARY KEY)',
      );
      expect(tables, contains('users'));
    });

    test('handles CREATE TABLE IF NOT EXISTS', () {
      final tables = SqlParser.extractTables(
        'CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY)',
      );
      expect(tables, contains('users'));
    });
  });
}
