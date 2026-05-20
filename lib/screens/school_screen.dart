import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/group_service.dart';
import '../services/school_service.dart';
import '../services/student_service.dart';
import '../services/event_service.dart';
import '../widgets/add_event_dialog.dart';
import '../widgets/edit_event_dialog.dart';
import '../widgets/enroll_event_dialog.dart';
import '../widgets/enroll_group_dialog.dart';
import '../widgets/pay_student_dialog.dart';
import '../widgets/add_group_dialog.dart';
import '../widgets/add_student_dialog.dart';
import '../widgets/edit_group_dialog.dart';
import '../widgets/edit_student_dialog.dart';

// ─── Design tokens (blue palette — school theme) ─────────────────────────────
class _S {
  _S._();

  static const bg          = Color(0xFFF8FBFF);
  static const surface     = Color(0xFFFFFFFF);
  static const primary     = Color(0xFF2563EB);
  static const primaryLt   = Color(0xFF3B82F6);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primaryDim  = Color(0xFFEFF6FF);
  static const tabBg       = Color(0xFFEEF2FF);
  static const headerBg    = Color(0xFFF1F5F9);
  static const ink         = Color(0xFF1E293B);
  static const muted       = Color(0xFF64748B);
  static const hint        = Color(0xFF94A3B8);
  static const border      = Color(0xFFE2E8F0);
  static const fieldBg     = Color(0xFFF1F5F9);
  static const paidBg      = Color(0xFFDCFCE7);
  static const paidText    = Color(0xFF16A34A);
  static const unpaidBg    = Color(0xFFFEE2E2);
  static const unpaidText  = Color(0xFFDC2626);
  static const errorRed    = Color(0xFFEF4444);
  static const sidebarW    = 220.0;
  static const rightColW   = 260.0;

  static const _av = [
    [Color(0xFFEFF6FF), Color(0xFF2563EB)],
    [Color(0xFFFEF3C7), Color(0xFFD97706)],
    [Color(0xFFF3E8FF), Color(0xFF9333EA)],
    [Color(0xFFDCFCE7), Color(0xFF16A34A)],
    [Color(0xFFFEE2E2), Color(0xFFDC2626)],
  ];
  static Color avBg(int i)  => _av[i % _av.length][0];
  static Color avTxt(int i) => _av[i % _av.length][1];
}

TextStyle _st(double sz, FontWeight w, Color c, {double ls = 0}) =>
    GoogleFonts.outfit(fontSize: sz, fontWeight: w, color: c, letterSpacing: ls);

// Table column fixed widths (used in both header and rows for alignment)
const _kAvatarSlot = 48.0; // avatar (36) + gap (12)
const _kColCurso   = 72.0;
const _kColEstado  = 104.0;
const _kColActions = 120.0;  // 32 + 8 + 32 + 8 + 32 + padding (edit+pay+delete)

// Column header label style
Widget _colLbl(String text) => Text(
      text.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: _S.hint, letterSpacing: 0.7,
      ),
    );

enum _Layout { mobile, tablet, web }
_Layout _layoutOf(double w) {
  if (w >= 1100) return _Layout.web;
  if (w >= 600)  return _Layout.tablet;
  return _Layout.mobile;
}

enum _Tab { students, events, alerts, wardrobe, groups, choreo }

// ─── Tab metadata helpers ─────────────────────────────────────────────────────
String _tabLabelKey(_Tab t) => switch (t) {
  _Tab.students => 'school.tabStudents',
  _Tab.events   => 'school.tabEvents',
  _Tab.alerts   => 'school.tabAlerts',
  _Tab.wardrobe => 'school.tabWardrobe',
  _Tab.groups   => 'school.tabGroups',
  _Tab.choreo   => 'school.tabChoreo',
};

IconData _tabIcon(_Tab t) => switch (t) {
  _Tab.students => Icons.people_outline_rounded,
  _Tab.events   => Icons.event_rounded,
  _Tab.alerts   => Icons.notifications_outlined,
  _Tab.wardrobe => Icons.checkroom_rounded,
  _Tab.groups   => Icons.groups_rounded,
  _Tab.choreo   => Icons.queue_music_rounded,
};

// ─── SchoolScreen ─────────────────────────────────────────────────────────────
class SchoolScreen extends StatefulWidget {
  final School school;
  const SchoolScreen({super.key, required this.school});

  @override
  State<SchoolScreen> createState() => _SchoolScreenState();
}

class _SchoolScreenState extends State<SchoolScreen> {
  _Tab             _tab            = _Tab.students;
  int              _filter         = 0;
  bool             _loading        = true;
  String?          _error;
  List<Student>    _allStudents    = [];
  Map<int, String> _studentGroupMap = {};
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Load students + group map in parallel; group map failure is non-fatal
      final results = await Future.wait([
        StudentService.getBySchoolWithPayments(widget.school.id),
        _buildGroupMap(widget.school.id),
      ]);
      if (!mounted) return;
      setState(() {
        _allStudents     = results[0] as List<Student>;
        _studentGroupMap = results[1] as Map<int, String>;
        _loading         = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  static Future<Map<int, String>> _buildGroupMap(int schoolId) async {
    try {
      final groups = await GroupService.getBySchool(schoolId);
      final enrollmentLists = await Future.wait(
        groups.map((g) => GroupService.getEnrollments(g.id)),
      );
      final map = <int, String>{};
      for (var i = 0; i < groups.length; i++) {
        for (final e in enrollmentLists[i]) {
          if (e.active) map[e.studentId] = groups[i].name;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> _handleAddStudent() async {
    final added = await showAddStudentDialog(
      context,
      schoolId: widget.school.id,
    );
    if (added && mounted) _loadData();
  }

Future<void> _handleAddCsv() async {
    try {
      // 1. Pick file — withData: true ensures bytes on all platforms (web + mobile)
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;

      final file  = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || !mounted) return;

      // 2. Show non-dismissible progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(
                    color: _S.primaryDim, shape: BoxShape.circle),
                child: const Icon(Icons.upload_file_rounded,
                    color: _S.primary, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                file.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _st(13, FontWeight.w600, _S.ink),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                  color: _S.primary, strokeWidth: 2.5),
              const SizedBox(height: 12),
              Text('Importando alumnos…',
                  style: _st(13, FontWeight.normal, _S.muted)),
            ],
          ),
        ),
      );

      // 3. Upload
      int     count    = 0;
      String? errorMsg;
      try {
        count = await StudentService.importFromCsv(
          schoolId: widget.school.id,
          bytes:    bytes,
          filename: file.name,
        );
      } on StudentException catch (e) {
        errorMsg = e.message;
      } catch (_) {
        errorMsg = 'Error inesperado al importar el archivo';
      }

      if (!mounted) return;

      // 4. Close progress dialog
      Navigator.of(context).pop();
      if (!mounted) return;

      // 5. Show result
      if (errorMsg != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(_csvSnackBar(
            message: errorMsg,
            isSuccess: false,
          ));
      } else {
        final label = count > 0
            ? '$count alumno${count == 1 ? '' : 's'} importado${count == 1 ? '' : 's'} correctamente'
            : 'Alumnos importados correctamente';
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(_csvSnackBar(message: label, isSuccess: true));
        _loadData(); // reload student list
      }
    } catch (_) {
      // User cancelled the file picker — no action needed
    }
  }

