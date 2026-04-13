import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'forgot_password_screen.dart';
import 'home_screen.dart';

// ─── Palette ──────────────────────────────────────────────────
const Color _kPurple   = Color(0xFF7C5CFC);
const Color _kPurpleLt = Color(0xFF9B7EFD);
const Color _kDark     = Color(0xFF1A1918);
const Color _kMid      = Color(0xFF6D6C6A);
const Color _kHint     = Color(0xFF9C9B99);
const Color _kFieldBg  = Color(0xFFF5F4F1);
const Color _kBorder   = Color(0xFFE5E4E1);

// ─── Language options (code + locale) ─────────────────────────
const List<String>  _kLangCodes   = ['EN', 'ES', 'BG'];
const List<Locale>  _kLangLocales = [Locale('en'), Locale('es'), Locale('bg')];

// Dimensions of the segmented pill
const double _kSegW  = 46.0;   // width per segment
const double _kSegH  = 34.0;   // height of the selector track
const double _kPad   =  3.0;   // inner padding

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus  = FocusNode();

  bool _obscurePass = true;
  bool _isLoading   = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1200)); // TODO: replace with auth API
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            _background(),
            // Deco Circle 1 — top-left  (pen: x=-60, y=-40, 200×200)
            Positioned(
              left: -60, top: -40,
              child: Opacity(
                opacity: 0.6,
                child: Container(
                  width: 200, height: 200,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x087C5CFC),
                  ),
                ),
              ),
            ),
            // Deco Circle 2 — bottom-right  (pen: x=320, y=720, 150×150)
            Positioned(
              left: 320, top: 720,
              child: Opacity(
                opacity: 0.5,
                child: Container(
                  width: 150, height: 150,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x10D89575),
                  ),
                ),
              ),
            ),
            // Main content
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Language selector — fixed at top-right, doesn't scroll
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 14, 32, 0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _languageSelector(),
                          ),
                        ),
                        // ── Scrollable form content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 24),
                                _heroSection(),
                                const SizedBox(height: 40),
                                _emailField(),
                                const SizedBox(height: 16),
                                _passwordField(),
                                _forgotRow(),
                                const SizedBox(height: 28),
                                _signInButton(),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Language Selector (sliding segmented control) ────────────
  Widget _languageSelector() {
    // Resolve current active index
    final currentCode = context.locale.languageCode;
    final activeIdx   = _kLangLocales
        .indexWhere((l) => l.languageCode == currentCode)
        .clamp(0, _kLangLocales.length - 1);

    return Container(
      padding: const EdgeInsets.all(_kPad),
      decoration: BoxDecoration(
        // Subtle lavender track — matches the design palette
        color: const Color(0xFFEDE8FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width:  _kSegW * _kLangCodes.length,
        height: _kSegH,
        child: Stack(
          children: [
            // ── Sliding purple thumb ──────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left:   activeIdx * _kSegW,
              top:    0,
              bottom: 0,
              width:  _kSegW,
              child: Container(
                decoration: BoxDecoration(
                  color: _kPurple,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: const [
                    BoxShadow(
                      color:  Color(0x3D7C5CFC),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // ── Language labels ──────────────────────────────
            Row(
              children: List.generate(_kLangCodes.length, (i) {
                final active = i == activeIdx;
                return GestureDetector(
                  onTap: () {
                    if (!active) context.setLocale(_kLangLocales[i]);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width:  _kSegW,
                    height: _kSegH,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : const Color(0xFF9C8FD4),
                        ),
                        child: Text(_kLangCodes[i]),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Background ───────────────────────────────────────────────
  Widget _background() {
    return Container(
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
  }

  // ─── Hero Section ─────────────────────────────────────────────
  Widget _heroSection() {
    return Column(
      children: [
        // Logo Container  (pen: 88×88, gradient 135°, cornerRadius 100)
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kPurple, Color(0xFFA78BFA)],
            ),
            borderRadius: BorderRadius.circular(100),
            boxShadow: const [
              BoxShadow(
                color: Color(0x307C5CFC),
                offset: Offset(0, 8),
                blurRadius: 32,
              ),
            ],
          ),
          child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 12),
        Text(
          'app.name'.tr(),
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: _kDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'app.tagline'.tr(),
          style: GoogleFonts.outfit(fontSize: 15, color: _kMid),
        ),
      ],
    );
  }

  // ─── Email Field ──────────────────────────────────────────────
  Widget _emailField() {
    return TextFormField(
      controller: _emailCtrl,
      focusNode: _emailFocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _passFocus.requestFocus(),
      style: GoogleFonts.outfit(fontSize: 15, color: _kDark),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'auth.validationEmail'.tr() : null,
      decoration: _fieldDecoration(
        hint: 'auth.emailAddress'.tr(),
        prefixIcon: Icons.mail_outline_rounded,
      ),
    );
  }

  // ─── Password Field ───────────────────────────────────────────
  Widget _passwordField() {
    return TextFormField(
      controller: _passCtrl,
      focusNode: _passFocus,
      obscureText: _obscurePass,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _signIn(),
      style: GoogleFonts.outfit(fontSize: 15, color: _kDark),
      validator: (v) =>
          (v == null || v.isEmpty) ? 'auth.validationPassword'.tr() : null,
      decoration: _fieldDecoration(
        hint: 'auth.password'.tr(),
        prefixIcon: Icons.lock_outline_rounded,
        suffix: GestureDetector(
          onTap: () => setState(() => _obscurePass = !_obscurePass),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _obscurePass
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _kHint,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Shared InputDecoration ───────────────────────────────────
  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(fontSize: 15, color: _kHint),
      filled: true,
      fillColor: _kFieldBg,
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 18, right: 12),
        child: Icon(prefixIcon, color: _kHint, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    );
  }

  // ─── Forgot Row ───────────────────────────────────────────────
  Widget _forgotRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
          ),
          child: Text(
            'auth.forgotPassword'.tr(),
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _kPurple,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Sign In Button ───────────────────────────────────────────
  Widget _signInButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _signIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        decoration: BoxDecoration(
          gradient: _isLoading
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kPurple, _kPurpleLt],
                ),
          color: _isLoading ? const Color(0xFFBDB0F8) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x357C5CFC),
                    offset: Offset(0, 6),
                    blurRadius: 24,
                  ),
                ],
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
                  'auth.signIn'.tr(),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
