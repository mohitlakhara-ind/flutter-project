import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FocusAnalytics extends StatelessWidget {
  final String userId;
  const FocusAnalytics({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Calculate the date exactly 7 days ago
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF0EA5E9)),
              const SizedBox(width: 10),
              Text(
                'Focus Analytics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150, // Height for the bar chart
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('focus_sessions')
                  .where('userId', isEqualTo: userId)
                  .where('timestamp', isGreaterThanOrEqualTo: weekAgo)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Group minutes by day
                final Map<int, int> minutesByWeekday = {
                  1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0
                }; // 1 = Monday, 7 = Sunday
                
                int maxMinutes = 1; // Default to 1 to avoid division by zero

                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = data['timestamp'] as Timestamp?;
                  if (timestamp != null) {
                    final date = timestamp.toDate();
                    final duration = data['durationMinutes'] as int? ?? 0;
                    minutesByWeekday[date.weekday] = (minutesByWeekday[date.weekday] ?? 0) + duration;
                    if (minutesByWeekday[date.weekday]! > maxMinutes) {
                      maxMinutes = minutesByWeekday[date.weekday]!;
                    }
                  }
                }

                final today = DateTime.now().weekday;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final int weekday = index + 1;
                    final int minutes = minutesByWeekday[weekday] ?? 0;
                    final double percentage = minutes / maxMinutes;
                    final bool isToday = weekday == today;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Tooltip / Minutes Text
                        if (minutes > 0)
                          Text(
                            '${minutes}m',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 4),
                        // Animated Bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.fastOutSlowIn,
                          width: 24,
                          height: (percentage * 100).clamp(4.0, 100.0), // Min height of 4
                          decoration: BoxDecoration(
                            gradient: isToday ? const LinearGradient(
                              colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ) : null,
                            color: isToday ? null : (isDark ? Colors.white10 : Colors.black12),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isToday ? [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ] : [],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Day Label
                        Text(
                          _getWeekdayLetter(weekday),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday 
                                ? const Color(0xFF0EA5E9) 
                                : (isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                      ],
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekdayLetter(int weekday) {
    switch (weekday) {
      case 1: return 'M';
      case 2: return 'T';
      case 3: return 'W';
      case 4: return 'T';
      case 5: return 'F';
      case 6: return 'S';
      case 7: return 'S';
      default: return 'X';
    }
  }
}