  SnackBar _csvSnackBar({required String message, required bool isSuccess}) {
    return SnackBar(
      content: Row(children: [
        Icon(
          isSuccess
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white),
          ),
        ),
      ]),
      backgroundColor:
          isSuccess ? const Color(0xFF22C55E) : _S.errorRed,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      duration: const Duration(seconds: 4),
    );
  }

  List<Student> get _students {
    var list = _allStudents;
    if (_filter == 1) list = list.where((s) => s.isPaid).toList();
    if (_filter == 2) list = list.where((s) => !s.isPaid).toList();
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((s) =>
        s.fullName.toLowerCase().contains(q) ||
        s.email.toLowerCase().contains(q),
      ).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final w      = MediaQuery.of(context).size.width;
    final layout = _layoutOf(w);
    final safeB  = MediaQuery.of(context).viewPadding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _S.bg,
        body: switch (layout) {
          _Layout.web    => _WebSchool(
              school: widget.school, tab: _tab, filter: _filter,
              searchCtrl: _searchCtrl, students: _students,
              groupMap: _studentGroupMap,
              loading: _loading, error: _error,
              onTab: (t) => setState(() => _tab = t),
              onFilter: (f) => setState(() => _filter = f),
              onSearch: () => setState(() {}),
              onBack: () => Navigator.pop(context),
              onRetry: _loadData,
              onAddStudent: _handleAddStudent,
              onAddCsv: _handleAddCsv,
            ),
          _Layout.tablet => _TabletSchool(
              school: widget.school, tab: _tab, filter: _filter,
              searchCtrl: _searchCtrl, students: _students, safeBottom: safeB,
              groupMap: _studentGroupMap,
              loading: _loading, error: _error,
              onTab: (t) => setState(() => _tab = t),
              onFilter: (f) => setState(() => _filter = f),
              onSearch: () => setState(() {}),
              onBack: () => Navigator.pop(context),
              onRetry: _loadData,
              onAddStudent: _handleAddStudent,
              onAddCsv: _handleAddCsv,
            ),
          _Layout.mobile => _MobileSchool(
              school: widget.school, tab: _tab, filter: _filter,
              searchCtrl: _searchCtrl, students: _students, safeBottom: safeB,
              groupMap: _studentGroupMap,
              loading: _loading, error: _error,
              onTab: (t) => setState(() => _tab = t),
              onFilter: (f) => setState(() => _filter = f),
              onSearch: () => setState(() {}),
              onBack: () => Navigator.pop(context),
              onRetry: _loadData,
              onAddStudent: _handleAddStudent,
              onAddCsv: _handleAddCsv,
            ),
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MOBILE  (< 600 px)
// ═══════════════════════════════════════════════════════════════════════════════

class _MobileSchool extends StatelessWidget {
  final School             school;
  final _Tab               tab;
  final int                filter;
  final TextEditingController searchCtrl;
  final List<Student>      students;
  final Map<int, String>   groupMap;
  final double             safeBottom;
  final bool               loading;
  final String?            error;
  final void Function(_Tab) onTab;
  final void Function(int)  onFilter;
  final VoidCallback        onSearch;
  final VoidCallback        onBack;
  final VoidCallback        onRetry;
  final VoidCallback        onAddStudent;
  final VoidCallback        onAddCsv;

  const _MobileSchool({
    required this.school, required this.tab, required this.filter,
    required this.searchCtrl, required this.students, required this.safeBottom,
    required this.groupMap,
    required this.loading, required this.error,
    required this.onTab, required this.onFilter,
    required this.onSearch, required this.onBack, required this.onRetry,
    required this.onAddStudent, required this.onAddCsv,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).viewPadding.top;
    return Column(children: [
      SizedBox(height: top),
      _SchoolHeader(
        schoolName: school.name, compact: true, onBack: onBack,
        onAddStudent: onAddStudent, onAddCsv: onAddCsv,
      ),
      _SchoolTabBar(current: tab, onSelect: onTab),
      Expanded(
        child: switch (tab) {
          _Tab.students => _StudentsBody(
              students: students, filter: filter, groupMap: groupMap,
              searchCtrl: searchCtrl, onFilter: onFilter, onSearch: onSearch,
              tableMode: false, safeBottom: safeBottom,
              loading: loading, error: error, onRetry: onRetry,
            ),
          _Tab.events   => _EventsTab(school: school),
          _Tab.alerts   => _PlaceholderContent(
              icon: Icons.notifications_outlined, labelKey: 'school.tabAlerts'),
          _Tab.wardrobe => _PlaceholderContent(
              icon: Icons.checkroom_rounded, labelKey: 'school.tabWardrobe'),
          _Tab.groups   => _GroupsTab(school: school),
          _Tab.choreo   => _PlaceholderContent(
              icon: Icons.queue_music_rounded, labelKey: 'school.tabChoreo'),
        },
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TABLET  (600 – 1099 px) — full-width table in students tab
// ═══════════════════════════════════════════════════════════════════════════════

class _TabletSchool extends StatelessWidget {
  final School             school;
  final _Tab               tab;
  final int                filter;
  final TextEditingController searchCtrl;
  final List<Student>      students;
  final Map<int, String>   groupMap;
  final double             safeBottom;
  final bool               loading;
  final String?            error;
  final void Function(_Tab) onTab;
  final void Function(int)  onFilter;
  final VoidCallback        onSearch;
  final VoidCallback        onBack;
  final VoidCallback        onRetry;
  final VoidCallback        onAddStudent;
  final VoidCallback        onAddCsv;

  const _TabletSchool({
    required this.school, required this.tab, required this.filter,
    required this.searchCtrl, required this.students, required this.safeBottom,
    required this.groupMap,
    required this.loading, required this.error,
    required this.onTab, required this.onFilter,
    required this.onSearch, required this.onBack, required this.onRetry,
    required this.onAddStudent, required this.onAddCsv,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).viewPadding.top;
    return Column(children: [
      SizedBox(height: top),
      _SchoolHeader(
        schoolName: school.name, compact: false, onBack: onBack,
        searchCtrl: searchCtrl, onSearch: onSearch,
        onAddStudent: onAddStudent, onAddCsv: onAddCsv,
      ),
      _SchoolTabBar(current: tab, onSelect: onTab),
      Expanded(
        child: switch (tab) {
          // Full-width table — no side panel on tablet
          _Tab.students => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _StudentsBody(
                students: students, filter: filter, groupMap: groupMap,
                searchCtrl: searchCtrl, onFilter: onFilter, onSearch: onSearch,
                tableMode: true, safeBottom: safeBottom, showSearch: false,
                loading: loading, error: error, onRetry: onRetry,
              ),
            ),
          _Tab.events   => _EventsTab(school: school),
          _Tab.alerts   => _PlaceholderContent(
              icon: Icons.notifications_outlined, labelKey: 'school.tabAlerts'),
          _Tab.wardrobe => _PlaceholderContent(
              icon: Icons.checkroom_rounded, labelKey: 'school.tabWardrobe'),
          _Tab.groups   => _GroupsTab(school: school),
          _Tab.choreo   => _PlaceholderContent(
              icon: Icons.queue_music_rounded, labelKey: 'school.tabChoreo'),
        },
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  WEB  (≥ 1100 px)
// ═══════════════════════════════════════════════════════════════════════════════

class _WebSchool extends StatelessWidget {
  final School             school;
  final _Tab               tab;
  final int                filter;
  final TextEditingController searchCtrl;
  final List<Student>      students;
  final Map<int, String>   groupMap;
  final bool               loading;
  final String?            error;
  final void Function(_Tab) onTab;
  final void Function(int)  onFilter;
  final VoidCallback        onSearch;
  final VoidCallback        onBack;
  final VoidCallback        onRetry;
  final VoidCallback        onAddStudent;
  final VoidCallback        onAddCsv;

  const _WebSchool({
    required this.school, required this.tab, required this.filter,
    required this.searchCtrl, required this.students,
    required this.groupMap,
    required this.loading, required this.error,
    required this.onTab, required this.onFilter,
    required this.onSearch, required this.onBack, required this.onRetry,
    required this.onAddStudent, required this.onAddCsv,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).viewPadding.top;
    return Row(children: [
      _Sidebar(current: tab, schoolName: school.name, onSelect: onTab, onBack: onBack),
      Expanded(
        child: Column(children: [
          SizedBox(height: top),
          _SchoolHeader(
            schoolName: school.name, compact: false, showBackButton: false,
            searchCtrl: searchCtrl, onSearch: onSearch,
            onAddStudent: onAddStudent, onAddCsv: onAddCsv,
          ),
          Expanded(
            child: switch (tab) {
              _Tab.students => Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: _StudentsBody(
                        students: students, filter: filter, groupMap: groupMap,
                        searchCtrl: searchCtrl, onFilter: onFilter, onSearch: onSearch,
                        tableMode: true, safeBottom: 0, showSearch: false,
                        loading: loading, error: error, onRetry: onRetry,
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: _S.rightColW,
                      child: const _EventsPanel(safeBottom: 0),
                    ),
                  ]),
                ),
              _Tab.events   => _PlaceholderContent(
                  icon: Icons.event_rounded, labelKey: 'school.tabEvents'),
              _Tab.alerts   => _PlaceholderContent(
                  icon: Icons.notifications_outlined, labelKey: 'school.tabAlerts'),
              _Tab.wardrobe => _PlaceholderContent(
                  icon: Icons.checkroom_rounded, labelKey: 'school.tabWardrobe'),
              _Tab.groups   => _GroupsTab(school: school),
              _Tab.choreo   => _PlaceholderContent(
                  icon: Icons.queue_music_rounded, labelKey: 'school.tabChoreo'),
            },
          ),
        ]),
      ),
    ]);
  }
}

// ─── Sidebar (web only) ───────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final _Tab   current;
  final String schoolName;
  final void Function(_Tab) onSelect;
  final VoidCallback onBack;

  const _Sidebar({
    required this.current, required this.schoolName,
    required this.onSelect, required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _S.sidebarW,
      decoration: const BoxDecoration(
        color: _S.surface,
        border: Border(right: BorderSide(color: _S.border)),
      ),
      child: Column(children: [
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _S.border)),
          ),
          child: Row(children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [_S.primaryDark, _S.primaryLt],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('DanceWithMe',
                  style: _st(15, FontWeight.w700, _S.ink),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _S.border)),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _S.primaryDim, borderRadius: BorderRadius.circular(10),
            ),
            child: Text(schoolName,
                style: _st(12, FontWeight.w600, _S.primary),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
            child: Column(children: [
              ...(_Tab.values.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _SideNavItem(
                  icon: _tabIcon(t),
                  labelKey: _tabLabelKey(t),
                  active: current == t,
                  onTap: () => onSelect(t),
                ),
              ))),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 28),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _S.fieldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _S.border),
                ),
                child: Row(children: [
                  const Icon(Icons.arrow_back_rounded, color: _S.muted, size: 16),
                  const SizedBox(width: 8),
                  Text('Mis Escuelas', style: _st(13, FontWeight.w500, _S.muted)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final String   labelKey;
  final bool     active;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.icon, required this.labelKey,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? _S.primaryDim : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: active ? _S.primary : _S.hint),
            const SizedBox(width: 10),
            Text(labelKey.tr(),
                style: _st(14,
                    active ? FontWeight.w600 : FontWeight.w500,
                    active ? _S.primary : _S.muted)),
          ]),
        ),
      ),
    );
  }
}

// ─── Shared Header ────────────────────────────────────────────────────────────
class _SchoolHeader extends StatelessWidget {
  final String  schoolName;
  final bool    compact;
  final bool    showBackButton;
  final VoidCallback? onBack;
  final TextEditingController? searchCtrl;
  final VoidCallback? onSearch;
  final VoidCallback? onAddStudent;
  final VoidCallback? onAddCsv;

  const _SchoolHeader({
    required this.schoolName,
    required this.compact,
    this.showBackButton = true,
    this.onBack,
    this.searchCtrl,
    this.onSearch,
    this.onAddStudent,
    this.onAddCsv,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
      decoration: const BoxDecoration(
        color: _S.surface,
        border: Border(bottom: BorderSide(color: _S.border)),
      ),
      child: Row(children: [
        // ── Back button ───────────────────────────────────────────────────
        if (showBackButton && onBack != null) ...[
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(0, 8, 12, 8),
                child: Icon(Icons.arrow_back_rounded, color: _S.ink, size: 22),
              ),
            ),
          ),
        ],
        // ── School name ───────────────────────────────────────────────────
        Expanded(
          child: Text(schoolName,
              style: _st(compact ? 18 : 20, FontWeight.w700, _S.ink),
              overflow: TextOverflow.ellipsis),
        ),
        // ── Search bar (tablet / web only) ────────────────────────────────
        if (!compact && searchCtrl != null) ...[
          const SizedBox(width: 16),
          SizedBox(
            width: 200, height: 38,
            child: TextField(
              controller: searchCtrl,
              onChanged: (_) => onSearch?.call(),
              style: _st(13, FontWeight.normal, _S.ink),
              decoration: InputDecoration(
                hintText: 'school.searchHint'.tr(),
                hintStyle: _st(13, FontWeight.normal, _S.hint),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.search_rounded, color: _S.hint, size: 16),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                filled: true, fillColor: _S.fieldBg, isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _S.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _S.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _S.primary, width: 1.5)),
              ),
            ),
          ),
        ],
        const SizedBox(width: 10),
        // ── Action buttons ────────────────────────────────────────────────
        if (!compact) ...[
          // Add student (tablet / web)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onAddStudent,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [_S.primaryDark, _S.primaryLt],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x442563EB),
                        offset: Offset(0, 3), blurRadius: 8),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.person_add_outlined,
                      color: Colors.white, size: 15),
                  const SizedBox(width: 6),
                  Text('school.addStudent'.tr(),
                      style: _st(13, FontWeight.w600, Colors.white)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // CSV button (tablet / web)
          Tooltip(
            message: 'Importar CSV',
            preferBelow: false,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onAddCsv,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _S.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _S.border),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x081E293B),
                          offset: Offset(0, 2), blurRadius: 6),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.upload_file_rounded,
                        color: _S.muted, size: 15),
                    const SizedBox(width: 6),
                    Text('CSV',
                        style: _st(13, FontWeight.w600, _S.muted)),
                  ]),
                ),
              ),
            ),
          ),
        ] else ...[
          // Add student icon (mobile)
          Tooltip(
            message: 'school.addStudent'.tr(),
            preferBelow: false,
            child: GestureDetector(
              onTap: onAddStudent,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Icon(Icons.person_add_outlined,
                    color: _S.primary, size: 22),
              ),
            ),
          ),
          // CSV icon (mobile)
          Tooltip(
            message: 'Importar CSV',
            preferBelow: false,
            child: GestureDetector(
              onTap: onAddCsv,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Icon(Icons.upload_file_rounded,
                    color: _S.muted, size: 21),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Tab bar (mobile + tablet) ────────────────────────────────────────────────
class _SchoolTabBar extends StatelessWidget {
  final _Tab current;
  final void Function(_Tab) onSelect;

  const _SchoolTabBar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: _S.surface,
        border: Border(bottom: BorderSide(color: _S.border)),
      ),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _S.tabBg, borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (_, constraints) {
            const minW = 74.0;
            final fits = _Tab.values.length * minW <= constraints.maxWidth;
            final pills = _Tab.values
                .map((t) => _TabPill(
                      tab: t,
                      labelKey: _tabLabelKey(t),
                      current: current,
                      onTap: onSelect,
                      fixedWidth: fits ? null : minW,
                    ))
                .toList();
            if (fits) return Row(children: pills);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(children: pills),
            );
          },
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final _Tab  tab;
  final String labelKey;
  final _Tab  current;
  final void Function(_Tab) onTap;
  final double? fixedWidth; // null → Expanded, value → fixed scroll mode

  const _TabPill({
    required this.tab, required this.labelKey,
    required this.current, required this.onTap,
    this.fixedWidth,
  });

  @override
  Widget build(BuildContext context) {
    final active = tab == current;
    final pill = GestureDetector(
      onTap: () => onTap(tab),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: active ? _S.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: active
              ? const [
                  BoxShadow(
                      color: Color(0x121E293B),
                      offset: Offset(0, 1), blurRadius: 4),
                ]
              : null,
        ),
        child: Center(
          child: Text(labelKey.tr(),
              style: _st(12,
                  active ? FontWeight.w600 : FontWeight.w500,
                  active ? _S.primary : _S.hint)),
        ),
      ),
    );

    if (fixedWidth != null) {
      return SizedBox(width: fixedWidth, child: pill);
    }
    return Expanded(child: pill);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  STUDENTS BODY
