import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/payment_service.dart';
import '../services/student_service.dart';
import '../utils/app_toast.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kPrimary    = Color(0xFF2563EB);
const _kPrimaryDk  = Color(0xFF1D4ED8);
const _kPrimaryLt  = Color(0xFF3B82F6);
const _kInk        = Color(0xFF1E293B);
const _kMuted      = Color(0xFF64748B);
const _kHint       = Color(0xFF94A3B8);
const _kBorder     = Color(0xFFE2E8F0);
const _kFieldBg    = Color(0xFFF1F5F9);
const _kError      = Color(0xFFEF4444);
const _kPaidBg     = Color(0xFFDCFCE7);
const _kPaidText   = Color(0xFF16A34A);
const _kPendBg     = Color(0xFFFFF7ED);
const _kPendText   = Color(0xFFD97706);

const _kMethods = ['EFECTIVO','TRANSFERENCIA','TARJETA','DOMICILIACION'];

List<String> _months()    => 'ui.monthsShort'.tr().split(',');
String _methodLabel(int i) {
  const keys = [
    'payment.methodCash',
    'payment.methodTransfer',
    'payment.methodCard',
    'payment.methodDirectDebit',
  ];
  return i < keys.length ? keys[i].tr() : _kMethods[i];
}

TextStyle _ot(double sz, FontWeight w, Color c) =>
    GoogleFonts.outfit(fontSize: sz, fontWeight: w, color: c);

// ─── Public entry ─────────────────────────────────────────────────────────────
Future<bool> showPayStudentDialog(
  BuildContext context, {
  required Student student,
  required int     schoolId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PayStudentDialog(student: student, schoolId: schoolId),
  );
  return result ?? false;
}

// ─── Dialog ───────────────────────────────────────────────────────────────────
class _PayStudentDialog extends StatefulWidget {
  final Student student;
  final int     schoolId;
  const _PayStudentDialog({required this.student, required this.schoolId});

  @override
  State<_PayStudentDialog> createState() => _PayStudentDialogState();
}

class _PayStudentDialogState extends State<_PayStudentDialog> {
  // ── Section A state ────────────────────────────────────────────────────────
  late int    _year;
  late int    _month;
  String?     _method;
  bool        _saving    = false;
  final _amountCtrl = TextEditingController(text: '60.00');
  final _notesCtrl  = TextEditingController();

  // ── Section B state ────────────────────────────────────────────────────────
  bool          _loadingPayments  = true;
  List<Payment> _payments         = [];
  String?       _paymentsErr;
  int?          _expandedPayId;
  String?       _cobrarMethod;
  int?          _cobrandoId;

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year  = now.year;
    _month = now.month;
    _loadPayments();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _todayIso() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ── Load payments ─────────────────────────────────────────────────────────
  Future<void> _loadPayments() async {
    setState(() { _loadingPayments = true; _paymentsErr = null; });
    try {
      final list = await PaymentService.getStudentPayments(widget.student.id);
      if (!mounted) return;
      // Sort: year desc, month desc
      list.sort((a, b) {
        final yc = b.year.compareTo(a.year);
        return yc != 0 ? yc : b.month.compareTo(a.month);
      });
      setState(() { _payments = list; _loadingPayments = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPayments = false;
        _paymentsErr = e is PaymentException ? e.message : 'Error al cargar pagos';
      });
    }
  }

