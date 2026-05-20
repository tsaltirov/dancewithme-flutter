import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/student_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFF2563EB);
const _kPrimaryDk = Color(0xFF1D4ED8);
const _kPrimaryLt = Color(0xFF3B82F6);
const _kInk       = Color(0xFF1E293B);
const _kMuted     = Color(0xFF64748B);
const _kHint      = Color(0xFF94A3B8);
const _kBorder    = Color(0xFFE2E8F0);
const _kFieldBg   = Color(0xFFF1F5F9);
const _kError     = Color(0xFFEF4444);

TextStyle _ot(double sz, FontWeight w, Color c, {double ls = 0}) =>
    GoogleFonts.outfit(fontSize: sz, fontWeight: w, color: c, letterSpacing: ls);

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: _ot(14, FontWeight.normal, _kHint),
      filled: true,
      fillColor: _kFieldBg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kError)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kError, width: 1.5)),
      errorStyle: _ot(11, FontWeight.normal, _kError),
    );

// ─── Public entry ─────────────────────────────────────────────────────────────
Future<bool> showEditStudentDialog(
  BuildContext context, {
  required Student student,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _EditStudentDialog(student: student),
  );
  return result ?? false;
}

// ─── Dialog ───────────────────────────────────────────────────────────────────
class _EditStudentDialog extends StatefulWidget {
  final Student student;
  const _EditStudentDialog({required this.student});

  @override
  State<_EditStudentDialog> createState() => _State();
}

class _State extends State<_EditStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _surnCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  DateTime? _dob;
  bool      _busy = false;
  String?   _err;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameCtrl  = TextEditingController(text: s.name);
    _surnCtrl  = TextEditingController(text: s.lastName);
    _emailCtrl = TextEditingController(text: s.email);
    _phoneCtrl = TextEditingController(text: s.phone);
    _dob       = _parseBirthDate(s.birthDate);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseBirthDate(String? iso) {
    if (iso == null) return null;
    try {
      final parts = iso.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (_) {}
    return null;
  }

  String _display(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now     = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 18, now.month, now.day);
    final picked  = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1930),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _kPrimary,
            onPrimary: Colors.white,
            onSurface: _kInk,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _err = null; });
    try {
      await StudentService.updateStudent(
        id:        widget.student.id,
        name:      _nameCtrl.text.trim(),
        lastName:  _surnCtrl.text.trim(),
        email:     _emailCtrl.text.trim().toLowerCase(),
        phone:     _phoneCtrl.text.trim(),
        birthDate: _dob != null ? _iso(_dob!) : null,
        schoolId:  widget.student.schoolId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err  = 'student.updateError'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isMobile = w < 600;

    return Dialog(
      insetPadding: isMobile
          ? const EdgeInsets.fromLTRB(16, 48, 16, 16)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ───────────────────────────────────────────────────
                _DialogHeader(
                  studentName: widget.student.fullName,
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 24),

                // ── Nombre + Apellidos ────────────────────────────────────────
                if (!isMobile)
                  Row(children: [
                    Expanded(child: _LabeledField(
                      label: 'form.name'.tr(), hint: 'student.nameHint'.tr(), required: true,
                      ctrl: _nameCtrl,
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _LabeledField(
                      label: 'form.lastName'.tr(), hint: 'student.lastNameHint'.tr(), required: true,
                      ctrl: _surnCtrl,
                    )),
                  ])
                else ...[
                  _LabeledField(
                    label: 'form.name'.tr(), hint: 'student.nameHint'.tr(), required: true,
                    ctrl: _nameCtrl,
                  ),
                  const SizedBox(height: 14),
                  _LabeledField(
                    label: 'form.lastName'.tr(), hint: 'student.lastNameHint'.tr(), required: true,
                    ctrl: _surnCtrl,
                  ),
                ],
                const SizedBox(height: 14),

                // ── Email ─────────────────────────────────────────────────────
                _LabeledField(
                  label: 'form.email'.tr(), hint: 'student.emailHint'.tr(), required: true,
                  ctrl: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'form.requiredEmail'.tr();
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                      return 'form.invalidEmail'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Teléfono + Fecha ──────────────────────────────────────────
                if (!isMobile)
                  Row(children: [
                    Expanded(child: _LabeledField(
                      label: 'form.phone'.tr(), hint: 'student.phoneHint'.tr(),
                      ctrl: _phoneCtrl, keyboardType: TextInputType.phone,
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _DatePickerField(
                      label: 'form.birthDate'.tr(),
                      value: _dob != null ? _display(_dob!) : null,
                      onTap: _pickDate,
                    )),
                  ])
                else ...[
                  _LabeledField(
                    label: 'form.phone'.tr(), hint: 'student.phoneHint'.tr(),
                    ctrl: _phoneCtrl, keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _DatePickerField(
                    label: 'form.birthDate'.tr(),
                    value: _dob != null ? _display(_dob!) : null,
                    onTap: _pickDate,
                  ),
                ],

                // ── Error ──────────────────────────────────────────────────────
                if (_err != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _err!),
                ],
                const SizedBox(height: 28),

                // ── Buttons ───────────────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: _OutlineButton(
                      label: 'form.cancel'.tr(),
                      onTap: _busy ? null : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PrimaryButton(
                      label: 'form.saveChanges'.tr(),
                      loading: _busy,
                      onTap: _submit,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dialog header ────────────────────────────────────────────────────────────
class _DialogHeader extends StatelessWidget {
  final String       studentName;
  final VoidCallback onClose;
  const _DialogHeader({required this.studentName, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_kPrimaryDk, _kPrimaryLt],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('student.editTitle'.tr(), style: _ot(18, FontWeight.w700, _kInk)),
            Text(studentName,
                style: _ot(12, FontWeight.normal, _kMuted),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      GestureDetector(
        onTap: onClose,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _kFieldBg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.close_rounded, size: 18, color: _kMuted),
        ),
      ),
    ]);
  }
}

// ─── Labeled text field ───────────────────────────────────────────────────────
class _LabeledField extends StatelessWidget {
  final String                     label;
  final String                     hint;
  final TextEditingController      ctrl;
  final bool                       required;
  final TextInputType?             keyboardType;
  final String? Function(String?)? validator;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.ctrl,
    this.required = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: _ot(13, FontWeight.w600, _kInk),
            children: required
                ? [TextSpan(text: ' *', style: _ot(13, FontWeight.w600, _kError))]
                : [],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: _ot(14, FontWeight.normal, _kInk),
          validator: validator ??
              (required
                  ? (v) => (v == null || v.trim().isEmpty) ? 'form.required'.tr() : null
                  : null),
          decoration: _dec(hint),
        ),
      ],
    );
  }
}

