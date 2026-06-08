import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException, AuthUser;

import '../services/auth_service.dart';
import '../utils/app_toast.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _P {
  _P._();
  static const bg        = Color(0xFFF7F5FF);
  static const surface   = Color(0xFFFFFFFF);
  static const purple    = Color(0xFF7C5CFC);
  static const purpleLt  = Color(0xFF9B7EFD);
  static const purpleDim = Color(0xFFEDE9FF);
  static const ink       = Color(0xFF1A1525);
  static const muted     = Color(0xFF8B879A);
  static const border    = Color(0xFFE8E4F4);
  static const errorRed  = Color(0xFFEF4444);

  // Tab bar height — matches home_screen._T.tabBarH (62 + 14*2)
  static const double kTabBarH = 90.0;
}

TextStyle _pt(double sz, FontWeight w, Color c, {double ls = 0, double? lh}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: sz, fontWeight: w, color: c, letterSpacing: ls, height: lh);

// ─── ProfileTab ───────────────────────────────────────────────────────────────
class ProfileTab extends StatefulWidget {
  final AuthUser user;
  const ProfileTab({super.key, required this.user});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool       _editing = false;
  bool       _saving  = false;
  late String _displayName;
  late String _displayLastName;
  Uint8List?  _pendingBytes;
  int         _photoVersion = 0;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastCtrl;
  final _formKey = GlobalKey<FormState>();

  String? get _photoUrl {
    final uid = widget.user.id.trim();
    if (uid.isEmpty) return null;
    final url = Supabase.instance.client.storage
        .from('dancewithme')
        .getPublicUrl('users/$uid.jpg');
    final versioned = '$url?v=$_photoVersion';
    if (kDebugMode) debugPrint('[ProfileTab] photo URL → $versioned');
    return versioned;
  }

  String get _initials {
    final n = _displayName.trim();
    final l = _displayLastName.trim();
    return '${n.isNotEmpty ? n[0].toUpperCase() : ''}'
        '${l.isNotEmpty ? l[0].toUpperCase() : ''}';
  }

