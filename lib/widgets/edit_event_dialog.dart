import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/event_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFF2563EB);
const _kPrimaryDk = Color(0xFF1D4ED8);
const _kPrimaryLt = Color(0xFF3B82F6);
const _kGreenDk   = Color(0xFF16A34A);
const _kGreenLt   = Color(0xFF22C55E);
const _kInk       = Color(0xFF1E293B);
const _kMuted     = Color(0xFF64748B);
const _kHint      = Color(0xFF94A3B8);
const _kBorder    = Color(0xFFE2E8F0);
const _kFieldBg   = Color(0xFFF1F5F9);
const _kError     = Color(0xFFEF4444);

TextStyle _ot(double sz, FontWeight w, Color c) =>
    GoogleFonts.outfit(fontSize: sz, fontWeight: w, color: c);

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: _ot(14, FontWeight.normal, _kHint),
      filled: true,
      fillColor: _kFieldBg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
Future<bool> showEditEventDialog(
  BuildContext context, {
  required Event event,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EditEventDialog(event: event),
  );
  return result ?? false;
}

// ─── Dialog ───────────────────────────────────────────────────────────────────
class _EditEventDialog extends StatefulWidget {
  final Event event;
  const _EditEventDialog({required this.event});

  @override
  State<_EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<_EditEventDialog> {
  // ── Navigation ───────────────────────────────────────────────────────────
  int _step = 0;

  // ── Step 1 ───────────────────────────────────────────────────────────────
  final _s1Key     = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _venueCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  late int      _capacity;
  bool    _busyS1 = false;
  String? _errS1;

  // ── Step 2 ───────────────────────────────────────────────────────────────
  bool              _loadingPrices = false;
  List<EventPrice>  _prices        = [];
  String?           _pricesErr;
  bool              _showAddForm   = false;
  final _addKey     = GlobalKey<FormState>();
  final _addTypeCtrl   = TextEditingController();
  final _addLabelCtrl  = TextEditingController();
  final _addAmountCtrl = TextEditingController();
  bool    _addOptional = false;
  bool    _addingPrice = false;
  String? _errAdd;

  // ── Helpers ───────────────────────────────────────────────────────────────
  static DateTime _parseIso(String iso) {
    try { return DateTime.parse(iso).toLocal(); }
    catch (_) { return DateTime.now(); }
  }

  String _fmtDisplay(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  String _toIso(DateTime dt) => dt.toUtc().toIso8601String();

  @override
  void initState() {
    super.initState();
    final e       = widget.event;
    _titleCtrl    = TextEditingController(text: e.title);
    _descCtrl     = TextEditingController(text: e.description);
    _venueCtrl    = TextEditingController(text: e.venue);
    _startDate    = _parseIso(e.startDate);
    _endDate      = _parseIso(e.endDate);
    _capacity     = e.maxCapacity.clamp(1, 9999);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _venueCtrl.dispose();
    _addTypeCtrl.dispose();
    _addLabelCtrl.dispose();
    _addAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _kPrimary, onPrimary: Colors.white, onSurface: _kInk),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _kPrimary, onPrimary: Colors.white, onSurface: _kInk),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    final result = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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

  // ── Step 1: update event ──────────────────────────────────────────────────
  Future<void> _submitStep1() async {
    if (!_s1Key.currentState!.validate()) return;
    if (_endDate.isBefore(_startDate)) {
      setState(() => _errS1 = 'eventForm.dateError'.tr());
      return;
    }
    setState(() { _busyS1 = true; _errS1 = null; });
    try {
      await EventService.updateEvent(
        id:          widget.event.id,
        title:       _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        startDate:   _toIso(_startDate),
        endDate:     _toIso(_endDate),
        venue:       _venueCtrl.text.trim(),
        maxCapacity: _capacity,
        schoolId:    widget.event.schoolId,
      );
      if (!mounted) return;
      setState(() { _busyS1 = false; _step = 1; });
      _loadPrices();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busyS1 = false;
        _errS1  = 'eventForm.updateError'.tr();
      });
    }
  }

  // ── Step 2: load prices ───────────────────────────────────────────────────
  Future<void> _loadPrices() async {
    setState(() { _loadingPrices = true; _pricesErr = null; });
    try {
      final prices = await EventService.getEventPrices(widget.event.id);
      if (!mounted) return;
      setState(() { _prices = prices; _loadingPrices = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingPrices = false; _pricesErr = e.toString(); });
    }
  }

  // ── Step 2: add new price ─────────────────────────────────────────────────
  Future<void> _addPrice() async {
    if (!_addKey.currentState!.validate()) return;
    final amount = double.tryParse(
          _addAmountCtrl.text.trim().replaceAll(',', '.'),
        ) ?? 0.0;
    setState(() { _addingPrice = true; _errAdd = null; });
    try {
      final newPrice = await EventPriceService.createEventPrice(
        eventId:  widget.event.id,
        type:     _addTypeCtrl.text.trim(),
        label:    _addLabelCtrl.text.trim(),
        amount:   amount,
        optional: _addOptional,
      );
      if (!mounted) return;
      setState(() {
        _prices      = [..._prices, newPrice];
        _addingPrice = false;
        _showAddForm = false;
      });
      _addTypeCtrl.clear();
      _addLabelCtrl.clear();
      _addAmountCtrl.clear();
      _addKey.currentState?.reset();
    } catch (_) {
      if (!mounted) return;
      setState(() { _addingPrice = false; _errAdd = 'pricing.addError'.tr(); });
    }
  }

  void _onPriceUpdated(int index, EventPrice updated) =>
      setState(() => _prices = [..._prices]..[index] = updated);

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

  // ── Step 1 ────────────────────────────────────────────────────────────────
  Widget _buildStep1(bool isMobile, {Key? key}) => SingleChildScrollView(
        key: key,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        child: Form(
          key: _s1Key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Step1Header(
                subtitle: widget.event.title,
                onClose:  () => Navigator.pop(context, false),
              ),
              const SizedBox(height: 24),
              _LabeledField(label: 'eventForm.titleField'.tr(), hint: 'eventForm.titleHint'.tr(),
                  ctrl: _titleCtrl, required: true),
              const SizedBox(height: 10),
              _LabeledMultilineField(label: 'eventForm.descField'.tr(),
                  hint: 'eventForm.descHint'.tr(), ctrl: _descCtrl),
              const SizedBox(height: 10),
              if (!isMobile)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _DateTimePickerField(
                    label: 'eventForm.startDate'.tr(), value: _fmtDisplay(_startDate),
                    onTap: () => _pickDateTime(isStart: true),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _DateTimePickerField(
                    label: 'eventForm.endDate'.tr(), value: _fmtDisplay(_endDate),
                    onTap: () => _pickDateTime(isStart: false),
                  )),
                ])
              else ...[
                _DateTimePickerField(label: 'eventForm.startDate'.tr(),
                    value: _fmtDisplay(_startDate),
                    onTap: () => _pickDateTime(isStart: true)),
                const SizedBox(height: 10),
                _DateTimePickerField(label: 'eventForm.endDate'.tr(),
                    value: _fmtDisplay(_endDate),
                    onTap: () => _pickDateTime(isStart: false)),
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
                    label: 'eventForm.maxCapacity'.tr(), value: _capacity,
                    onChange: (v) => setState(() => _capacity = v),
                  )),
                ])
              else ...[
                _LabeledField(label: 'eventForm.venue'.tr(), hint: 'eventForm.venueHint'.tr(),
                    ctrl: _venueCtrl, required: true),
                const SizedBox(height: 10),
                _CapacityStepper(label: 'eventForm.maxCapacity'.tr(), value: _capacity,
                    onChange: (v) => setState(() => _capacity = v)),
              ],
              if (_errS1 != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: _errS1!),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _OutlineButton(
                  label: 'form.cancel'.tr(),
                  onTap: _busyS1 ? null : () => Navigator.pop(context, false),
                )),
                const SizedBox(width: 12),
                Expanded(child: _PrimaryButton(
                  label: 'eventForm.saveAndContinue'.tr(),
                  loading: _busyS1, onTap: _submitStep1,
                )),
              ]),
            ],
          ),
        ),
      );

  // ── Step 2 ────────────────────────────────────────────────────────────────
  Widget _buildStep2(bool isMobile, {Key? key}) => SingleChildScrollView(
        key: key,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Step2Header(
              eventTitle: widget.event.title,
              onClose:    () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 20),

            // ── Price list ─────────────────────────────────────────────────
            if (_loadingPrices)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(
                    color: _kPrimary, strokeWidth: 2.5)),
              )
            else if (_pricesErr != null)
              _ErrorBanner(message: _pricesErr!)
            else if (_prices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Sin precios configurados',
                    style: _ot(13, FontWeight.normal, _kHint),
                    textAlign: TextAlign.center),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _prices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _EditablePriceCard(
                  key: ValueKey(_prices[i].id),
                  price:     _prices[i],
                  eventId:   widget.event.id,
                  isMobile:  isMobile,
                  onUpdated: (updated) => _onPriceUpdated(i, updated),
                ),
              ),

            const SizedBox(height: 16),

            // ── Add price section ──────────────────────────────────────────
            _AddPriceSection(
              isMobile:   isMobile,
              formKey:    _addKey,
              typeCtrl:   _addTypeCtrl,
              labelCtrl:  _addLabelCtrl,
              amountCtrl: _addAmountCtrl,
              optional:   _addOptional,
              expanded:   _showAddForm,
              loading:    _addingPrice,
              error:      _errAdd,
              onToggle:   () => setState(() {
                _showAddForm = !_showAddForm;
                _errAdd      = null;
              }),
              onOptionalChanged: (v) => setState(() => _addOptional = v),
              onAdd:      _addPrice,
            ),

            const SizedBox(height: 24),
            _PrimaryButton(
              label: 'eventForm.finish'.tr(),
              loading: false,
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
}

