import 'package:flutter/material.dart';

class TodoTile extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onDelete;

  const TodoTile({
    super.key,
    required this.title,
    required this.isCompleted,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark 
                ? (isCompleted ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.1))
                : (isCompleted ? Colors.grey.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: GestureDetector(
            onTap: () => onChanged(!isCompleted),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted 
                    ? const Color(0xFF0EA5E9) 
                    : Colors.transparent,
                border: Border.all(
                  color: isCompleted 
                      ? const Color(0xFF0EA5E9) 
                      : (isDark ? Colors.white54 : Colors.grey.shade400),
                  width: 2,
                ),
              ),
              child: isCompleted 
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
          title: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: isCompleted 
                  ? (isDark ? Colors.white38 : Colors.grey.shade400) 
                  : (isDark ? Colors.white : Colors.black87),
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              fontWeight: isCompleted ? FontWeight.w400 : FontWeight.w500,
            ),
            child: Text(title),
          ),
        ),
      ),
    );
  }
}
