import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:LumorahAI/pages/MenuPrincipal.dart';
import 'package:LumorahAI/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Nuevo import

class IntroPage extends StatefulWidget {
  final int pageIndex;

  const IntroPage({Key? key, required this.pageIndex}) : super(key: key);

  @override
  _IntroPageState createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> with TickerProviderStateMixin {
  late AnimationController _contentController;
  late AnimationController _particlesController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonScaleAnimation;
  final StorageService _storageService = StorageService(); // Nueva instancia
  bool _vibrationEnabled = true; // Estado inicial

  final List<Map<String, dynamic>> _pageConfigs = [
    {
      'icon': Icons.message_rounded,
      'mainText': 'writeFreely'.tr(),
      'mainTextSize': 24.0,
      'subText': '',
      'subTextSize': 0.0,
      'buttonLabel': 'nextButton'.tr(),
      'nextPage': (context) => IntroPage(pageIndex: 2),
      'isLastPage': false, // Añade esto
    },
    {
      'icon': Icons.mic,
      'mainText': 'speakWithMic'.tr(),
      'mainTextSize': 30.0,
      'subText': 'iListen'.tr(),
      'subTextSize': 30.0,
      'buttonLabel': 'nextButton'.tr(),
      'nextPage': (context) => IntroPage(pageIndex: 3),
      'isLastPage': false, // Añade esto
    },
    {
      'icon': null,
      'mainText': 'speakYourWay'.tr(),
      'mainTextSize': 30.0,
      'subText': 'lumorahListens'.tr(),
      'subTextSize': 25.0,
      'buttonLabel': 'startButton'.tr(),
      'nextPage': (context) => Menuprincipal(),
      'isLastPage': true, // Añade esto
    },
  ];

  Future<void> _completeOnboarding() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    debugPrint('Onboarding marcado como completado'); // Para debug
  } catch (e) {
    debugPrint('Error guardando preferencia: $e');
  }
}
  @override
  void initState() {
    super.initState();
    // Controller for content animations (fade, slide, button scale)
    _contentController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..forward();

    // Controller for particle animation
    _particlesController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 20),
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeInOut),
    );

    _loadVibrationPreference(); // Cargar preferencia de vibración al iniciar
  }

  Future<void> _loadVibrationPreference() async {
    final vibrationEnabled =
        await _storageService.getString('vibration_enabled') == 'true' ||
            await _storageService.getString('vibration_enabled') ==
                null; // Por defecto true si no está configurado
    setState(() {
      _vibrationEnabled = vibrationEnabled;
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _particlesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configIndex = widget.pageIndex - 1;
    if (configIndex < 0 || configIndex >= _pageConfigs.length) {
      return Scaffold(
        body: Center(child: Text('Error: Invalid page index')),
      );
    }
    final config = _pageConfigs[configIndex];

    return Scaffold(
      backgroundColor: Color(0xFF88D5C2),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particlesController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ParticulasPainter(_particlesController.value),
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 20),
                _buildProgressBar(
                    currentPage: widget.pageIndex,
                    totalPages: _pageConfigs.length),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _contentController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.translate(
                          offset: _slideAnimation.value,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (config['icon'] != null)
                                Icon(
                                  config['icon'],
                                  size: 120,
                                  color: Colors.white,
                                ),
                              if (config['icon'] != null)
                                SizedBox(
                                    height: config['mainTextSize'] == 24.0
                                        ? 20
                                        : 30),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 25.0),
                                child: Text(
                                  config['mainText'],
                                  style: TextStyle(
                                    fontSize: config['mainTextSize'],
                                    color: Colors.black,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (config['subText'].isNotEmpty)
                                SizedBox(
                                    height: config['mainTextSize'] == 30.0
                                        ? 8
                                        : 28),
                              if (config['subText'].isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 8.0),
                                  child: Text(
                                    config['subText'],
                                    style: TextStyle(
                                      fontSize: config['subTextSize'],
                                      color: Colors.black,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.normal,
                                      height: 1.3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              SizedBox(height: 40),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
  padding: EdgeInsets.only(bottom: 50),
  child: ElevatedButton(
    onPressed: () async {
      if (_vibrationEnabled) {
        HapticFeedback.lightImpact();
      }
      
      if (widget.pageIndex == _pageConfigs.length) { // Verifica si es la última página
        await _completeOnboarding();
      }
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: _pageConfigs[widget.pageIndex - 1]['nextPage']
        ),
      );
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFFFDF8F2),
      foregroundColor: Colors.black87,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.symmetric(horizontal: 80, vertical: 15),
      elevation: 2,
    ),
    child: Text(
      config['buttonLabel'],
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
      {required int currentPage, required int totalPages}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        child: LinearProgressIndicator(
          value: currentPage / totalPages,
          backgroundColor: Colors.white.withOpacity(0.3),
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _ParticulasPainter extends CustomPainter {
  final double progress;
  final Random _random = Random();

  _ParticulasPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 25; i++) {
      final dx = (size.width * ((i * 17 + progress * 120) % 100) / 100);
      final dy = size.height * ((i * 13 + progress * 90) % 100) / 100;
      final radius = 1.8 + (i % 4);
      paint.color =
          Colors.white.withOpacity(0.1 + (_random.nextDouble() * 0.1));
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticulasPainter oldDelegate) => true;
}
