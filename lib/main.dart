import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'widgets/search_overlay.dart';
import 'screens/main_dashboard.dart';

final AuthService _authService = AuthService();

// Global state for manual theme switching
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

// --- MAIN ENTRY POINT ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const FirebaseNotesApp());
}

// --- APP CONFIGURATION ---
class FirebaseNotesApp extends StatelessWidget {
  const FirebaseNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Firebase Notes App',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode, // Listens to manual overrides
          
          // --- LIGHT THEME ---
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.light,
              seedColor: const Color(0xFF0284C7),
              surface: Colors.white,
              onSurface: const Color(0xFF0F172A),
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              iconTheme: IconThemeData(color: Color(0xFF0F172A)),
            ),
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
            ),
          ),

          // --- DARK THEME ---
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.dark,
              seedColor: const Color(0xFF38BDF8),
              surface: const Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFF38BDF8),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              iconTheme: IconThemeData(color: Colors.white),
            ),
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
            ),
          ),
          home: const AuthGate(),
        );
      }
    );
  }
}

// --- AUTH GATE ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authService.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          // If no user, sign in anonymously automatically (Guest Mode)
          _authService.signInAnonymously();
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // We have a user!
        return MainDashboard(userId: snapshot.data!.uid);
      },
    );
  }
}

// --- CONSTANTS & ENUMS ---
const List<Color> noteColors = [
  Color(0xFF334155), // Slate
  Color(0xFF7C3AED), // Deep Purple
  Color(0xFFDB2777), // Pink
  Color(0xFF059669), // Emerald
  Color(0xFFD97706), // Amber
  Color(0xFF0D9488), // Teal
];

enum SortOption { latest, oldest, az, za }

// --- HOME SCREEN ---
class HomeScreen extends StatefulWidget {
  final String userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CollectionReference _notesCollection =
      FirebaseFirestore.instance.collection('notes');
  
