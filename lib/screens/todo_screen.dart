import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/todo_tile.dart';

class TodoScreen extends StatefulWidget {
  final String userId;
  const TodoScreen({super.key, required this.userId});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final CollectionReference _todosCollection = FirebaseFirestore.instance.collection('todos');
  final TextEditingController _taskController = TextEditingController();

  void _addTask() {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;

    _todosCollection.add({
      'title': title,
      'isCompleted': false,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': widget.userId,
    });

    _taskController.clear();
  }

  void _toggleTask(String id, bool? isCompleted) {
    if (isCompleted == null) return;
    _todosCollection.doc(id).update({'isCompleted': isCompleted});
  }

  void _deleteTask(String id) {
    _todosCollection.doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task deleted'), duration: Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 28, color: Color(0xFF0EA5E9)),
              const SizedBox(width: 12),
              Text(
                'My Tasks',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        // Input Field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: TextField(
              controller: _taskController,
              onSubmitted: (_) => _addTask(),
              decoration: InputDecoration(
                hintText: 'What needs to be done?',
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                prefixIcon: const Icon(Icons.add_task),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF0EA5E9)),
                  onPressed: _addTask,
                )
              ),
            ),
          ),
        ),

        // Todo List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _todosCollection
                .where('userId', isEqualTo: widget.userId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error loading tasks', style: TextStyle(color: Colors.red)));
              }

              final docs = snapshot.data?.docs ?? [];
              
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task_alt, size: 80, color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('All caught up!', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return TodoTile(
                    title: data['title'] ?? 'Untitled',
                    isCompleted: data['isCompleted'] ?? false,
                    onChanged: (val) => _toggleTask(docs[index].id, val),
                    onDelete: () => _deleteTask(docs[index].id),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
