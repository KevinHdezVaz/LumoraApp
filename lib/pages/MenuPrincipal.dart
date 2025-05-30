import 'dart:math';
import 'package:LumorahAI/pages/home_page.dart';
import 'package:LumorahAI/pages/screens/SettingsModal.dart';
import 'package:LumorahAI/utils/PermissionService.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:LumorahAI/auth/auth_service.dart';
import 'package:LumorahAI/auth/login_page.dart';
import 'package:LumorahAI/auth/register_page.dart';
import 'package:LumorahAI/pages/screens/chats/ChatHistoryScreen.dart';
import 'package:LumorahAI/pages/screens/chats/ChatScreen.dart';
import 'package:LumorahAI/pages/screens/chats/VoiceChatScreen.dart';
import 'package:LumorahAI/utils/colors.dart';
import 'package:LumorahAI/services/storage_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:LumorahAI/pages/screens/WaveVisualizer.dart';
import 'package:flutter/painting.dart' as painting;

class Menuprincipal extends StatefulWidget {
  final int? sessionId;

  const Menuprincipal({
    this.sessionId,
  }) : super();

  @override
  _MenuprincipalState createState() => _MenuprincipalState();
}

class _MenuprincipalState extends State<Menuprincipal>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  late Animation<double> _sunAnimation;
  late AnimationController _sunController;
  final TextEditingController _textController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  final Color tiffanyColor = Color(0xFF88D5C2);
  final Color ivoryColor = Color(0xFFFDF8F2);
  final Color darkTextColor = Colors.black87;
  final Color lightTextColor = Colors.black;
  final Color micButtonColor = Color(0xFF4ECDC4);
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _currentSessionId;
  late AnimationController _particlesController;

  bool _isListening = false;
  bool _isSpeechInitialized = false;
  double _soundLevel = 0.0;

  // Mapa de códigos de idioma para reconocimiento de voz
  final Map<String, String> _speechLocales = {
    'es': 'es_ES',
    'en': 'en_US',
    'fr': 'fr_FR',
    'pt': 'pt_BR',
  };

  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.sessionId;

    _sunController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Controller for particle animation
    _particlesController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 20),
    )..repeat();
    _sunAnimation = Tween<double>(begin: 130.0, end: 200.0).animate(
      CurvedAnimation(parent: _sunController, curve: Curves.easeInOut),
    );

    _initializeSpeech();
    _loadStoredLanguage();
    _playStartupSound();
  }

  // En Menuprincipal
  Future<void> _initializeSpeech() async {
    try {
      final permissionService = PermissionService();
      final micStatus =
          await permissionService.checkOrRequest(Permission.microphone);

      if (!micStatus.isGranted) {
        if (micStatus.isPermanentlyDenied) {
          _showErrorSnackBar(
              'Por favor habilita los permisos de micrófono en Configuración');
          await openAppSettings();
        }
        return;
      }

      _isSpeechInitialized = await _speech.initialize(
        onStatus: (status) => debugPrint('Status: $status'),
        onError: (error) {
          debugPrint('Error: $error');
          setState(() {
            _isListening = false;
            _soundLevel = 0.0;
            _showErrorSnackBar(
                'Error en reconocimiento de voz: ${error.errorMsg}');
          });
        },
      );

      if (!_isSpeechInitialized && mounted) {
        _showErrorSnackBar('No se pudo inicializar el reconocimiento de voz');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
            'Error al inicializar reconocimiento de voz: ${e.toString()}');
      }
    }
  }

  Future<void> _loadStoredLanguage() async {
    final storedLanguage = await _storageService.getLanguage();
    if (storedLanguage != null && mounted) {
      context.setLocale(Locale(storedLanguage));
    }
  }

  @override
  void dispose() {
    _sunController.dispose();
    _textController.dispose();
    _particlesController.dispose();
    _audioPlayer.dispose();
    _speech.stop();
    _speech.cancel();
    super.dispose();
  }

  Future<bool> _isUserAuthenticated() async {
    final token = await _storageService.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> _getUserName() async {
    final user = await _storageService.getUser();
    return user?.nombre;
  }

  Future<void> _playStartupSound() async {
    try {
      final soundPref = await _storageService.getString('sound_enabled');
      final soundEnabled = soundPref == null ? true : soundPref == 'true';
      if (soundEnabled) {
        await _audioPlayer.setVolume(0.2);
        await _audioPlayer.play(AssetSource('sounds/inicio.mp3'));
      }
    } catch (e) {
      debugPrint('Error al reproducir sonido de inicio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('errorPlayingSound'.tr())),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WillPopScope(
          onWillPop: () async => false,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );

      await _authService.logout();

      if (mounted) {
        navigator.pop();
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => Menuprincipal()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) navigator.pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('logout_error'.tr(args: [e.toString()]))),
        );
      }
    }
  }

  void _showLoginModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => LoginModal(
        showRegisterPage: () {
          _showRegisterModal(context);
        },
        inputMode: 'keyboard',
      ),
    );
  }

  void _showRegisterModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => RegisterModal(
        showLoginPage: () {
          Navigator.pop(context);
          _showLoginModal(context);
        },
        inputMode: 'keyboard',
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'selectLanguage'.tr(),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildLanguageCard(
                    context,
                    'Español',
                    'es',
                    '🇪🇸',
                    Colors.red[700]!,
                  ),
                  _buildLanguageCard(
                    context,
                    'English',
                    'en',
                    '🇬🇧',
                    Colors.blue[700]!,
                  ),
                  _buildLanguageCard(
                    context,
                    'Français',
                    'fr',
                    '🇫🇷',
                    Colors.blue[600]!,
                  ),
                  _buildLanguageCard(
                    context,
                    'Português',
                    'pt',
                    '🇵🇹',
                    Colors.green[700]!,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard(BuildContext context, String languageName,
      String languageCode, String flag, Color color) {
    return GestureDetector(
      onTap: () async {
        await _storageService.saveLanguage(languageCode);
        if (mounted) {
          context.setLocale(Locale(languageCode));
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('languageChanged'.tr(args: [languageName])),
              backgroundColor: color.withOpacity(0.8),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ivoryColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              flag,
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(width: 10),
            Text(
              languageName,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SettingsModal(
        onSignOut: () => _signOut(context),
      ),
    );
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    try {
      // 1. Verificar el estado del permiso del micrófono
      var micStatus = await Permission.microphone.status;

      // 2. Solicitar permiso si no está concedido
      if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
        micStatus = await Permission.microphone.request();

        if (micStatus.isDenied) {
          _showErrorSnackBar(
              'Se requieren permisos de micrófono para continuar. Habilítalos en Configuración.');
          return;
        }
      }

      // 3. Inicializar reconocimiento de voz si no está listo
      if (!_isSpeechInitialized) {
        _isSpeechInitialized = await _speech.initialize(
          onStatus: (status) => debugPrint('Status: $status'),
          onError: (error) {
            debugPrint('Error: $error');
            setState(() {
              _isListening = false;
              _soundLevel = 0.0;
              _showErrorSnackBar(
                  'Error en reconocimiento de voz: ${error.errorMsg}');
            });
          },
        );

        if (!_isSpeechInitialized) {
          _showErrorSnackBar('No se pudo inicializar el reconocimiento de voz');
          return;
        }
      }

      // 4. Configurar el idioma para el reconocimiento
      final localeId = _speechLocales[context.locale.languageCode] ?? 'es_ES';
      debugPrint('Iniciando reconocimiento con locale: $localeId');

      // 5. Iniciar la escucha
      setState(() {
        _isListening = true;
        _textController.clear();
      });

      _speech.listen(
        onResult: (result) {
          debugPrint(
              'Resultado: ${result.recognizedWords} (Confianza: ${result.confidence})');
          setState(() {
            _textController.text = result.recognizedWords;
            _textController.selection = TextSelection.collapsed(
              offset: _textController.text.length,
            );
          });
        },
        onSoundLevelChange: (level) {
          setState(() {
            _soundLevel = level.clamp(0.0, 100.0);
          });
        },
        localeId: localeId,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      );
    } on PlatformException catch (e) {
      debugPrint('Error de plataforma: ${e.toString()}');
      setState(() {
        _isListening = false;
      });

      if (e.code == 'speech_recognition_not_available') {
        _showErrorSnackBar('Reconocimiento de voz no disponible');
      } else if (e.code == 'microphone_access_denied') {
        _showErrorSnackBar('Acceso al micrófono denegado');
      } else {
        _showErrorSnackBar('Error desconocido: ${e.message}');
      }
    } catch (e) {
      debugPrint('Error inesperado: ${e.toString()}');
      setState(() {
        _isListening = false;
      });
      _showErrorSnackBar('Error al iniciar: ${e.toString()}');
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
      _showErrorSnackBar('Error al detener: $e');
    }
  }

  Widget _buildVoiceVisualizer() {
    if (!_isListening) return const SizedBox.shrink();
    return WaveVisualizer(
      soundLevel: _soundLevel,
      primaryColor: Colors.grey,
      secondaryColor: Colors.black,
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context,
      {bool isVoice = false}) async {
    final isAuthenticated = await _isUserAuthenticated();
    if (!isAuthenticated) {
      _showLoginModal(context);
      return;
    }

    final inputMode = isVoice ? 'voice' : 'keyboard';
    final message = _textController.text.trim();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
          initialMessages: [],
          inputMode: inputMode,
          sessionId: null,
          initialMessage: message.isNotEmpty ? message : null,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var slideAnimation = animation.drive(tween);

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: Duration(milliseconds: 300),
      ),
    );

    if (message.isNotEmpty) {
      _textController.clear();
    }
  }

  Widget _buildKeyboardInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (_isListening) _buildVoiceVisualizer(),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final textPainter = TextPainter(
                text: TextSpan(
                  text:
                      _textController.text.isEmpty ? ' ' : _textController.text,
                  style: const TextStyle(fontSize: 16, fontFamily: 'Lora'),
                ),
                maxLines: null,
                textDirection: painting.TextDirection.ltr,
              )..layout(maxWidth: constraints.maxWidth - 80);

              final lineCount = textPainter.computeLineMetrics().length;
              final baseHeight = 60.0;
              final lineHeight = 20.0;
              final calculatedHeight =
                  baseHeight + (lineCount - 1) * lineHeight;
              final textFieldHeight = calculatedHeight.clamp(baseHeight, 200.0);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                height: textFieldHeight,
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'writeHint'.tr(),
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isListening ? Icons.stop_circle : Icons.mic_none,
                            color: _isListening ? Colors.red : micButtonColor,
                            size: _isListening ? 30 : 24,
                          ),
                          tooltip: _isListening
                              ? 'Detener grabación'
                              : 'Iniciar grabación',
                          onPressed: () async {
                            if (_isListening) {
                              await _stopListening();
                            } else {
                              await _startListening();
                            }
                          },
                        ),
                        if (_textController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.send, color: micButtonColor),
                            onPressed: () => _handleAction(context),
                          ),
                        if (_textController.text.isEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.record_voice_over,
                                color: micButtonColor,
                                size: 22,
                              ),
                              tooltip: 'Chat de voz avanzado',
                              onPressed: () async {
                                final isAuthenticated =
                                    await _isUserAuthenticated();
                                if (isAuthenticated) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => VoiceChatScreen(
                                        language: context.locale.languageCode,
                                      ),
                                    ),
                                  );
                                } else {
                                  _showLoginModal(context);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  onChanged: (text) {
                    setState(() {}); // Reconstruir para actualizar la altura
                  },
                  scrollController: ScrollController(),
                ),
              );
            },
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tiffanyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: lightTextColor.withOpacity(0.9)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: Container(
          color: tiffanyColor.withOpacity(0.95),
          child: FutureBuilder<bool>(
            future: _isUserAuthenticated(),
            builder: (context, authSnapshot) {
              bool isAuthenticated = authSnapshot.data ?? false;
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  FutureBuilder<String?>(
                    future: _getUserName(),
                    builder: (context, userSnapshot) {
                      String headerText;
                      if (isAuthenticated &&
                          userSnapshot.hasData &&
                          userSnapshot.data != null) {
                        headerText = 'Hola, ${userSnapshot.data}!'.tr();
                      } else {
                        headerText = 'helloLumorah'.tr();
                      }
                      return DrawerHeader(
                        decoration: BoxDecoration(
                          color: ivoryColor.withOpacity(0.7),
                        ),
                        child: Text(
                          headerText,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: darkTextColor,
                            fontFamily: 'Inter',
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.chat, color: lightTextColor),
                    title: Text(
                      'chat'.tr(),
                      style: TextStyle(
                        color: lightTextColor,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  ChatScreen(
                            initialMessages: [],
                            inputMode: 'keyboard',
                            sessionId: null,
                          ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            const begin = Offset(1.0, 0.0);
                            const end = Offset.zero;
                            const curve = Curves.easeInOut;

                            var tween = Tween(begin: begin, end: end)
                                .chain(CurveTween(curve: curve));
                            var slideAnimation = animation.drive(tween);

                            return SlideTransition(
                              position: slideAnimation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          transitionDuration: Duration(milliseconds: 300),
                        ),
                      );
                    },
                  ),
                  if (isAuthenticated)
                    ListTile(
                      leading: Icon(Icons.history, color: lightTextColor),
                      title: Text(
                        'chatHistory'.tr(),
                        style: TextStyle(
                          color: lightTextColor,
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ListTile(
                    leading: Icon(Icons.language, color: lightTextColor),
                    title: Text(
                      'changeLanguage'.tr(),
                      style: TextStyle(
                        color: lightTextColor,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showLanguageSelector(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.settings, color: lightTextColor),
                    title: Text(
                      'settings'.tr(),
                      style: TextStyle(
                        color: lightTextColor,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showSettingsModal(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      isAuthenticated ? Icons.logout : Icons.login,
                      color: lightTextColor,
                    ),
                    title: Text(
                      isAuthenticated ? 'logOut'.tr() : 'logIn'.tr(),
                      style: TextStyle(
                        color: lightTextColor,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (isAuthenticated) {
                        _signOut(context);
                      } else {
                        _showLoginModal(context);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: ParticulasFlotantes()),
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _sunAnimation,
                builder: (context, child) {
                  return Container(
                    width: _sunAnimation.value,
                    height: _sunAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFE5B4).withOpacity(0.7),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFFE5B4).withOpacity(0.8),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 80), // Reduced from 180 to move content up
                Text(
                  'writeOrSpeak'.tr(),
                  style: TextStyle(
                    fontSize: 30,
                    color: Colors.black,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Text(
                  'iAmHere'.tr(),
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.black.withOpacity(0.9),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),
                _buildKeyboardInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ParticulasFlotantes extends StatefulWidget {
  @override
  _ParticulasFlotantesState createState() => _ParticulasFlotantesState();
}

class _ParticulasFlotantesState extends State<ParticulasFlotantes>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(seconds: 15), // Reducido para movimiento más rápido
    )..repeat();

    // Generar partículas con velocidades más visibles
    for (int i = 0; i < 20; i++) {
      // Aumentar número de partículas
      _particles.add(Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 3 + 2, // Tamaños más grandes
        speed: _random.nextDouble() * 0.3 + 0.1, // Velocidades más altas
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox.expand(
          child: CustomPaint(
            painter: _ParticlesPainter(_particles, _controller.value),
          ),
        );
      },
    );
  }
}

class Particle {
  double x, y, size, speed;
  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<Particle> particles;
  final double time;

  _ParticlesPainter(this.particles, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
          .withOpacity(0.2) // Aumentar opacidad para mejor visibilidad
      ..style = PaintingStyle.fill;

    for (var particle in particles) {
      final x = (particle.x + time * particle.speed) % 1.0 * size.width;
      final y = (particle.y + time * particle.speed * 0.5) % 1.0 * size.height;
      canvas.drawCircle(Offset(x, y), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) => true;
}
