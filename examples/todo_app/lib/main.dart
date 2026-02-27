import 'package:flutter/material.dart';
import 'package:sql_speed/sql_speed.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sql_speed Todo App',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  SqlSpeedDatabase? _db;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _openDatabase();
  }

  Future<void> _openDatabase() async {
    final db = await FlutterSqlSpeed.openDefault(
      'todos.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            done INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    setState(() => _db = db);
  }

  @override
  void dispose() {
    _db?.close();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _addTodo() async {
    final title = _textController.text.trim();
    if (title.isEmpty || _db == null) return;

    await _db!.insert(
      'INSERT INTO todos (title, done, created_at) VALUES (?, 0, ?)',
      [title, DateTime.now().millisecondsSinceEpoch],
    );
    _textController.clear();
  }

  Future<void> _toggleTodo(int id, bool currentDone) async {
    await _db!.update(
      'UPDATE todos SET done = ? WHERE id = ?',
      [currentDone ? 0 : 1, id],
    );
  }

  Future<void> _deleteTodo(int id) async {
    await _db!.delete('DELETE FROM todos WHERE id = ?', [id]);
  }

  Future<void> _clearCompleted() async {
    await _db!.delete('DELETE FROM todos WHERE done = 1');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
        actions: [
          TextButton(
            onPressed: _clearCompleted,
            child: const Text('Clear Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Input row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'What needs to be done?',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addTodo,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),

          // Todo count (reactive)
          if (_db != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SqlSpeedBuilder<List<Map<String, Object?>>>(
                stream: _db!.watch(
                  'SELECT COUNT(*) as total, SUM(CASE WHEN done = 1 THEN 1 ELSE 0 END) as completed FROM todos',
                ),
                builder: (context, data, isLoading) {
                  if (isLoading || data == null || data.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final total = data.first['total'] as int? ?? 0;
                  final completed = data.first['completed'] as int? ?? 0;
                  return Text('$completed of $total completed');
                },
              ),
            ),

          const Divider(),

          // Todo list (reactive)
          Expanded(
            child: _db == null
                ? const Center(child: CircularProgressIndicator())
                : SqlSpeedBuilder<List<Map<String, Object?>>>(
                    stream: _db!.watch(
                      'SELECT * FROM todos ORDER BY done ASC, created_at DESC',
                    ),
                    builder: (context, todos, isLoading) {
                      if (isLoading || todos == null) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (todos.isEmpty) {
                        return const Center(
                          child: Text('No todos yet!'),
                        );
                      }
                      return ListView.builder(
                        itemCount: todos.length,
                        itemBuilder: (context, index) {
                          final todo = todos[index];
                          final id = todo['id'] as int;
                          final title = todo['title'] as String;
                          final done = (todo['done'] as int) == 1;

                          return Dismissible(
                            key: ValueKey(id),
                            onDismissed: (_) => _deleteTodo(id),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(Icons.delete,
                                  color: Colors.white),
                            ),
                            child: ListTile(
                              leading: Checkbox(
                                value: done,
                                onChanged: (_) => _toggleTodo(id, done),
                              ),
                              title: Text(
                                title,
                                style: done
                                    ? const TextStyle(
                                        decoration:
                                            TextDecoration.lineThrough,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
