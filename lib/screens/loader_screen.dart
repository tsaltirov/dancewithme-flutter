import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Palette (from loader.pen) ────────────────────────────────
const Color _kPurple   = Color(0xFF7C5CFC);
const Color _kPurpleDk = Color(0xFF5A3ED9);
const Color _kPurpleLt = Color(0xFFA78BFA);
const Color _kLavender = Color(0xFFD8B4FE);
const Color _kPeach    = Color(0xFFD89575);
const Color _kPinkBg   = Color(0xFFFFF0F5);
const Color _kGray     = Color(0xFF9C9B99);

class LoaderScreen extends StatefulWidget {
  final Widget nextScreen;
  const LoaderScreen({super.key, required this.nextScreen});

  @override
  State<LoaderScreen> createState() => _LoaderScreenState();
}

class _LoaderScreenState extends State<LoaderScreen>
    with TickerProviderStateMixin {
  // Rings: each value 0→1 = one full revolution
  late final AnimationController _ring1;  // back,  slow  CW  (10 s)
  late final AnimationController _ring2;  // mid,   med   CCW  (7 s)
  late final AnimationController _ring3;  // front, fast  CW   (4.5 s)

  late final AnimationController _pulse;   // sphere breathe   (1.8 s)
  late final AnimationController _float;   // orb sine float   (2.4 s)
  late final AnimationController _dots;    // bounce dots seq  (1.2 s)
  late final AnimationController _sparkle; // sparkle twinkle  (2.2 s)
  late final AnimationController _fade;    // exit fade-out    (450 ms)

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _ring1   = AnimationController(vsync: this, duration: const Duration(milliseconds: 10000))..repeat();
    _ring2   = AnimationController(vsync: this, duration: const Duration(milliseconds:  7000))..repeat();
    _ring3   = AnimationController(vsync: this, duration: const Duration(milliseconds:  4500))..repeat();
    _pulse   = AnimationController(vsync: this, duration: const Duration(milliseconds:  1800))..repeat();
    _float   = AnimationController(vsync: this, duration: const Duration(milliseconds:  2400))..repeat();
    _dots    = AnimationController(vsync: this, duration: const Duration(milliseconds:  1200))..repeat();
    _sparkle = AnimationController(vsync: this, duration: const Duration(milliseconds:  2200))..repeat();
    _fade    = AnimationController(vsync: this, duration: const Duration(milliseconds:   450));

    _navTimer = Timer(const Duration(milliseconds: 2800), _exit);
  }

  void _exit() {
    if (!mounted) return;
    _fade.forward().then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.nextScreen,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ));
    });
  }

  @override
  void dispose() {
    _ring1.dispose();
    _ring2.dispose();
    _ring3.dispose();
    _pulse.dispose();
    _float.dispose();
    _dots.dispose();
    _sparkle.dispose();
    _fade.dispose();
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0)
          .animate(CurvedAnimation(parent: _fade, curve: Curves.easeOut)),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.expand(
          child: CustomPaint(
            painter: const _BgPainter(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 402),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _loaderZone(),
                    const SizedBox(height: 32),
                    _textZone(),
                    const SizedBox(height: 24),
                    _dotRow(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 320×320 Loader Zone ──────────────────────────────────────
  Widget _loaderZone() {
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        children: [
          // Rings + sphere (all GPU-composited via CustomPainter)
          AnimatedBuilder(
            animation: Listenable.merge([_ring1, _ring2, _ring3, _pulse]),
            builder: (_, __) => CustomPaint(
              size: const Size(320, 320),
              painter: _LoaderPainter(
                ring1:  _ring1.value * 2 * math.pi,
                ring2: -_ring2.value * 2 * math.pi,          // CCW
                ring3:  _ring3.value * 2 * math.pi,
                pulse:  1.0 + math.sin(_pulse.value * 2 * math.pi) * 0.04,
              ),
            ),
          ),

          // Dancer icon at sphere center (x=138, y=138 from pen)
          const Positioned(
            left: 138, top: 138,
            child: SizedBox(
              width: 44, height: 44,
              child: Icon(Icons.sports_gymnastics, color: Colors.white, size: 30),
            ),
          ),

          // Orb Note 1 — top-right, purple  (x=248, y=100, w=36)
          _orbNote(248, 100, 0.00, 36,
            const [Color(0xFFF3EEFF), _kLavender, _kPurpleLt],
            Icons.music_note, _kPurple, 18,
            const Color(0x447C5CFC)),

          // Orb Note 2 — left-mid, peach    (x=36, y=165, w=30)
          _orbNote(36, 165, 0.60, 30,
            const [_kPinkBg, Color(0xFFF5C6D0), _kPeach],
            Icons.queue_music, _kPeach, 14,
            const Color(0x44D89575)),

          // Orb Note 3 — top-left, purple   (x=55, y=55, w=26)
          _orbNote(55, 55, 0.30, 26,
            const [Colors.white, Color(0xFFC4AEFF), _kPurple],
            Icons.audiotrack, Colors.white, 12,
            const Color(0x337C5CFC)),

          // Sparkles
          _sparkleWidget(270,  60, const Color(0xFFC4AEFF), 8, 0.00),
          _sparkleWidget( 20, 130, const Color(0xFFD8B4FE), 6, 0.20),
          _sparkleWidget(290, 230, const Color(0xFFE8DEFF), 5, 0.45),
          _sparkleWidget( 45, 270, const Color(0xFFC4AEFF), 7, 0.65),
          _sparkleWidget(230, 270, _kPeach,                 4, 0.85),
        ],
      ),
    );
  }

  Widget _orbNote(
    double left, double top, double phase, double size,
    List<Color> colors, IconData icon, Color iconColor,
    double iconSize, Color shadow,
  ) {
    return AnimatedBuilder(
      animation: _float,
      builder: (_, __) {
        final dy = math.sin((_float.value + phase) * 2 * math.pi) * 5;
        return Positioned(
          left: left,
          top: top + dy,
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                radius: 0.85,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(color: shadow, blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Center(child: Icon(icon, color: iconColor, size: iconSize)),
          ),
        );
      },
    );
  }

  Widget _sparkleWidget(
    double left, double top, Color color, double size, double phase,
  ) {
    return AnimatedBuilder(
      animation: _sparkle,
      builder: (_, __) {
        final opacity =
            (0.25 + 0.75 * math.sin((_sparkle.value + phase) * 2 * math.pi).abs())
                .clamp(0.0, 1.0);
        return Positioned(
          left: left, top: top,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size, height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [BoxShadow(color: color, blurRadius: size)],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Text Zone ────────────────────────────────────────────────
  Widget _textZone() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kPurpleDk, _kPurple, _kPurpleLt],
          ).createShader(r),
          child: Text(
            'DanceWithMe',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: Colors.white, // replaced by ShaderMask
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Getting the rhythm ready...',
          style: GoogleFonts.outfit(fontSize: 14, color: _kGray),
        ),
      ],
    );
  }

  // ─── Loading Dots ─────────────────────────────────────────────
  Widget _dotRow() {
    return AnimatedBuilder(
      animation: _dots,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(0, _kPurple,   const Color(0xFF7C5CFC), true),
          const SizedBox(width: 12),
          _dot(1, _kPurpleLt, const Color(0x99A78BFA), false), // 0.6 opacity
          const SizedBox(width: 12),
          _dot(2, _kLavender, const Color(0x59D8B4FE), false), // 0.35 opacity
        ],
      ),
    );
  }

  Widget _dot(int i, Color glowColor, Color dotColor, bool glow) {
    final t = _dots.value;
    final s = i / 3.0;
    final e = (i + 1) / 3.0;
    double dy = 0;
    if (t >= s && t <= e) {
      final norm = (t - s) / (e - s);
      dy = -math.sin(norm * math.pi) * 7;
    }
    return Transform.translate(
      offset: Offset(0, dy),
      child: Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dotColor,
          boxShadow: glow
              ? [BoxShadow(color: glowColor.withValues(alpha: 0.53), blurRadius: 8)]
              : null,
        ),
      ),
    );
  }
}