  bool _isGridView = true;
  bool _isFabVisible = true;
  String _searchQuery = '';
  Color? _filterColor;
  String _filterTag = '';
  SortOption _currentSort = SortOption.latest;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Dynamic Time Greeting!
  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning ☀️';
    } else if (hour < 17) {
      return 'Good Afternoon ☕';
    } else {
      return 'Good Evening 🌙';
    }
  }

  // Smart relative time parser
  String _getTimeAgo(DateTime date) {
    final duration = DateTime.now().difference(date);
    if (duration.inDays >= 7) {
      return DateFormat('MMM d').format(date);
    } else if (duration.inDays >= 1) {
      return '${duration.inDays}d ago';
    } else if (duration.inHours >= 1) {
      return '${duration.inHours}h ago';
    } else if (duration.inMinutes >= 1) {
      return '${duration.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Home Screen Delete Handler for Swiping & Action Menu
  Future<void> _deleteNoteDirectly(QueryDocumentSnapshot doc) async {
    final id = doc.id;
    final data = doc.data() as Map<String, dynamic>;
    
    await _notesCollection.doc(id).delete();
    
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Note deleted permanently'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: const Color(0xFF38BDF8),
            onPressed: () async {
               await _notesCollection.doc(id).set(data);
            },
          ),
        ),
      );
    }
  }

  void _showQuickActionsMenu(BuildContext context, QueryDocumentSnapshot doc, bool isPinned) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
         return Container(
           decoration: BoxDecoration(
             color: Theme.of(context).colorScheme.surface,
             borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
             boxShadow: [
               BoxShadow(
                 color: Colors.black.withOpacity(0.15),
                 blurRadius: 20,
                 offset: const Offset(0, -5),
               )
             ],
           ),
           child: SafeArea(
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 const SizedBox(height: 12),
                 Container(
                   width: 40, height: 4,
                   decoration: BoxDecoration(
                     color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                     borderRadius: BorderRadius.circular(10),
                   ),
                 ),
                 const SizedBox(height: 12),
                 ListTile(
                   leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, color: const Color(0xFF38BDF8)),
                   title: Text(isPinned ? 'Unpin Note' : 'Pin Note', style: const TextStyle(fontWeight: FontWeight.bold)),
                   onTap: () { 
                     Navigator.pop(context); 
                     _togglePinNote(doc.id, isPinned); 
                   },
                 ),
                 ListTile(
                   leading: const Icon(Icons.copy_rounded),
                   title: const Text('Copy to Clipboard', style: TextStyle(fontWeight: FontWeight.bold)),
                   onTap: () { 
                      Navigator.pop(context);
                      final data = doc.data() as Map<String, dynamic>;
                      final copyText = "${data['title']}\n\n${data['description']}".trim();
                      Clipboard.setData(ClipboardData(text: copyText));
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied directly to clipboard!')));
                   },
                 ),
                 ListTile(
                   leading: const Icon(Icons.edit_note_rounded),
                   title: const Text('Quick Edit', style: TextStyle(fontWeight: FontWeight.bold)),
                   onTap: () {
                     Navigator.pop(context);
                     _showNoteDialog(doc: doc);
                   },
                 ),
                 ListTile(
                   leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                   title: const Text('Move to Trash', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                   onTap: () { 
                     Navigator.pop(context); 
                     _deleteNoteDirectly(doc); 
                   },
                 ),
                 const SizedBox(height: 16),
               ]
             )
           )
         );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark 
        ? const [Color(0xFF0F172A), Color(0xFF020617)]
        : const [Color(0xFFF1F5F9), Color(0xFFE2E8F0)];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildColorFilter(isDark),
              Expanded(
                child: NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.direction == ScrollDirection.forward) {
                      if (!_isFabVisible) setState(() => _isFabVisible = true);
                    } else if (notification.direction == ScrollDirection.reverse) {
                      if (_isFabVisible) setState(() => _isFabVisible = false);
                    }
                    return true;
                  },
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
              .collection('notes')
              .where('userId', isEqualTo: widget.userId)
              .where('isArchived', isEqualTo: false) // Only active notes
              .snapshots(),
                    builder: (context, snapshot) {
                      // 1. Handle Errors (Crucial for identifying Database Rule errors!)
                      if (snapshot.hasError) {
                         return Center(
                           child: Padding(
                             padding: const EdgeInsets.all(20.0),
                             child: Text(
                               'Database Error:\n${snapshot.error}',
                               textAlign: TextAlign.center,
                               style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                             ),
                           )
                         );
                      }

                      // 2. Handle Loading (Only if completely no data exists)
                      if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      }

                      // 3. Fallback check for safe logic
                      if (!snapshot.hasData) {
                         return _buildEmptyState(isDark, noData: true);
                      }

                      // 4. Handle absolutely empty collections
                      if (snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState(isDark, noData: true);
                      }
                  
                      // 5. Fetch and Setup data
                      var notes = snapshot.data!.docs.toList();
                  
                      // 2. Client-side Sort & Pin Logic!
                      notes.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        
                        final aPinned = aData['isPinned'] ?? false;
                        final bPinned = bData['isPinned'] ?? false;
                        
                        // Pinned always bubble to the top.
                        if (aPinned != bPinned) {
                           return aPinned ? -1 : 1;
                        }

                        // Apply standard sorting for the rest
                        switch (_currentSort) {
                          case SortOption.latest:
                            final aTime = aData['timestamp'] as Timestamp?;
                            final bTime = bData['timestamp'] as Timestamp?;
                            if (aTime == null || bTime == null) return 0;
                            return bTime.compareTo(aTime);
                          case SortOption.oldest:
                            final aTime = aData['timestamp'] as Timestamp?;
                            final bTime = bData['timestamp'] as Timestamp?;
                            if (aTime == null || bTime == null) return 0;
                            return aTime.compareTo(bTime);
                          case SortOption.az:
                            final aTitle = (aData['title'] ?? '').toString().toLowerCase();
                            final bTitle = (bData['title'] ?? '').toString().toLowerCase();
                            return aTitle.compareTo(bTitle);
                          case SortOption.za:
                            final aTitle = (aData['title'] ?? '').toString().toLowerCase();
                            final bTitle = (bData['title'] ?? '').toString().toLowerCase();
                            return bTitle.compareTo(aTitle);
                        }
                      });
                  
                      // 3. Apply Filters
                      notes = notes.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        bool matchesSearch = true;
                        bool matchesColor = true;
                        bool matchesTag = true;
                  
                        // Filter: Search
                        if (_searchQuery.isNotEmpty) {
                          final title = (data['title'] ?? '').toString().toLowerCase();
                          final desc = (data['description'] ?? '').toString().toLowerCase();
                          final query = _searchQuery.toLowerCase();
                          matchesSearch = title.contains(query) || desc.contains(query);
                        }
                  
                        // Filter: Color
                        if (_filterColor != null) {
                           final docColorValue = data['color'] as int? ?? noteColors.first.value;
                           matchesColor = docColorValue == _filterColor!.value;
                        }

                        // Filter: Tag
                        if (_filterTag.isNotEmpty) {
                           final docTags = List<String>.from(data['tags'] ?? []);
                           matchesTag = docTags.contains(_filterTag);
                        }
                  
                        return matchesSearch && matchesColor && matchesTag;
                      }).toList();
                  
                      if (notes.isEmpty) {
                         return _buildEmptyState(isDark, noData: false);
                      }
                      
                      // Extract unique tags from ALL docs (not just filtered ones) to show in filter strip
                      final allDocs = snapshot.data!.docs;
                      final Set<String> uniqueTags = {};
                      for (var doc in allDocs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final docTags = List<String>.from(data['tags'] ?? []);
                        uniqueTags.addAll(docTags.where((t) => t.trim().isNotEmpty));
                      }
                      final sortedTags = uniqueTags.toList()..sort();
                  
                      return Column(
                        children: [
                          if (sortedTags.isNotEmpty)
                            Container(
                              height: 40,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: sortedTags.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    final isSelected = _filterTag.isEmpty;
                                    return GestureDetector(
                                      onTap: () => setState(() => _filterTag = ''),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface.withOpacity(isDark ? 0.5 : 0.8),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'All Tags',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final tag = sortedTags[index - 1];
                                  final isSelected = _filterTag == tag;
                                  return GestureDetector(
                                    onTap: () => setState(() => _filterTag = tag),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface.withOpacity(isDark ? 0.5 : 0.8),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: isSelected ? Colors.transparent : Theme.of(context).dividerColor.withOpacity(0.1)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '#$tag',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _isGridView 
                            ? MasonryGridView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 80),
                                gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                ),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                itemCount: notes.length,
                                itemBuilder: (context, index) => _buildNoteCard(notes[index]),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 80),
                                itemCount: notes.length,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildNoteCard(notes[index]),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: GoogleFonts.outfit(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'My Notes',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Search All Docs',
                icon: const Icon(Icons.search_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchOverlay(userId: widget.userId),
                    ),
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Settings & View',
                onSelected: (value) {
                  if (value == 'view') {
                    setState(() => _isGridView = !_isGridView);
                  } else if (value == 'theme') {
                    _showThemePicker();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: ListTile(
                      leading: Icon(_isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded),
                      title: Text(_isGridView ? 'List View' : 'Grid View'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    child: PopupMenuButton<SortOption>(
                      child: ListTile(
                        leading: const Icon(Icons.sort_rounded),
                        title: const Text('Sort by'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSelected: (option) => setState(() => _currentSort = option),
                      itemBuilder: (context) => SortOption.values.map((option) => PopupMenuItem(
                        value: option,
                        child: Text(option.name.toUpperCase()),
                      )).toList(),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'theme',
                    child: ListTile(
                      leading: Icon(Icons.palette_rounded),
                      title: Text('Appearance'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _showNoteDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('Appearance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            ...ThemeMode.values.map((mode) => ListTile(
              leading: Icon(mode == ThemeMode.system ? Icons.brightness_auto : (mode == ThemeMode.light ? Icons.light_mode : Icons.dark_mode)),
              title: Text(mode.name.split('.').last.toUpperCase()),
              trailing: themeNotifier.value == mode ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                themeNotifier.value = mode;
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  
  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        textCapitalization: TextCapitalization.words,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search notes...',
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          suffixIcon: _searchQuery.isNotEmpty 
              ? IconButton(
                  icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface.withOpacity(isDark ? 0.5 : 0.8),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildColorFilter(bool isDark) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: noteColors.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _filterColor == null;
            return GestureDetector(
              onTap: () => setState(() => _filterColor = null),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                   color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface.withOpacity(isDark ? 0.5 : 0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  'All',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            );
          }
          
          final color = noteColors[index - 1];
          final isSelected = _filterColor == color;
          
          return GestureDetector(
            onTap: () => setState(() => _filterColor = color),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)] : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, {required bool noData}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noData ? Icons.note_alt_outlined : Icons.search_off_rounded, 
            size: 80, 
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            noData ? 'No notes yet' : 'No matching notes',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          if (noData) ...[
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add one',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ]
        ],
      ),
    );
  }

  // --- NEW: Search Keyword Highlighting Logic ---
  Widget _buildHighlightedText(String text, TextStyle baseStyle) {
    if (_searchQuery.isEmpty) {
      return Text(text, style: baseStyle, maxLines: _isGridView ? 10 : null, overflow: TextOverflow.fade);
    }
    
    final String lowercaseText = text.toLowerCase();
    final String lowercaseQuery = _searchQuery.toLowerCase();
    final List<TextSpan> spans = [];
    int start = 0;

    int indexOfMatch;
    while ((indexOfMatch = lowercaseText.indexOf(lowercaseQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + lowercaseQuery.length),
        style: baseStyle.copyWith(backgroundColor: Colors.yellowAccent.withOpacity(0.3), fontWeight: FontWeight.bold),
      ));
      start = indexOfMatch + lowercaseQuery.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: _isGridView ? 10 : null,
      overflow: TextOverflow.fade,
    );
  }

  Widget _buildNoteCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = (data['title'] ?? 'No Title').toString();
    final description = (data['description'] ?? '').toString();
    final colorValue = data['color'] as int? ?? noteColors.first.value;
    final timestamp = data['timestamp'] as Timestamp?;
    final isPinned = data['isPinned'] ?? false;
    final isPrivate = data['isPrivate'] ?? false;
    final tags = List<String>.from(data['tags'] ?? []);
    
    // Read time calculator
    final wordCount = description.trim().split(RegExp(r'\s+')).where((String e) => e.isNotEmpty).length;
    final readTimeMins = (wordCount / 200).ceil();
    final readTimeStr = readTimeMins > 0 ? '$readTimeMins min read' : '< 1m read';
    
    String timeString = '';
    if (timestamp != null) {
      timeString = _getTimeAgo(timestamp.toDate());
    }

    final noteColor = Color(colorValue);

    final cardChild = Hero(
      tag: doc.id,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showNoteDialog(doc: doc),
          onDoubleTap: () => _togglePinNote(doc.id, isPinned), // Double tap to pin/unpin!
          onLongPress: () => _showQuickActionsMenu(context, doc, isPinned), // Long Press Menu!
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: noteColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildHighlightedText( // RichText Highlighting
                        title, 
                        GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        )
                      ),
                    ),
                    if (isPrivate)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0, top: 2),
                        child: Icon(Icons.lock_rounded, color: Colors.white70, size: 16),
                      ),
                    if (isPinned)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0, top: 2),
                        child: Icon(Icons.push_pin_rounded, color: Colors.white, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (description.isNotEmpty) ...[
                   Builder(
                     builder: (context) {
                       Widget textWidget;
                       bool hasCheckboxes = description.contains('- [ ]') || description.contains('- [x]');
                       
                       if (hasCheckboxes) {
                          List<Widget> linesWidgets = [];
                          final splitLines = LineSplitter().convert(description);
                          for (int i = 0; i < splitLines.length; i++) {
                             final line = splitLines[i];
                             final trimLine = line.trim();
                             if (trimLine.startsWith('- [ ]') || trimLine.startsWith('- [x]')) {
                                bool isChecked = trimLine.startsWith('- [x]');
                                String text = trimLine.substring(5).trim();
                                linesWidgets.add(
                                   GestureDetector(
                                      onTap: () {
                                         List<String> newLines = List.from(splitLines);
                                         newLines[i] = line.replaceFirst(isChecked ? '- [x]' : '- [ ]', isChecked ? '- [ ]' : '- [x]');
                                         _notesCollection.doc(doc.id).update({'description': newLines.join('\n')});
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                           crossAxisAlignment: CrossAxisAlignment.start,
                                           children: [
                                              Icon(isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 18, color: Colors.white.withOpacity(0.9)),
                                              const SizedBox(width: 8),
                                              Expanded(child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, decoration: isChecked ? TextDecoration.lineThrough : null))),
                                           ]
                                        ),
                                      ),
                                   )
                                );
                             } else {
                                linesWidgets.add(Padding(padding: const EdgeInsets.only(bottom: 6), child: _buildHighlightedText(line, TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9), height: 1.4))));
                             }
                          }
                          textWidget = Column(crossAxisAlignment: CrossAxisAlignment.start, children: linesWidgets);
                       } else {
                          textWidget = _buildHighlightedText(
                             description,
                             TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9), height: 1.4),
                          );
                       }

                       if (isPrivate) {
                         if (kIsWeb) {
                             return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                   color: Colors.white.withOpacity(0.1),
                                   borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(child: Text('🔒 Private Note\nTap to view', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                             );
                         } else {
                             return ImageFiltered(
                               imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                               child: textWidget,
                             );
                         }
                       }
                       return textWidget;
                     }
                   ),
                ],
                 if (tags.isNotEmpty) ...[
                   const SizedBox(height: 12),
                   Wrap(
                     spacing: 6,
                     runSpacing: 6,
                     children: tags.map((tag) => Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(
                         color: Colors.white.withOpacity(0.15),
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                       ),
                       child: Text(
                         '#$tag',
                         style: const TextStyle(
                           color: Colors.white,
                           fontSize: 10,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     )).toList(),
                   ),
                 ],
                if (timeString.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        timeString,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.menu_book_rounded, size: 12, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text(
                            readTimeStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Swipe to Archive or Delete mechanic!
    return Dismissible(
      key: Key(doc.id),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 32),
      ),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.archive_rounded, color: Colors.white, size: 32),
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteNoteDirectly(doc);
        } else {
          _archiveNote(doc.id);
        }
      },
      child: cardChild,
    );
  }

  Future<void> _archiveNote(String id) async {
    await _notesCollection.doc(id).update({'isArchived': true});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Note archived'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _notesCollection.doc(id).update({'isArchived': false}),
          ),
        ),
      );
    }
  }

  void _showNoteDialog({QueryDocumentSnapshot? doc}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: NoteDialogContent(
            notesCollection: _notesCollection, 
            existingDoc: doc,
            userId: widget.userId,
          ),
        );
      },
    );
  }
  
  Future<void> _togglePinNote(String id, bool currentStatus) async {
    await _notesCollection.doc(id).update({'isPinned': !currentStatus});
    if(mounted) {
       ScaffoldMessenger.of(context).clearSnackBars();
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(currentStatus ? 'Note unpinned' : 'Note pinned'),
           duration: const Duration(seconds: 1),
         ),
       );
    }
  }
}

