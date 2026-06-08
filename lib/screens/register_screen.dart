import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthException, AuthUser;

import '../services/auth_service.dart';
import '../utils/app_toast.dart';
import '../utils/validators.dart';
import 'home_screen.dart';

// ─── Palette (mirrors login_screen) ──────────────────────────────────────────
const Color _kPurple   = Color(0xFF7C5CFC);
const Color _kPurpleLt = Color(0xFF9B7EFD);
const Color _kDark     = Color(0xFF1A1918);
const Color _kMid      = Color(0xFF6D6C6A);
const Color _kHint     = Color(0xFF9C9B99);
const Color _kFieldBg  = Color(0xFFF5F4F1);
const Color _kBorder   = Color(0xFFE5E4E1);

// ─── RegisterScreen ───────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();

  final _nameFocus     = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus    = FocusNode();
  final _passFocus     = FocusNode();

  bool       _obscurePass    = true;
  bool       _isLoading      = false;
  bool       _isPickingPhoto = false;
  Uint8List? _photoBytes;
  String     _photoExt       = 'jpg';

  late final String _loginImageUrl;

  @override
  void initState() {
    super.initState();
    _loginImageUrl = Supabase.instance.client.storage
        .from('dancewithme')
        .getPublicUrl('instance/login.png');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  // ── Photo picking ─────────────────────────────────────────────────────────
  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _isPickingPhoto = true);
    try {
      final file = await ImagePicker()
          .pickImage(source: source, imageQuality: 85, maxWidth: 800);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final ext   = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';
      setState(() {
        _photoBytes = bytes;
        _photoExt   = ext.isNotEmpty ? ext : 'jpg';
      });
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _requestPhoto() async {
    if (kIsWeb) {
      await _pickPhoto(ImageSource.gallery);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoSheet(onPick: _pickPhoto),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_photoBytes != null) {
        imageUrl = await _uploadPhoto(_photoBytes!, _photoExt);
      }

      await AuthService.register(
        name:      _nameCtrl.text,
        lastName:  _lastNameCtrl.text,
        email:     _emailCtrl.text,
        password:  _passCtrl.text,
        imageUrl:  imageUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.trKey.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Supabase photo upload ─────────────────────────────────────────────────
  Future<String> _uploadPhoto(Uint8List bytes, String ext) async {
    final supabase = Supabase.instance.client;
    final path = 'users/${_uuid()}.$ext';
    await supabase.storage.from('dancewithme').uploadBinary(
      path, bytes,
      fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
    );
    return supabase.storage.from('dancewithme').getPublicUrl(path);
  }

  static String _uuid() {
    final rng   = math.Random();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 600
              ? _buildWide(constraints)
              : _buildNarrow(),
        ),
      ),
    );
  }

  // ─── Wide layout (tablet / web) ───────────────────────────────────────────
  Widget _buildWide(BoxConstraints constraints) {
    final panelW = (constraints.maxWidth * 0.45).clamp(280.0, 520.0);
    return Row(children: [
      SizedBox(
        width: panelW, height: double.infinity,
        child: _RegisterLeftPanel(imageUrl: _loginImageUrl),
      ),
      Expanded(
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _formScroll(wide: true),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ─── Narrow layout (mobile) ───────────────────────────────────────────────
  Widget _buildNarrow() {
    return Stack(children: [
      _background(),
      Positioned(left: -60, top: -40,
          child: _decoCircle(200, const Color(0x087C5CFC))),
      Positioned(right: -40, bottom: 40,
          child: _decoCircle(150, const Color(0x10D89575))),
      SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _formScroll(wide: false),
          ),
        ),
      ),
    ]);
  }

  // ─── Shared scrollable form ───────────────────────────────────────────────
  Widget _formScroll({required bool wide}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // Back
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.arrow_back_rounded, color: _kDark, size: 22),
                const SizedBox(width: 6),
                Text('auth.back'.tr(),
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w500, color: _kDark)),
              ]),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: wide ? 32 : 20),
                  // Hero
                  Text(
                    'auth.registerTitle'.tr(),
                    style: GoogleFonts.outfit(
                      fontSize: 28, fontWeight: FontWeight.w800,
                      letterSpacing: -0.5, color: _kDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'auth.registerSubtitle'.tr(),
                    style: GoogleFonts.outfit(fontSize: 14, color: _kMid),
                  ),
                  const SizedBox(height: 28),
                  // Avatar picker
                  Center(child: _AvatarPicker(
                    bytes:      _photoBytes,
                    isLoading:  _isPickingPhoto,
                    onTap:      _requestPhoto,
                  )),
                  const SizedBox(height: 28),
                  // Name
                  _field(
                    ctrl:      _nameCtrl,
                    focus:     _nameFocus,
                    nextFocus: _lastNameFocus,
                    hint:      'auth.firstName'.tr(),
                    icon:      Icons.person_outline_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'auth.validationName'.tr() : null,
                  ),
                  const SizedBox(height: 14),
                  // Last name
                  _field(
                    ctrl:      _lastNameCtrl,
                    focus:     _lastNameFocus,
                    nextFocus: _emailFocus,
                    hint:      'auth.lastName'.tr(),
                    icon:      Icons.badge_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'auth.validationLastName'.tr() : null,
                  ),
                  const SizedBox(height: 14),
                  // Email
                  _field(
                    ctrl:      _emailCtrl,
                    focus:     _emailFocus,
                    nextFocus: _passFocus,
                    hint:      'auth.emailAddress'.tr(),
                    icon:      Icons.mail_outline_rounded,
                    keyboard:  TextInputType.emailAddress,
                    validator: (v) => AppValidators.email(v)?.tr(),
                  ),
                  const SizedBox(height: 14),
                  // Password
                  _passwordField(),
                  const SizedBox(height: 28),
                  // Register button
                  _registerButton(),
                  const SizedBox(height: 24),
                  // Sign in link
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('auth.haveAccount'.tr(),
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
                  ]),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Text field ───────────────────────────────────────────────────────────
  Widget _field({
    required TextEditingController ctrl,
    required FocusNode focus,
    required FocusNode nextFocus,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller:      ctrl,
      focusNode:       focus,
      keyboardType:    keyboard,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => nextFocus.requestFocus(),
      style: GoogleFonts.outfit(fontSize: 15, color: _kDark),
      validator: validator,
      decoration: _dec(hint: hint, icon: icon),
    );
  }

  // ─── Password field ───────────────────────────────────────────────────────
  Widget _passwordField() {
    return TextFormField(
      controller:      _passCtrl,
      focusNode:       _passFocus,
      obscureText:     _obscurePass,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _register(),
      style: GoogleFonts.outfit(fontSize: 15, color: _kDark),
      validator: (v) => AppValidators.password(v)?.tr(),
      decoration: _dec(
        hint: 'auth.password'.tr(),
        icon: Icons.lock_outline_rounded,
        suffix: GestureDetector(
          onTap: () => setState(() => _obscurePass = !_obscurePass),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _kHint, size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // ─── InputDecoration helper ───────────────────────────────────────────────
  InputDecoration _dec({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText:  hint,
        hintStyle: GoogleFonts.outfit(fontSize: 15, color: _kHint),
        filled:    true,
        fillColor: _kFieldBg,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 18, right: 12),
          child: Icon(icon, color: _kHint, size: 20),
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

  // ─── Register button ──────────────────────────────────────────────────────
  Widget _registerButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _isLoading ? null : _register,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 56,
          decoration: BoxDecoration(
            gradient: _isLoading
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                        blurRadius: 24),
                  ],
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white)))
                : Text(
                    'auth.registerBtn'.tr(),
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  // ─── Background helpers ───────────────────────────────────────────────────
  Widget _background() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3EEFF), Color(0xFFFFF7F3), Colors.white],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      );

  Widget _decoCircle(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

// ─── Avatar picker ────────────────────────────────────────────────────────────
class _AvatarPicker extends StatelessWidget {
  final Uint8List? bytes;
  final bool       isLoading;
  final VoidCallback onTap;

  const _AvatarPicker({
    required this.bytes,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Circle avatar
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF0EAFF),
                border: Border.all(color: const Color(0xFFDDD8F8), width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 28, height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(_kPurple),
                        ),
                      ),
                    )
                  : bytes != null
                      ? Image.memory(bytes!, fit: BoxFit.cover,
                          width: 100, height: 100)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_rounded,
                                color: _kPurple, size: 36),
                            const SizedBox(height: 2),
                            Text(
                              'auth.addPhoto'.tr(),
                              style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _kPurple),
                            ),
                          ],
                        ),
            ),
            // Camera badge
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_kPurple, _kPurpleLt],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x447C5CFC), blurRadius: 8, offset: Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Photo source bottom sheet ────────────────────────────────────────────────
class _PhotoSheet extends StatelessWidget {
  final Future<void> Function(ImageSource) onPick;
  const _PhotoSheet({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE5E4E1),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _SourceBtn(
              icon: Icons.camera_alt_rounded,
              label: 'school.imgSourceCamera'.tr(),
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.camera);
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: _SourceBtn(
              icon: Icons.photo_library_rounded,
              label: 'school.imgSourceGallery'.tr(),
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.gallery);
              },
            )),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F4F1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('form.cancel'.tr(),
                  style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: const Color(0xFF6D6C6A))),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _SourceBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kPurple, _kPurpleLt],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x447C5CFC), blurRadius: 12, offset: Offset(0, 4))
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      ),
    );
  }
}

// ─── Left panel (wide layout) ─────────────────────────────────────────────────
class _RegisterLeftPanel extends StatelessWidget {
  final String imageUrl;
  const _RegisterLeftPanel({required this.imageUrl});

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
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(24)),
                        child: const Center(
                          child: Icon(Icons.music_note_rounded,
                              color: Colors.white, size: 64),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'DanceWithMe',
                  style: GoogleFonts.outfit(
                      fontSize: 28, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  'auth.registerSubtitle'.tr(),
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: Colors.white.withValues(alpha: 0.75)),
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