// ─── Step 1 header ────────────────────────────────────────────────────────────
class _Step1Header extends StatelessWidget {
  final String       subtitle;
  final VoidCallback onClose;
  const _Step1Header({required this.subtitle, required this.onClose});

  @override
  Widget build(BuildContext context) => Row(children: [
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
          child: const Icon(Icons.edit_calendar_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('eventForm.editTitle'.tr(), style: _ot(18, FontWeight.w700, _kInk)),
              Text(subtitle,
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
          child: Text('eventForm.step1of2'.tr(), style: _ot(11, FontWeight.w600, _kMuted)),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: _kFieldBg, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: const Icon(Icons.close_rounded, size: 18, color: _kMuted),
          ),
        ),
      ]);
}

// ─── Step 2 header ────────────────────────────────────────────────────────────
class _Step2Header extends StatelessWidget {
  final String       eventTitle;
  final VoidCallback onClose;
  const _Step2Header({required this.eventTitle, required this.onClose});

  @override
  Widget build(BuildContext context) => Row(children: [
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
          child: Text('eventForm.step2of2'.tr(), style: _ot(11, FontWeight.w600, _kMuted)),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: _kFieldBg, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: const Icon(Icons.close_rounded, size: 18, color: _kMuted),
          ),
        ),
      ]);
}

