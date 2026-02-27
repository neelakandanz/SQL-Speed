import 'package:flutter/material.dart';
import 'package:sql_speed/sql_speed.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NotesApp());
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sql_speed Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const NotesScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Notes Screen — demonstrates CRUD, reactive streams, query builder
// ---------------------------------------------------------------------------

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  SqlSpeedDatabase? _db;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _openDatabase();
  }

  // ---- 1. Open database & create table ----
  Future<void> _openDatabase() async {
    final db = await FlutterSqlSpeed.openDefault(
      'notes.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            body TEXT NOT NULL DEFAULT '',
            pinned INTEGER NOT NULL DEFAULT 0,
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
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  // ---- 2. INSERT — raw SQL ----
  Future<void> _addNote() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _db == null) return;

    await _db!.insert(
      'INSERT INTO notes (title, body, created_at) VALUES (?, ?, ?)',
      [title, _bodyCtrl.text.trim(), DateTime.now().millisecondsSinceEpoch],
    );
    _titleCtrl.clear();
    _bodyCtrl.clear();
  }

  // ---- 3. INSERT — query builder ----
  Future<void> _addNoteWithBuilder() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _db == null) return;

    await _db!.insertInto('notes').values({
      'title': title,
      'body': _bodyCtrl.text.trim(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }).execute();
    _titleCtrl.clear();
    _bodyCtrl.clear();
  }

  // ---- 4. UPDATE — toggle pin ----
  Future<void> _togglePin(int id, bool currentlyPinned) async {
    await _db!.update(
      'UPDATE notes SET pinned = ? WHERE id = ?',
      [currentlyPinned ? 0 : 1, id],
    );
  }

  // ---- 5. DELETE ----
  Future<void> _deleteNote(int id) async {
    await _db!.delete('DELETE FROM notes WHERE id = ?', [id]);
  }

  // ---- 6. BATCH — seed sample data ----
  Future<void> _seedSampleNotes() async {
    if (_db == null) return;

    await _db!.batch((batch) {
      final samples = [
        'Buy groceries',
        'Read Flutter docs',
        'Fix login bug',
        'Call dentist',
        'Plan weekend trip',
      ];
      for (final title in samples) {
        batch.insert(
          'INSERT INTO notes (title, body, created_at) VALUES (?, ?, ?)',
          [title, '', DateTime.now().millisecondsSinceEpoch],
        );
      }
    });
  }

  // ---- 7. TRANSACTION — delete all unpinned ----
  Future<void> _deleteUnpinned() async {
    if (_db == null) return;

    await _db!.transaction((txn) async {
      txn.delete('DELETE FROM notes WHERE pinned = 0');
    });
  }

  // ---- 8. SELECT — query builder with filter ----
  Future<void> _showPinnedCount() async {
    if (_db == null) return;

    final count = await _db!
        .select('notes')
        .where('pinned = 1')
        .count();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pinned notes: $count')),
      );
    }
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.push_pin),
            tooltip: 'Pinned count',
            onPressed: _showPinnedCount,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'seed') _seedSampleNotes();
              if (v == 'clean') _deleteUnpinned();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'seed', child: Text('Seed 5 notes (batch)')),
              const PopupMenuItem(value: 'clean', child: Text('Delete unpinned (txn)')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // -- Input form --
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Body (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _addNote,
                        icon: const Icon(Icons.add),
                        label: const Text('Add (raw SQL)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addNoteWithBuilder,
                        icon: const Icon(Icons.add),
                        label: const Text('Add (builder)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // -- Reactive note list using SqlSpeedBuilder --
          Expanded(
            child: _db == null
                ? const Center(child: CircularProgressIndicator())
                : SqlSpeedBuilder<List<Map<String, Object?>>>(
                    // 9. WATCH — reactive stream auto-updates the list
                    stream: _db!.watch(
                      'SELECT * FROM notes ORDER BY pinned DESC, created_at DESC',
                    ),
                    builder: (context, notes, isLoading) {
                      if (isLoading || notes == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (notes.isEmpty) {
                        return const Center(
                          child: Text('No notes yet. Add one above!'),
                        );
                      }
                      return ListView.builder(
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          final id = note['id'] as int;
                          final title = note['title'] as String;
                          final body = note['body'] as String;
                          final pinned = (note['pinned'] as int) == 1;

                          return Dismissible(
                            key: ValueKey(id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _deleteNote(id),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            child: ListTile(
                              leading: IconButton(
                                icon: Icon(
                                  pinned ? Icons.push_pin : Icons.push_pin_outlined,
                                  color: pinned ? Colors.teal : null,
                                ),
                                onPressed: () => _togglePin(id, pinned),
                              ),
                              title: Text(title),
                              subtitle: body.isNotEmpty ? Text(body) : null,
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
