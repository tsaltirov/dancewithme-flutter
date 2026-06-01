import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/event_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kPrimary    = Color(0xFF2563EB);
const _kPrimaryDk  = Color(0xFF1D4ED8);
const _kPrimaryLt  = Color(0xFF3B82F6);
const _kGreenDk    = Color(0xFF16A34A);
const _kGreenLt    = Color(0xFF22C55E);
const _kInk        = Color(0xFF1E293B);
const _kMuted      = Color(0xFF64748B);
const _kHint       = Color(0xFF94A3B8);
const _kBorder     = Color(0xFFE2E8F0);
const _kFieldBg    = Color(0xFFF1F5F9);
const _kError      = Color(0xFFEF4444);

TextStyle _ot(double sz, FontWeight w, Color c) =>
    GoogleFonts.outfit(fontSize: sz, fontWeight: w, color: c);

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: _ot(14, FontWeight.normal, _kHint),
      filled: true,
      fillColor: _kFieldBg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
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

// ─── Price entry (local UI model) ─────────────────────────────────────────────
class _PriceEntry {
  final String type;
  final String label;
  final double amount;
  final bool   optional;

  const _PriceEntry({
    required this.type,
    required this.label,
    required this.amount,
    required this.optional,
  });
}

// ─── Badge color helpers ──────────────────────────────────────────────────────
Color _badgeBg(String type) => switch (type.toLowerCase()) {
      'vip'        => const Color(0xFFF3E8FF),
      'socio'      => const Color(0xFFDCFCE7),
      'early bird' => const Color(0xFFFEF3C7),
      _            => const Color(0xFFEFF6FF),
    };

Color _badgeFg(String type) => switch (type.toLowerCase()) {
      'vip'        => const Color(0xFF9333EA),
      'socio'      => const Color(0xFF16A34A),
      'early bird' => const Color(0xFFD97706),
      _            => _kPrimary,
    };

// ─── Public entry ─────────────────────────────────────────────────────────────
Future<bool> showAddEventDialog(
  BuildContext context, {
  required int schoolId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AddEventDialog(schoolId: schoolId),
  );
  return result ?? false;
}

// ─── Dialog ───────────────────────────────────────────────────────────────────
class _AddEventDialog extends StatefulWidget {
  final int schoolId;
  const _AddEventDialog({required this.schoolId});