// ═══════════════════════════════════════════════════════════════════════════════

class _StudentsBody extends StatelessWidget {
  final List<Student>         students;
  final int                   filter;
  final Map<int, String>      groupMap;
  final TextEditingController searchCtrl;
  final void Function(int)    onFilter;
  final VoidCallback          onSearch;
  final bool                  tableMode;
  final double                safeBottom;
  final bool                  showSearch;
  final bool                  loading;
  final String?               error;
  final VoidCallback?         onRetry;

  const _StudentsBody({
    required this.students,
    required this.filter,
    required this.searchCtrl,
    required this.onFilter,
    required this.onSearch,
    required this.tableMode,
    required this.safeBottom,
    this.groupMap  = const {},
    this.showSearch = true,
    this.loading    = false,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: _S.primary, strokeWidth: 2.5),
      );
    }
    if (error != null) return _ErrorBody(onRetry: onRetry);

    return RefreshIndicator(
      color: _S.primary,
      onRefresh: () async { onRetry?.call(); },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(0, 16, 0, safeBottom + 20),
        children: [
          if (showSearch) ...[
            _SearchField(ctrl: searchCtrl, onChanged: onSearch),
            const SizedBox(height: 12),
          ],
          _FilterChips(selected: filter, onSelect: onFilter),
          const SizedBox(height: 16),
          if (students.isEmpty)
            const _EmptyStudents()
          else if (tableMode) ...[
            // ── Table header ──────────────────────────────────────────────────
            _TableHeader(),
            const SizedBox(height: 6),
            // ── Table rows ────────────────────────────────────────────────────
            ...students.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _TableRow(student: e.value, index: e.key, onReload: onRetry, groupMap: groupMap),
                )),
          ] else
            // ── Mobile cards ──────────────────────────────────────────────────
            ...students.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MobileStudentCard(student: e.value, index: e.key, onReload: onRetry, groupMap: groupMap),
                )),
        ],
      ),
    );
  }
}

