import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/group_service.dart';
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
const _kSurface   = Color(0xFFFFFFFF);

const _kAvColors = [
  [Color(0xFFEFF6FF), Color(0xFF2563EB)],
  [Color(0xFFFEF3C7), Color(0xFFD97706)],
  [Color(0xFFF3E8FF), Color(0xFF9333EA)],
  [Color(0xFFDCFCE7), Color(0xFF16A34A)],
  [Color(0xFFFEE2E2), Color(0xFFDC2626)],
];
Color _avBg(int i)  => _kAvColors[i % _kAvColors.length][0];
Color _avTxt(int i) => _kAvColors[i % _kAvColors.length][1];

TextStyle _ot(double sz, FontWeight w, Color c) =>
    GoogleFonts.outfit(fontSize: sz, fontWeight: w, color: c);

// ─── Public entry ─────────────────────────────────────────────────────────────
Future<bool> showEnrollGroupDialog(
  BuildContext context, {
  required int       groupId,
  required int       schoolId,
  required List<int> alreadyEnrolledIds,
  required int       maxCapacity,
  required int       currentEnrollmentCount,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EnrollGroupDialog(
      groupId:               groupId,
      schoolId:              schoolId,
      alreadyEnrolledIds:    alreadyEnrolledIds,
      maxCapacity:           maxCapacity,
      currentEnrollmentCount: currentEnrollmentCount,
    ),
  );
  return result ?? false;
}

// ─── Dialog ───────────────────────────────────────────────────────────────────
class _EnrollGroupDialog extends StatefulWidget {
  final int       groupId;
  final int       schoolId;
  final List<int> alreadyEnrolledIds;
  final int       maxCapacity;
  final int       currentEnrollmentCount;

  const _EnrollGroupDialog({
    required this.groupId,
    required this.schoolId,
    required this.alreadyEnrolledIds,
    required this.maxCapacity,
    required this.currentEnrollmentCount,
  });

  @override
  State<_EnrollGroupDialog> createState() => _EnrollGroupDialogState();
}

class _EnrollGroupDialogState extends State<_EnrollGroupDialog> {
  List<Student>  _students  = [];
  bool           _loading   = true;
  String?        _loadErr;
  String         _query     = '';
  final Set<int> _selected  = {};
  bool           _enrolling = false;
  String?        _enrollErr;

  int  get _availableSlots => widget.maxCapacity - widget.currentEnrollmentCount;
  bool get _isFull         => _availableSlots <= 0;
  bool get _wouldOverflow  => _selected.length > _availableSlots;