  @override
  void initState() {
    super.initState();
    _displayName     = widget.user.name;
    _displayLastName = widget.user.lastName;
    _nameCtrl = TextEditingController(text: _displayName);
    _lastCtrl = TextEditingController(text: _displayLastName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  // ── Photo ─────────────────────────────────────────────────────────────────
  Future<void> _requestPhoto() async {
    if (!_editing) return;
    if (kIsWeb) { await _pickFrom(ImageSource.gallery); return; }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoSourceSheet(onPick: _pickFrom),
    );
  }

  Future<void> _pickFrom(ImageSource source) async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, imageQuality: 85, maxWidth: 800);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _pendingBytes = bytes);
    } catch (e, st) {
      if (kDebugMode) debugPrint('[ProfileTab._pickFrom] $e\n$st');
      if (!mounted) return;
      _snack('profile.photoError'.tr(), error: true);
    }
  }

  // ── Save / Cancel ─────────────────────────────────────────────────────────
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? uploadedUrl;
      if (_pendingBytes != null) {
        uploadedUrl = await _uploadPhoto(_pendingBytes!);
      }
      final name     = _nameCtrl.text.trim();
      final lastName = _lastCtrl.text.trim();
      await AuthService.updateProfile(
          userId:   widget.user.id,
          name:     name,
          lastName: lastName,
          imageUrl: uploadedUrl);
      if (!mounted) return;
      setState(() {
        _displayName     = name;
        _displayLastName = lastName;
        _pendingBytes    = null;
        _editing         = false;
        if (uploadedUrl != null) {
          _photoVersion = DateTime.now().millisecondsSinceEpoch;
        }
      });
      _snack('profile.updateSuccess'.tr());
    } catch (e, st) {
      if (kDebugMode) debugPrint('[ProfileTab._save] $e\n$st');
      if (!mounted) return;
      _snack('profile.updateError'.tr(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Returns the public URL; throws StorageException on failure.
  Future<String> _uploadPhoto(Uint8List bytes) async {
    final path = 'users/${widget.user.id}.jpg';
    if (kDebugMode) debugPrint('[ProfileTab._uploadPhoto] uploading to $path');
    await Supabase.instance.client.storage
        .from('dancewithme')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
              contentType: 'image/jpeg', upsert: true),
        );
    final url = Supabase.instance.client.storage
        .from('dancewithme')
        .getPublicUrl(path);
    if (kDebugMode) debugPrint('[ProfileTab._uploadPhoto] public URL → $url');
    return url;
  }

  void _cancelEdit() {
    FocusScope.of(context).unfocus();
    setState(() {
      _editing       = false;
      _pendingBytes  = null;
      _nameCtrl.text = _displayName;
      _lastCtrl.text = _displayLastName;
    });
  }

  void _snack(String msg, {bool error = false}) =>
      error ? AppToast.error(context, msg) : AppToast.success(context, msg);

  // ── Build ─────────────────────────────────────────────────────────────────
  // Mirrors home_screen._layoutFor: tab bar is present unless desktop/web AND w≥1100.
  static bool _isDesktopOrWebPlatform() =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final isWide    = constraints.maxWidth >= 600;
      final screenW   = MediaQuery.of(context).size.width;
      final sysBottom = MediaQuery.of(context).viewPadding.bottom;
      // Floating tab bar is present in home_screen unless: desktop/web AND width ≥ 1100.
      final hasTabBar = !(_isDesktopOrWebPlatform() && screenW >= 1100);

      return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Container(
          color: _P.bg,
          // Reserve space for the floating tab bar so Column content is never hidden under it.
          padding: EdgeInsets.only(
              bottom: hasTabBar ? sysBottom + _P.kTabBarH : 0.0),
          child: Column(children: [
            // ── Hero header ───────────────────────────────────────────────
            _HeroHeader(
              isWide:       isWide,
              photoUrl:     _pendingBytes != null ? null : _photoUrl,
              pendingBytes: _pendingBytes,
              initials:     _initials,
              editing:      _editing,
              onAvatarTap:  _requestPhoto,
            ),

            // ── Scrollable body ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 48 : 20, 24,
                  isWide ? 48 : 20,
                  24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: isWide ? 560 : double.infinity),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Name + role
                          _NameDisplay(
                            name:     _displayName,
                            lastName: _displayLastName,
                            role:     widget.user.role,
                            isWide:   isWide,
                          ),
                          const SizedBox(height: 24),

                          // Edit-mode indicator
                          if (_editing)
                            _EditingBanner(onCancel: _cancelEdit),

                          if (_editing) const SizedBox(height: 16),

                          // Info card
                          _InfoCard(
                            nameCtrl:     _nameCtrl,
                            lastNameCtrl: _lastCtrl,
                            email:        widget.user.email,
                            editing:      _editing,
                          ),

                          // Edit button (view mode)
                          if (!_editing) ...[
                            const SizedBox(height: 24),
                            _EditButton(
                              onTap: () => setState(() => _editing = true)),
                            const SizedBox(height: 40),
                            const _VersionBadge(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Sticky save bar (edit mode only) ─────────────────────────
            if (_editing)
              _SaveBar(
                saving:       _saving,
                onSave:       _save,
                onCancel:     _cancelEdit,
                bottomInset:  14,
                isWide:       isWide,
              ),
          ]),
        ),
      );
    });
  }
}

// ─── Hero header ──────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final bool       isWide;
  final String?    photoUrl;
  final Uint8List? pendingBytes;
  final String     initials;
  final bool       editing;
  final VoidCallback onAvatarTap;

  const _HeroHeader({
    required this.isWide,
    required this.photoUrl,
    required this.pendingBytes,
    required this.initials,
    required this.editing,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = isWide ? 130.0 : 110.0;
    final bannerH    = isWide ? 200.0 : 175.0;

    return SizedBox(
      height: bannerH + avatarSize * 0.5, // banner + half avatar overflow
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Gradient banner
          Positioned(
            top: 0, left: 0, right: 0,
            height: bannerH,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4C23C8),
                    Color(0xFF7C5CFC),
                    Color(0xFF9B7EFD),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(children: [
                // Decorative orbs
                Positioned(
                  top: -30, right: -20,
                  child: _Orb(160, Colors.white.withValues(alpha: 0.07)),
                ),
                Positioned(
                  bottom: -10, left: -30,
                  child: _Orb(120, Colors.white.withValues(alpha: 0.05)),
                ),
                Positioned(
                  top: 20, left: 40,
                  child: _Orb(60, Colors.white.withValues(alpha: 0.06)),
                ),
              ]),
            ),
          ),

          // Avatar — centred, half overflowing the bottom of the banner
          Positioned(
            bottom: 0,
            left: 0, right: 0,
            child: Center(
              child: _ProfileAvatar(
                size:         avatarSize,
                photoUrl:     photoUrl,
                pendingBytes: pendingBytes,
                initials:     initials,
                editing:      editing,
                onTap:        onAvatarTap,
              ),
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
  const _Orb(this.size, this.color);
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

// ─── Avatar ───────────────────────────────────────────────────────────────────
class _ProfileAvatar extends StatelessWidget {
  final double     size;
  final String?    photoUrl;
  final Uint8List? pendingBytes;
  final String     initials;
  final bool       editing;
  final VoidCallback onTap;

  const _ProfileAvatar({
    required this.size,
    required this.photoUrl,
    required this.pendingBytes,
    required this.initials,
    required this.editing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: editing ? onTap : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // White ring
          Container(
            width: size + 8, height: size + 8,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.white),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: _AvatarImage(
                size: size + 2,
                photoUrl: photoUrl,
                pendingBytes: pendingBytes,
                initials: initials,
              ),
            ),
          ),
          // Camera badge
          if (editing)
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _P.purple,
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x557C5CFC),
                        blurRadius: 8,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  final double     size;
  final String?    photoUrl;
  final Uint8List? pendingBytes;
  final String     initials;

  const _AvatarImage({
    required this.size,
    required this.photoUrl,
    required this.pendingBytes,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (pendingBytes != null) {
      inner = Image.memory(pendingBytes!, fit: BoxFit.cover);
    } else {
      inner = Image.network(
        photoUrl ?? '',
        fit: BoxFit.cover,
        errorBuilder:   (_, __, ___) => _InitialsFallback(size: size, initials: initials),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                color: _P.purpleDim,
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_P.purple),
                  ),
                ),
              ),
      );
    }
    return ClipOval(child: SizedBox.square(dimension: size, child: inner));
  }
}

