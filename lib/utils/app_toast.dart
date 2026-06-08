import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Public API ───────────────────────────────────────────────────────────────
class AppToast {
  AppToast._();

  static void success(BuildContext context, String message) =>
      _insert(context, message, _ToastKind.success);

  static void error(BuildContext context, String message) =>
      _insert(context, message, _ToastKind.error);

  static void info(BuildContext context, String message) =>
      _insert(context, message, _ToastKind.info);

  static void _insert(BuildContext context, String message, _ToastKind kind) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        message: message,
        kind:    kind,
        onDone:  () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

// ─── Kind ─────────────────────────────────────────────────────────────────────
enum _ToastKind { success, error, info }

// ─── Overlay widget ───────────────────────────────────────────────────────────
class _ToastOverlay extends StatefulWidget {
  final String       message;
  final _ToastKind   kind;
  final VoidCallback onDone;

  const _ToastOverlay({
    required this.message,
    required this.kind,
    required this.onDone,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _timer = Timer(const Duration(milliseconds: 3200), _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final mq     = MediaQuery.of(context);
    final topPad = mq.viewPadding.top + 8;
    final maxW   = (mq.size.width - 32).clamp(0.0, 480.0);

    return Positioned(
      top: topPad, left: 0, right: 0,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: GestureDetector(
                onTap: _dismiss,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: maxW,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: _color(widget.kind),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _color(widget.kind).withValues(alpha: 0.38),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(children: [
                      Icon(_icon(widget.kind), color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _color(_ToastKind k) => switch (k) {
    _ToastKind.success => const Color(0xFF22C55E),
    _ToastKind.error   => const Color(0xFFEF4444),
    _ToastKind.info    => const Color(0xFF3B82F6),
  };

  static IconData _icon(_ToastKind k) => switch (k) {
    _ToastKind.success => Icons.check_circle_outline_rounded,
    _ToastKind.error   => Icons.error_outline_rounded,
    _ToastKind.info    => Icons.info_outline_rounded,
  };
}