  // ── Create payment ────────────────────────────────────────────────────────
  Future<void> _createPayment() async {
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      AppToast.error(context, 'payment.invalidAmount'.tr());
      return;
    }
    setState(() => _saving = true);
    try {
      await PaymentService.createPayment(
        studentId:     widget.student.id,
        schoolId:      widget.schoolId,
        year:          _year,
        month:         _month,
        amount:        amount,
        paymentDate:   _method != null ? _todayIso() : null,
        paymentMethod: _method,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );
      if (!mounted) return;
      setState(() {
        _saving     = false;
        _hasChanges = true;
        _method     = null;
      });
      _notesCtrl.clear();
      _loadPayments();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, e is PaymentException ? e.message : 'payment.createError'.tr());
    }
  }

  // ── Mark as paid ──────────────────────────────────────────────────────────
  Future<void> _markAsPaid(int paymentId) async {
    if (_cobrarMethod == null) return;
    setState(() => _cobrandoId = paymentId);
    try {
      await PaymentService.markAsPaid(id: paymentId, paymentMethod: _cobrarMethod!);
      if (!mounted) return;
      setState(() {
        _cobrandoId    = null;
        _expandedPayId = null;
        _cobrarMethod  = null;
        _hasChanges    = true;
      });
      _loadPayments();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cobrandoId = null);
      AppToast.error(context, e is PaymentException ? e.message : 'payment.collectError'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isMobile = w < 600;

    return Dialog(
      insetPadding: isMobile
          ? const EdgeInsets.fromLTRB(12, 24, 12, 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  560,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: _buildHeader(),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            // ── Scrollable body ──────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSectionA(isMobile),
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 20),
                    _buildSectionB(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Close ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _OutlineButton(
                label: 'payment.closeBtn'.tr(),
                onTap: () => Navigator.pop(context, _hasChanges),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Row(children: [
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
          child: const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('payment.title'.tr(),
                  style: _ot(18, FontWeight.w700, _kInk)),
              Text(widget.student.fullName,
                  style: _ot(12, FontWeight.normal, _kMuted),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context, _hasChanges),
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

  // ── SECTION A: Registrar nuevo pago ────────────────────────────────────────
  Widget _buildSectionA(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('payment.newSection'.tr(),
            style: _ot(14, FontWeight.w700, _kInk)),
        const SizedBox(height: 14),

        // Year wheel
        Text('payment.yearLabel'.tr(), style: _ot(12, FontWeight.w600, _kMuted)),
        const SizedBox(height: 6),
        _YearWheelPicker(
          selected:  _year,
          onChanged: (y) => setState(() => _year = y),
        ),
        const SizedBox(height: 14),

        // Month grid 4×3
        Text('payment.monthLabel'.tr(), style: _ot(12, FontWeight.w600, _kMuted)),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   4,
            crossAxisSpacing: 8,
            mainAxisSpacing:  8,
            childAspectRatio: 2.2,
          ),
          itemCount: 12,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => setState(() => _month = i + 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: _month == i + 1 ? _kPrimary : _kFieldBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _month == i + 1 ? _kPrimary : _kBorder,
                ),
              ),
              alignment: Alignment.center,
              child: Text(_months()[i],
                  style: _ot(12, FontWeight.w600,
                      _month == i + 1 ? Colors.white : _kMuted)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Amount
        Text('payment.amountLabel'.tr(), style: _ot(12, FontWeight.w600, _kMuted)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: _ot(14, FontWeight.normal, _kInk),
          decoration: _fieldDec('60.00'),
        ),
        const SizedBox(height: 14),

        // Method pills
        Text('payment.methodLabel'.tr(),
            style: _ot(12, FontWeight.w600, _kMuted)),
        Text('payment.methodNote'.tr(),
            style: _ot(11, FontWeight.normal, _kHint)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: List.generate(_kMethods.length, (i) {
            final sel = _method == _kMethods[i];
            return GestureDetector(
              onTap: () => setState(() =>
                  _method = sel ? null : _kMethods[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color:  sel ? _kPrimary : _kFieldBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel ? _kPrimary : _kBorder,
                  ),
                ),
                child: Text(_methodLabel(i),
                    style: _ot(12, FontWeight.w600,
                        sel ? Colors.white : _kMuted)),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),

        // Notes
        Text('payment.notesLabel'.tr(), style: _ot(12, FontWeight.w600, _kMuted)),
        const SizedBox(height: 6),
        TextField(
          controller: _notesCtrl,
          style: _ot(13, FontWeight.normal, _kInk),
          decoration: _fieldDec('payment.notesHint'.tr()),
        ),

        const SizedBox(height: 16),

        // Register button
        _PrimaryButton(
          label: _method == null ? 'payment.registerPendingBtn'.tr() : 'payment.registerBtn'.tr(),
          loading: _saving,
          onTap: _createPayment,
        ),
      ],
    );
  }

  // ── SECTION B: Pagos existentes ────────────────────────────────────────────
  Widget _buildSectionB() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Text('payment.existingSection'.tr(),
              style: _ot(14, FontWeight.w700, _kInk)),
          const Spacer(),
          if (_loadingPayments)
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
            ),
        ]),
        const SizedBox(height: 12),

        if (_paymentsErr != null) ...[
          _ErrorBanner(message: _paymentsErr!),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _loadPayments,
            child: Text('form.retry'.tr(),
                style: _ot(13, FontWeight.w600, _kPrimary)),
          ),
        ] else if (!_loadingPayments && _payments.isEmpty)
          Text('payment.noPayments'.tr(),
              style: _ot(13, FontWeight.normal, _kHint))
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: _payments
                .map((p) => _buildPaymentRow(p))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildPaymentRow(Payment p) {
    final isExpanded = _expandedPayId == p.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                // Month/year pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kFieldBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Text(
                    '${_months()[p.month - 1]} ${p.year}',
                    style: _ot(11, FontWeight.w700, _kInk),
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.isPaid ? _kPaidBg : _kPendBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.isPaid ? 'school.badgePaid'.tr() : 'school.pendingLabel'.tr(),
                    style: _ot(10, FontWeight.w700,
                        p.isPaid ? _kPaidText : _kPendText),
                  ),
                ),
                const SizedBox(width: 8),
                // Amount — kept in Expanded so it takes remaining space
                Expanded(
                  child: Text(
                    '€ ${p.amount.toStringAsFixed(2)}',
                    style: _ot(13, FontWeight.w600, _kInk),
                    maxLines: 1,
                  ),
                ),
                // Method (if exists)
                if (p.paymentMethod != null) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      p.paymentMethod!,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: _ot(11, FontWeight.normal, _kMuted),
                    ),
                  ),
                ],
                // Compact toggle — circle icon to avoid crowding the amount text
                if (!p.isPaid) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      if (isExpanded) {
                        _expandedPayId = null;
                        _cobrarMethod  = null;
                      } else {
                        _expandedPayId = p.id;
                        _cobrarMethod  = null;
                      }
                    }),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: isExpanded ? _kPrimary : const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.chevron_right_rounded,
                        size: 15,
                        color: isExpanded ? Colors.white : _kPrimary,
                      ),
                    ),
                  ),
                ],
              ]),
            ),

            // Expanded cobrar section
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? _buildCobrarSection(p)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCobrarSection(Payment p) {
    final isSaving = _cobrandoId == p.id;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 10),
          // Show previously registered note if present
          if (p.notes != null && p.notes!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.sticky_note_2_outlined,
                    size: 14, color: _kMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(p.notes!,
                      style: _ot(12, FontWeight.normal, _kInk)),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          Text('payment.methodSelectTitle'.tr(),
              style: _ot(12, FontWeight.w600, _kMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: List.generate(_kMethods.length, (i) {
              final sel = _cobrarMethod == _kMethods[i];
              return GestureDetector(
                onTap: isSaving
                    ? null
                    : () => setState(() => _cobrarMethod = _kMethods[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:  sel ? _kPrimary : _kFieldBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sel ? _kPrimary : _kBorder,
                    ),
                  ),
                  child: Text(_methodLabel(i),
                      style: _ot(12, FontWeight.w600,
                          sel ? Colors.white : _kMuted)),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: _cobrarMethod == null ? 0.4 : 1.0,
            child: _PrimaryButton(
              label:   'payment.confirmCollect'.tr(),
              loading: isSaving,
              onTap:   _cobrarMethod == null ? null : () => _markAsPaid(p.id),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Field decoration ─────────────────────────────────────────────────────────
InputDecoration _fieldDec(String hint) => InputDecoration(
      hintText:        hint,
      hintStyle:       _ot(14, FontWeight.normal, _kHint),
      filled:          true,
      fillColor:       _kFieldBg,
      isDense:         true,
      contentPadding:  const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _kPrimary, width: 1.5)),
    );

// ─── Year wheel picker ────────────────────────────────────────────────────────
class _YearWheelPicker extends StatefulWidget {
  final int               selected;
  final ValueChanged<int> onChanged;
  const _YearWheelPicker({required this.selected, required this.onChanged});

  @override
  State<_YearWheelPicker> createState() => _YearWheelPickerState();
}

class _YearWheelPickerState extends State<_YearWheelPicker> {
  static const _min = 2018;
  static const _max = 2035;
  late final FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = FixedExtentScrollController(
      initialItem: (widget.selected - _min).clamp(0, _max - _min),
    );
  }

  @override
  void didUpdateWidget(_YearWheelPicker old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      final idx = (widget.selected - _min).clamp(0, _max - _min);
      if (_ctrl.selectedItem != idx) {
        _ctrl.animateToItem(idx,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 34,
            decoration: BoxDecoration(
              color:  _kPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kPrimary.withValues(alpha: 0.25)),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller:    _ctrl,
            itemExtent:    34,
            diameterRatio: 2.0,
            physics:       const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) => widget.onChanged(_min + i),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: _max - _min + 1,
              builder: (_, i) {
                final year = _min + i;
                final sel  = year == widget.selected;
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: _ot(
                      sel ? 16 : 13,
                      sel ? FontWeight.w700 : FontWeight.w400,
                      sel ? _kPrimary : _kHint,
                    ),
                    child: Text('$year'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kError.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: _kError, size: 14),
          const SizedBox(width: 6),
          Expanded(child: Text(message,
              style: _ot(12, FontWeight.w500, _kError))),
        ]),
      );
}

// ─── Outline button ───────────────────────────────────────────────────────────
class _OutlineButton extends StatelessWidget {
  final String        label;
  final VoidCallback? onTap;
  const _OutlineButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: _ot(14, FontWeight.w600, _kMuted)),
        ),
      );
}

// ─── Primary button ───────────────────────────────────────────────────────────
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
          height: 44,
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
                    BoxShadow(color: Color(0x342563EB),
                        offset: Offset(0, 3), blurRadius: 8),
                  ],
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(label, style: _ot(14, FontWeight.w600, Colors.white)),
        ),
      );
}