// ─── Editable price card ──────────────────────────────────────────────────────
class _EditablePriceCard extends StatefulWidget {
  final EventPrice              price;
  final int                     eventId;
  final bool                    isMobile;
  final ValueChanged<EventPrice> onUpdated;

  const _EditablePriceCard({
    super.key,
    required this.price,
    required this.eventId,
    required this.isMobile,
    required this.onUpdated,
  });

  @override
  State<_EditablePriceCard> createState() => _EditablePriceCardState();
}

class _EditablePriceCardState extends State<_EditablePriceCard> {
  bool    _editing  = false;
  bool    _saving   = false;
  String? _err;

  // Current display values (updated after successful save)
  late String _type;
  late String _label;
  late double _amount;
  late bool   _optional;

  late final TextEditingController _typeCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _type     = widget.price.type;
    _label    = widget.price.label;
    _amount   = widget.price.amount;
    _optional = widget.price.optional;
    _typeCtrl   = TextEditingController(text: _type);
    _labelCtrl  = TextEditingController(text: _label);
    _amountCtrl = TextEditingController(text: _amount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _enterEdit() {
    _typeCtrl.text   = _type;
    _labelCtrl.text  = _label;
    _amountCtrl.text = _amount.toStringAsFixed(2);
    setState(() { _editing = true; _err = null; });
  }

  void _cancelEdit() => setState(() { _editing = false; _err = null; });

  Future<void> _save() async {
    final amount = double.tryParse(
          _amountCtrl.text.trim().replaceAll(',', '.'),
        ) ?? _amount;
    setState(() { _saving = true; _err = null; });
    try {
      final updated = await EventService.updateEventPrice(
        eventId:  widget.eventId,
        priceId:  widget.price.id,
        type:     _typeCtrl.text.trim(),
        label:    _labelCtrl.text.trim(),
        amount:   amount,
        optional: _optional,
      );
      if (!mounted) return;
      setState(() {
        _type     = updated.type;
        _label    = updated.label;
        _amount   = updated.amount;
        _saving   = false;
        _editing  = false;
      });
      widget.onUpdated(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() { _saving = false; _err = 'Error al guardar el precio.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _editing ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _editing ? _kPrimary : _kBorder,
            width: _editing ? 1.5 : 1.0),
        boxShadow: _editing
            ? [const BoxShadow(
                color: Color(0x1A2563EB), offset: Offset(0, 2), blurRadius: 8)]
            : null,
      ),
      child: _editing ? _buildEditMode() : _buildViewMode(),
    );
  }

  Widget _buildViewMode() => Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _badgeBg(_type), borderRadius: BorderRadius.circular(20),
          ),
          child: Text(_type,
              style: _ot(11, FontWeight.w700, _badgeFg(_type))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_label, style: _ot(13, FontWeight.w600, _kInk)),
              Text('€ ${_amount.toStringAsFixed(2)}',
                  style: _ot(12, FontWeight.normal, _kMuted)),
            ],
          ),
        ),
        if (_optional) ...[
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
        GestureDetector(
          onTap: _enterEdit,
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.edit_outlined, size: 14, color: _kPrimary),
          ),
        ),
      ]);

  Widget _buildEditMode() {
    final isMobile = widget.isMobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit mode header
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _badgeBg(_type), borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Editando',
                style: _ot(11, FontWeight.w700, _badgeFg(_type))),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _saving ? null : _cancelEdit,
            child: const Icon(Icons.close_rounded, size: 18, color: _kMuted),
          ),
        ]),
        const SizedBox(height: 10),

        // Type | Label
        if (!isMobile)
          Row(children: [
            Expanded(child: _SmallField(label: 'Tipo', hint: 'General', ctrl: _typeCtrl)),
            const SizedBox(width: 10),
            Expanded(child: _SmallField(label: 'Etiqueta', hint: 'Entrada general', ctrl: _labelCtrl)),
          ])
        else ...[
          _SmallField(label: 'Tipo', hint: 'General', ctrl: _typeCtrl),
          const SizedBox(height: 8),
          _SmallField(label: 'Etiqueta', hint: 'Entrada general', ctrl: _labelCtrl),
        ],
        const SizedBox(height: 8),

        // Amount | Optional
        if (!isMobile)
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: _SmallAmountField(ctrl: _amountCtrl)),
            const SizedBox(width: 10),
            Expanded(child: _SmallOptionalToggle(
              value: _optional,
              onChanged: (v) => setState(() => _optional = v),
            )),
          ])
        else ...[
          _SmallAmountField(ctrl: _amountCtrl),
          const SizedBox(height: 8),
          _SmallOptionalToggle(
            value: _optional,
            onChanged: (v) => setState(() => _optional = v),
          ),
        ],

        if (_err != null) ...[
          const SizedBox(height: 8),
          _ErrorBanner(message: _err!),
        ],
        const SizedBox(height: 12),

        SizedBox(
          height: 38,
          child: _saving
              ? const Center(child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: _kPrimary)))
              : GestureDetector(
                  onTap: _save,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [_kPrimaryDk, _kPrimaryLt],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_rounded,
                          color: Colors.white, size: 15),
                      const SizedBox(width: 6),
                      Text('form.saveChanges'.tr(),
                          style: _ot(13, FontWeight.w600, Colors.white)),
                    ]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Add price section (collapsible) ─────────────────────────────────────────
