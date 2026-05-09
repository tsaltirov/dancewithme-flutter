import 'package:flutter/material.dart';
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
Future<bool> showEditGroupDialog(
  BuildContext context, {
  required Group group,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _EditGroupDialog(group: group),
  );
  return result ?? false;
}

// ─── Dialog ───────────────────────────────────────────────────────────────────
class _EditGroupDialog extends StatefulWidget {
  final Group group;
  const _EditGroupDialog({required this.group});

  @override
  State<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<_EditGroupDialog> {
  final _formKey     = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _styleCtrl;
  late final TextEditingController _scheduleCtrl;

  // Level via onSaved; initialised with current value as fallback
  String? _level;
  late int _capacity;
  bool     _busy = false;
  String?  _err;

  @override
  void initState() {
    super.initState();
    _nameCtrl     = TextEditingController(text: widget.group.name);
    _styleCtrl    = TextEditingController(text: widget.group.danceStyle);
    _scheduleCtrl = TextEditingController(text: widget.group.schedule);
    _level        = widget.group.level;
    _capacity     = widget.group.maxCapacity.clamp(1, 9999);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _styleCtrl.dispose();
    _scheduleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save(); // writes _level via onSaved
    setState(() { _busy = true; _err = null; });
    try {
      await GroupService.updateGroup(
        id:          widget.group.id,
        name:        _nameCtrl.text.trim(),
        danceStyle:  _styleCtrl.text.trim(),
        level:       _level!,
        maxCapacity: _capacity,
        schedule:    _scheduleCtrl.text.trim(),
        schoolId: widget.group.schoolId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err  = 'No se pudo actualizar el grupo. Comprueba los datos.';
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
                _DialogHeader(
                  groupName: widget.group.name,
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 24),

                // ── Fila 1: Nombre + Estilo ────────────────────────────────
                if (!isMobile)
                  Row(children: [
                    Expanded(child: _LabeledField(
                      label: 'Nombre del grupo',
                      hint: 'Ej: Salsa Nivel 1',
                      ctrl: _nameCtrl,
                      required: true,
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _LabeledField(
                      label: 'Estilo de baile',
                      hint: 'Salsa, Bachata…',
                      ctrl: _styleCtrl,
                      required: true,
                    )),
                  ])
                else ...[
                  _LabeledField(
                    label: 'Nombre del grupo',
                    hint: 'Ej: Salsa Nivel 1',
                    ctrl: _nameCtrl,
                    required: true,
                  ),
                  const SizedBox(height: 14),
                  _LabeledField(
                    label: 'Estilo de baile',
                    hint: 'Salsa, Bachata…',
                    ctrl: _styleCtrl,
                    required: true,
                  ),
                ],
                const SizedBox(height: 14),

                // ── Fila 2: Nivel + Capacidad (stepper) ───────────────────
                if (!isMobile)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _LabeledDropdown(
                      label: 'Nivel',
                      initialValue: widget.group.level,
                      items: _kLevels,
                      onSaved: (v) => _level = v ?? _level,
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _CapacityStepper(
                      label: 'Capacidad máxima',
                      value: _capacity,
                      onChange: (v) => setState(() => _capacity = v),
                    )),
                  ])
                else ...[
                  _LabeledDropdown(
                    label: 'Nivel',
                    initialValue: widget.group.level,
                    items: _kLevels,
                    onSaved: (v) => _level = v ?? _level,
                  ),
                  const SizedBox(height: 14),
                  _CapacityStepper(
                    label: 'Capacidad máxima',
                    value: _capacity,
                    onChange: (v) => setState(() => _capacity = v),
                  ),
                ],
                const SizedBox(height: 14),

                // ── Fila 3: Horario (full width) ───────────────────────────
                _LabeledField(
                  label: 'Horario',
                  hint: 'Ej: Lunes y Miércoles 18:00-19:30',
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
                      label: 'Cancelar',
                      onTap: _busy ? null : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PrimaryButton(
                      label: 'Guardar Cambios',
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
  final String       groupName;
  final VoidCallback onClose;
  const _DialogHeader({required this.groupName, required this.onClose});

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
        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Editar Grupo', style: _ot(18, FontWeight.w700, _kInk)),
            Text(
              groupName,
              style: _ot(12, FontWeight.normal, _kMuted),
              overflow: TextOverflow.ellipsis,
            ),
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

// ─── Capacity stepper ─────────────────────────────────────────────────────────
class _CapacityStepper extends StatelessWidget {
  final String         label;
  final int            value;
  final ValueChanged<int> onChange;

  const _CapacityStepper({
    required this.label,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrement = value > 1;
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
        Row(children: [
          // ── Decrement ───────────────────────────────────────────────────
          GestureDetector(
            onTap: canDecrement ? () => onChange(value - 1) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: canDecrement ? Colors.white : const Color(0xFFF8FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: canDecrement ? _kBorder : const Color(0xFFECECEC),
                ),
              ),
              child: Icon(
                Icons.remove_rounded,
                size: 18,
                color: canDecrement ? _kInk : _kHint,
              ),
            ),
          ),
          // ── Value display ───────────────────────────────────────────────
          Expanded(
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _kFieldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: _ot(22, FontWeight.w700, _kInk),
              ),
            ),
          ),
          // ── Increment ───────────────────────────────────────────────────
          GestureDetector(
            onTap: () => onChange(value + 1),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kPrimaryDk, _kPrimaryLt],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x442563EB),
                      offset: Offset(0, 2),
                      blurRadius: 6),
                ],
              ),
              child: const Icon(
                  Icons.add_rounded, size: 18, color: Colors.white),
            ),
          ),
        ]),
      ],
    );
  }
}

// ─── Labeled text field ───────────────────────────────────────────────────────
class _LabeledField extends StatelessWidget {
  final String              label;
  final String              hint;
  final TextEditingController ctrl;
  final bool                required;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.ctrl,
    this.required = false,
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
          style: _ot(14, FontWeight.normal, _kInk),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null
              : null,
          decoration: _dec(hint),
        ),
      ],
    );
  }
}

// ─── Labeled dropdown (initialValue + onSaved — no deprecated 'value') ────────
class _LabeledDropdown extends StatelessWidget {
  final String               label;
  final String?              initialValue;
  final List<String>         items;
  final FormFieldSetter<String>? onSaved;

  const _LabeledDropdown({
    required this.label,
    required this.initialValue,
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
          initialValue: initialValue,
          decoration: _dec('Selecciona el nivel'),
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
