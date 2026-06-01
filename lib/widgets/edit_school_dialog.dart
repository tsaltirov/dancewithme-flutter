import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/school_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const Color _kPurple   = Color(0xFF7C5CFC);
const Color _kPurpleLt = Color(0xFF9B7EFD);

// ─── Entry point ──────────────────────────────────────────────────────────────
class EditSchoolDialog extends StatefulWidget {
  final School school;
  const EditSchoolDialog({super.key, required this.school});

  /// Shows the dialog and returns `true` if the school was updated.
  static Future<bool?> show(BuildContext context, School school) {
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
      pageBuilder: (_, __, ___) => EditSchoolDialog(school: school),
    );
  }

  @override
  State<EditSchoolDialog> createState() => _EditSchoolDialogState();
}

// ─── State ────────────────────────────────────────────────────────────────────
class _EditSchoolDialogState extends State<EditSchoolDialog> {
  final _formKey   = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  Uint8List? _newImageBytes;
  String     _newImageExt      = 'jpg';
  bool       _isLoading        = false;
  bool       _isPickingImage   = false;

  static TextStyle _t(double sz, FontWeight fw, Color c,
      {double ls = 0}) =>
      GoogleFonts.plusJakartaSans(
          fontSize: sz, fontWeight: fw, color: c, letterSpacing: ls);

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.school.name);
    _addrCtrl  = TextEditingController(text: widget.school.address);
    _phoneCtrl = TextEditingController(text: widget.school.phone);
    _emailCtrl = TextEditingController(text: widget.school.email);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Pick new image ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    if (_isLoading) return;
    setState(() => _isPickingImage = true);
    try {
      final file = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final ext   = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';
      setState(() {
        _newImageBytes = bytes;
        _newImageExt   = ext.isNotEmpty ? ext : 'jpg';
      });
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      String? imageUrl = widget.school.imageUrl.isNotEmpty
          ? widget.school.imageUrl
          : null;
      if (_newImageBytes != null) {
        imageUrl = await SchoolService.uploadImage(_newImageBytes!, _newImageExt);
      }
      await SchoolService.updateSchool(
        id:       widget.school.id,
        name:     _nameCtrl.text,
        address:  _addrCtrl.text,
        phone:    _phoneCtrl.text,
        email:    _emailCtrl.text,
        userId:   widget.school.userId,
        imageUrl: imageUrl,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on SchoolException catch (e) {
      if (mounted) _snackError(e.message);
    } catch (_) {
      if (mounted) _snackError('school.errorUpdate'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snackError(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: _t(14, FontWeight.w500, Colors.white))),
        ]),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 4),
      ));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
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
                    _EditHeader(onClose: () => Navigator.of(context).pop()),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _EditImagePicker(
                                newBytes:    _newImageBytes,
                                existingUrl: widget.school.imageUrl,
                                isLoading:   _isPickingImage,
                                onTap:       _pickImage,
                              ),
                              const SizedBox(height: 18),
                              _EditField(
                                ctrl:      _nameCtrl,
                                hint:      'school.fieldName'.tr(),
                                icon:      Icons.school_outlined,
                                action:    TextInputAction.next,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'school.validName'.tr() : null,
                              ),
                              const SizedBox(height: 12),
                              _EditField(
                                ctrl:      _addrCtrl,
                                hint:      'school.fieldAddress'.tr(),
                                icon:      Icons.location_on_outlined,
                                action:    TextInputAction.next,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'school.validAddress'.tr() : null,
                              ),
                              const SizedBox(height: 12),
                              _EditField(
                                ctrl:      _phoneCtrl,
                                hint:      'school.fieldPhone'.tr(),
                                icon:      Icons.phone_outlined,
                                keyboard:  TextInputType.phone,
                                action:    TextInputAction.next,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'school.validPhone'.tr() : null,
                              ),
                              const SizedBox(height: 12),
                              _EditField(
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
                              _EditActions(
                                isLoading: _isLoading,
                                onCancel:  () => Navigator.of(context).pop(),
                                onSubmit:  _submit,
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

// ─── Header ───────────────────────────────────────────────────────────────────
class _EditHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _EditHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A3ED9), _kPurple],
        ),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'school.editTitle'.tr(),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 3),
              Text(
                'school.editSubtitle'.tr(),
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
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Image picker (supports existing network URL + new local bytes) ────────────
class _EditImagePicker extends StatelessWidget {
  final Uint8List? newBytes;
  final String?    existingUrl;
  final bool       isLoading;
  final VoidCallback onTap;

  const _EditImagePicker({
    required this.newBytes,
    required this.existingUrl,
    required this.isLoading,
    required this.onTap,
  });

  bool get _hasExistingImage =>
      existingUrl != null && existingUrl!.isNotEmpty;

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
                      valueColor: AlwaysStoppedAnimation(_kPurple),
                    ),
                  ),
                )
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (newBytes != null) {
      return Stack(fit: StackFit.expand, children: [
        Image.memory(newBytes!, fit: BoxFit.cover),
        _changeChip(),
      ]);
    }
    if (_hasExistingImage) {
      return Stack(fit: StackFit.expand, children: [
        Image.network(
          existingUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
        _changeChip(),
      ]);
    }
    return _placeholder();
  }

  Widget _changeChip() => Positioned(
    bottom: 8, right: 8,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'school.changeImage'.tr(),
        style: GoogleFonts.plusJakartaSans(
            fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    ),
  );

  Widget _placeholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFEDE9FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.add_photo_alternate_outlined,
            color: _kPurple, size: 22),
      ),
      const SizedBox(height: 8),
      Text('school.addImage'.tr(),
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w500, color: _kPurple)),
    ],
  );
}

// ─── Text field ───────────────────────────────────────────────────────────────
class _EditField extends StatelessWidget {
  final TextEditingController        ctrl;
  final String                       hint;
  final IconData                     icon;
  final TextInputType                keyboard;
  final TextInputAction              action;
  final ValueChanged<String>?        onSubmitted;
  final FormFieldValidator<String>?  validator;

  const _EditField({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.keyboard    = TextInputType.text,
    this.action      = TextInputAction.next,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8E4F4))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8E4F4))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kPurple, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEF4444))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
      ),
    );
  }
}

// ─── Action buttons ───────────────────────────────────────────────────────────
class _EditActions extends StatelessWidget {
  final bool         isLoading;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _EditActions({
    required this.isLoading,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
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
                        colors: [Color(0xFF5A3ED9), _kPurple, _kPurpleLt]),
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
                      const Icon(Icons.check_rounded,
                          color: Colors.white, size: 17),
                      const SizedBox(width: 6),
                      Text('school.btnUpdate'.tr(),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
