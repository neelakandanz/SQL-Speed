# sql_speed

**High-performance, SQL-first local database for Flutter and Dart.**

Write SQL you already know. Get speed you didn't expect.

## Features

- **Real SQL** — Full SQL support: SELECT, INSERT, UPDATE, DELETE, JOIN, GROUP BY, HAVING, subqueries, UNION, CTEs
- **High Performance** — Prepared statement caching, WAL mode, background isolate, connection pooling
- **Reactive Streams** — `db.watch()` returns live-updating streams for any SQL query
- **Code Generation** — Optional `@Table`, `@Column`, `@PrimaryKey` annotations for auto-generated CRUD
- **Encryption** — Optional AES-256 encryption via SQLCipher
- **Background Isolate** — All DB operations run off the UI thread automatically
- **Query Builder** — Optional fluent API: `db.select('users').where('age > ?', [25]).get()`
- **Migration System** — Version-based migrations with automatic backup/restore
- **Type Mapping** — Automatic Dart↔SQLite type conversion with custom converter support

## Quick Start

```dart
// Open database
final db = await FlutterSqlSpeed.openDefault('app.db', version: 1,
  onCreate: (db, v) async {
    await db.execute('CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)');
  },
);

// Insert
final id = await db.insert('INSERT INTO users (name, age) VALUES (?, ?)', ['Alice', 30]);

// Query
final users = await db.query('SELECT * FROM users WHERE age > ?', [25]);

// Reactive stream
final stream = db.watch('SELECT * FROM users ORDER BY name');

// Close
await db.close();
```

## Benchmarks

Measured on iPhone 16 Plus Simulator (debug mode, in-memory SQLite):

| Operation | Result |
|---|---|
| Single INSERT (avg of 100) | **230.8 us** |
| Batch INSERT 1,000 rows | **16 ms** |
| Single SELECT by PK (avg of 100) | **106.0 us** |
| Bulk SELECT 1,000 rows | **2 ms** |
| Batch INSERT 10,000 rows | **38 ms** |

Run benchmarks yourself:

```bash
cd benchmarks
flutter run
```

## Packages

| Package | Description |
|---------|-------------|
| [`sql_speed_core`](packages/sql_speed_core/) | Pure Dart core engine (no Flutter dependency) |
| [`sql_speed`](packages/sql_speed/) | Flutter package with widgets and platform support |
| [`sql_speed_generator`](packages/sql_speed_generator/) | Code generation from annotated Dart classes |

## Documentation

- [Getting Started](docs/getting-started.md)
- [API Reference](https://pub.dev/documentation/sql_speed/latest/)

## License

MIT License. See [LICENSE](LICENSE) for details.
