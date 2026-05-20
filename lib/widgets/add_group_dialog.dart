import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/group_service.dart';

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

const _kLevels = <String>[
  'Principiante',
  'Intermedio',
  'Avanzado',
  'Profesional',
];

TextStyle _ot(double sz, FontWeight w, Color c) =>
    GoogleFonts.outfit(fontSize: sz, fontWeight: w, color: c);

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
Future<bool> showAddGroupDialog(
  BuildContext context, {
  required int schoolId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _AddGroupDialog(schoolId: schoolId),
  );
  return result ?? false;
}

// ─── Dialog ───────────────────────────────────────────────────────────────────
class _AddGroupDialog extends StatefulWidget {
  final int schoolId;
  const _AddGroupDialog({required this.schoolId});

  @override
  State<_AddGroupDialog> createState() => _AddGroupDialogState();
}

class _AddGroupDialogState extends State<_AddGroupDialog> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _styleCtrl    = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _scheduleCtrl = TextEditingController();
  String? _level;
  bool    _busy = false;
  String? _err;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _styleCtrl.dispose();
    _capacityCtrl.dispose();
    _scheduleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save(); // writes onSaved values (level, etc.)
    setState(() { _busy = true; _err = null; });
    try {
      await GroupService.createGroup(
        name:        _nameCtrl.text.trim(),
        danceStyle:  _styleCtrl.text.trim(),
        level:       _level!,
        maxCapacity: int.parse(_capacityCtrl.text.trim()),
        schedule:    _scheduleCtrl.text.trim(),
        schoolId:    widget.schoolId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err  = 'groupForm.createError'.tr();
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
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ─────────────────────────────────────────────────
                _DialogHeader(onClose: () => Navigator.pop(context)),
                const SizedBox(height: 24),

                // ── Fila 1: Nombre + Estilo de baile ──────────────────────
                if (!isMobile)
                  Row(children: [
                    Expanded(child: _LabeledField(
                      label: 'groupForm.nameField'.tr(),
                      hint: 'groupForm.nameHint'.tr(),
                      ctrl: _nameCtrl,
                      required: true,
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _LabeledField(
                      label: 'groupForm.styleField'.tr(),
                      hint: 'groupForm.styleHint'.tr(),
                      ctrl: _styleCtrl,
                      required: true,
                    )),
                  ])
                else ...[
                  _LabeledField(
                    label: 'groupForm.nameField'.tr(),
                    hint: 'groupForm.nameHint'.tr(),
                    ctrl: _nameCtrl,
                    required: true,
                  ),
                  const SizedBox(height: 14),
                  _LabeledField(
                    label: 'groupForm.styleField'.tr(),
                    hint: 'groupForm.styleHint'.tr(),
                    ctrl: _styleCtrl,
                    required: true,
                  ),
                ],
                const SizedBox(height: 14),

                // ── Fila 2: Nivel + Capacidad máxima ──────────────────────
                if (!isMobile)
                  Row(children: [
                    Expanded(child: _LabeledDropdown(
                      label: 'groupForm.levelField'.tr(),
                      items: _kLevels,
                      onSaved: (v) => _level = v,
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _LabeledField(
                      label: 'groupForm.maxCapacity'.tr(),
                      hint: '20',
                      ctrl: _capacityCtrl,
                      required: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _capacityValidator,
                    )),
                  ])
                else ...[
                  _LabeledDropdown(
                    label: 'groupForm.levelField'.tr(),
                    items: _kLevels,
                    onSaved: (v) => _level = v,
                  ),
                  const SizedBox(height: 14),
                  _LabeledField(
                    label: 'groupForm.maxCapacity'.tr(),
                    hint: '20',
                    ctrl: _capacityCtrl,
                    required: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _capacityValidator,
                  ),
                ],
                const SizedBox(height: 14),

                // ── Fila 3: Horario (ancho completo) ──────────────────────
                _LabeledField(
                  label: 'groupForm.scheduleField'.tr(),
                  hint: 'groupForm.scheduleHint'.tr(),
                  ctrl: _scheduleCtrl,
                  required: true,
                ),

                // ── Error ──────────────────────────────────────────────────
                if (_err != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _err!),
                ],
                const SizedBox(height: 28),

                // ── Botones ────────────────────────────────────────────────
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
                      label: 'groupForm.createBtn'.tr(),
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

  String? _capacityValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'form.required'.tr();
    final n = int.tryParse(v.trim());
    if (n == null || n <= 0) return 'Debe ser mayor que 0';
    return null;
  }
}

// ─── Dialog header ────────────────────────────────────────────────────────────
class _DialogHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _DialogHeader({required this.onClose});

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
        child: const Icon(Icons.groups_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('groupForm.addTitle'.tr(), style: _ot(18, FontWeight.w700, _kInk)),
            Text('Rellena los datos del grupo',
                style: _ot(12, FontWeight.normal, _kMuted)),
          ],
        ),
      ),
      GestureDetector(
        onTap: onClose,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _kFieldBg, borderRadius: BorderRadius.circular(8),
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
  final String              label;
  final String              hint;
  final TextEditingController ctrl;
  final bool                required;
  final TextInputType?      keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.ctrl,
    this.required = false,
    this.keyboardType,
    this.inputFormatters,
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
          inputFormatters: inputFormatters,
          style: _ot(14, FontWeight.normal, _kInk),
          validator: validator ??
              (required
                  ? (v) => (v == null || v.trim().isEmpty)
                      ? 'form.required'.tr()
                      : null
                  : null),
          decoration: _dec(hint),
        ),
      ],
    );
  }
}

// ─── Labeled dropdown ─────────────────────────────────────────────────────────
class _LabeledDropdown extends StatelessWidget {
  final String                  label;
  final List<String>            items;
  final FormFieldSetter<String>? onSaved;

  const _LabeledDropdown({
    required this.label,
    required this.items,
    this.onSaved,
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
            children: [
              TextSpan(text: ' *', style: _ot(13, FontWeight.w600, _kError)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: null,
          decoration: _dec('groupForm.selectLevel'.tr()),
          icon: const Icon(
              Icons.keyboard_arrow_down_rounded, color: _kHint, size: 20),
          isExpanded: true,
          dropdownColor: Colors.white,
          style: _ot(14, FontWeight.normal, _kInk),
          borderRadius: BorderRadius.circular(12),
          items: items
              .map((l) => DropdownMenuItem(
                    value: l,
                    child: Text(l, style: _ot(14, FontWeight.normal, _kInk)),
                  ))
              .toList(),
          onChanged: (_) {},
          onSaved: onSaved,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'El nivel es obligatorio' : null,
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
  final String       label;
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
            style: _ot(14, FontWeight.w600,
                onTap == null ? _kHint : _kMuted)),
      ),
    );
  }
}

// ─── Primary button ───────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String       label;
  final bool         loading;
  final VoidCallback? onTap;
  const _PrimaryButton({
    required this.label,
    required this.loading,
    this.onTap,
  });

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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kPrimaryDk, _kPrimaryLt],
                ),
          color: loading ? const Color(0xFFBFDBFE) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: loading
              ? null
              : const [
                  BoxShadow(
                      color: Color(0x442563EB),
                      offset: Offset(0, 4),
                      blurRadius: 12),
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