class _InitialsFallback extends StatelessWidget {
  final double size;
  final String initials;
  const _InitialsFallback({required this.size, required this.initials});

  @override
  Widget build(BuildContext context) => Container(
        color: _P.purpleDim,
        child: Center(
          child: Text(
            initials,
            style: GoogleFonts.plusJakartaSans(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w800,
              color: _P.purple,
            ),
          ),
        ),
      );
}

// ─── Name + role display ──────────────────────────────────────────────────────
class _NameDisplay extends StatelessWidget {
  final String name;
  final String lastName;
  final String role;
  final bool   isWide;

  const _NameDisplay({
    required this.name, required this.lastName,
    required this.role, required this.isWide,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(
          '$name $lastName'.trim(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _pt(isWide ? 28 : 24, FontWeight.w800, _P.ink, lh: 1.2),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4C23C8), _P.purpleLt]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x337C5CFC),
                blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Text(
            role.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: 1.2),
          ),
        ),
      ]);
}

// ─── Edit-mode indicator banner ───────────────────────────────────────────────
class _EditingBanner extends StatelessWidget {
  final VoidCallback onCancel;
  const _EditingBanner({required this.onCancel});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _P.purpleDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.purple.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.edit_rounded, color: _P.purple, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo edición — modifica tus datos y pulsa guardar',
              style: _pt(12, FontWeight.w500, _P.purple),
            ),
          ),
        ]),
      );
}

// ─── Info card ────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController lastNameCtrl;
  final String email;
  final bool   editing;

  const _InfoCard({
    required this.nameCtrl, required this.lastNameCtrl,
    required this.email,    required this.editing,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _P.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x127C5CFC), blurRadius: 20, offset: Offset(0, 4)),
          ],
        ),
        child: Column(children: [
          _FieldRow(
            icon: Icons.person_outline_rounded,
            label: 'profile.nameField'.tr(),
            controller: nameCtrl,
            editing: editing,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'profile.nameRequired'.tr() : null,
          ),
          Divider(height: 1, indent: 20, endIndent: 20, color: _P.border),
          _FieldRow(
            icon: Icons.badge_outlined,
            label: 'profile.lastNameField'.tr(),
            controller: lastNameCtrl,
            editing: editing,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'profile.lastNameRequired'.tr() : null,
          ),
          Divider(height: 1, indent: 20, endIndent: 20, color: _P.border),
          _FieldRow(
            icon: Icons.mail_outline_rounded,
            label: 'profile.emailField'.tr(),
            staticValue: email,
            editing: false,
            readOnly: true,
          ),
        ]),
      );
}

class _FieldRow extends StatelessWidget {
  final IconData                   icon;
  final String                     label;
  final TextEditingController?     controller;
  final String?                    staticValue;
  final bool                       editing;
  final bool                       readOnly;
  final String? Function(String?)? validator;

