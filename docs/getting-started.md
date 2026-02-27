# Getting Started with sql_speed

## Installation

Add `sql_speed` to your Flutter project:

```yaml
dependencies:
  sql_speed: ^1.0.0
  sqlite3_flutter_libs: ^0.5.0  # Bundles SQLite for all platforms
```

For code generation (optional):

```yaml
dev_dependencies:
  sql_speed_generator: ^1.0.0
  build_runner: ^2.4.0
```

## Quick Start

### 1. Open a Database

```dart
import 'package:sql_speed/sql_speed.dart';

final db = await FlutterSqlSpeed.openDefault(
  'myapp.db',
  version: 1,
  onCreate: (db, version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  },
);
```

### 2. Insert Data

```dart
final id = await db.insert(
  'INSERT INTO users (name, age, created_at) VALUES (?, ?, ?)',
  ['Alice', 30, DateTime.now().millisecondsSinceEpoch],
);
print('Inserted user with id: $id');
```

### 3. Query Data

```dart
final users = await db.query(
  'SELECT * FROM users WHERE age > ?',
  [25],
);

for (final user in users) {
  print('${user['name']} is ${user['age']} years old');
}
```

### 4. Watch for Changes (Reactive Streams)

```dart
// In your Flutter widget:
StreamBuilder(
  stream: db.watch('SELECT * FROM users ORDER BY name'),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    final users = snapshot.data!;
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (ctx, i) => Text(users[i]['name'] as String),
    );
  },
);
```

### 5. Transactions

```dart
await db.transaction((txn) async {
  txn.insert('INSERT INTO users (name, age, created_at) VALUES (?, ?, ?)',
    ['Bob', 25, DateTime.now().millisecondsSinceEpoch]);
  txn.insert('INSERT INTO users (name, age, created_at) VALUES (?, ?, ?)',
    ['Charlie', 35, DateTime.now().millisecondsSinceEpoch]);
  // Both succeed or both fail
});
```

### 6. Batch Operations

```dart
await db.batch((batch) {
  for (var i = 0; i < 1000; i++) {
    batch.insert(
      'INSERT INTO users (name, age, created_at) VALUES (?, ?, ?)',
      ['User $i', 20 + i % 50, DateTime.now().millisecondsSinceEpoch],
    );
  }
}); // All 1000 inserts in one transaction — very fast!
```

### 7. Query Builder

```dart
final results = await db
  .select('users', columns: ['name', 'age'])
  .where('age > ?', [25])
  .orderBy('name')
  .limit(10)
  .get();
```

### 8. Close the Database

```dart
await db.close();
```

## Next Steps

- [Raw SQL Guide](raw-sql-guide.md) — All SQL methods with examples
- [Streams Guide](streams-guide.md) — Reactive queries and StreamBuilder
- [Code Generation Guide](codegen-guide.md) — Annotations and auto-generated CRUD
- [Migration Guide](migration-guide.md) — Schema versioning
- [Performance Tips](performance-tips.md) — Indexing, batching, and tuning