  final _searchCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    setState(() { _loading = true; _loadErr = null; });
    try {
      final list = await StudentService.getBySchool(widget.schoolId);
      if (!mounted) return;
      setState(() { _students = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadErr = e is StudentException ? e.message : 'Error al cargar alumnos';
      });
    }
  }

  List<Student> get _filtered {
    if (_query.trim().isEmpty) return _students;
    final q = _query.toLowerCase();
    return _students.where((s) =>
      s.fullName.toLowerCase().contains(q) ||
      s.email.toLowerCase().contains(q),
    ).toList();
  }

  Future<void> _enroll() async {
    if (_selected.isEmpty) return;
    setState(() { _enrolling = true; _enrollErr = null; });
    final notes = _notesCtrl.text.trim();
    try {
      await Future.wait(
        _selected.map((sid) => GroupService.addEnrollment(
          studentId: sid,
          groupId:   widget.groupId,
          notes:     notes,
        )),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enrolling = false;
        _enrollErr = e is GroupException ? e.message : 'Error al inscribir alumnos';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isMobile = w < 600;

    return Dialog(
      insetPadding: isMobile
          ? const EdgeInsets.fromLTRB(12, 48, 12, 12)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: _kSurface,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: _buildHeader(),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSearch(),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildNotesField(),
            ),
            const SizedBox(height: 8),
            // ── Capacity banners ─────────────────────────────────────────────
            if (_isFull)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _CapacityBanner(
                  color: const Color(0xFFFFFBEB),
                  borderColor: const Color(0xFFF59E0B),
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  text: 'Este grupo está completo (${widget.currentEnrollmentCount}/${widget.maxCapacity} plazas)',
                  textColor: const Color(0xFF92400E),
                ),
              )
            else if (_wouldOverflow)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _CapacityBanner(
                  color: const Color(0xFFFFF7ED),
                  borderColor: const Color(0xFFD97706),
                  icon: Icons.warning_rounded,
                  iconColor: const Color(0xFFD97706),
                  text: 'Solo quedan $_availableSlots plaza${_availableSlots != 1 ? "s" : ""} disponible${_availableSlots != 1 ? "s" : ""}',
                  textColor: const Color(0xFF92400E),
                ),
              ),
            const SizedBox(height: 8),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 14, color: _kPrimary),
                    const SizedBox(width: 6),
                    Text(
                      '${_selected.length} seleccionado'
                      '${_selected.length != 1 ? "s" : ""}',
                      style: _ot(12, FontWeight.w600, _kPrimary),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_enrollErr != null) ...[
                    _ErrorBanner(message: _enrollErr!),
                    const SizedBox(height: 12),
                  ],
                  Row(children: [
                    Expanded(
                      child: _OutlineButton(
                        label: 'enroll.cancel'.tr(),
                        onTap: _enrolling
                            ? null
                            : () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Opacity(
                        opacity: (_selected.isEmpty || _isFull || _wouldOverflow)
                            ? 0.4
                            : 1.0,
                        child: _PrimaryButton(
                          label: _selected.isEmpty
                              ? 'school.enrollBtn'.tr()
                              : '${'school.enrollBtn'.tr()} (${_selected.length})',
                          loading: _enrolling,
                          onTap: (_selected.isEmpty || _isFull || _wouldOverflow)
                              ? null
                              : _enroll,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          child: const Icon(Icons.group_add_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('enroll.groupTitle'.tr(),
                  style: _ot(18, FontWeight.w700, _kInk)),
              Text(
                _isFull
                    ? 'Grupo completo · ${widget.currentEnrollmentCount}/${widget.maxCapacity} plazas'
                    : '$_availableSlots plaza${_availableSlots != 1 ? "s" : ""} disponible${_availableSlots != 1 ? "s" : ""}',
                style: _ot(12, FontWeight.w600,
                    _isFull ? const Color(0xFFD97706) : _kMuted),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context, false),
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

  Widget _buildSearch() => Container(
        height: 42,
        decoration: BoxDecoration(
          color: _kFieldBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          const SizedBox(width: 12),
          const Icon(Icons.search_rounded, color: _kHint, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: _ot(13, FontWeight.normal, _kInk),
              decoration: InputDecoration(
                hintText: 'enroll.searchHint'.tr(),
                hintStyle: _ot(13, FontWeight.normal, _kHint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close_rounded, size: 14, color: _kHint),
              ),
            )
          else
            const SizedBox(width: 12),
        ]),
      );

  Widget _buildNotesField() => TextField(
        controller: _notesCtrl,
        style: _ot(13, FontWeight.normal, _kInk),
        decoration: InputDecoration(
          hintText: 'enroll.notesHint'.tr(),
          hintStyle: _ot(13, FontWeight.normal, _kHint),
          filled: true,
          fillColor: _kFieldBg,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
        ),
      );

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.5),
        ),
      );
    }
    if (_loadErr != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ErrorBanner(message: _loadErr!),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _fetchStudents,
              child: Text('form.retry'.tr(),
                  style: _ot(13, FontWeight.w600, _kPrimary)),
            ),
          ],
        ),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('form.noResults'.tr(),
            style: _ot(13, FontWeight.normal, _kHint),
            textAlign: TextAlign.center),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(color: _kBorder, height: 1),
      itemBuilder: (_, i) {
        final s           = list[i];
        final enrolled    = widget.alreadyEnrolledIds.contains(s.id);
        final selected    = _selected.contains(s.id);
        // Disabled if: already enrolled, group is full and not yet selected,
        // or we've already reached available slots and this isn't selected
        final checkboxOff = enrolled ||
            (!selected && (_isFull || _selected.length >= _availableSlots));
        return Opacity(
          opacity: (enrolled || (checkboxOff && !selected)) ? 0.45 : 1.0,
          child: InkWell(
            onTap: checkboxOff && !selected
                ? null
                : () => setState(() {
                      if (selected) { _selected.remove(s.id); }
                      else          { _selected.add(s.id); }
                    }),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _avBg(i),
                  ),
                  alignment: Alignment.center,
                  child: Text(s.initials,
                      style: _ot(13, FontWeight.w700, _avTxt(i))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.fullName,
                          style: _ot(13, FontWeight.w600, _kInk)),
                      if (s.email.isNotEmpty)
                        Text(s.email,
                            style: _ot(11, FontWeight.normal, _kHint),
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (enrolled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('enroll.alreadyEnrolled'.tr(),
                        style: _ot(10, FontWeight.w600,
                            const Color(0xFF16A34A))),
                  )
                else
                  SizedBox(
                    width: 24, height: 24,
                    child: Checkbox(
                      value:    selected,
                      onChanged: checkboxOff && !selected
                          ? null
                          : (_) => setState(() {
                              if (selected) { _selected.remove(s.id); }
                              else          { _selected.add(s.id); }
                            }),
                      activeColor: _kPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ─── Shared UI widgets ────────────────────────────────────────────────────────
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
          Expanded(child: Text(message,
              style: _ot(13, FontWeight.w500, _kError))),
        ]),
      );
}

// ─── Capacity banner ──────────────────────────────────────────────────────────
class _CapacityBanner extends StatelessWidget {
  final Color    color;
  final Color    borderColor;
  final IconData icon;
  final Color    iconColor;
  final String   text;
  final Color    textColor;

  const _CapacityBanner({
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text,
              style: _ot(12, FontWeight.w500, textColor))),
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
              : Text(label, style: _ot(14, FontWeight.w600, Colors.white)),
        ),
      );
}
