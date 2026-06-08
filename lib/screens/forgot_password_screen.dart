import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../utils/app_toast.dart';
import 'otp_reset_screen.dart';

// ─── Palette (shared with login) ──────────────────────────────
const Color _kPurple  = Color(0xFF7C5CFC);
const Color _kPurpleLt = Color(0xFF9B7EFD);
const Color _kDark    = Color(0xFF1A1918);
const Color _kMid     = Color(0xFF6D6C6A);
const Color _kHint    = Color(0xFF9C9B99);
const Color _kFieldBg = Color(0xFFF5F4F1);
const Color _kBorder  = Color(0xFFE5E4E1);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.requestPasswordCode(_emailCtrl.text);
      if (!mounted) return;
      setState(() => _sent = true);
      // Brief success pulse, then navigate to OTP screen
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpResetScreen(
            email: _emailCtrl.text.trim().toLowerCase(),
          ),
        ),
      );
      setState(() => _sent = false);
    } on AuthException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.trKey.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) {
            return _buildWide(constraints);
          }
          return _buildNarrow();
        },
      ),
    );
  }

  // ─── Wide layout (tablet / web) ───────────────────────────────
  Widget _buildWide(BoxConstraints constraints) {
    final panelW = (constraints.maxWidth * 0.45).clamp(280.0, 520.0);
    return Row(
      children: [
        SizedBox(
          width: panelW,
          height: double.infinity,
          child: _LeftPanel(),
        ),
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
      ],
    );
  }

  // ─── Narrow layout (mobile) ───────────────────────────────────
  Widget _buildNarrow() {
    return Stack(
      children: [
        _background(),
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
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _formColumn(),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Form column (shared by both layouts) ─────────────────────
  Widget _formColumn() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_rounded, color: _kDark, size: 24),
                  const SizedBox(width: 8),
                  Text('auth.back'.tr(),
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _kDark)),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  _heroSection(),
                  const SizedBox(height: 32),
                  _formSection(),
                  const SizedBox(height: 24),
                  _sendButton(),
                  const SizedBox(height: 20),
                  if (!_sent)
                    Text(
                      'auth.helpNote'.tr(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: _kHint, height: 1.5),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('auth.rememberPassword'.tr(),
                    style: GoogleFonts.outfit(fontSize: 13, color: _kMid)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text('auth.signIn'.tr(),
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kPurple)),
                ),
              ],
            ),
          ),
        ],
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
        // Icon Background (96×96, #F3EEFF, key icon)
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFFF3EEFF),
            borderRadius: BorderRadius.circular(100),
            boxShadow: const [
              BoxShadow(
                color: Color(0x157C5CFC),
                offset: Offset(0, 4),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(Icons.key_rounded, color: _kPurple, size: 40),
        ),
        const SizedBox(height: 16),

        Text(
          'auth.forgotTitle'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: _kDark,
          ),
        ),
        const SizedBox(height: 8),

        Text(
          'auth.forgotDesc'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: _kMid,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ─── Form Section ─────────────────────────────────────────────
  Widget _formSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'auth.emailLabel'.tr(),
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kDark,
          ),
        ),
        const SizedBox(height: 8),
        _emailField(),
      ],
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailCtrl,
      focusNode: _emailFocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _sendResetLink(),
      style: GoogleFonts.outfit(fontSize: 15, color: _kDark),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'auth.validationEmail'.tr() : null,
      decoration: InputDecoration(
        hintText: 'auth.emailPlaceholder'.tr(),
        hintStyle: GoogleFonts.outfit(fontSize: 15, color: _kHint),
        filled: true,
        fillColor: _kFieldBg,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 18, right: 12),
          child: Icon(Icons.mail_outline_rounded, color: _kHint, size: 20),
        ),
        prefixIconConstraints:
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

  // ─── Send Button ──────────────────────────────────────────────
  Widget _sendButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _sendResetLink,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: _sent
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kPurple, _kPurpleLt],
                ),
          color: _sent ? const Color(0xFFE8F5E9) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _sent
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
              : _sent
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF4CAF50), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'auth.codeSent'.tr(),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'auth.sendCode'.tr(),
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

// ─── Left decorative panel (tablet / web) ────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

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
              child: _Orb(size: 280, color: Colors.white.withValues(alpha: 0.06))),
          Positioned(bottom: -40, right: -40,
              child: _Orb(size: 220, color: Colors.white.withValues(alpha: 0.08))),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: Colors.white, size: 48),
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
                  'auth.forgotDesc'.tr(),
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

class _Orb extends StatelessWidget {
  final double size;
  final Color  color;
  const _Orb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}
