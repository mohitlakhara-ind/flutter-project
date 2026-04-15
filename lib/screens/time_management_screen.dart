import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/focus_analytics.dart';
import 'dart:async';

class TimeManagementScreen extends StatefulWidget {
  final String userId;
  const TimeManagementScreen({super.key, required this.userId});

  @override
  State<TimeManagementScreen> createState() => _TimeManagementScreenState();
}

class _TimeManagementScreenState extends State<TimeManagementScreen> {
  static const int focusDuration = 25 * 60; // 25 mins
  static const int breakDuration = 5 * 60; // 5 mins

  int _remainingSeconds = focusDuration;
  bool _isActive = false;
  bool _isFocusMode = true; // true = Focus, false = Break
  Timer? _timer;

  final CollectionReference _focusCollection = FirebaseFirestore.instance.collection('focus_sessions');

  void _recordFocusSession() {
    _focusCollection.add({
      'durationMinutes': focusDuration ~/ 60,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': widget.userId,
    });
  }

  void _startTimer() {
    setState(() => _isActive = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        if (_isFocusMode) _recordFocusSession();
        _stopTimer();
        _toggleMode();
      }
    });
  }

  void _stopTimer() {
    setState(() => _isActive = false);
    _timer?.cancel();
  }

  void _resetTimer() {
    _stopTimer();
    setState(() {
      _remainingSeconds = _isFocusMode ? focusDuration : breakDuration;
    });
  }

  void _toggleMode() {
    _stopTimer();
    setState(() {
      _isFocusMode = !_isFocusMode;
      _remainingSeconds = _isFocusMode ? focusDuration : breakDuration;
    });
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _remainingSeconds / (_isFocusMode ? focusDuration : breakDuration);
    final themeColor = _isFocusMode ? const Color(0xFF0EA5E9) : const Color(0xFF10B981);

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mode Toggle
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModeButton(
                    title: 'Focus',
                    isSelected: _isFocusMode,
                    activeColor: const Color(0xFF0EA5E9),
                    onTap: () {
                      if (!_isFocusMode) _toggleMode();
                    },
                  ),
                  _ModeButton(
                    title: 'Break',
                    isSelected: !_isFocusMode,
                    activeColor: const Color(0xFF10B981),
                    onTap: () {
                      if (_isFocusMode) _toggleMode();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),

            // Circular Timer
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 64,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isFocusMode ? 'Time to Focus' : 'Take a breather',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white54 : Colors.black54,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 60),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reset Button
                IconButton(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.refresh, size: 32),
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 30),
                
                // Play/Pause Button
                GestureDetector(
                  onTap: _isActive ? _stopTimer : _startTimer,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: themeColor,
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ]
                    ),
                    child: Icon(
                      _isActive ? Icons.pause : Icons.play_arrow,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 30),
                
                // Skip Button
                IconButton(
                  onPressed: _toggleMode,
                  icon: const Icon(Icons.skip_next, size: 32),
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ],
            ),
            const SizedBox(height: 40),
            FocusAnalytics(userId: widget.userId),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ModeButton({
    required this.title,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }
}