  @override
  State<_AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<_AddEventDialog> {
  // ── Navigation ───────────────────────────────────────────────────────────────
  int    _step              = 0;
  int?   _createdEventId;
  String _createdEventTitle = '';

  // ── Step 1: event details ─────────────────────────────────────────────────
  final _s1Key     = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _venueCtrl = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  int     _capacity = 20;
  bool    _busyS1   = false;
  String? _errS1;

  // ── Step 2: prices ────────────────────────────────────────────────────────
  final _s2Key      = GlobalKey<FormState>();
  final _typeCtrl   = TextEditingController();
  final _labelCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool              _optional      = false;
  List<_PriceEntry> _prices        = [];
  bool              _savingPrices  = false;
  String?           _errS2;

  @override
  void initState() {
    super.initState();
    final now  = DateTime.now();
    _startDate = now;
    _endDate   = now.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _venueCtrl.dispose();
    _typeCtrl.dispose();
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmtDisplay(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  String _toIso(DateTime dt) => dt.toUtc().toIso8601String();

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _kPrimary, onPrimary: Colors.white, onSurface: _kInk,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _kPrimary, onPrimary: Colors.white, onSurface: _kInk,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedTime == null || !mounted) return;

    final result = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      pickedTime.hour, pickedTime.minute,
    );
    setState(() {
      if (isStart) {
        _startDate = result;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(hours: 2));
        }
      } else {
        _endDate = result;
      }
    });
  }

  // ── Step 1 submit ─────────────────────────────────────────────────────────
  Future<void> _submitStep1() async {
    if (!_s1Key.currentState!.validate()) return;
    if (_endDate.isBefore(_startDate)) {
      setState(() => _errS1 = 'eventForm.dateError'.tr());
      return;
    }
    setState(() { _busyS1 = true; _errS1 = null; });
    try {
      final event = await EventService.createEvent(
        title:       _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        startDate:   _toIso(_startDate),
        endDate:     _toIso(_endDate),
        venue:       _venueCtrl.text.trim(),
        maxCapacity: _capacity,
        schoolId:    widget.schoolId,
      );
      if (!mounted) return;
      setState(() {
        _createdEventId    = event.id;
        _createdEventTitle = event.title;
        _busyS1            = false;
        _step              = 1;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busyS1 = false;
        _errS1  = 'eventForm.createError'.tr();
      });
    }
  }

  // ── Step 2: add price to local list ──────────────────────────────────────
  void _addPrice() {
    if (!_s2Key.currentState!.validate()) return;
    final amount = double.tryParse(
          _amountCtrl.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
    setState(() {
      _prices = [
        ..._prices,
        _PriceEntry(
          type:     _typeCtrl.text.trim(),
          label:    _labelCtrl.text.trim(),
          amount:   amount,
          optional: _optional,
        ),
      ];
      _typeCtrl.clear();
      _labelCtrl.clear();
      _amountCtrl.clear();
      _optional = false;
    });
    _s2Key.currentState?.reset();
  }

  // ── Step 2: save prices batch ─────────────────────────────────────────────
  Future<void> _saveAndFinish() async {
    if (_prices.isEmpty) return;
    setState(() { _savingPrices = true; _errS2 = null; });
    try {
      await Future.wait(
        _prices.map((p) => EventPriceService.createEventPrice(
          eventId:  _createdEventId!,
          type:     p.type,
          label:    p.label,
          amount:   p.amount,
          optional: p.optional,
        )),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingPrices = false;
        _errS2 = 'pricing.saveError'.tr();
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isMobile = w < 600;

    return Dialog(
      insetPadding: EdgeInsets.only(
        left:   isMobile ? 16 : 40,
        right:  isMobile ? 16 : 40,
        top:    isMobile ? 24 : 40,
        bottom: isMobile ? 16 : 40,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: _step == 0
              ? _buildStep1(isMobile, key: const ValueKey(0))
              : _buildStep2(isMobile, key: const ValueKey(1)),
        ),
      ),
    );
  }

  // ── Step 1 content ────────────────────────────────────────────────────────
  Widget _buildStep1(bool isMobile, {Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Form(
        key: _s1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(onClose: () => Navigator.pop(context, false)),
            const SizedBox(height: 24),

            _LabeledField(
              label: 'eventForm.titleField'.tr(), hint: 'eventForm.titleHint'.tr(),
              ctrl: _titleCtrl, required: true,
            ),
            const SizedBox(height: 10),

            _LabeledMultilineField(
              label: 'eventForm.descField'.tr(), hint: 'eventForm.descHint'.tr(),
              ctrl: _descCtrl,
            ),
            const SizedBox(height: 10),

            if (!isMobile)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _DateTimePickerField(
                  label: 'eventForm.startDate'.tr(),
                  value: _fmtDisplay(_startDate),
                  onTap: () => _pickDateTime(isStart: true),
                )),
                const SizedBox(width: 16),
                Expanded(child: _DateTimePickerField(
                  label: 'eventForm.endDate'.tr(),
                  value: _fmtDisplay(_endDate),
                  onTap: () => _pickDateTime(isStart: false),
                )),
              ])
            else ...[
              _DateTimePickerField(
                label: 'eventForm.startDate'.tr(),
                value: _fmtDisplay(_startDate),
                onTap: () => _pickDateTime(isStart: true),
              ),
              const SizedBox(height: 10),
              _DateTimePickerField(
                label: 'eventForm.endDate'.tr(),
                value: _fmtDisplay(_endDate),
                onTap: () => _pickDateTime(isStart: false),
              ),
            ],
            const SizedBox(height: 10),

            if (!isMobile)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _LabeledField(
                  label: 'eventForm.venue'.tr(), hint: 'eventForm.venueHint'.tr(),
                  ctrl: _venueCtrl, required: true,
                )),
                const SizedBox(width: 16),
                Expanded(child: _CapacityStepper(
                  label: 'eventForm.maxCapacity'.tr(),
                  value: _capacity,
                  onChange: (v) => setState(() => _capacity = v),
                )),
              ])
            else ...[
              _LabeledField(
                label: 'eventForm.venue'.tr(), hint: 'eventForm.venueHint'.tr(),
                ctrl: _venueCtrl, required: true,
              ),
              const SizedBox(height: 10),
              _CapacityStepper(
                label: 'eventForm.maxCapacity'.tr(),
                value: _capacity,
                onChange: (v) => setState(() => _capacity = v),
              ),
            ],

            if (_errS1 != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _errS1!),
            ],
            const SizedBox(height: 20),

            Row(children: [
              Expanded(
                child: _OutlineButton(
                  label: 'form.cancel'.tr(),
                  onTap: _busyS1 ? null : () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PrimaryButton(
                  label: 'eventForm.saveAndContinue'.tr(),
                  loading: _busyS1,
                  onTap: _submitStep1,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Step 2 content ────────────────────────────────────────────────────────
  Widget _buildStep2(bool isMobile, {Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          _Step2Header(
            eventTitle: _createdEventTitle,
            onClose:    () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 20),

          // ── Price list ────────────────────────────────────────────────────
          if (_prices.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Aún no has añadido precios',
                style: _ot(13, FontWeight.normal, _kHint),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _prices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _PriceEntryCard(
                entry:    _prices[i],
                onRemove: () => setState(() => _prices.removeAt(i)),
              ),
            ),
          const SizedBox(height: 16),

          // ── Add price form ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: Form(
              key: _s2Key,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('pricing.addSection'.tr(),
                      style: _ot(13, FontWeight.w700, _kInk)),
                  const SizedBox(height: 12),

                  // Tipo | Etiqueta
                  if (!isMobile)
                    Row(children: [
                      Expanded(child: _LabeledField(
                        label: 'pricing.typeField'.tr(), hint: 'pricing.typeHint'.tr(),
                        ctrl: _typeCtrl, required: true,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _LabeledField(
                        label: 'pricing.labelField'.tr(), hint: 'pricing.labelHint'.tr(),
                        ctrl: _labelCtrl, required: true,
                      )),
                    ])
                  else ...[
                    _LabeledField(
                      label: 'pricing.typeField'.tr(), hint: 'pricing.typeHint'.tr(),
                      ctrl: _typeCtrl, required: true,
                    ),
                    const SizedBox(height: 10),
                    _LabeledField(
                      label: 'pricing.labelField'.tr(), hint: 'pricing.labelHint'.tr(),
                      ctrl: _labelCtrl, required: true,
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Importe | Opcional
                  if (!isMobile)
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: _LabeledAmountField(ctrl: _amountCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _OptionalToggle(
                        value: _optional,
                        onChanged: (v) => setState(() => _optional = v),
                      )),
                    ])
                  else ...[
                    _LabeledAmountField(ctrl: _amountCtrl),
                    const SizedBox(height: 10),
                    _OptionalToggle(
                      value: _optional,
                      onChanged: (v) => setState(() => _optional = v),
                    ),
                  ],
                  const SizedBox(height: 10),

                  _AddPriceButton(onTap: _addPrice),
                ],
              ),
            ),
          ),

          if (_errS2 != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _errS2!),
          ],
          const SizedBox(height: 24),

          // ── Final buttons ─────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _OutlineButton(
                label: 'eventForm.skipAndFinish'.tr(),
                onTap: _savingPrices ? null : () => Navigator.pop(context, true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: _prices.isEmpty ? 0.4 : 1.0,
                child: _PrimaryButton(
                  label: 'eventForm.saveAndFinish'.tr(),
                  loading: _savingPrices,
                  onTap: _prices.isEmpty ? null : _saveAndFinish,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Step 2 header ────────────────────────────────────────────────────────────
class _Step2Header extends StatelessWidget {
  final String       eventTitle;
  final VoidCallback onClose;

  const _Step2Header({required this.eventTitle, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_kGreenDk, _kGreenLt],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.monetization_on_outlined,
            color: Colors.white, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('eventForm.pricesTitle'.tr(),
                style: _ot(18, FontWeight.w700, _kInk)),
            Text(eventTitle,
                style: _ot(12, FontWeight.normal, _kMuted),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _kFieldBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder),
        ),
        child: Text('eventForm.step2of2'.tr(),
            style: _ot(11, FontWeight.w600, _kMuted)),
      ),
      const SizedBox(width: 8),
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

// ─── Price entry card ─────────────────────────────────────────────────────────
class _PriceEntryCard extends StatelessWidget {
  final _PriceEntry  entry;
  final VoidCallback onRemove;

  const _PriceEntryCard({required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        // Type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _badgeBg(entry.type),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(entry.type,
              style: _ot(11, FontWeight.w700, _badgeFg(entry.type))),
        ),
        const SizedBox(width: 10),
        // Label + amount
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.label, style: _ot(13, FontWeight.w600, _kInk)),
              Text('€ ${entry.amount.toStringAsFixed(2)}',
                  style: _ot(12, FontWeight.normal, _kMuted)),
            ],
          ),
        ),
        // Optional chip
        if (entry.optional) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Opcional',
                style: _ot(10, FontWeight.w600, const Color(0xFF9333EA))),
          ),
          const SizedBox(width: 8),
        ],
        // Remove
        GestureDetector(
          onTap: onRemove,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.close_rounded, size: 14, color: _kError),
          ),
        ),
      ]),
    );
  }
}

