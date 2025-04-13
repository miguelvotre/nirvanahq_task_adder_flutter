import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'dart:io' show Platform;
import 'services/nirvana_service.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa hotkey_manager para atalhos globais
  if (Platform.isWindows) {
    // A versão atual não usa mais initialize()
    await hotKeyManager.unregisterAll();
  }
  
  // Verifica se está rodando no Windows
  if (Platform.isWindows) {
    // Configuração específica para Windows
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    
    // Define um tamanho menor para a janela no Windows
    WindowOptions windowOptions = const WindowOptions(
      size: Size(400, 600), // Tamanho menor e mais compacto
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

  // Verifica se o usuário já está autenticado
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

// Tela de Login
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
    // Validação básica
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, preencha todos os campos';
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
      
      // Chama a função de callback para atualizar o estado do app
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
        title: const Text('Login Nirvana'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWindows ? 350 : 600, // Mais estreito no Windows
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
                    labelText: 'Senha',
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
                      : const Text('Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Tela de Adicionar Tarefa
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
    
    // Verifica se é Windows e inicializa funcionalidades específicas
    _isWindows = Platform.isWindows;
    
    if (_isWindows) {
      _initWindowsFeatures();
      _registerHotkey();
    }
    
    // Foca no campo de título na inicialização
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
  
  // Inicializa recursos específicos do Windows
  Future<void> _initWindowsFeatures() async {
    windowManager.addListener(this);
    await _initTray();
  }

  // Inicializa o system tray
  Future<void> _initTray() async {
    trayManager.addListener(this);
    await trayManager.setIcon('assets/flutter_logo.ico');
    await trayManager.setToolTip("Nirvana Task Adder");
    
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(label: "Abrir", onClick: (menuItem) => _showWindow()),
          MenuItem(label: "Sair", onClick: (menuItem) => _exitApp()),
        ],
      ),
    );
  }
  
  // Registra o atalho global Windows+Shift+A
  Future<void> _registerHotkey() async {
    HotKey hotKey = HotKey(
      KeyCode.keyA,
      // Adiciona a tecla Windows (Meta) junto com Shift
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
  
  // Remove o registro do atalho
  Future<void> _unregisterHotkey() async {
    await hotKeyManager.unregisterAll();
  }
  
  // Alterna entre mostrar e esconder a janela
  Future<void> _toggleWindowVisibility() async {
    bool isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      _showWindow(); // Sem await, pois _showWindow não retorna Future
    }
  }
  
  // Adicionar tarefa
  Future<void> _addTask() async {
    // Validação básica
    if (_titleController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, informe um título para a tarefa';
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
        _successMessage = 'Tarefa adicionada com sucesso!';
        _titleController.clear();
        _notesController.clear();
      });
      
      // Limpa a mensagem de sucesso após 3 segundos
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
  
  // Fazer logout
  Future<void> _logout() async {
    await _nirvanaService.logout();
    widget.onLogout();
  }
  
  // --- Métodos específicos do Windows ---
  
  void _showWindow() {
    if (_isWindows) {
      windowManager.show();
      windowManager.focus();
      
      // Foca no campo de título quando a janela é aberta
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

  // Processa a tecla Ctrl+Enter
  void _handleKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.enter) {
      // Adiciona a tarefa e minimiza para o tray
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
        title: const Text('Adicionar Tarefa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sair',
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
                  // Informação de usuário logado
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Logado como: ${widget.userEmail}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  
                  // Campo de título com foco automático
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Título da Tarefa',
                      border: OutlineInputBorder(),
                      hintText: 'Pressione Ctrl+Enter para adicionar',
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo de notas
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas/Comentários',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                  
                  // Mensagens de erro/sucesso
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
                  
                  // Botão de adicionar
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
                        : const Text('Adicionar Tarefa'),
                  ),
                  
                  // Dica para Windows
                  if (_isWindows)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'O aplicativo continuará rodando na bandeja do sistema quando fechado.',
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