class _AddPriceSection extends StatelessWidget {
  final bool                 isMobile;
  final GlobalKey<FormState> formKey;
  final TextEditingController typeCtrl;
  final TextEditingController labelCtrl;
  final TextEditingController amountCtrl;
  final bool                 optional;
  final bool                 expanded;
  final bool                 loading;
  final String?              error;
  final VoidCallback         onToggle;
  final ValueChanged<bool>   onOptionalChanged;
  final VoidCallback         onAdd;

  const _AddPriceSection({
    required this.isMobile,
    required this.formKey,
    required this.typeCtrl,
    required this.labelCtrl,
    required this.amountCtrl,
    required this.optional,
    required this.expanded,
    required this.loading,
    required this.error,
    required this.onToggle,
    required this.onOptionalChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle header
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: expanded ? _kPrimary : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    expanded ? Icons.remove_rounded : Icons.add_rounded,
                    size: 16,
                    color: expanded ? Colors.white : _kPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Text('pricing.addSection'.tr(),
                    style: _ot(13, FontWeight.w600,
                        expanded ? _kPrimary : _kInk)),
              ]),
            ),
          ),

          // Collapsible form
          if (expanded) ...[
            const Divider(color: _kBorder, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMobile)
                      Row(children: [
                        Expanded(child: _LabeledField(
                          label: 'pricing.typeField'.tr(), hint: 'pricing.typeHint'.tr(),
                          ctrl: typeCtrl, required: true,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _LabeledField(
                          label: 'pricing.labelField'.tr(), hint: 'pricing.labelHint'.tr(),
                          ctrl: labelCtrl, required: true,
                        )),
                      ])
                    else ...[
                      _LabeledField(label: 'pricing.typeField'.tr(), hint: 'pricing.typeHint'.tr(),
                          ctrl: typeCtrl, required: true),
                      const SizedBox(height: 10),
                      _LabeledField(label: 'pricing.labelField'.tr(), hint: 'pricing.labelHint'.tr(),
                          ctrl: labelCtrl, required: true),
                    ],
                    const SizedBox(height: 10),
                    if (!isMobile)
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Expanded(child: _LabeledAmountField(ctrl: amountCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _OptionalToggle(
                          value: optional, onChanged: onOptionalChanged,
                        )),
                      ])
                    else ...[
                      _LabeledAmountField(ctrl: amountCtrl),
                      const SizedBox(height: 10),
                      _OptionalToggle(
                        value: optional, onChanged: onOptionalChanged,
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBanner(message: error!),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 42,
                      child: loading
                          ? const Center(child: SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: _kPrimary)))
                          : GestureDetector(
                              onTap: onAdd,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _kPrimary, width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.add_rounded,
                                      color: _kPrimary, size: 16),
                                  const SizedBox(width: 6),
                                  Text('＋ Añadir',
                                      style: _ot(13, FontWeight.w600, _kPrimary)),
                                ]),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Small field (for inline edit mode) ──────────────────────────────────────