// ─── Amount field ─────────────────────────────────────────────────────────────
class _LabeledAmountField extends StatelessWidget {
  final TextEditingController ctrl;
  const _LabeledAmountField({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            text: 'pricing.amountField'.tr(),
            style: _ot(13, FontWeight.w600, _kInk),
            children: [
              TextSpan(text: ' *', style: _ot(13, FontWeight.w600, _kError)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: _ot(14, FontWeight.normal, _kInk),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'form.required'.tr();
            final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
            if (parsed == null || parsed < 0) return 'pricing.invalidAmount'.tr();
            return null;
          },
          decoration: _dec('0.00'),
        ),
      ],
    );
  }
}

// ─── Optional toggle ──────────────────────────────────────────────────────────
class _OptionalToggle extends StatelessWidget {
  final bool                 value;
  final ValueChanged<bool>   onChanged;

  const _OptionalToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('pricing.optionalField'.tr(), style: _ot(13, FontWeight.w600, _kInk)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _kFieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: Row(children: [
            Text(value ? 'pricing.optionalYes'.tr() : 'pricing.optionalNo'.tr(),
                style: _ot(14, FontWeight.normal, value ? _kPrimary : _kMuted)),
            const Spacer(),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: _kPrimary,
              activeTrackColor: _kPrimaryLt,
            ),
          ]),
        ),
      ],
    );
  }
}