// ─── Snack helpers ────────────────────────────────────────────────────────────
SnackBar _successSnack(String msg) => SnackBar(
      content: Text(msg,
          style: GoogleFonts.outfit(
              fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
      backgroundColor: _S.paidText,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

SnackBar _errorSnack(String msg) => SnackBar(
      content: Text(msg,
          style: GoogleFonts.outfit(
              fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
      backgroundColor: _S.errorRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

// ─── Delete confirmation dialog ───────────────────────────────────────────────
Future<bool> _confirmDeleteStudent(BuildContext context, String name) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: _S.unpaidBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person_remove_outlined,
                color: _S.unpaidText, size: 26),
          ),
          const SizedBox(height: 16),
          Text('¿Eliminar alumno?',
              style: _st(18, FontWeight.w700, _S.ink),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _S.unpaidBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warning_amber_rounded,
                  color: _S.unpaidText, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(name,
                    style: _st(13, FontWeight.w600, _S.unpaidText),
                    textAlign: TextAlign.center),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Text('Esta acción no se puede deshacer.',
              style: _st(13, FontWeight.normal, _S.muted),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
        ],
      ),
      actions: [
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _S.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Cancelar',
                  style: _st(14, FontWeight.w600, _S.muted)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _S.unpaidText,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: Text('Eliminar',
                  style: _st(14, FontWeight.w600, Colors.white)),
            ),
          ),
        ]),
      ],
    ),
  );
  return result ?? false;
}

// ─── Group delete confirmation ────────────────────────────────────────────────
Future<bool> _confirmDeleteGroup(BuildContext context, String name) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: _S.unpaidBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.group_remove_rounded,
                color: _S.unpaidText, size: 26),
          ),
          const SizedBox(height: 16),
          Text('¿Eliminar grupo?',
              style: _st(18, FontWeight.w700, _S.ink),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _S.unpaidBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warning_amber_rounded,
                  color: _S.unpaidText, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(name,
                    style: _st(13, FontWeight.w600, _S.unpaidText),
                    textAlign: TextAlign.center),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Text('Se eliminará el grupo y sus datos. Esta acción no se puede deshacer.',
              style: _st(13, FontWeight.normal, _S.muted),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
        ],
      ),
      actions: [
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _S.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Cancelar',
                  style: _st(14, FontWeight.w600, _S.muted)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _S.unpaidText,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: Text('Eliminar',
                  style: _st(14, FontWeight.w600, Colors.white)),
            ),
          ),
        ]),
      ],
    ),
  );
  return result ?? false;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TABLE (tablet / web)
// ═══════════════════════════════════════════════════════════════════════════════

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _S.headerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _S.border),
      ),
      child: Row(children: [
        // Avatar spacer
        const SizedBox(width: _kAvatarSlot),
        // Nombre y Apellidos
        Expanded(flex: 3, child: _colLbl('Nombre y Apellidos')),
        // Curso
        SizedBox(width: _kColCurso, child: Center(child: _colLbl('Curso'))),
        // Email
        Expanded(flex: 2, child: _colLbl('Email')),
        // Estado
        SizedBox(width: _kColEstado, child: Center(child: _colLbl('Estado'))),
        // Acciones
        SizedBox(width: _kColActions, child: Center(child: _colLbl('Acciones'))),
      ]),
    );
  }
}

class _TableRow extends StatelessWidget {
  final Student          student;
  final int              index;
  final VoidCallback?    onReload;
  final Map<int, String> groupMap;

