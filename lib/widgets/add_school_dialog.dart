import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/school_service.dart';
import '../utils/app_toast.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────
class AddSchoolDialog extends StatefulWidget {
  const AddSchoolDialog({super.key});

  /// Opens the dialog and returns `true` if a school was created successfully.
  static Future<bool?> show(BuildContext context) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x881A1525),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.93, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      pageBuilder: (_, __, ___) => const AddSchoolDialog(),
    );
  }

  @override
  State<AddSchoolDialog> createState() => _AddSchoolDialogState();
}

// ─── State ────────────────────────────────────────────────────────────────────
class _AddSchoolDialogState extends State<AddSchoolDialog> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _addrCtrl   = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _emailCtrl  = TextEditingController();

  String?    _userId;
  Uint8List? _imageBytes;
  String     _imageExt        = 'jpg';
  bool       _isLoading       = false;
  bool       _isPickingImage  = false;

  // ── Font helper ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _resolveUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Load stored user ID ──────────────────────────────────────────────────
  Future<void> _resolveUser() async {
    try {
      final user = await AuthService.getUser();
      if (mounted) setState(() => _userId = user?.id);
    } catch (e) {
      // Storage decryption can fail on web if IndexedDB key ≠ localStorage data.
      // The user will see an error on submit; they should re-login to fix it.
      if (mounted) {
        if (kDebugMode) debugPrint('[AddSchoolDialog] _resolveUser error: $e');
      }
    }
  }

  // ── Photo picker — shows sheet on native, gallery-only on web ────────────
  Future<void> _requestImage() async {
    if (_isLoading) return;
    if (kIsWeb) { await _pickFrom(ImageSource.gallery); return; }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(onPick: _pickFrom),
    );
  }

  Future<void> _pickFrom(ImageSource source) async {
    setState(() => _isPickingImage = true);
    try {
      final file = await ImagePicker()
          .pickImage(source: source, imageQuality: 85);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final ext   = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase() : 'jpg';
      setState(() {
        _imageBytes = bytes;
        _imageExt   = ext.isNotEmpty ? ext : 'jpg';
      });
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userId == null) {
      _snackError('school.errorCreate'.tr());
      return;
    }
    setState(() => _isLoading = true);
    try {
      String? imageUrl;
      if (_imageBytes != null) {
        imageUrl = await SchoolService.uploadImage(_imageBytes!, _imageExt);
      }
      await SchoolService.addSchool(
        name:     _nameCtrl.text,
        address:  _addrCtrl.text,
        phone:    _phoneCtrl.text,
        email:    _emailCtrl.text,
        userId:   _userId!,
        imageUrl: imageUrl,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on SchoolException catch (e) {
      if (mounted) _snackError(e.message);
    } catch (_) {
      if (mounted) _snackError('school.errorCreate'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snackError(String msg) => AppToast.error(context, msg);

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final kbBottom = MediaQuery.of(context).viewInsets.bottom;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AnimatedPadding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + kbBottom),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x281A1525),
                      offset: Offset(0, 24),
                      blurRadius: 64),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Header(onClose: () => Navigator.of(context).pop()),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ImagePicker(
                                bytes:         _imageBytes,
                                isLoading:     _isPickingImage,
                                onTap:         _requestImage,
                                changeLabel:   'school.changeImage'.tr(),
                                addLabel:      'school.addImage'.tr(),
                              ),
                              const SizedBox(height: 18),
                              _Field(
                                ctrl:        _nameCtrl,
                                hint:        'school.fieldName'.tr(),
                                icon:        Icons.school_outlined,
                                action:      TextInputAction.next,
                                validator:   (v) => (v == null || v.trim().isEmpty)
                                    ? 'school.validName'.tr() : null,
                              ),
                              const SizedBox(height: 12),
                              _Field(
                                ctrl:        _addrCtrl,
                                hint:        'school.fieldAddress'.tr(),
                                icon:        Icons.location_on_outlined,
                                action:      TextInputAction.next,
                                validator:   (v) => (v == null || v.trim().isEmpty)
                                    ? 'school.validAddress'.tr() : null,
                              ),
                              const SizedBox(height: 12),
                              _Field(
                                ctrl:        _phoneCtrl,
                                hint:        'school.fieldPhone'.tr(),
                                icon:        Icons.phone_outlined,
                                keyboard:    TextInputType.phone,
                                action:      TextInputAction.next,
                                validator:   (v) => (v == null || v.trim().isEmpty)
                                    ? 'school.validPhone'.tr() : null,
                              ),
                              const SizedBox(height: 12),
                              _Field(
                                ctrl:        _emailCtrl,
                                hint:        'school.fieldEmail'.tr(),
                                icon:        Icons.mail_outline_rounded,
                                keyboard:    TextInputType.emailAddress,
                                action:      TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'school.validEmail'.tr();
                                  }
                                  if (!v.contains('@') || !v.contains('.')) {
                                    return 'school.validEmail'.tr();
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 26),
                              _Actions(
                                isLoading: _isLoading,
                                onCancel: () => Navigator.of(context).pop(),
                                onSubmit: _submit,
                              ),
                            ],
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
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C5CFC), Color(0xFF9B7EFD)],
        ),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'school.addTitle'.tr(),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 3),
              Text(
                'school.addSubtitle'.tr(),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ImagePicker extends StatelessWidget {
  final Uint8List? bytes;
  final bool       isLoading;
  final VoidCallback onTap;
  final String     addLabel;
  final String     changeLabel;

  const _ImagePicker({
    required this.bytes,
    required this.isLoading,
    required this.onTap,
    required this.addLabel,
    required this.changeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDDD8F8), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation(Color(0xFF7C5CFC)),
                    ),
                  ),
                )
              : bytes != null
                  ? Stack(fit: StackFit.expand, children: [
                      Image.memory(bytes!, fit: BoxFit.cover),
                      Positioned(
                        bottom: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(changeLabel,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                    ])
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: Color(0xFF7C5CFC), size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(addLabel,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF7C5CFC))),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController   ctrl;
  final String                  hint;
  final IconData                icon;
  final TextInputType           keyboard;
  final TextInputAction         action;
  final ValueChanged<String>?   onSubmitted;
  final FormFieldValidator<String>? validator;

  const _Field({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.keyboard   = TextInputType.text,
    this.action     = TextInputAction.next,
    this.onSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:       ctrl,
      keyboardType:     keyboard,
      textInputAction:  action,
      onFieldSubmitted: onSubmitted,
      validator:        validator,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 14, color: const Color(0xFF1A1525)),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: const Color(0xFF9C9B99)),
        filled:     true,
        fillColor:  const Color(0xFFF5F4F8),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child:   Icon(icon, color: const Color(0xFF9C9B99), size: 18),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8E4F4))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8E4F4))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Color(0xFF7C5CFC), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEF4444))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final bool         isLoading;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _Actions({
    required this.isLoading,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Cancel
      Expanded(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: isLoading ? null : onCancel,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F0F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8E4F4)),
              ),
              child: Text('auth.back'.tr(),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6D6C6A))),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      // Submit
      Expanded(
        flex: 2,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: isLoading ? null : onSubmit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isLoading
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7C5CFC), Color(0xFF9B7EFD)]),
                color: isLoading ? const Color(0xFFBDB0F8) : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isLoading
                    ? null
                    : const [
                        BoxShadow(
                            color: Color(0x557C5CFC),
                            offset: Offset(0, 4),
                            blurRadius: 14),
                      ],
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('school.btnCreate'.tr(),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 16),
                    ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ─── Camera / Gallery bottom sheet ───────────────────────────────────────────
class _ImageSourceSheet extends StatelessWidget {
  final Future<void> Function(ImageSource) onPick;
  const _ImageSourceSheet({required this.onPick});

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
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE5E4E1),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _SrcBtn(
              icon: Icons.camera_alt_rounded,
              label: 'wardrobe.imgSourceCamera'.tr(),
              onTap: () { Navigator.pop(context); onPick(ImageSource.camera); },
            )),
            const SizedBox(width: 12),
            Expanded(child: _SrcBtn(
              icon: Icons.photo_library_rounded,
              label: 'wardrobe.imgSourceGallery'.tr(),
              onTap: () { Navigator.pop(context); onPick(ImageSource.gallery); },
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
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: const Color(0xFF6D6C6A))),
            ),
          ),
        ],
      ),
    );
  }
}

class _SrcBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _SrcBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C5CFC), Color(0xFF9B7EFD)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x447C5CFC), blurRadius: 12, offset: Offset(0, 4))
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      ),
    );
  }
}