class _SmallField extends StatelessWidget {
  final String                label;
  final String                hint;
  final TextEditingController ctrl;

  const _SmallField({required this.label, required this.hint, required this.ctrl});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: _ot(12, FontWeight.w600, _kMuted)),
          const SizedBox(height: 4),
          TextFormField(
            controller: ctrl,
            style: _ot(13, FontWeight.normal, _kInk),
            decoration: _dec(hint),
          ),
        ],
      );
}

// ─── Small amount field ───────────────────────────────────────────────────────
class _SmallAmountField extends StatelessWidget {
  final TextEditingController ctrl;
  const _SmallAmountField({required this.ctrl});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('pricing.amountField'.tr(), style: _ot(12, FontWeight.w600, _kMuted)),
          const SizedBox(height: 4),
          TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: _ot(13, FontWeight.normal, _kInk),
            decoration: _dec('0.00'),
          ),
        ],
      );
}

// ─── Small optional toggle ────────────────────────────────────────────────────
class _SmallOptionalToggle extends StatelessWidget {
  final bool               value;
  final ValueChanged<bool> onChanged;

  const _SmallOptionalToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('pricing.optionalField'.tr(), style: _ot(12, FontWeight.w600, _kMuted)),
          const SizedBox(height: 4),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _kFieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Row(children: [
              Text(value ? 'Sí' : 'No',
                  style: _ot(13, FontWeight.normal,
                      value ? _kPrimary : _kMuted)),
              const Spacer(),
              Switch.adaptive(
                value: value, onChanged: onChanged,
                activeThumbColor: _kPrimary,
                activeTrackColor: _kPrimaryLt,
              ),
            ]),
          ),
        ],
      );
}