  const _TableRow({
    required this.student,
    required this.index,
    this.onReload,
    this.groupMap = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _S.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _S.border),
        boxShadow: const [
          BoxShadow(color: Color(0x061E293B), offset: Offset(0, 1), blurRadius: 4),
        ],
      ),
      child: Row(children: [
        // Avatar
        _Avatar(initials: student.initials, index: index, size: 36),
        const SizedBox(width: 12),
        // Nombre y Apellidos
        Expanded(
          flex: 3,
          child: Text(student.fullName,
              style: _st(14, FontWeight.w600, _S.ink),
              overflow: TextOverflow.ellipsis),
        ),
        // Curso
        SizedBox(
          width: _kColCurso,
          child: Center(
            child: Text(
              groupMap[student.id] ?? '—',
              style: _st(12, FontWeight.normal,
                  groupMap.containsKey(student.id) ? _S.ink : _S.hint),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        // Email
        Expanded(
          flex: 2,
          child: Text(student.email,
              style: _st(13, FontWeight.normal, _S.muted),
              overflow: TextOverflow.ellipsis),
        ),
        // Estado
        SizedBox(
          width: _kColEstado,
          child: Center(child: _Badge(isPaid: student.isPaid)),
        ),
        // Acciones
        SizedBox(
          width: _kColActions,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _ActionBtn(
              icon: Icons.edit_outlined,
              color: _S.primary, bg: _S.primaryDim,
              tooltip: 'Editar',
              onTap: () async {
                final ok = await showEditStudentDialog(context, student: student);
                if (!context.mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(_successSnack('Alumno actualizado correctamente'));
                  onReload?.call();
                }
              },
            ),
            const SizedBox(width: 8),
            _ActionBtn(
              icon: Icons.payments_rounded,
              color: _S.paidText, bg: _S.paidBg,
              tooltip: 'Gestionar pago',
              onTap: () async {
                final changed = await showPayStudentDialog(
                  context, student: student, schoolId: student.schoolId);
                if (!context.mounted) return;
                if (changed) onReload?.call();
              },
            ),
            const SizedBox(width: 8),
            _ActionBtn(
              icon: Icons.delete_outline_rounded,
              color: _S.unpaidText, bg: _S.unpaidBg,
              tooltip: 'Eliminar',
              onTap: () async {
                final confirmed = await _confirmDeleteStudent(context, student.fullName);
                if (!context.mounted) return;
                if (!confirmed) return;
                try {
                  await StudentService.deleteStudent(student.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(_successSnack('Alumno eliminado'));
                  onReload?.call();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    _errorSnack(e is StudentException ? e.message : 'Error al eliminar'),
                  );
                }
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MOBILE CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _MobileStudentCard extends StatelessWidget {
  final Student          student;
  final int              index;
  final VoidCallback?    onReload;
  final Map<int, String> groupMap;

  const _MobileStudentCard({
    required this.student,
    required this.index,
    this.onReload,
    this.groupMap = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _S.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _S.border),
        boxShadow: const [
          BoxShadow(color: Color(0x081E293B), offset: Offset(0, 2), blurRadius: 8),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _Avatar(initials: student.initials, index: index, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: name + badge
              Row(children: [
                Expanded(
                  child: Text(student.fullName,
                      style: _st(14, FontWeight.w600, _S.ink),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                _Badge(isPaid: student.isPaid),
              ]),
              const SizedBox(height: 4),
              // Row 2: email
              Text(student.email,
                  style: _st(12, FontWeight.normal, _S.hint),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              // Row 3: curso + action buttons
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _S.headerBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _S.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Curso: ', style: _st(11, FontWeight.w500, _S.hint)),
                    Text(
                      groupMap[student.id] ?? '—',
                      style: _st(11, FontWeight.normal,
                          groupMap.containsKey(student.id) ? _S.ink : _S.hint),
                    ),
                  ]),
                ),
                const Spacer(),
                _ActionBtn(
                  icon: Icons.edit_outlined,
                  color: _S.primary, bg: _S.primaryDim,
                  tooltip: 'Editar',
                  onTap: () async {
                    final ok = await showEditStudentDialog(context, student: student);
                    if (!context.mounted) return;
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(_successSnack('Alumno actualizado correctamente'));
                      onReload?.call();
                    }
                  },
                ),
                const SizedBox(width: 6),
                _ActionBtn(
                  icon: Icons.payments_rounded,
                  color: _S.paidText, bg: _S.paidBg,
                  tooltip: 'Gestionar pago',
                  onTap: () async {
                    final changed = await showPayStudentDialog(
                      context, student: student, schoolId: student.schoolId);
                    if (!context.mounted) return;
                    if (changed) onReload?.call();
                  },
                ),
                const SizedBox(width: 6),
                _ActionBtn(
                  icon: Icons.delete_outline_rounded,
                  color: _S.unpaidText, bg: _S.unpaidBg,
                  tooltip: 'Eliminar',
                  onTap: () async {
                    final confirmed = await _confirmDeleteStudent(context, student.fullName);
                    if (!context.mounted) return;
                    if (!confirmed) return;
                    try {
                      await StudentService.deleteStudent(student.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(_successSnack('Alumno eliminado'));
                      onReload?.call();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        _errorSnack(e is StudentException ? e.message : 'Error al eliminar'),
                      );
                    }
                  },
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHARED SMALL COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Action button (edit / delete) ───────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final Color    bg;
  final String   tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon, required this.color,
    required this.bg, required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }
}

// ─── Error body ───────────────────────────────────────────────────────────────
class _ErrorBody extends StatelessWidget {
  final VoidCallback? onRetry;
  const _ErrorBody({this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
          child: const Icon(Icons.cloud_off_rounded, color: _S.errorRed, size: 32),
        ),
        const SizedBox(height: 14),
        Text('Error al cargar', style: _st(16, FontWeight.w600, _S.ink)),
        const SizedBox(height: 6),
        Text('Comprueba tu conexión', style: _st(13, FontWeight.normal, _S.hint)),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: _S.primaryDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _S.primary.withValues(alpha: 0.3)),
              ),
              child: Text('Reintentar', style: _st(14, FontWeight.w600, _S.primary)),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Search field ─────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onChanged;

  const _SearchField({required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: _S.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _S.border),
        boxShadow: const [
          BoxShadow(color: Color(0x081E293B), offset: Offset(0, 2), blurRadius: 8),
        ],
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        const Icon(Icons.search_rounded, color: _S.hint, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctrl,
            onChanged: (_) => onChanged(),
            style: _st(14, FontWeight.normal, _S.ink),
            decoration: InputDecoration(
              hintText: 'school.searchHint'.tr(),
              hintStyle: _st(14, FontWeight.normal, _S.hint),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (ctrl.text.isNotEmpty)
          GestureDetector(
            onTap: () { ctrl.clear(); onChanged(); },
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.close_rounded, color: _S.hint, size: 16),
            ),
          )
        else
          const SizedBox(width: 14),
      ]),
    );
  }
}

// ─── Filter chips ─────────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;

  const _FilterChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _Chip(label: 'school.filterAll'.tr(),    index: 0, selected: selected, onTap: onSelect,
          activeBg: _S.primary,   activeText: Colors.white),
      const SizedBox(width: 8),
      _Chip(label: 'school.filterPaid'.tr(),   index: 1, selected: selected, onTap: onSelect,
          activeBg: _S.paidBg,   activeText: _S.paidText),
      const SizedBox(width: 8),
      _Chip(label: 'school.filterUnpaid'.tr(), index: 2, selected: selected, onTap: onSelect,
          activeBg: _S.unpaidBg, activeText: _S.unpaidText),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int    index;
  final int    selected;
  final void Function(int) onTap;
  final Color  activeBg;
  final Color  activeText;

  const _Chip({
    required this.label, required this.index, required this.selected,
    required this.onTap, required this.activeBg, required this.activeText,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? activeBg : _S.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? activeBg : _S.border),
          boxShadow: active
              ? null
              : const [BoxShadow(color: Color(0x061E293B), offset: Offset(0, 1), blurRadius: 4)],
        ),
        child: Text(label,
            style: _st(12, FontWeight.w600, active ? activeText : _S.muted)),
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String initials;
  final int    index;
  final double size;

  const _Avatar({required this.initials, required this.index, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: _S.avBg(index), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials, style: _st(size * 0.33, FontWeight.w700, _S.avTxt(index))),
    );
  }
}

// ─── Badge ────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final bool isPaid;
  const _Badge({required this.isPaid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? _S.paidBg : _S.unpaidBg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        isPaid ? 'school.badgePaid'.tr() : 'school.badgeUnpaid'.tr(),
        style: _st(11, FontWeight.w600, isPaid ? _S.paidText : _S.unpaidText),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyStudents extends StatelessWidget {
  const _EmptyStudents();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(color: _S.primaryDim, shape: BoxShape.circle),
          child: const Icon(Icons.people_outline_rounded, color: _S.primary, size: 32),
        ),
        const SizedBox(height: 14),
        Text('school.noStudents'.tr(), style: _st(16, FontWeight.w600, _S.ink)),
        const SizedBox(height: 6),
        Text('school.noStudentsDesc'.tr(),
            textAlign: TextAlign.center,
            style: _st(13, FontWeight.normal, _S.hint)),
      ]),
    );
  }
}

// ─── Events panel (right column — web only) ──────────────────────────────────
class _EventsPanel extends StatelessWidget {
  final double safeBottom;
  const _EventsPanel({required this.safeBottom});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(0, 16, 0, safeBottom + 20),
      child: Container(
        decoration: BoxDecoration(
          color: _S.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _S.border),
          boxShadow: const [
            BoxShadow(color: Color(0x081E293B), offset: Offset(0, 2), blurRadius: 12),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.event_rounded, color: _S.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('school.upcomingEvents'.tr(),
                  style: _st(15, FontWeight.w700, _S.ink)),
            ),
          ]),
          const SizedBox(height: 14),
          _PanelEventCard(title: 'Exhibición de Salsa',  date: '15 Feb 2025', active: true),
          const SizedBox(height: 10),
          _PanelEventCard(title: 'Clase Especial Tango', date: '22 Feb 2025', active: false),
        ]),
      ),
    );
  }
}

class _PanelEventCard extends StatelessWidget {
  final String title;
  final String date;
  final bool   active;

  const _PanelEventCard({required this.title, required this.date, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? _S.primaryDim : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: _st(13, FontWeight.w600, _S.ink)),
        const SizedBox(height: 5),
        Row(children: [
          Icon(Icons.calendar_today_rounded,
              size: 12, color: active ? _S.muted : _S.hint),
          const SizedBox(width: 6),
          Text(date, style: _st(12, FontWeight.normal, active ? _S.muted : _S.hint)),
        ]),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 32, width: double.infinity,
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [_S.primaryDark, _S.primaryLt])
                  : null,
              color: active ? null : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: active ? null : Border.all(color: _S.border),
            ),
            alignment: Alignment.center,
            child: Text('school.viewDetails'.tr(),
                style: _st(12, FontWeight.w600, active ? Colors.white : _S.muted)),
          ),
        ),
      ]),
    );
  }
}

// ─── Events tab ───────────────────────────────────────────────────────────────
class _EventsTab extends StatefulWidget {
  final School school;
  const _EventsTab({required this.school});

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  bool         _loading = true;
  String?      _error;
  List<Event>  _events  = [];
  String       _query   = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() { _loading = true; _error = null; });
    try {
      final events = await EventService.getBySchool(widget.school.id);
      if (!mounted) return;
      setState(() { _events = events; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Event> get _filtered {
    if (_query.trim().isEmpty) return _events;
    final q = _query.toLowerCase();
    return _events.where((e) =>
      e.title.toLowerCase().contains(q) ||
      e.venue.toLowerCase().contains(q),
    ).toList();
  }

  Future<void> _onEventAdded() async {
    await _loadEvents();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Evento creado con éxito',
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
          ),
        ]),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isMobile = w < 600;
    final hPad     = isMobile ? 16.0 : 24.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          if (!isMobile)
            Row(children: [
              Text('Eventos', style: _st(20, FontWeight.w800, _S.ink, ls: -0.4)),
              if (_events.isNotEmpty) ...[
                const SizedBox(width: 10),
                _CountBadge(count: _filtered.length),
              ],
              const Spacer(),
              SizedBox(
                width: 200,
                child: _EventSearchField(
                  ctrl: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () { _searchCtrl.clear(); setState(() => _query = ''); },
                ),
              ),
              const SizedBox(width: 12),
              _NewEventButton(schoolId: widget.school.id, onSuccess: _onEventAdded),
            ])
          else ...[
            Row(children: [
              Text('Eventos', style: _st(20, FontWeight.w800, _S.ink, ls: -0.4)),
              if (_events.isNotEmpty) ...[
                const SizedBox(width: 10),
                _CountBadge(count: _filtered.length),
              ],
              const Spacer(),
              _NewEventButton(schoolId: widget.school.id, onSuccess: _onEventAdded),
            ]),
            const SizedBox(height: 10),
            _EventSearchField(
              ctrl: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              onClear: () { _searchCtrl.clear(); setState(() => _query = ''); },
            ),
          ],
          const SizedBox(height: 16),

          // ── Content ───────────────────────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _S.primary, strokeWidth: 2.5),
      );
    }
    if (_error != null) return _ErrorBody(onRetry: _loadEvents);

    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
                color: _S.primaryDim, shape: BoxShape.circle),
            child: const Icon(Icons.event_outlined, color: _S.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            _events.isEmpty ? 'school.noEvents'.tr() : 'school.noResults'.tr(),
            style: _st(16, FontWeight.w600, _S.ink),
          ),
          const SizedBox(height: 6),
          Text(
            _events.isEmpty
                ? 'school.noEventsDesc'.tr()
                : 'school.noResultsDesc'.tr(),
            textAlign: TextAlign.center,
            style: _st(13, FontWeight.normal, _S.hint),
          ),
        ]),
      );
    }

    return LayoutBuilder(builder: (_, bc) {
      final isMobile = bc.maxWidth < 600;
      if (isMobile) {
        return RefreshIndicator(
          color: _S.primary,
          onRefresh: _loadEvents,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _EventCard(event: list[i], index: i, onUpdated: _loadEvents),
          ),
        );
      }
      final cols    = bc.maxWidth >= 900 ? 3 : 2;
      final spacing = cols == 3 ? 16.0 : 12.0;
      final cardW   = (bc.maxWidth - spacing * (cols - 1)) / cols;
      return RefreshIndicator(
        color: _S.primary,
        onRefresh: _loadEvents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: list.asMap().entries.map((e) => SizedBox(
              width: cardW,
              child: _EventCard(event: e.value, index: e.key, onUpdated: _loadEvents),
            )).toList(),
          ),
        ),
      );
    });
  }
}