// ─── Add price outline button ─────────────────────────────────────────────────
class _AddPriceButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPriceButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kPrimary, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add_rounded, color: _kPrimary, size: 16),
          const SizedBox(width: 6),
          Text('pricing.addBtn'.tr(),
              style: _ot(13, FontWeight.w600, _kPrimary)),
        ]),
      ),
    );
  }
}

// ─── Dialog header (step 1) ───────────────────────────────────────────────────
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
        child: const Icon(Icons.event_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('eventForm.addTitle'.tr(), style: _ot(18, FontWeight.w700, _kInk)),
            Text('eventForm.addSubtitle'.tr(),
                style: _ot(12, FontWeight.normal, _kMuted)),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _kFieldBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder),
        ),
        child: Text('eventForm.step1of2'.tr(),
            style: _ot(11, FontWeight.w600, _kMuted)),
      ),
      const SizedBox(width: 8),
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
  final String                label;
  final String                hint;
  final TextEditingController ctrl;
  final bool                  required;

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
              ? (v) => (v == null || v.trim().isEmpty) ? 'form.required'.tr() : null
              : null,
          decoration: _dec(hint),
        ),
      ],
    );
  }
}

// ─── Multiline text field ─────────────────────────────────────────────────────
class _LabeledMultilineField extends StatelessWidget {
  final String                label;
  final String                hint;
  final TextEditingController ctrl;

  const _LabeledMultilineField({
    required this.label,
    required this.hint,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _ot(13, FontWeight.w600, _kInk)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: 3,
          style: _ot(14, FontWeight.normal, _kInk),
          decoration: _dec(hint),
        ),
      ],
    );
  }
}

// ─── DateTime picker field ────────────────────────────────────────────────────
class _DateTimePickerField extends StatelessWidget {
  final String       label;
  final String       value;
  final VoidCallback onTap;

  const _DateTimePickerField({
    required this.label,
    required this.value,
    required this.onTap,
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
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _kFieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 16, color: _kPrimary),
              const SizedBox(width: 10),
              Expanded(child: Text(value,
                  style: _ot(14, FontWeight.normal, _kInk))),
              const Icon(Icons.edit_calendar_rounded,
                  size: 14, color: _kHint),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── Capacity stepper ─────────────────────────────────────────────────────────
class _CapacityStepper extends StatelessWidget {
  final String            label;
  final int               value;
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
          GestureDetector(
            onTap: canDecrement ? () => onChange(value - 1) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: canDecrement ? Colors.white : const Color(0xFFF8FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: canDecrement ? _kBorder : const Color(0xFFECECEC),
                ),
              ),
              child: Icon(Icons.remove_rounded, size: 18,
                  color: canDecrement ? _kInk : _kHint),
            ),
          ),
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
              child: Text('$value', style: _ot(22, FontWeight.w700, _kInk)),
            ),
          ),
          GestureDetector(
            onTap: () => onChange(value + 1),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_kPrimaryDk, _kPrimaryLt],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x442563EB),
                      offset: Offset(0, 2), blurRadius: 6),
                ],
              ),
              child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            ),
          ),
        ]),
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
        height: 42,
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
        height: 42,
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