// --- NOTE DIALOG (ADD & EDIT) ---
class NoteDialogContent extends StatefulWidget {
  final CollectionReference notesCollection;
  final QueryDocumentSnapshot? existingDoc;
  final String userId;

  const NoteDialogContent({
    super.key,
    required this.notesCollection,
    required this.userId,
    this.existingDoc,
  });

  @override
  State<NoteDialogContent> createState() => _NoteDialogContentState();
}

class _NoteDialogContentState extends State<NoteDialogContent> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _tagsController;
  late Color _selectedColor;
  bool _isPinned = false;
  bool _isPrivate = false;

  bool get isEditing => widget.existingDoc != null;

  // Live Metrics tracking
  int _wordCount = 0;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    String initTitle = '';
    String initDesc = '';
    String initTags = '';
    Color initColor = noteColors.first;

    if (isEditing) {
      final data = widget.existingDoc!.data() as Map<String, dynamic>;
      initTitle = data['title'] ?? '';
      initDesc = data['description'] ?? '';
      _isPinned = data['isPinned'] ?? false;
      _isPrivate = data['isPrivate'] ?? false;
      if (data['tags'] != null) {
         initTags = (data['tags'] as List).join(', ');
      }
      if (data['color'] != null) {
        initColor = Color(data['color']);
      }
    }

    _titleController = TextEditingController(text: initTitle);
    _descriptionController = TextEditingController(text: initDesc);
    _tagsController = TextEditingController(text: initTags);
    _selectedColor = initColor;
    
    // Set initial counts
    _updateMetrics();
    
    // Listen for ongoing text changes for live counts!
    _descriptionController.addListener(_updateMetrics);
  }

  void _updateMetrics() {
    final text = _descriptionController.text;
    final words = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    final chars = text.length;
    
    if (_wordCount != words || _charCount != chars) {
      setState(() {
        _wordCount = words;
        _charCount = chars;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final tagsRaw = _tagsController.text;
    final List<String> tags = tagsRaw.isNotEmpty 
        ? tagsRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : [];

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }

    final data = {
      'title': title,
      'description': description,
      'tags': tags,
      'color': _selectedColor.value,
      'isPinned': _isPinned,
      'isPrivate': _isPrivate,
      'userId': widget.userId,
      'isArchived': false,
    };
    
    if (!isEditing) {
       data['timestamp'] = FieldValue.serverTimestamp();
    }

    // ⭐ OPTIMISTIC UI: Close the dialog immediately for instant feedback!
    Navigator.of(context).pop();

    // Send the write request to Firestore without awaiting it.
    // This allows the app to feel snappy even on slow networks, 
    // and correctly caches the write if the user is offline.
    if (isEditing) {
      widget.notesCollection.doc(widget.existingDoc!.id).update(data)
        .catchError((e) => debugPrint("Failed to update note: $e"));
    } else {
      widget.notesCollection.add(data)
        .catchError((e) => debugPrint("Failed to add note: $e"));
    }
  }

  Future<void> _deleteNote() async {
    try {
      final id = widget.existingDoc!.id;
      final data = widget.existingDoc!.data() as Map<String, dynamic>;
      
      await widget.notesCollection.doc(id).delete();
      
      if (mounted) {
        Navigator.of(context).pop(); 
        
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note moved to trash'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: const Color(0xFF38BDF8),
              onPressed: () async {
                 await widget.notesCollection.doc(id).set(data);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
  
  void _copyToClipboard() {
    final textToCopy = "${_titleController.text}\n\n${_descriptionController.text}".trim();
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Note' : 'Create Note',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isEditing) ...[
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      onPressed: _copyToClipboard,
                      tooltip: 'Copy Note',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: _deleteNote,
                      tooltip: 'Delete Note',
                    ),
                  ],
                  IconButton(
                    icon: Icon(
                      _isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: _isPrivate ? Colors.redAccent : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    onPressed: () => setState(() => _isPrivate = !_isPrivate),
                    tooltip: _isPrivate ? 'Make Public' : 'Make Private',
                  ),
                  IconButton(
                    icon: Icon(
                      _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                      color: _isPinned ? const Color(0xFF38BDF8) : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    onPressed: () => setState(() => _isPinned = !_isPinned),
                    tooltip: _isPinned ? 'Unpin Note' : 'Pin Note',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences, // Start sentences with capital letters
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Note Title',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.next,
              ),

              Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),

              TextField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences, // Start sentences with capital letters
                style: const TextStyle(fontSize: 16, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Type something...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                ),
                maxLines: 5,
                minLines: 3,
              ),

              Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              
              TextField(
                controller: _tagsController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add tags (comma separated)',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.tag, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                ),
                textInputAction: TextInputAction.done,
              ),

              const SizedBox(height: 16),
              
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: noteColors.length,
                  itemBuilder: (context, index) {
                    final color = noteColors[index];
                    final isSelected = _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                            color: isSelected 
                                ? (isDark ? Colors.white : Colors.black87) 
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected 
                            ? const Icon(Icons.check, size: 20, color: Colors.white) 
                            : null,
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   // Live Status Label for Words and Characters
                   Text(
                     '$_wordCount words  •  $_charCount chars',
                     style: TextStyle(
                       color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                       fontSize: 12,
                       fontWeight: FontWeight.w600,
                     ),
                   ),
                   Row(
                     children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveNote, // Directly run save
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).floatingActionButtonTheme.backgroundColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(isEditing ? 'Update' : 'Save', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                     ],
                   )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