// ─── Count badge ──────────────────────────────────────────────────────────────
class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _S.primaryDim,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$count', style: _st(12, FontWeight.w700, _S.primary)),
    );
  }
}

// ─── New event button ─────────────────────────────────────────────────────────
class _NewEventButton extends StatelessWidget {
  final int                     schoolId;
  final Future<void> Function()? onSuccess;

  const _NewEventButton({required this.schoolId, this.onSuccess});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final added = await showAddEventDialog(context, schoolId: schoolId);
          if (added) await onSuccess?.call();
        },
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_S.primaryDark, _S.primaryLt],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x442563EB),
                  offset: Offset(0, 3), blurRadius: 8),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text('school.addEvent'.tr(), style: _st(13, FontWeight.w600, Colors.white)),
          ]),
        ),
      ),
    );
  }
}

// ─── Event search field ───────────────────────────────────────────────────────
class _EventSearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String>  onChanged;
  final VoidCallback          onClear;

  const _EventSearchField({
    required this.ctrl,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: _S.fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _S.border),
      ),
      child: Row(children: [
        const SizedBox(width: 10),
        const Icon(Icons.search_rounded, color: _S.hint, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: ctrl,
            onChanged: onChanged,
            style: _st(13, FontWeight.normal, _S.ink),
            decoration: InputDecoration(
              hintText: 'Buscar por título o lugar…',
              hintStyle: _st(13, FontWeight.normal, _S.hint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (ctrl.text.isNotEmpty)
          GestureDetector(
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(Icons.close_rounded, color: _S.hint, size: 14),
            ),
          )
        else
          const SizedBox(width: 10),
      ]),
    );
  }
}

// ─── Event card ───────────────────────────────────────────────────────────────
class _EventCard extends StatefulWidget {
  final Event         event;
  final int           index;
  final VoidCallback? onUpdated;

  const _EventCard({required this.event, required this.index, this.onUpdated});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool                     _expanded       = false;
  bool                     _loadingDetails = false;
  bool                     _detailsLoaded  = false;
  List<EventPrice>         _prices         = [];
  List<EventParticipation> _participations = [];
  String?                  _detailsErr;

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const days   = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
      const months = ['ene','feb','mar','abr','may','jun',
                      'jul','ago','sep','oct','nov','dic'];
      return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} · '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _loadDetails() async {
    if (_detailsLoaded || _loadingDetails) return;
    setState(() { _loadingDetails = true; _detailsErr = null; });
    try {
      final results = await Future.wait([
        EventService.getEventPrices(widget.event.id),
        EventService.getParticipations(widget.event.id),
      ]);
      if (!mounted) return;
      setState(() {
        _prices         = results[0] as List<EventPrice>;
        _participations = results[1] as List<EventParticipation>;
        _loadingDetails = false;
        _detailsLoaded  = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loadingDetails = false; _detailsErr = 'Error al cargar detalles'; });
    }
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded) _loadDetails();
  }

  Future<void> _handleEnroll() async {
    if (!_detailsLoaded) await _loadDetails();
    if (!mounted) return;
    final enrolled = _participations.map((p) => p.studentId).toList();
    final ok = await showEnrollEventDialog(
      context,
      eventId:            widget.event.id,
      schoolId:           widget.event.schoolId,
      alreadyEnrolledIds: enrolled,
    );
    if (!mounted) return;
    if (ok) {
      _detailsLoaded = false;
      await _loadDetails();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(_successSnack('Inscripción realizada'));
    }
  }

  Future<void> _handleEdit() async {
    final ok = await showEditEventDialog(context, event: widget.event);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(_successSnack('Evento actualizado'));
      widget.onUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _S.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _S.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1E293B), offset: Offset(0, 4), blurRadius: 12),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildBody(),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return SizedBox(
      height: 130,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
              ),
            ),
          ),
          // Content column (leaves room for edit btn)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 52, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Evento',
                      style: _st(11, FontWeight.w700, Colors.white)),
                ),
                const Spacer(),
                Text(
                  widget.event.title,
                  style: _st(20, FontWeight.w800, Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Edit button (top-right)
          Positioned(
            top: 8, right: 8,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _handleEdit,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.edit_outlined,
                      color: Colors.white, size: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _EventInfoRow(
            icon: Icons.calendar_today_rounded,
            text: _fmtDate(widget.event.startDate),
          ),
          const SizedBox(height: 4),
          _EventInfoRow(
            icon: Icons.location_on_outlined,
            text: widget.event.venue.isNotEmpty ? widget.event.venue : '—',
          ),
          const SizedBox(height: 10),
          // Avatars + count + Apuntarse
          Row(children: [
            _buildAvatarStack(),
            const SizedBox(width: 8),
            Text(
              _detailsLoaded
                  ? (_participations.isEmpty
                      ? 'Sé el primero'
                      : '${_participations.length} inscritos')
                  : '${widget.event.maxCapacity} plazas',
              style: _st(12, FontWeight.normal, _S.muted),
            ),
            const Spacer(),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _handleEnroll,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text('school.joinBtn'.tr(),
                      style: _st(12, FontWeight.w600, Colors.white)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          const Divider(color: _S.border, height: 1),
          const SizedBox(height: 8),
          // Expand toggle
          GestureDetector(
            onTap: _toggleExpanded,
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
              Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16, color: _S.hint,
              ),
              const SizedBox(width: 4),
              Text('school.eventDetailsToggle'.tr(),
                  style: _st(13, FontWeight.w600, _S.primary)),
              const Spacer(),
              if (_loadingDetails)
                const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                      color: _S.primary, strokeWidth: 2),
                ),
            ]),
          ),
          // Expandable details
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _expanded ? _buildDetails() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack() {
    if (!_detailsLoaded || _participations.isEmpty) {
      return Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: _S.fieldBg, shape: BoxShape.circle,
          border: Border.all(color: _S.border),
        ),
        child: const Icon(Icons.people_outline_rounded, size: 14, color: _S.hint),
      );
    }
    final shown  = _participations.take(3).toList();
    final totalW = 28.0 + (shown.length - 1) * 18.0;
    return SizedBox(
      width: totalW, height: 28,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 18.0,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _S.avBg(i),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(shown[i].studentName),
                  style: _st(9, FontWeight.w700, _S.avTxt(i)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    if (_detailsErr != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(_detailsErr!,
            style: _st(12, FontWeight.normal, _S.errorRed)),
      );
    }
    if (!_detailsLoaded) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('school.pricesLabel'.tr(), style: _st(11, FontWeight.w700, _S.hint)),
          const SizedBox(height: 6),
          if (_prices.isEmpty)
            Text('school.noPrices'.tr(),
                style: _st(12, FontWeight.normal, _S.hint))
          else
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _prices.map((p) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _S.primaryDim,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${p.type} · €${p.amount.toStringAsFixed(2)}',
                  style: _st(11, FontWeight.w600, _S.primary),
                ),
              )).toList(),
            ),
          const SizedBox(height: 10),
          Text(
            '${'school.participantsLabel'.tr()} (${_participations.length}/${widget.event.maxCapacity})',
            style: _st(11, FontWeight.w700, _S.hint),
          ),
          const SizedBox(height: 6),
          if (_participations.isEmpty)
            Text('school.noEnrolled'.tr(), style: _st(12, FontWeight.normal, _S.hint))
          else ...[
            for (var i = 0; i < _participations.take(5).length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _S.avBg(i),
                    ),
                    alignment: Alignment.center,
                    child: Text(_initials(_participations[i].studentName),
                        style: _st(9, FontWeight.w700, _S.avTxt(i))),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(_participations[i].studentName,
                        style: _st(12, FontWeight.w500, _S.ink),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  _PaymentBadge(status: _participations[i].paymentStatus),
                ]),
              ),
            if (_participations.length > 5)
              Text('+${_participations.length - 5} más',
                  style: _st(11, FontWeight.normal, _S.hint)),
          ],
        ],
      ),
    );
  }
}