// ─── Date picker field ────────────────────────────────────────────────────────
class _DatePickerField extends StatelessWidget {
  final String      label;
  final String?     value;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _ot(13, FontWeight.w600, _kInk)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _kFieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16, color: hasValue ? _kPrimary : _kHint),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value ?? 'dd/mm/aaaa',
                  style: _ot(14, FontWeight.normal, hasValue ? _kInk : _kHint),
                ),
              ),
              if (hasValue)
                const Icon(Icons.check_circle_rounded, size: 16, color: _kPrimary),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kError.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: _kError, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: _ot(13, FontWeight.w500, _kError))),
      ]),
    );
  }
}

// ─── Outline button ───────────────────────────────────────────────────────────
class _OutlineButton extends StatelessWidget {
  final String        label;
  final VoidCallback? onTap;
  const _OutlineButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: _ot(14, FontWeight.w600, onTap == null ? _kHint : _kMuted)),
      ),
    );
  }
}

// ─── Primary button ───────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String        label;
  final bool          loading;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, required this.loading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 46,
        decoration: BoxDecoration(
          gradient: loading
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_kPrimaryDk, _kPrimaryLt]),
          color: loading ? const Color(0xFFBFDBFE) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: loading
              ? null
              : const [
                  BoxShadow(
                      color: Color(0x442563EB),
                      offset: Offset(0, 4), blurRadius: 12),
                ],
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Text(label, style: _ot(14, FontWeight.w600, Colors.white)),
      ),
    );
  }
}