// ─── Shared UI widgets (redefined — private in add_event_dialog.dart) ─────────

class _LabeledField extends StatelessWidget {
  final String                label;
  final String                hint;
  final TextEditingController ctrl;
  final bool                  required;

  const _LabeledField({
    required this.label, required this.hint, required this.ctrl,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              text: label, style: _ot(13, FontWeight.w600, _kInk),
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

class _LabeledMultilineField extends StatelessWidget {
  final String                label;
  final String                hint;
  final TextEditingController ctrl;

  const _LabeledMultilineField({
    required this.label, required this.hint, required this.ctrl,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: _ot(13, FontWeight.w600, _kInk)),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl, maxLines: 3,
            style: _ot(14, FontWeight.normal, _kInk),
            decoration: _dec(hint),
          ),
        ],
      );
}

class _DateTimePickerField extends StatelessWidget {
  final String       label;
  final String       value;
  final VoidCallback onTap;

  const _DateTimePickerField({
    required this.label, required this.value, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              text: label, style: _ot(13, FontWeight.w600, _kInk),
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

class _CapacityStepper extends StatelessWidget {
  final String            label;
  final int               value;
  final ValueChanged<int> onChange;

  const _CapacityStepper({
    required this.label, required this.value, required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final canDec = value > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            text: label, style: _ot(13, FontWeight.w600, _kInk),
            children: [
              TextSpan(text: ' *', style: _ot(13, FontWeight.w600, _kError)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          GestureDetector(
            onTap: canDec ? () => onChange(value - 1) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: canDec ? Colors.white : const Color(0xFFF8FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: canDec ? _kBorder : const Color(0xFFECECEC)),
              ),
              child: Icon(Icons.remove_rounded, size: 18,
                  color: canDec ? _kInk : _kHint),
            ),
          ),
          Expanded(
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _kFieldBg, borderRadius: BorderRadius.circular(10),
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
                  BoxShadow(color: Color(0x442563EB),
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

class _LabeledAmountField extends StatelessWidget {
  final TextEditingController ctrl;
  const _LabeledAmountField({required this.ctrl});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              text: 'pricing.amountField'.tr(), style: _ot(13, FontWeight.w600, _kInk),
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
              final p = double.tryParse(v.trim().replaceAll(',', '.'));
              if (p == null || p < 0) return 'pricing.invalidAmount'.tr();
              return null;
            },
            decoration: _dec('0.00'),
          ),
        ],
      );
}

class _OptionalToggle extends StatelessWidget {
  final bool               value;
  final ValueChanged<bool> onChanged;

  const _OptionalToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
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
                  style: _ot(14, FontWeight.normal,
                      value ? _kPrimary : _kMuted)),
              const Spacer(),
              Switch.adaptive(
                value: value, onChanged: onChanged,
                activeThumbColor: _kPrimary,
                activeTrackColor: _kPrimaryLt,
              ),
            ]),
          ),
        ],
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kError.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: _kError, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message, style: _ot(13, FontWeight.w500, _kError))),
        ]),
      );
}

class _OutlineButton extends StatelessWidget {
  final String        label;
  final VoidCallback? onTap;
  const _OutlineButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
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

class _PrimaryButton extends StatelessWidget {
  final String        label;
  final bool          loading;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, required this.loading, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
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
                    BoxShadow(color: Color(0x442563EB),
                        offset: Offset(0, 4), blurRadius: 12),
                  ],
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(label,
                  style: _ot(14, FontWeight.w600, Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
        ),
      );
}