// ─── Payment badge ────────────────────────────────────────────────────────────
class _PaymentBadge extends StatelessWidget {
  final String status;
  const _PaymentBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status.toUpperCase()) {
      'PAGADO'    => (_S.paidBg,               _S.paidText,             'school.paidLabel'.tr()),
      'PENDIENTE' => (const Color(0xFFFFF7ED), const Color(0xFFD97706), 'school.pendingLabel'.tr()),
      _           => (_S.fieldBg,              _S.muted,                status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: _st(10, FontWeight.w600, fg)),
    );
  }
}

// ─── Event info row ───────────────────────────────────────────────────────────
class _EventInfoRow extends StatelessWidget {
  final IconData icon;
  final String   text;

  const _EventInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: _S.hint),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style: _st(13, FontWeight.normal, _S.muted),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

// ─── Groups tab ───────────────────────────────────────────────────────────────
class _GroupsTab extends StatefulWidget {
  final School school;
  const _GroupsTab({required this.school});

  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> {
  bool         _loading = true;
  String?      _error;
  List<Group>  _groups  = [];
  String       _query   = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() { _loading = true; _error = null; });
    try {
      final groups = await GroupService.getBySchool(widget.school.id);
      if (!mounted) return;
      setState(() { _groups = groups; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Group> get _filtered {
    if (_query.trim().isEmpty) return _groups;
    final q = _query.toLowerCase();
    return _groups.where((g) =>
      g.name.toLowerCase().contains(q) ||
      g.danceStyle.toLowerCase().contains(q),
    ).toList();
  }

  Future<void> _onGroupAdded() async {
    await _loadGroups();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Grupo creado con éxito',
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
          ),
        ]),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isMobile = w < 600;
    final hPad     = isMobile ? 16.0 : 24.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          if (!isMobile)
            Row(children: [
              Text('Grupos',
                  style: _st(20, FontWeight.w800, _S.ink, ls: -0.4)),
              const Spacer(),
              SizedBox(
                width: 200,
                child: _GroupSearchField(
                  ctrl: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () { _searchCtrl.clear(); setState(() => _query = ''); },
                ),
              ),
              const SizedBox(width: 12),
              _NewGroupButton(schoolId: widget.school.id, onSuccess: _onGroupAdded),
            ])
          else ...[
            Row(children: [
              Text('Grupos',
                  style: _st(20, FontWeight.w800, _S.ink, ls: -0.4)),
              const Spacer(),
              _NewGroupButton(schoolId: widget.school.id, onSuccess: _onGroupAdded),
            ]),
            const SizedBox(height: 10),
            _GroupSearchField(
              ctrl: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              onClear: () { _searchCtrl.clear(); setState(() => _query = ''); },
            ),
          ],
          const SizedBox(height: 16),

          // ── Content ───────────────────────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _S.primary, strokeWidth: 2.5),
      );
    }
    if (_error != null) return _ErrorBody(onRetry: _loadGroups);

    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
                color: _S.primaryDim, shape: BoxShape.circle),
            child: const Icon(Icons.groups_rounded, color: _S.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            _groups.isEmpty ? 'school.noGroups'.tr() : 'school.noResults'.tr(),
            style: _st(16, FontWeight.w600, _S.ink),
          ),
          const SizedBox(height: 6),
          Text(
            _groups.isEmpty
                ? 'school.noGroupsDesc'.tr()
                : 'school.noResultsDesc'.tr(),
            textAlign: TextAlign.center,
            style: _st(13, FontWeight.normal, _S.hint),
          ),
        ]),
      );
    }

    return LayoutBuilder(builder: (_, bc) {
      final isMobile = bc.maxWidth < 600;
      if (isMobile) {
        return RefreshIndicator(
          color: _S.primary,
          onRefresh: _loadGroups,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _GroupCard(group: list[i], index: i, onUpdated: _loadGroups),
          ),
        );
      }
      final cols    = bc.maxWidth >= 900 ? 3 : 2;
      final spacing = cols == 3 ? 16.0 : 12.0;
      final cardW   = (bc.maxWidth - spacing * (cols - 1)) / cols;
      return RefreshIndicator(
        color: _S.primary,
        onRefresh: _loadGroups,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: list.asMap().entries.map((e) => SizedBox(
              width: cardW,
              child: _GroupCard(group: e.value, index: e.key, onUpdated: _loadGroups),
            )).toList(),
          ),
        ),
      );
    });
  }
}

// ─── New group button ─────────────────────────────────────────────────────────
class _NewGroupButton extends StatelessWidget {
  final int                    schoolId;
  final Future<void> Function()? onSuccess;

  const _NewGroupButton({required this.schoolId, this.onSuccess});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final added = await showAddGroupDialog(context, schoolId: schoolId);
          if (added) await onSuccess?.call();
        },
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_S.primaryDark, _S.primaryLt],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x442563EB),
                  offset: Offset(0, 3),
                  blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text('school.addGroup'.tr(),
                  style: _st(13, FontWeight.w600, Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Group search field ───────────────────────────────────────────────────────
class _GroupSearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String>  onChanged;
  final VoidCallback          onClear;

  const _GroupSearchField({
    required this.ctrl,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: _S.fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _S.border),
      ),
      child: Row(children: [
        const SizedBox(width: 10),
        const Icon(Icons.search_rounded, color: _S.hint, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: ctrl,
            onChanged: onChanged,
            style: _st(13, FontWeight.normal, _S.ink),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o estilo…',
              hintStyle: _st(13, FontWeight.normal, _S.hint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (ctrl.text.isNotEmpty)
          GestureDetector(
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(Icons.close_rounded, color: _S.hint, size: 14),
            ),
          )
        else
          const SizedBox(width: 10),
      ]),
    );
  }
}

// ─── Group level style helper (Dart 3 record) ─────────────────────────────────
typedef _LevelStyle = ({Color bg, Color text});

_LevelStyle _levelStyle(String level) => switch (level.toLowerCase()) {
      'principiante' => (
          bg: const Color(0xFFDCFCE7),
          text: const Color(0xFF16A34A)
        ),
      'intermedio' => (bg: _S.primaryDim, text: _S.primary),
      'avanzado'   => (
          bg: const Color(0xFFFEF3C7),
          text: const Color(0xFFD97706)
        ),
      'profesional' => (
          bg: const Color(0xFFF3E8FF),
          text: const Color(0xFF9333EA)
        ),
      _ => (bg: _S.fieldBg, text: _S.muted),
    };

// ─── Dance-style gradient helper ─────────────────────────────────────────────
List<Color> _groupGradient(String danceStyle) {
  final s = danceStyle.toLowerCase();
  if (s.contains('salsa') || s.contains('bachata') || s.contains('merengue')) {
    return const [Color(0xFF7C3AED), Color(0xFF9333EA)];
  }
  if (s.contains('tango') || s.contains('vals')) {
    return const [Color(0xFF0F172A), Color(0xFF1E3A8A)];
  }
  if (s.contains('hip') || s.contains('urban')) {
    return const [Color(0xFF1A1A2E), Color(0xFF16213E)];
  }
  return const [Color(0xFF1D4ED8), Color(0xFF3B82F6)];
}

// ─── Group card ───────────────────────────────────────────────────────────────
class _GroupCard extends StatefulWidget {
  final Group         group;
  final int           index;
  final VoidCallback? onUpdated;

