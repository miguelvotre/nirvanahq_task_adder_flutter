import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'dart:io' show Platform;
import 'services/nirvana_service.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize hotkey_manager for global shortcuts
  if (Platform.isWindows) {
    // Current version doesn't use initialize() anymore
    await hotKeyManager.unregisterAll();
  }
  
  // Check if running on Windows
  if (Platform.isWindows) {
    // Windows specific configuration
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    
    // Define a smaller window size for Windows
    WindowOptions windowOptions = const WindowOptions(
      size: Size(400, 600), // Smaller and more compact size
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: "Nirvana Task Adder",
    );
    
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isAuthenticated = false;
  String _userEmail = '';
  final NirvanaService _nirvanaService = NirvanaService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  // Check if user is already authenticated
  Future<void> _checkAuth() async {
    final authInfo = await _nirvanaService.checkAuth();
    setState(() {
      _isAuthenticated = authInfo['token'] != null;
      _userEmail = authInfo['email'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nirvana Task Adder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: _isAuthenticated 
          ? TaskPage(
              userEmail: _userEmail,
              onLogout: () {
                setState(() {
                  _isAuthenticated = false;
                  _userEmail = '';
                });
              },
            ) 
          : LoginPage(
              onLogin: (email) {
                setState(() {
                  _isAuthenticated = true;
                  _userEmail = email;
                });
              },
            ),
    );
  }
}

// Login Screen
class LoginPage extends StatefulWidget {
  final Function(String) onLogin;
  
  const LoginPage({Key? key, required this.onLogin}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final NirvanaService _nirvanaService = NirvanaService();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Basic validation
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _nirvanaService.login(
        _emailController.text.trim(), 
        _passwordController.text.trim()
      );
      
      // Call callback function to update app state
      widget.onLogin(_emailController.text);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWindows = Platform.isWindows;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nirvana Login'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWindows ? 350 : 600, // Narrower on Windows
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _login(),
                ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24, 
                          height: 24, 
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Add Task Screen
class TaskPage extends StatefulWidget {
  final String userEmail;
  final VoidCallback onLogout;
  
  const TaskPage({Key? key, required this.userEmail, required this.onLogout}) : super(key: key);

  @override
  _TaskPageState createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> with WindowListener, TrayListener {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final NirvanaService _nirvanaService = NirvanaService();
  final FocusNode _titleFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isWindows = false;
  String _successMessage = '';
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    
    // Check if Windows and initialize specific features
    _isWindows = Platform.isWindows;
    
    if (_isWindows) {
      _initWindowsFeatures();
      _registerHotkey();
    }
    
    // Focus on title field on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _titleFocusNode.dispose();
    
    if (_isWindows) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
      _unregisterHotkey();
    }
    
    super.dispose();
  }
  
  // Initialize Windows-specific resources
  Future<void> _initWindowsFeatures() async {
    windowManager.addListener(this);
    await _initTray();
  }

  // Initialize system tray
  Future<void> _initTray() async {
    // Only initialize on Windows
    if (!_isWindows) return;
    
    trayManager.addListener(this);
    
    // Updated to use correct path
    await trayManager.setIcon('assets/images/logo.ico');
    await trayManager.setToolTip("Nirvana Task Adder");
    
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(label: "Open", onClick: (menuItem) => _showWindow()),
          MenuItem(label: "Exit", onClick: (menuItem) => _exitApp()),
        ],
      ),
    );
  }
  
  // Register global shortcut Windows+Shift+A
  Future<void> _registerHotkey() async {
    HotKey hotKey = HotKey(
      KeyCode.keyA,
      // Add Windows key (Meta) together with Shift
      modifiers: [KeyModifier.shift, KeyModifier.meta],
      scope: HotKeyScope.system,
    );
    
    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (hotKey) {
        _toggleWindowVisibility();
      },
    );
  }
  
  // Unregister shortcut
  Future<void> _unregisterHotkey() async {
    await hotKeyManager.unregisterAll();
  }
  
  // Toggle window visibility
  Future<void> _toggleWindowVisibility() async {
    bool isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      _showWindow(); // No await, as _showWindow doesn't return Future
    }
  }
  
  // Add task
  Future<void> _addTask() async {
    // Basic validation
    if (_titleController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a task title';
        _successMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      await _nirvanaService.createTask(
        _titleController.text.trim(),
        _notesController.text.trim()
      );
      
      setState(() {
        _successMessage = 'Task added successfully!';
        _titleController.clear();
        _notesController.clear();
      });
      
      // Clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = '';
          });
        }
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Logout
  Future<void> _logout() async {
    await _nirvanaService.logout();
    widget.onLogout();
  }
  
  // --- Windows-specific methods ---
  
  void _showWindow() {
    if (_isWindows) {
      windowManager.show();
      windowManager.focus();
      
      // Focus on title field when window is opened
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _titleFocusNode.requestFocus();
      });
    }
  }

  void _exitApp() {
    if (_isWindows) {
      trayManager.destroy();
      windowManager.destroy();
    }
  }

  @override
  void onWindowClose() async {
    if (_isWindows) {
      windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    if (_isWindows) {
      trayManager.popUpContextMenu();
    }
  }

  // Process Ctrl+Enter key
  void _handleKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.enter) {
      // Add task and minimize to tray
      _addTask().then((_) {
        if (_isWindows) {
          windowManager.hide();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKey: _handleKeyPress,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _isWindows ? 350 : 600,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logged in user information
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Logged in as: ${widget.userEmail}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  
                  // Title field with auto focus
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Task Title',
                      border: OutlineInputBorder(),
                      hintText: 'Press Ctrl+Enter to add',
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Notes field
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes/Comments',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                  
                  // Error/success messages
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_successMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _successMessage,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Add button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _addTask,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add Task'),
                  ),
                  
                  // Windows tip
                  if (_isWindows)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'The app will continue running in the system tray when closed.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