// ─── Background Painter — simulated mesh gradient ─────────────
class _BgPainter extends CustomPainter {
  const _BgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // White base
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    // Radial blobs at the 9 mesh-gradient points
    void blob(double fx, double fy, double fr, Color col, Color transparent) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(size.width * fx, size.height * fy),
            size.width * fr,
            [col, transparent],
          ),
      );
    }

    blob(0.10, 0.08, 0.65, const Color(0x70EDE7FF), const Color(0x00EDE7FF));
    blob(0.90, 0.07, 0.55, const Color(0x55FFF0F5), const Color(0x00FFF0F5));
    blob(0.08, 0.90, 0.55, const Color(0x50F0E6FF), const Color(0x00F0E6FF));
    blob(0.92, 0.93, 0.50, const Color(0x50FFF5F0), const Color(0x00FFF5F0));
    blob(0.50, 0.50, 0.35, const Color(0x20F3EEFF), const Color(0x00F3EEFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Loader Painter — rings + sphere ─────────────────────────
class _LoaderPainter extends CustomPainter {
  final double ring1, ring2, ring3, pulse;

  const _LoaderPainter({
    required this.ring1,
    required this.ring2,
    required this.ring3,
    required this.pulse,
  });

  // All ring elements are centered at (160, 160) in the 320×320 frame
  static const _c = Offset(160, 160);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Outer glow (r=140, radial)
    canvas.drawCircle(_c, 140, Paint()
      ..shader = ui.Gradient.radial(_c, 140,
        [const Color(0x127C5CFC), const Color(0x007C5CFC)]));

    // 2. Ring 3D Back   — r=110, stroke=3, slow CW
    _sweepRing(canvas, 110, 3, ring1, const [
      Color(0xAAB39DFC),
      Color(0xFFD8B4FE),
      Color(0x22B39DFC),
      Color(0xAAC084FC),
      Color(0xAAB39DFC),
    ], const [0.0, 0.25, 0.5, 0.75, 1.0]);

    // 3. Ring 3D Mid    — r=90, stroke=4, CCW, +45° base rotation
    _sweepRing(canvas, 90, 4, ring2 + math.pi / 4, const [
      Color(0xCC7C5CFC),
      Color(0xFFA78BFA),
      Color(0x227C5CFC),
      Color(0xCC9B7EFD),
      Color(0xCC7C5CFC),
    ], const [0.0, 0.3, 0.55, 0.8, 1.0]);

    // 4. Ring 3D Front  — r=70, stroke=5, CW, −30° base + outer glow
    canvas.drawCircle(_c, 70, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = const Color(0x557C5CFC));
    _sweepRing(canvas, 70, 5, ring3 - math.pi / 6, const [
      Color(0xFF7C5CFC),
      Color(0xFFA78BFA),
      Color(0x117C5CFC),
      Color(0xFFC084FC),
      Color(0xFF7C5CFC),
    ], const [0.0, 0.2, 0.5, 0.75, 1.0]);

    // 5. 3D Sphere
    _drawSphere(canvas, 50.0 * pulse);
  }

  void _sweepRing(
    Canvas canvas,
    double radius,
    double strokeW,
    double startAngle,
    List<Color> colors,
    List<double> stops,
  ) {
    canvas.drawCircle(_c, radius, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..shader = ui.Gradient.sweep(
        _c, colors, stops, TileMode.clamp,
        startAngle, startAngle + 2 * math.pi,
      ));
  }

  void _drawSphere(Canvas canvas, double r) {
    // Drop shadow (pen: #7C5CFC44, offset y=8, blur=32 → blur/2 for MaskFilter)
    canvas.drawCircle(_c + Offset(0, r * 0.16), r * 0.9, Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16)
      ..color = const Color(0x447C5CFC));

    // Sphere body — radial gradient, highlight center at (35%, 30%) of bounding box
    // → sphere center offset: (−0.3r, −0.4r)
    final hPt = Offset(_c.dx - r * 0.3, _c.dy - r * 0.4);
    canvas.drawCircle(_c, r, Paint()
      ..shader = ui.Gradient.radial(hPt, r * 1.5, const [
        Color(0xFFE8DEFF),
        Color(0xFFC4AEFF),
        Color(0xFF7C5CFC),
        Color(0xFF5A3ED9),
      ], [0.0, 0.4, 0.85, 1.0]));

    // Specular highlight — ellipse at (130,122)+20,14 = center(150,136)
    // offset from sphere center (160,160): (−10, −24)
    final hlC = Offset(_c.dx - 10, _c.dy - 24);
    canvas.drawOval(
      Rect.fromCenter(center: hlC, width: r * 0.75, height: r * 0.50),
      Paint()
        ..shader = ui.Gradient.radial(hlC, r * 0.35, const [
          Color(0xCCFFFFFF),
          Color(0x00FFFFFF),
        ]));
  }

  @override
  bool shouldRepaint(covariant _LoaderPainter old) =>
      old.ring1 != ring1 ||
      old.ring2 != ring2 ||
      old.ring3 != ring3 ||
      old.pulse != pulse;
}
