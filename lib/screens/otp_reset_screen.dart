import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../utils/app_toast.dart';

// ─── Palette (shared with auth screens) ──────────────────────────────────────
const Color _kPurple   = Color(0xFF7C5CFC);
const Color _kPurpleLt = Color(0xFF9B7EFD);
const Color _kPurpleDim = Color(0xFFEDE9FF);
const Color _kDark     = Color(0xFF1A1918);
const Color _kMid      = Color(0xFF6D6C6A);
const Color _kHint     = Color(0xFF9C9B99);
const Color _kFieldBg  = Color(0xFFF5F4F1);
const Color _kBorder   = Color(0xFFE5E4E1);

// ─── OtpResetScreen ───────────────────────────────────────────────────────────
class OtpResetScreen extends StatefulWidget {
  final String email;
  const OtpResetScreen({super.key, required this.email});

  @override
  State<OtpResetScreen> createState() => _OtpResetScreenState();
}

class _OtpResetScreenState extends State<OtpResetScreen>
    with SingleTickerProviderStateMixin {
  // ── OTP ──────────────────────────────────────────────────────────────────
  final List<TextEditingController> _otpCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  bool _distributing = false;

  // ── Password ──────────────────────────────────────────────────────────────
  final _formKey    = GlobalKey<FormState>();
  final _passCtrl   = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;

  // ── Cursor blink animation for active OTP box ─────────────────────────────
  late final AnimationController _cursor;
  late final Animation<double>   _cursorAnim;

  bool get _otpComplete =>
      _otpCtrl.every((c) => c.text.length == 1);

  // Used in _submit() when API is wired in the next step
  String get _otpValue => _otpCtrl.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();

    // Cursor blink (500 ms on/off)
    _cursor = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _cursorAnim = _cursor;

    // Rebuild on focus change so box borders update
    for (final f in _otpFocus) {
      f.addListener(() { if (mounted) setState(() {}); });
    }

    // Auto-focus first box after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocus[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _cursor.dispose();
    for (final c in _otpCtrl) { c.dispose(); }
    for (final f in _otpFocus) { f.dispose(); }
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── OTP input handler ────────────────────────────────────────────────────
  void _onOtpChanged(int idx, String val) {
    if (_distributing) return;

    final digits = val.replaceAll(RegExp(r'\D'), '');

    if (digits.length > 1) {
      // ── Paste: fill boxes starting at idx ─────────────────────────────
      _distributing = true;
      for (int j = 0; j < digits.length && j < 6; j++) {
        _otpCtrl[j].text = digits[j];
        _otpCtrl[j].selection =
            TextSelection.collapsed(offset: 1);
      }
      final next = (digits.length >= 6 ? 5 : digits.length).clamp(0, 5);
      _otpFocus[next].requestFocus();
      _distributing = false;
      setState(() {});
      return;
    }

    if (digits.length == 1) {
      _otpCtrl[idx].text = digits;
      _otpCtrl[idx].selection = const TextSelection.collapsed(offset: 1);
      if (idx < 5) {
        _otpFocus[idx + 1].requestFocus();
      } else {
        _otpFocus[idx].unfocus();
      }
    } else {
      _otpCtrl[idx].text = '';
    }
    setState(() {});
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_otpComplete) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.resetPassword(
        email:       widget.email,
        code:        _otpValue,
        newPassword: _passCtrl.text,
      );
      if (!mounted) return;
      _showSuccessDialog();
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(e.trKey.tr());
    } catch (_) {
      if (!mounted) return;
      _showError('auth.errorServer'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) => AppToast.error(context, msg);

  void _showSuccessDialog() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x881A1525),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      pageBuilder: (dialogCtx, __, ___) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x201A1525),
                        offset: Offset(0, 20),
                        blurRadius: 60),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success icon
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF86EFAC), width: 1.5),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Color(0xFF16A34A), size: 38),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'auth.resetSuccess'.tr(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1525),
                          letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'auth.resetSuccessDesc'.tr(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: const Color(0xFF6D6C6A),
                          height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    // Button
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(dialogCtx).pop();
                          // Clear the whole auth stack and show LoginScreen
                          Navigator.of(context).popUntil(
                              (route) => route.isFirst);
                        },
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_kPurple, _kPurpleLt],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x557C5CFC),
                                  offset: Offset(0, 4),
                                  blurRadius: 14),
                            ],
                          ),
                          child: Text(
                            'auth.goToLogin'.tr(),
                            style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
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
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 600
            ? _buildWide(constraints)
            : _buildNarrow(),
      ),
    );
  }

  Widget _buildWide(BoxConstraints constraints) {
    final panelW = (constraints.maxWidth * 0.45).clamp(280.0, 520.0);
    return Row(children: [
      SizedBox(width: panelW, height: double.infinity, child: const _OtpLeftPanel()),
      Expanded(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _formColumn(),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildNarrow() {
    return Stack(children: [
      _background(),
      _decoCircle(left: -60, top: -40, size: 200, color: const Color(0x087C5CFC), opacity: 0.6),
      _decoCircle(left: 320, top: 720, size: 150, color: const Color(0x10D89575), opacity: 0.5),
      SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _formColumn(),
          ),
        ),
      ),
    ]);
  }

  Widget _formColumn() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.arrow_back_rounded, color: _kDark, size: 24),
                  const SizedBox(width: 8),
                  Text('auth.back'.tr(),
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w500, color: _kDark)),
                ]),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 36),
                  _heroSection(),
                  const SizedBox(height: 32),
                  _otpSection(),
                  const SizedBox(height: 10),
                  _resendRow(),
                  const SizedBox(height: 28),
                  _divider(),
                  const SizedBox(height: 24),
                  _passwordSection(),
                  const SizedBox(height: 28),
                  _submitButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Background ───────────────────────────────────────────────────────────
  Widget _background() => Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3EEFF), Color(0xFFFFF7F3), Colors.white],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      );

  Widget _decoCircle({
    required double left,
    required double top,
    required double size,
    required Color color,
    required double opacity,
  }) =>
      Positioned(
        left: left,
        top: top,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      );

  // ─── Hero ─────────────────────────────────────────────────────────────────
  Widget _heroSection() {
    return Column(
      children: [
        // Icon — layered: outer circle + inner icon
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFFF3EEFF),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x157C5CFC),
                      offset: Offset(0, 4),
                      blurRadius: 20),
                ],
              ),
            ),
            const Icon(Icons.sms_outlined, color: _kPurple, size: 38),
            // Badge circle with check
            Positioned(
              bottom: 8, right: 8,
              child: Container(
                width: 26, height: 26,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kPurple, _kPurpleLt],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tag_rounded,
                    color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'auth.otpTitle'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: _kDark),
        ),
        const SizedBox(height: 8),
        Text(
          'auth.otpSubtitle'.tr(namedArgs: {'email': widget.email}),
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
              fontSize: 14, color: _kMid, height: 1.5),
        ),
      ],
    );
  }

  // ─── OTP Section ──────────────────────────────────────────────────────────
  Widget _otpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'auth.otpLabel'.tr(),
          style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kDark),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _otpBox(i)),
        ),
      ],
    );
  }

  Widget _otpBox(int i) {
    final filled     = _otpCtrl[i].text.isNotEmpty;
    final focused    = _otpFocus[i].hasFocus;
    final showCursor = focused && !filled;

    return SizedBox(
      width: 46,
      height: 58,
      child: Focus(
        onKeyEvent: (_, event) {
          // Backspace on empty box → move to previous
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _otpCtrl[i].text.isEmpty &&
              i > 0) {
            _otpCtrl[i - 1].clear();
            _otpFocus[i - 1].requestFocus();
            setState(() {});
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextFormField(
          controller:   _otpCtrl[i],
          focusNode:    _otpFocus[i],
          keyboardType: TextInputType.number,
          textAlign:    TextAlign.center,
          maxLength:    null,
          showCursor:   false, // we draw our own cursor
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (val) => _onOtpChanged(i, val),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _kDark,
            letterSpacing: 0,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: filled
                ? _kPurpleDim
                : focused
                    ? Colors.white
                    : _kFieldBg,
            contentPadding: EdgeInsets.zero,
            // Blinking cursor bar rendered via suffix
            suffix: showCursor
                ? AnimatedBuilder(
                    animation: _cursorAnim,
                    builder: (_, __) => Opacity(
                      opacity: _cursorAnim.value,
                      child: Container(
                        width: 2, height: 24,
                        color: _kPurple,
                      ),
                    ),
                  )
                : null,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: focused ? _kPurple : _kBorder,
                    width: focused ? 2 : 1)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: filled ? _kPurpleLt : _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kPurple, width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.redAccent)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Colors.redAccent, width: 2)),
          ),
        ),
      ),
    );
  }

  // ─── Resend row ───────────────────────────────────────────────────────────
  Widget _resendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('auth.resendCode'.tr(),
            style: GoogleFonts.outfit(fontSize: 13, color: _kMid)),
        const SizedBox(width: 4),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            // Go back to ForgotPasswordScreen so user can request a new code
            onTap: () => Navigator.pop(context),
            child: Text(
              'auth.resendAction'.tr(),
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kPurple),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Divider ──────────────────────────────────────────────────────────────
  Widget _divider() {
    return Row(children: [
      const Expanded(child: Divider(color: Color(0xFFECECEC))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'auth.newPassword'.tr(),
          style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kHint),
        ),
      ),
      const Expanded(child: Divider(color: Color(0xFFECECEC))),
    ]);
  }

  // ─── Password section ─────────────────────────────────────────────────────
  Widget _passwordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _passwordField(
          ctrl:      _passCtrl,
          hint:      'auth.newPassword'.tr(),
          obscure:   _obscurePass,
          onToggle:  () => setState(() => _obscurePass = !_obscurePass),
          action:    TextInputAction.next,
          validator: (v) {
            if (v == null || v.isEmpty) return 'auth.validationPassword'.tr();
            if (v.length < 6) return 'auth.validationPasswordMin'.tr();
            return null;
          },
        ),
        const SizedBox(height: 12),
        _passwordField(
          ctrl:     _confirmCtrl,
          hint:     'auth.confirmPassword'.tr(),
          obscure:  _obscureConfirm,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
          action:   TextInputAction.done,
          onSubmit: (_) => _submit(),
          validator: (v) {
            if (v == null || v.isEmpty) return 'auth.validationPassword'.tr();
            if (v != _passCtrl.text) return 'auth.passwordsNoMatch'.tr();
            return null;
          },
        ),
      ],
    );
  }

  Widget _passwordField({
    required TextEditingController ctrl,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmit,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller:         ctrl,
      obscureText:        obscure,
      textInputAction:    action,
      onFieldSubmitted:   onSubmit,
      style: GoogleFonts.outfit(fontSize: 15, color: _kDark),
      validator:          validator,
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: GoogleFonts.outfit(fontSize: 15, color: _kHint),
        filled:    true,
        fillColor: _kFieldBg,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 18, right: 12),
          child: const Icon(Icons.lock_outline_rounded,
              color: _kHint, size: 20),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _kHint,
                size: 20,
              ),
            ),
          ),
        ),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _kPurple, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.5)),
      ),
    );
  }

  // ─── Submit button ─────────────────────────────────────────────────────────
  Widget _submitButton() {
    final enabled = _otpComplete && !_isLoading;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? _submit : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_kPurple, _kPurpleLt])
                : null,
            color: _isLoading
                ? const Color(0xFFBDB0F8)
                : enabled ? null : const Color(0xFFE5E2F0),
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                        color: Color(0x357C5CFC),
                        offset: Offset(0, 6),
                        blurRadius: 24)
                  ]
                : null,
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    'auth.resetPassword'.tr(),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? Colors.white
                          : const Color(0xFFADA8BE),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Left decorative panel (tablet / web) ────────────────────────────────────
class _OtpLeftPanel extends StatelessWidget {
  const _OtpLeftPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4C23C8), Color(0xFF7C5CFC), Color(0xFF9B7EFD)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(top: -60, left: -60,
              child: _OtpOrb(size: 280, color: Colors.white.withValues(alpha: 0.06))),
          Positioned(bottom: -40, right: -40,
              child: _OtpOrb(size: 220, color: Colors.white.withValues(alpha: 0.08))),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Icon(Icons.sms_outlined, color: Colors.white, size: 44),
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.tag_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'DanceWithMe',
                  style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'auth.helpNote'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.75),
                      height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpOrb extends StatelessWidget {
  final double size;
  final Color  color;
  const _OtpOrb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}
