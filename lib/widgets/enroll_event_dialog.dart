import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/event_service.dart';
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

// Avatar palette (5 pairs bg/text)
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
Future<bool> showEnrollEventDialog(
  BuildContext context, {
  required int       eventId,
  required int       schoolId,
  required List<int> alreadyEnrolledIds,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EnrollEventDialog(
      eventId:            eventId,
      schoolId:           schoolId,
      alreadyEnrolledIds: alreadyEnrolledIds,
    ),
  );
  return result ?? false;
}

// ─── Dialog ───────────────────────────────────────────────────────────────────
class _EnrollEventDialog extends StatefulWidget {
  final int       eventId;
  final int       schoolId;
  final List<int> alreadyEnrolledIds;

  const _EnrollEventDialog({
    required this.eventId,
    required this.schoolId,
    required this.alreadyEnrolledIds,
  });

  @override
  State<_EnrollEventDialog> createState() => _EnrollEventDialogState();
}

class _EnrollEventDialogState extends State<_EnrollEventDialog> {
  List<Student>  _students    = [];
  bool           _loading     = true;
  String?        _loadErr;
  String         _query       = '';
  final Set<int> _selected    = {};
  bool           _enrolling   = false;
  String?        _enrollErr;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
    try {
      await Future.wait(
        _selected.map((sid) => EventService.addParticipation(
          eventId:   widget.eventId,
          studentId: sid,
        )),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enrolling = false;
        _enrollErr = e is EventException ? e.message : 'Error al inscribir alumnos';
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
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: _buildHeader(),
            ),
            const SizedBox(height: 16),

            // ── Search ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSearch(),
            ),
            const SizedBox(height: 8),

            // ── Selection counter ────────────────────────────────────────────
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 14, color: _kPrimary),
                    const SizedBox(width: 6),
                    Text(
                      '${_selected.length} seleccionado${_selected.length != 1 ? "s" : ""}',
                      style: _ot(12, FontWeight.w600, _kPrimary),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 8),

            // ── Student list ─────────────────────────────────────────────────
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildList(),
              ),
            ),

            // ── Error + Buttons ──────────────────────────────────────────────
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
                        onTap: _enrolling ? null : () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Opacity(
                        opacity: _selected.isEmpty ? 0.4 : 1.0,
                        child: _PrimaryButton(
                          label: _selected.isEmpty
                              ? 'school.enrollBtn'.tr()
                              : '${'school.enrollBtn'.tr()} (${_selected.length})',
                          loading: _enrolling,
                          onTap: _selected.isEmpty ? null : _enroll,
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
          child: const Icon(Icons.how_to_reg_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('enroll.eventTitle'.tr(),
                  style: _ot(18, FontWeight.w700, _kInk)),
              Text('enroll.eventSubtitle'.tr(),
                  style: _ot(12, FontWeight.normal, _kMuted)),
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
        child: Text('form.noResults'.tr(), style: _ot(13, FontWeight.normal, _kHint),
            textAlign: TextAlign.center),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(color: _kBorder, height: 1),
      itemBuilder: (_, i) {
        final s         = list[i];
        final enrolled  = widget.alreadyEnrolledIds.contains(s.id);
        final selected  = _selected.contains(s.id);
        return Opacity(
          opacity: enrolled ? 0.45 : 1.0,
          child: InkWell(
            onTap: enrolled ? null : () => setState(() {
              if (selected) { _selected.remove(s.id); }
              else          { _selected.add(s.id); }
            }),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                // Avatar
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _avBg(i),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    s.initials,
                    style: _ot(13, FontWeight.w700, _avTxt(i)),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + email
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
                // Already enrolled label OR checkbox
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
                      value:          selected,
                      onChanged:      (_) => setState(() {
                        if (selected) { _selected.remove(s.id); }
                        else          { _selected.add(s.id); }
                      }),
                      activeColor:    _kPrimary,
                      shape:          RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

// ─── Error banner ─────────────────────────────────────────────────────────────
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
            child: Text(message,
                style: _ot(13, FontWeight.w500, _kError)),
          ),
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
