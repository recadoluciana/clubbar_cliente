import 'dart:math' as math;
import 'package:clubbar_cliente/screens/main/main_navigation_screen.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entradaController;
  late AnimationController _vooController;
  late AnimationController _particulasController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _logoSlide;

  bool _olhoFechado = false;

  @override
  void initState() {
    super.initState();

    _entradaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    _vooController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _particulasController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _logoScale = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(parent: _entradaController, curve: Curves.easeOutBack),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entradaController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entradaController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeIn),
      ),
    );

    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entradaController,
            curve: Curves.easeOutCubic,
          ),
        );

    _entradaController.forward();
    _vooController.repeat(reverse: true);
    _particulasController.repeat();

    _iniciarPiscada();

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    });
  }

  Future<void> _iniciarPiscada() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      setState(() => _olhoFechado = true);
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() => _olhoFechado = false);

      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() => _olhoFechado = true);
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() => _olhoFechado = false);
    }
  }

  @override
  void dispose() {
    _entradaController.dispose();
    _vooController.dispose();
    _particulasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final tamanhoLogo = largura * 0.34;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF08090D), Color(0xFF141726), Color(0xFF1F2340)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -70,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -110,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.deepPurple.withOpacity(0.10),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _particulasController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _ParticlesPainter(_particulasController.value),
                );
              },
            ),
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _entradaController,
                  _vooController,
                ]),
                builder: (context, child) {
                  final vooY =
                      math.sin(_vooController.value * 2 * math.pi) * 10;
                  final vooX = math.cos(_vooController.value * 2 * math.pi) * 4;
                  final rotacao =
                      math.sin(_vooController.value * 2 * math.pi) * 0.035;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: SlideTransition(
                          position: _logoSlide,
                          child: Transform.translate(
                            offset: Offset(vooX, vooY),
                            child: Transform.rotate(
                              angle: rotacao,
                              child: Transform.scale(
                                scale: _logoScale.value,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: tamanhoLogo + 60,
                                      height: tamanhoLogo + 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Colors.amber.withOpacity(0.22),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: tamanhoLogo,
                                      height: tamanhoLogo,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber.withOpacity(
                                              0.20,
                                            ),
                                            blurRadius: 36,
                                            spreadRadius: 4,
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.30,
                                            ),
                                            blurRadius: 22,
                                            offset: const Offset(0, 14),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(30),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 90,
                                          ),
                                          switchInCurve: Curves.easeIn,
                                          switchOutCurve: Curves.easeOut,
                                          child: Image.asset(
                                            _olhoFechado
                                                ? 'assets/images/corujao_piscando.png'
                                                : 'assets/images/corujao.png',
                                            key: ValueKey(_olhoFechado),
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          children: [
                            TypingText(
                              text: '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sua balada começa aqui',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.80),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration speed;

  const TypingText({
    super.key,
    required this.text,
    required this.style,
    this.speed = const Duration(milliseconds: 70),
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _visibleText = '';

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  Future<void> _startTyping() async {
    for (int i = 0; i <= widget.text.length; i++) {
      await Future.delayed(widget.speed);
      if (!mounted) return;
      setState(() {
        _visibleText = widget.text.substring(0, i);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(_visibleText, style: widget.style);
  }
}

class _ParticlesPainter extends CustomPainter {
  final double progress;

  _ParticlesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(12);

    for (int i = 0; i < 22; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;

      final offsetY = (progress * 40 + i * 6) % size.height;
      final y = (baseY - offsetY + size.height) % size.height;
      final x = baseX + math.sin((progress * 2 * math.pi) + i) * 6;

      final radius = 1.5 + random.nextDouble() * 2.8;

      paint.color = (i % 3 == 0)
          ? Colors.amber.withOpacity(0.20)
          : Colors.white.withOpacity(0.12);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