  const _GroupCard({required this.group, required this.index, this.onUpdated});

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool                    _expanded            = false;
  bool                    _loadingEnrollments  = false;
  bool                    _enrollmentsLoaded   = false;
  bool                    _showAllEnrollments  = false;
  List<GroupEnrollment>   _enrollments         = [];
  String?                 _enrollmentsErr;

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _loadEnrollments() async {
    if (_enrollmentsLoaded || _loadingEnrollments) return;
    setState(() { _loadingEnrollments = true; _enrollmentsErr = null; });
    try {
      final list = await GroupService.getEnrollments(widget.group.id);
      if (!mounted) return;
      setState(() {
        _enrollments        = list;
        _loadingEnrollments = false;
        _enrollmentsLoaded  = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingEnrollments = false;
        _enrollmentsErr     = 'Error al cargar inscritos';
      });
    }
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded) _loadEnrollments();
  }

  Future<void> _handleEdit() async {
    final updated = await showEditGroupDialog(context, group: widget.group);
    if (!mounted) return;
    if (updated) {
      ScaffoldMessenger.of(context).showSnackBar(
          _successSnack('Grupo actualizado con éxito'));
      widget.onUpdated?.call();
    }
  }

  Future<void> _handleEnroll() async {
    if (!_enrollmentsLoaded) await _loadEnrollments();
    if (!mounted) return;
    final enrolled = _enrollments.map((e) => e.studentId).toList();
    final ok = await showEnrollGroupDialog(
      context,
      groupId:               widget.group.id,
      schoolId:              widget.group.schoolId,
      alreadyEnrolledIds:    enrolled,
      maxCapacity:           widget.group.maxCapacity,
      currentEnrollmentCount: _enrollments.where((e) => e.active).length,
    );
    if (!mounted) return;
    if (ok) {
      _enrollmentsLoaded  = false;
      _showAllEnrollments = false;
      await _loadEnrollments();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(_successSnack('Alumno inscrito'));
    }
  }

  Future<void> _handleWithdraw(GroupEnrollment enrollment) async {
    try {
      await GroupService.withdrawEnrollment(enrollment.id);
      if (!mounted) return;
      _enrollmentsLoaded  = false;
      _showAllEnrollments = false;
      await _loadEnrollments();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(_successSnack('Alumno dado de baja'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        _errorSnack(e is GroupException ? e.message : 'Error al dar de baja'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _S.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _S.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A1E293B), offset: Offset(0, 4), blurRadius: 12),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final ls      = _levelStyle(widget.group.level);
    final colors  = _groupGradient(widget.group.danceStyle);

    return SizedBox(
      height: 110,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 52, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.group.danceStyle.isNotEmpty
                          ? widget.group.danceStyle
                          : 'Grupo',
                      style: _st(11, FontWeight.w700, Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ls.bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(widget.group.level,
                        style: _st(11, FontWeight.w700, ls.text)),
                  ),
                ]),
                const Spacer(),
                Text(
                  widget.group.name,
                  style: _st(18, FontWeight.w800, Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            top: 8, right: 8,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _handleEdit,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.edit_outlined,
                      color: Colors.white, size: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Schedule + count
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 14, color: _S.hint),
            const SizedBox(width: 6),
            Flexible(
              child: Text(widget.group.schedule,
                  style: _st(12, FontWeight.normal, _S.muted),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Text(
              _enrollmentsLoaded
                  ? '${_enrollments.length}/${widget.group.maxCapacity}'
                  : '${widget.group.maxCapacity} plazas',
              style: _st(12, FontWeight.w600, _S.muted),
            ),
          ]),
          const SizedBox(height: 8),
          // Avatars + count + Inscribir
          Row(children: [
            _buildAvatarStack(),
            const SizedBox(width: 8),
            Text(
              _enrollmentsLoaded
                  ? (_enrollments.isEmpty
                      ? 'Sé el primero'
                      : '${_enrollments.length} inscritos')
                  : '${widget.group.maxCapacity} plazas',
              style: _st(12, FontWeight.normal, _S.muted),
            ),
            const Spacer(),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _handleEnroll,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Color(0x3316A34A),
                          offset: Offset(0, 3), blurRadius: 8),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text('school.enrollBtn'.tr(),
                      style: _st(13, FontWeight.w600, Colors.white)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          const Divider(color: _S.border, height: 1),
          const SizedBox(height: 6),
          // Expand toggle
          GestureDetector(
            onTap: _toggleExpanded,
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
              Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16, color: _S.hint,
              ),
              const SizedBox(width: 4),
              Text('school.enrolledStudents'.tr(),
                  style: _st(13, FontWeight.w600, _S.primary)),
              const Spacer(),
              if (_loadingEnrollments)
                const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                      color: _S.primary, strokeWidth: 2),
                ),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _expanded ? _buildEnrollmentList() : const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          // Delete button (prominente)
          Row(children: [
            const Spacer(),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  final ok = await _confirmDeleteGroup(context, widget.group.name);
                  if (!mounted) return;
                  if (!ok) return;
                  try {
                    await GroupService.deleteGroup(widget.group.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(_successSnack('Grupo eliminado'));
                    widget.onUpdated?.call();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      _errorSnack(e is GroupException
                          ? e.message
                          : 'Error al eliminar'),
                    );
                  }
                },
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.delete_outline_rounded,
                        size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 5),
                    Text('Eliminar',
                        style: _st(12, FontWeight.w600,
                            const Color(0xFFDC2626))),
                  ]),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildAvatarStack() {
    if (!_enrollmentsLoaded || _enrollments.isEmpty) {
      return Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: _S.fieldBg, shape: BoxShape.circle,
          border: Border.all(color: _S.border),
        ),
        child: const Icon(Icons.people_outline_rounded,
            size: 14, color: _S.hint),
      );
    }
    final shown  = _enrollments.take(3).toList();
    final totalW = 28.0 + (shown.length - 1) * 18.0;
    return SizedBox(
      width: totalW, height: 28,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 18.0,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _S.avBg(i),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(shown[i].studentName),
                  style: _st(9, FontWeight.w700, _S.avTxt(i)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentList() {
    if (_enrollmentsErr != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(_enrollmentsErr!,
            style: _st(12, FontWeight.normal, _S.errorRed)),
      );
    }
    if (!_enrollmentsLoaded) return const SizedBox.shrink();
    if (_enrollments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('school.noEnrolled'.tr(),
            style: _st(12, FontWeight.normal, _S.hint)),
      );
    }

    // Active first, then inactive
    final sorted = [..._enrollments]
      ..sort((a, b) {
        if (a.active == b.active) return 0;
        return a.active ? -1 : 1;
      });

    final total      = sorted.length;
    final showCount  = _showAllEnrollments ? total : total.clamp(0, 5);
    final visible    = sorted.take(showCount).toList();
    final remaining  = total - showCount;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < visible.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _S.avBg(i)),
                  alignment: Alignment.center,
                  child: Text(_initials(visible[i].studentName),
                      style: _st(9, FontWeight.w700, _S.avTxt(i))),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(visible[i].studentName,
                      style: _st(12, FontWeight.w500, _S.ink),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                _ActiveBadge(active: visible[i].active),
                if (visible[i].active) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Dar de baja',
                    child: GestureDetector(
                      onTap: () => _handleWithdraw(visible[i]),
                      child: Container(
                        width: 24, height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.logout_rounded,
                            size: 12, color: Color(0xFFDC2626)),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          if (remaining > 0)
            GestureDetector(
              onTap: () => setState(() => _showAllEnrollments = true),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Ver $remaining más',
                      style: _st(12, FontWeight.w600, _S.primary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 12, color: _S.primary),
                ]),
              ),
            )
          else if (_showAllEnrollments && total > 5)
            GestureDetector(
              onTap: () => setState(() => _showAllEnrollments = false),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Ver menos',
                      style: _st(12, FontWeight.w600, _S.muted)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_up_rounded,
                      size: 14, color: _S.muted),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Active badge ─────────────────────────────────────────────────────────────
class _ActiveBadge extends StatelessWidget {
  final bool active;
  const _ActiveBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: active ? _S.paidBg : _S.unpaidBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        active ? 'school.activeLabel'.tr() : 'school.inactiveLabel'.tr(),
        style: _st(10, FontWeight.w600,
            active ? _S.paidText : _S.unpaidText),
      ),
    );
  }
}

// ─── Placeholder (Events / Alerts tabs) ──────────────────────────────────────
class _PlaceholderContent extends StatelessWidget {
  final IconData icon;
  final String   labelKey;

  const _PlaceholderContent({required this.icon, required this.labelKey});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(color: _S.primaryDim, shape: BoxShape.circle),
          child: Icon(icon, color: _S.primary, size: 32),
        ),
        const SizedBox(height: 14),
        Text(labelKey.tr(), style: _st(16, FontWeight.w600, _S.muted)),
        const SizedBox(height: 6),
        Text('Próximamente', style: _st(13, FontWeight.normal, _S.hint)),
      ]),
    );
  }
}