  const _FieldRow({
    required this.icon,
    required this.label,
    this.controller,
    this.staticValue,
    required this.editing,
    this.readOnly  = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: readOnly
                  ? const Color(0xFFF1F1F1)
                  : _P.purpleDim,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon,
                color: readOnly ? _P.muted : _P.purple, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: _pt(11, FontWeight.w600, _P.muted, ls: 0.3)),
                const SizedBox(height: 5),
                if (editing && !readOnly && controller != null)
                  TextFormField(
                    controller: controller,
                    validator:  validator,
                    style: _pt(15, FontWeight.w600, _P.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 2),
                      border: InputBorder.none,
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _P.border)),
                      focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: _P.purple, width: 2)),
                      errorBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _P.errorRed)),
                      focusedErrorBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _P.errorRed, width: 2)),
                    ),
                  )
                else
                  Text(
                    staticValue ?? controller?.text ?? '',
                    style: _pt(15, FontWeight.w600,
                        readOnly ? _P.muted : _P.ink),
                  ),
              ],
            ),
          ),
          // Editable indicator arrow (edit mode only)
          if (editing && !readOnly)
            const Icon(Icons.chevron_right_rounded,
                color: _P.purple, size: 18),
        ]),
      );
}

// ─── Edit button (view mode) ──────────────────────────────────────────────────
class _EditButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EditButton({required this.onTap});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_P.purple, _P.purpleLt],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D7C5CFC),
              blurRadius: 18, offset: Offset(0, 5)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('profile.editBtn'.tr(),
                      style: _pt(15, FontWeight.w700, Colors.white)),
                ],
              ),
            ),
          ),
        ),
      );
}

// ─── App version badge ────────────────────────────────────────────────────────
class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: const Color(0xFFDDD8F8)),
        ),
        child: Text(
          'v1.0.0',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF9C8FD4),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─── Sticky save bar (edit mode) ─────────────────────────────────────────────
class _SaveBar extends StatelessWidget {
  final bool         saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final double       bottomInset;
  final bool         isWide;

  const _SaveBar({
    required this.saving,
    required this.onSave,
    required this.onCancel,
    required this.bottomInset,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        border: Border(top: BorderSide(color: _P.border)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12, offset: Offset(0, -4)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        isWide ? 48 : 20,
        14,
        isWide ? 48 : 20,
        bottomInset,
      ),
      child: saving
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 26, height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(_P.purple),
                  ),
                ),
              ),
            )
          : Column(mainAxisSize: MainAxisSize.min, children: [
              // Save
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_P.purple, _P.purpleLt],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D7C5CFC),
                      blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: onSave,
                    borderRadius: BorderRadius.circular(16),
                    splashColor: Colors.white24,
                    highlightColor: Colors.white10,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      child: Text('profile.saveBtn'.tr(),
                          style: _pt(15, FontWeight.w700, Colors.white)),
                    ),
                  ),
                ),
              ),
              // Cancel — subtle text action
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: _P.muted,
                  minimumSize: const Size.fromHeight(44),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                child: Text('profile.cancelBtn'.tr(),
                    style: _pt(14, FontWeight.w500, _P.muted)),
              ),
            ]),
    );
  }
}

// ─── Photo source sheet ───────────────────────────────────────────────────────
class _PhotoSourceSheet extends StatelessWidget {
  final ValueChanged<ImageSource> onPick;
  const _PhotoSourceSheet({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final sysBottom = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Drag handle ──────────────────────────────────────────────────
        const SizedBox(height: 12),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: _P.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),
        // ── Header icon ──────────────────────────────────────────────────
        Container(
          width: 68, height: 68,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4C23C8), _P.purpleLt],
            ),
          ),
          child: const Icon(Icons.add_a_photo_rounded,
              color: Colors.white, size: 30),
        ),
        const SizedBox(height: 14),
        Text('profile.imgSourceTitle'.tr(),
            style: _pt(18, FontWeight.w800, _P.ink)),
        const SizedBox(height: 28),
        // ── Two large cards ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(
              child: _SourceCard(
                icon:  Icons.camera_alt_rounded,
                label: 'profile.imgSourceCamera'.tr(),
                onTap: () { Navigator.pop(context); onPick(ImageSource.camera); },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SourceCard(
                icon:  Icons.photo_library_rounded,
                label: 'profile.imgSourceGallery'.tr(),
                onTap: () { Navigator.pop(context); onPick(ImageSource.gallery); },
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // ── Cancel ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: _P.muted,
                backgroundColor: const Color(0xFFF3F0FA),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('profile.cancelBtn'.tr(),
                  style: _pt(15, FontWeight.w600, _P.muted)),
            ),
          ),
        ),
        SizedBox(height: sysBottom > 0 ? sysBottom : 20),
      ]),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  const _SourceCard(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: _P.purple.withValues(alpha: 0.15),
          highlightColor: _P.purple.withValues(alpha: 0.08),
          child: Container(
            height: 112,
            decoration: BoxDecoration(
              color: _P.purpleDim,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: _P.purple.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_P.purple, _P.purpleLt],
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 10),
                Text(label,
                    style: _pt(13, FontWeight.w700, _P.purple),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}
