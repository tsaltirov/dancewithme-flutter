import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/school_service.dart';
import '../widgets/add_school_dialog.dart';
import '../widgets/logout_dialog.dart';
import 'login_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _T {
  static const bg         = Color(0xFFF7F5FF);
  static const surface    = Color(0xFFFFFFFF);
  static const purple     = Color(0xFF7C5CFC);
  static const purpleLt   = Color(0xFF9B7EFD);
  static const purpleDim  = Color(0xFFEDE9FF);
  static const alertRed   = Color(0xFFFF3B30);
  // Logout — red-danger (eye-catching, UX standard for destructive action)
  static const logoutRed  = Color(0xFFEF4444);
  static const logoutRedBg = Color(0xFFFEE2E2);
  static const ink        = Color(0xFF1A1525);
  static const body       = Color(0xFF4A4558);
  static const muted      = Color(0xFF8B879A);
  static const border     = Color(0xFFE8E4F4);
  static const tabSurface  = Color(0xFFFFFFFF);
  static const tabInactive = Color(0xFFADA8BE);

  // School card gradients
  static const card1 = [Color(0xFF5040D4), Color(0xFF7C5CFC)];
  static const card2 = [Color(0xFF1A1528), Color(0xFF2D2550)];
  static const card3 = [Color(0xFFC0399A), Color(0xFF9B3FDB)];

  // Stats card colours
  static const statPeachNum    = Color(0xFFC07A5A);
  static const statPeachLbl    = Color(0xFFD89575);
  static const statPeachBg     = Color(0xFFFFF5F0);
  static const statPeachBorder = Color(0xFFF5E8E0);
  static const statGreenNum    = Color(0xFF2D8A52);
  static const statGreenLbl    = Color(0xFF4CAF79);
  static const statGreenBg     = Color(0xFFF0FFF5);
  static const statGreenBorder = Color(0xFFC6F0D8);

  // Tab bar geometry
  static const double tabH    = 62;
  static const double tabPadV = 14;
  static const double tabPadH = 20;
  static const double tabBarH = tabH + tabPadV * 2; // 90
  static const double maxW    = 560; // mobile content max

  // Sidebar (web)
  static const double sidebarW   = 240;
  static const sidebarBg         = Color(0xFFFFFFFF);
  static const sidebarBorder     = Color(0xFFEDE9F8);
  static const navActiveBg       = Color(0xFFF0EAFF);
  static const navActiveClr      = purple;
  static const navInactiveClr    = Color(0xFF6D6C6A);
  static const navInactiveIco    = Color(0xFF9C9B99);
  static const logoutBg  = logoutRedBg;
  static const logoutClr = logoutRed;
}

// ─── Breakpoints ──────────────────────────────────────────────────────────────
enum _Layout { mobile, tablet, web }

_Layout _layoutFor(double w) {
  if (w >= 1100) return _Layout.web;
  if (w >= 600)  return _Layout.tablet;
  return _Layout.mobile;
}

// ─── Text style helper ────────────────────────────────────────────────────────
TextStyle _pjs(double size, FontWeight w, Color c,
    {double ls = 0, double lh = 1.3}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: size, fontWeight: w, color: c, letterSpacing: ls, height: lh);

// ─── Tappable wrapper — pointer cursor on web ─────────────────────────────────
Widget _tap(Widget child,
    {required VoidCallback? onTap, HitTestBehavior? behavior}) =>
    MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(onTap: onTap, behavior: behavior, child: child),
    );

// ─── Gradient cycle helper ────────────────────────────────────────────────────
List<Color> _gradForIdx(int i) {
  const g = [_T.card1, _T.card2, _T.card3];
  return g[i % g.length];
}

// ─── Shared prominent Enter button ────────────────────────────────────────────
Widget _enterButton({required VoidCallback onTap, String? label}) =>
    _tap(
      Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_T.purple, _T.purpleLt],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x557C5CFC), offset: Offset(0, 4), blurRadius: 14),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label ?? 'Entrar',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 16),
          ],
        ),
      ),
      onTap: onTap,
    );

// ─── HomeScreen ───────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _fade;

  AuthUser?    _user;
  List<School> _schools        = [];
  bool         _loadingSchools = true;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await AuthService.getUser();
    if (!mounted) return;

    // Auth guard: if user can't be loaded (expired / storage error) → back to Login
    if (user == null || user.id.isEmpty) {
      setState(() => _loadingSchools = false);
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (_) => false,
      );
      return;
    }

    setState(() => _user = user);
    await _reloadSchools(user.id);
  }

  // Reloads only the schools list using the already-resolved userId.
  // Called from _showAddSchool to avoid hitting secure storage again.
  Future<void> _reloadSchools(String userId) async {
    setState(() => _loadingSchools = true);
    try {
      final schools = await SchoolService.getUserSchools(userId);
      if (!mounted) return;
      setState(() { _schools = schools; _loadingSchools = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSchools = false);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final ok = await showLogoutDialog(context);
    if (!(ok ?? false) || !mounted) return;
    await AuthService.logout();
    if (!mounted) return;
    if (kIsWeb) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (_) => false,
      );
    } else {
      SystemNavigator.pop();
    }
  }

  void _switchTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _fade..reset()..forward();
  }

  Future<void> _showAddSchool() async {
    final added = await AddSchoolDialog.show(context);
    if (added == true && mounted) {
      // Await reload so the list is updated before the snackbar appears.
      // Uses cached _user.id to avoid a second secure-storage read (web crypto issue).
      if (_user != null) await _reloadSchools(_user!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text('school.successCreate'.tr(),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white)),
            ),
          ]),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final width      = MediaQuery.of(context).size.width;
    final layout     = _layoutFor(width);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!kIsWeb) SystemNavigator.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark
            .copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: _T.bg,
          body: Stack(
            children: [
              const Positioned.fill(child: _BgGradient()),
              if (layout == _Layout.web)
                Positioned.fill(
                  child: _WebLayout(
                    tab:         _tab,
                    fade:        _fade,
                    user:        _user,
                    schools:     _schools,
                    loading:     _loadingSchools,
                    onTabSelect: _switchTab,
                    onLogout:    _logout,
                    onAddSchool: _showAddSchool,
                  ),
                )
              else ...[
                Positioned.fill(
                  child: SafeArea(
                    bottom: false,
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                          parent: _fade, curve: Curves.easeOut),
                      child: _tab == 0
                          ? (layout == _Layout.tablet
                              ? _TabletBody(
                                  safeBottom: safeBottom,
                                  user:       _user,
                                  schools:    _schools,
                                  loading:    _loadingSchools,
                                  onLogout:   _logout)
                              : _HomeBody(
                                  safeBottom: safeBottom,
                                  user:       _user,
                                  schools:    _schools,
                                  loading:    _loadingSchools,
                                  onLogout:   _logout))
                          : _PlaceholderTab(index: _tab),
                    ),
                  ),
                ),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: _FloatingTabBar(
                    current: _tab,
                    safeBottom: safeBottom,
                    onSelect: _switchTab,
                    maxWidth: layout == _Layout.mobile
                        ? _T.maxW
                        : double.infinity,
                  ),
                ),
                if (_tab == 0)
                  Positioned(
                    right: 20,
                    bottom: _T.tabBarH + safeBottom + 16,
                    child: _AddSchoolFab(onTap: _showAddSchool),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Background gradient ──────────────────────────────────────────────────────
class _BgGradient extends StatelessWidget {
  const _BgGradient();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BgPainter(), child: const SizedBox.expand());
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = _T.bg);
    for (final (fx, fy, c, op) in [
      (0.0, 0.0, const Color(0xFFEDE9FF), 0.75),
      (1.0, 1.0, const Color(0xFFFFEDE8), 0.60),
      (0.5, 0.5, Colors.white,            0.50),
    ]) {
      final center = Offset(s.width * fx, s.height * fy);
      final r = s.width * 0.85;
      canvas.drawCircle(
        center, r,
        Paint()
          ..shader = ui.Gradient.radial(
              center, r, [c.withValues(alpha: op), Colors.transparent]),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Placeholder for unimplemented tabs ───────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final int index;
  const _PlaceholderTab({required this.index});
  @override
  Widget build(BuildContext context) {
    const keys = ['', 'home.tabExplore', 'home.tabCalendar', 'home.tabProfile'];
    return Center(
        child: Text(keys[index].tr(),
            style: _pjs(18, FontWeight.w600, _T.muted)));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHARED COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Stats strip (tablet + web) ───────────────────────────────────────────────
class _StatsStrip extends StatelessWidget {
  final double height;
  final double gap;
  final int    schoolCount;
  const _StatsStrip({required this.height, required this.gap, required this.schoolCount});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _StatCard(
          num: schoolCount.toString(), label: 'home.statSchools'.tr().toUpperCase(),
          numColor: Colors.white,
          labelColor: Colors.white.withValues(alpha: 0.75),
          height: height,
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_T.purple, _T.purpleLt],
          ),
          shadow: const Color(0x337C5CFC),
        ),
      ),
      SizedBox(width: gap),
      Expanded(
        child: _StatCard(
          num: '320', label: 'Alumnos',
          numColor: _T.statPeachNum, labelColor: _T.statPeachLbl,
          height: height, bg: _T.statPeachBg,
          borderColor: _T.statPeachBorder,
        ),
      ),
      SizedBox(width: gap),
      Expanded(
        child: _StatCard(
          num: '5', label: 'Eventos',
          numColor: _T.statGreenNum, labelColor: _T.statGreenLbl,
          height: height, bg: _T.statGreenBg,
          borderColor: _T.statGreenBorder,
        ),
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String num;
  final String label;
  final Color numColor;
  final Color labelColor;
  final double height;
  final Color? bg;
  final Color? borderColor;
  final LinearGradient? gradient;
  final Color? shadow;

  const _StatCard({
    required this.num,
    required this.label,
    required this.numColor,
    required this.labelColor,
    required this.height,
    this.bg,
    this.borderColor,
    this.gradient,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? bg : null,
        borderRadius: BorderRadius.circular(18),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: shadow != null
            ? [BoxShadow(color: shadow!, offset: const Offset(0, 4), blurRadius: 16)]
            : borderColor != null
                ? [const BoxShadow(
                    color: Color(0x081A1918),
                    offset: Offset(0, 2), blurRadius: 8)]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(num,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 28, fontWeight: FontWeight.w700,
                  letterSpacing: -1, color: numColor, height: 1)),
          const SizedBox(height: 4),
          Text(label, style: _pjs(12, FontWeight.w500, labelColor)),
        ],
      ),
    );
  }
}


// ─── School image card (tablet top card + web grid) ───────────────────────────
class _SchoolImageCard extends StatelessWidget {
  final School       school;
  final int          index;
  final VoidCallback onEnter;

  const _SchoolImageCard({
    required this.school,
    required this.index,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    final grads = _gradForIdx(index);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: grads[0].withValues(alpha: 0.22),
              offset: const Offset(0, 8), blurRadius: 24),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          // Background: network image or gradient
          Positioned.fill(
            child: school.hasImage
                ? Image.network(school.imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: grads))))
                : Container(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: grads))),
          ),
          // Dark overlay for image legibility
          if (school.hasImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent])),
              ),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(school.name,
                    style: _pjs(17, FontWeight.w700, Colors.white, ls: -0.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 14),
                _enterButton(onTap: onEnter),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── School list card (tablet list rows) ─────────────────────────────────────
class _SchoolListCard extends StatelessWidget {
  final School       school;
  final int          index;
  final VoidCallback onEnter;

  const _SchoolListCard({
    required this.school,
    required this.index,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    final grads = _gradForIdx(index);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0EDE8)),
        boxShadow: const [
          BoxShadow(color: Color(0x101A1918), offset: Offset(0, 2), blurRadius: 12),
        ],
      ),
      child: Row(children: [
        // Thumbnail: network image or gradient fallback
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 62, height: 62,
            child: school.hasImage
                ? Image.network(school.imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: grads))))
                : Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: grads)),
                    child: Text((index + 1).toString().padLeft(2, '0'),
                        style: _pjs(18, FontWeight.w800,
                            Colors.white.withValues(alpha: 0.9))),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(school.name,
                  style: _pjs(15, FontWeight.w600, _T.ink),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              _enterButton(onTap: onEnter),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Empty state (no schools yet) ────────────────────────────────────────────
class _SchoolsEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              color: _T.purpleDim, shape: BoxShape.circle),
          child: const Icon(Icons.school_outlined, color: _T.purple, size: 34),
        ),
        const SizedBox(height: 16),
        Text('Aún no tienes escuelas',
            style: _pjs(16, FontWeight.w600, _T.ink)),
        const SizedBox(height: 6),
        Text('Crea tu primera academia con el botón +',
            textAlign: TextAlign.center,
            style: _pjs(13, FontWeight.w400, _T.muted)),
      ]),
    );
  }
}

// ─── Circle button (shared header) ───────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final bool hasDot;
  final VoidCallback onTap;

  const _CircleBtn({
    required this.icon,
    required this.iconColor,
    required this.bg,
    this.hasDot = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _tap(
      Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: _T.border),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0C1A1525),
                  offset: Offset(0, 2), blurRadius: 8),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        if (hasDot)
          Positioned(
            top: 4, right: 4,
            child: Container(
              width: 9, height: 9,
              decoration: const BoxDecoration(
                color: _T.alertRed, shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x66FF3B30), blurRadius: 4)
                ],
              ),
            ),
          ),
      ]),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MOBILE LAYOUT  (< 600px)
// ═══════════════════════════════════════════════════════════════════════════════

class _HomeBody extends StatelessWidget {
  final double      safeBottom;
  final AuthUser?   user;
  final List<School> schools;
  final bool        loading;
  final VoidCallback onLogout;
  const _HomeBody({
    required this.safeBottom,
    required this.user,
    required this.schools,
    required this.loading,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = _T.tabBarH + safeBottom + 28;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _T.maxW),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 6, 22, bottomPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MobileHeader(user: user, onLogout: onLogout),
                const SizedBox(height: 28),
                _SchoolsCountCard(count: schools.length),
                const SizedBox(height: 32),
                _MobileSchoolsSection(schools: schools, loading: loading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  final AuthUser?    user;
  final VoidCallback onLogout;
  const _MobileHeader({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greetKey = h < 12
        ? 'home.greetMorning'
        : h < 19 ? 'home.greetAfternoon' : 'home.greetEvening';
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_T.purple, Color(0xFFA78BFA)],
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x3A7C5CFC), offset: Offset(0, 4), blurRadius: 14),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'U',
          style: _pjs(20, FontWeight.w800, Colors.white),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(greetKey.tr(),
                style: _pjs(12, FontWeight.w500, _T.muted, ls: 0.2)),
            const SizedBox(height: 2),
            Text(
              user?.fullName.isNotEmpty == true ? user!.fullName : '—',
              style: _pjs(19, FontWeight.w800, _T.ink, ls: -0.3),
            ),
          ],
        ),
      ),
      _CircleBtn(
          icon: Icons.notifications_none_rounded,
          iconColor: _T.body, bg: _T.surface, hasDot: true, onTap: () {}),
      const SizedBox(width: 10),
      _CircleBtn(
          icon: Icons.logout_rounded,
          iconColor: _T.logoutRed, bg: _T.logoutRedBg, onTap: onLogout),
    ]);
  }
}

class _SchoolsCountCard extends StatelessWidget {
  final int count;
  const _SchoolsCountCard({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_T.purple, _T.purpleLt],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x3A7C5CFC), offset: Offset(0, 8), blurRadius: 24),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(count.toString(),
            style: GoogleFonts.plusJakartaSans(
                fontSize: 56, fontWeight: FontWeight.w800,
                height: 1, letterSpacing: -3, color: Colors.white)),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('home.statSchools'.tr().toUpperCase(),
                style: _pjs(13, FontWeight.w700, Colors.white, ls: 0.5)),
            const SizedBox(height: 3),
            Text('home.statAvailable'.tr(),
                style: _pjs(12, FontWeight.w400,
                    Colors.white.withValues(alpha: 0.65))),
          ],
        ),
        const Spacer(),
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
        ),
      ]),
    );
  }
}

class _MobileSchoolsSection extends StatelessWidget {
  final List<School> schools;
  final bool         loading;
  const _MobileSchoolsSection({required this.schools, required this.loading});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('home.sectionSchools'.tr(),
            style: _pjs(20, FontWeight.w800, _T.ink, ls: -0.4)),
        const SizedBox(height: 18),
        if (loading)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(color: _T.purple, strokeWidth: 2.5),
          ))
        else if (schools.isEmpty)
          _SchoolsEmptyState()
        else
          LayoutBuilder(builder: (ctx, bc) {
            final twoCol = bc.maxWidth > 480;
            final cards = schools.asMap().entries
                .map((e) => _MobileSchoolCard(
                    school: e.value, index: e.key, onEnter: () {}))
                .toList();
            if (twoCol && cards.length >= 2) {
              return Column(children: [
                cards[0],
                const SizedBox(height: 14),
                IntrinsicHeight(
                  child: Row(children: [
                    Expanded(child: cards[1]),
                    if (cards.length > 2) ...[
                      const SizedBox(width: 14),
                      Expanded(child: cards[2]),
                    ],
                  ]),
                ),
                ...cards.skip(3).map((c) =>
                    Padding(padding: const EdgeInsets.only(top: 14), child: c)),
              ]);
            }
            return Column(
              children: cards
                  .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 14), child: c))
                  .toList(),
            );
          }),
      ],
    );
  }
}

class _MobileSchoolCard extends StatelessWidget {
  final School       school;
  final int          index;
  final VoidCallback onEnter;

  const _MobileSchoolCard({
    required this.school,
    required this.index,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    final grads  = _gradForIdx(index);
    final numStr = (index + 1).toString().padLeft(2, '0');

    return _tap(
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: grads[0].withValues(alpha: 0.32),
              offset: const Offset(0, 8), blurRadius: 24,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            // Background: image or gradient
            Positioned.fill(
              child: school.hasImage
                  ? Image.network(school.imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight, colors: grads))))
                  : Container(decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight, colors: grads))),
            ),
            // Dark overlay for image
            if (school.hasImage)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.black.withValues(alpha: 0.1),
                    ],
                  )),
                ),
              ),
            // Content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Text(numStr,
                        style: _pjs(12, FontWeight.w700,
                            Colors.white.withValues(alpha: 0.85), ls: 1.0)),
                  ),
                  const SizedBox(height: 14),
                  Text(school.name,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 20, fontWeight: FontWeight.w800,
                          height: 1.15, letterSpacing: -0.5, color: Colors.white),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 18),
                  _enterButton(onTap: onEnter),
                ],
              ),
            ),
          ]),
        ),
      ),
      onTap: onEnter,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TABLET LAYOUT  (600px – 1099px)
// ═══════════════════════════════════════════════════════════════════════════════

class _TabletBody extends StatelessWidget {
  final double       safeBottom;
  final AuthUser?    user;
  final List<School> schools;
  final bool         loading;
  final VoidCallback onLogout;
  const _TabletBody({
    required this.safeBottom,
    required this.user,
    required this.schools,
    required this.loading,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = _T.tabBarH + safeBottom + 28;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, 0, 28, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TabletHeader(user: user, onLogout: onLogout),
            const SizedBox(height: 20),
            _StatsStrip(height: 80, gap: 12, schoolCount: schools.length),
            const SizedBox(height: 20),
            Text('home.sectionSchools'.tr(),
                style: _pjs(20, FontWeight.w700, _T.ink, ls: -0.2)),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(
                    color: _T.purple, strokeWidth: 2.5),
              ))
            else if (schools.isEmpty)
              _SchoolsEmptyState()
            else
              Column(children: [
                _SchoolImageCard(school: schools[0], index: 0, onEnter: () {}),
                if (schools.length > 1) ...[
                  const SizedBox(height: 12),
                  IntrinsicHeight(child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _SchoolListCard(
                          school: schools[1], index: 1, onEnter: () {})),
                      if (schools.length > 2) ...[
                        const SizedBox(width: 12),
                        Expanded(child: _SchoolListCard(
                            school: schools[2], index: 2, onEnter: () {})),
                      ],
                    ],
                  )),
                ],
                if (schools.length > 3)
                  ...schools.skip(3).toList().asMap().entries.map((e) =>
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _SchoolListCard(
                          school: e.value, index: e.key + 3, onEnter: () {}),
                    )),
              ]),
          ],
        ),
      ),
    );
  }
}

class _TabletHeader extends StatelessWidget {
  final AuthUser?    user;
  final VoidCallback onLogout;
  const _TabletHeader({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greetKey = h < 12
        ? 'home.greetMorning'
        : h < 19 ? 'home.greetAfternoon' : 'home.greetEvening';
    final initial = (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'U';
    final displayName = user?.fullName.isNotEmpty == true ? user!.fullName : '—';

    return Row(children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_T.purple, Color(0xFF9B7EFD)],
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x447C5CFC), offset: Offset(0, 4), blurRadius: 16),
          ],
        ),
        alignment: Alignment.center,
        child: Text(initial, style: _pjs(22, FontWeight.w700, Colors.white)),
      ),
      const SizedBox(width: 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(greetKey.tr(), style: _pjs(13, FontWeight.w400, _T.muted)),
          Text(displayName,
              style: _pjs(20, FontWeight.w700, _T.ink, ls: -0.3)),
        ],
      ),
      const Spacer(),
      _CircleBtn(
          icon: Icons.notifications_none_rounded,
          iconColor: _T.body, bg: _T.surface, hasDot: true, onTap: () {}),
      const SizedBox(width: 10),
      _CircleBtn(
          icon: Icons.logout_rounded,
          iconColor: _T.logoutRed, bg: _T.logoutRedBg, onTap: onLogout),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  WEB LAYOUT  (≥ 1100px)
// ═══════════════════════════════════════════════════════════════════════════════

class _WebLayout extends StatelessWidget {
  final int              tab;
  final AnimationController fade;
  final AuthUser?        user;
  final List<School>     schools;
  final bool             loading;
  final ValueChanged<int> onTabSelect;
  final VoidCallback     onLogout;
  final VoidCallback     onAddSchool;

  const _WebLayout({
    required this.tab,
    required this.fade,
    required this.user,
    required this.schools,
    required this.loading,
    required this.onTabSelect,
    required this.onLogout,
    required this.onAddSchool,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _Sidebar(current: tab, user: user, onSelect: onTabSelect, onLogout: onLogout),
      Expanded(
        child: Column(children: [
          _WebTopBar(user: user),
          Expanded(
            child: FadeTransition(
              opacity:
                  CurvedAnimation(parent: fade, curve: Curves.easeOut),
              child: tab == 0
                  ? _WebBody(schools: schools, loading: loading, onAddSchool: onAddSchool)
                  : _PlaceholderTab(index: tab),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _Sidebar extends StatelessWidget {
  final int current;
  final AuthUser?    user;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.current,
    required this.user,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _T.sidebarW,
      decoration: const BoxDecoration(
        color: _T.sidebarBg,
        border: Border(right: BorderSide(color: _T.sidebarBorder)),
      ),
      child: Column(children: [
        // Logo
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _T.sidebarBorder)),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_T.purple, _T.purpleLt],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text('DanceWithMe', style: _pjs(15, FontWeight.w700, _T.ink)),
          ]),
        ),
        // User card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: Color(0xFFF0EDE8))),
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _T.purpleDim,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [_T.purple, _T.purpleLt],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'U',
                  style: _pjs(16, FontWeight.w700, Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.fullName.isNotEmpty == true ? user!.fullName : '—',
                      style: _pjs(14, FontWeight.w600, _T.ink),
                    ),
                    Text(user?.role ?? 'Alumna',
                        style: _pjs(12, FontWeight.w400, _T.muted)),
                  ],
                ),
              ),
            ]),
          ),
        ),
        // Nav
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
            child: Column(children: [
              _SidebarNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'home.tabHome'.tr(),
                  active: current == 0,
                  onTap: () => onSelect(0)),
              const SizedBox(height: 4),
              _SidebarNavItem(
                  icon: Icons.explore_rounded,
                  label: 'home.tabExplore'.tr(),
                  active: current == 1,
                  onTap: () => onSelect(1)),
              const SizedBox(height: 4),
              _SidebarNavItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'home.tabCalendar'.tr(),
                  active: current == 2,
                  onTap: () => onSelect(2)),
              const SizedBox(height: 4),
              _SidebarNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'home.tabProfile'.tr(),
                  active: current == 3,
                  onTap: () => onSelect(3)),
            ]),
          ),
        ),
        // Logout
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
          child: _tap(
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _T.logoutBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.logout_rounded,
                    color: _T.logoutClr, size: 18),
                const SizedBox(width: 10),
                Text('Cerrar Sesión',
                    style: _pjs(14, FontWeight.w500, _T.logoutClr)),
              ]),
            ),
            onTap: onLogout,
          ),
        ),
      ]),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _tap(
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? _T.navActiveBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon,
              size: 18,
              color: active ? _T.navActiveClr : _T.navInactiveIco),
          const SizedBox(width: 10),
          Text(label,
              style: _pjs(14,
                  active ? FontWeight.w600 : FontWeight.w500,
                  active ? _T.navActiveClr : _T.navInactiveClr)),
        ]),
      ),
      onTap: onTap,
    );
  }
}

class _WebTopBar extends StatelessWidget {
  final AuthUser? user;
  const _WebTopBar({required this.user});

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greetKey = h < 12
        ? 'home.greetMorning'
        : h < 19 ? 'home.greetAfternoon' : 'home.greetEvening';

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: _T.surface,
        border: Border(bottom: BorderSide(color: _T.sidebarBorder)),
      ),
      child: Row(children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(greetKey.tr(), style: _pjs(13, FontWeight.w400, _T.muted)),
            Text(
              user?.fullName.isNotEmpty == true ? user!.fullName : '—',
              style: _pjs(20, FontWeight.w700, _T.ink, ls: -0.3),
            ),
          ],
        ),
        const Spacer(),
        _CircleBtn(
            icon: Icons.notifications_none_rounded,
            iconColor: _T.body, bg: _T.surface, hasDot: true, onTap: () {}),
      ]),
    );
  }
}

class _WebBody extends StatelessWidget {
  final List<School> schools;
  final bool         loading;
  final VoidCallback onAddSchool;
  const _WebBody({required this.schools, required this.loading, required this.onAddSchool});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatsStrip(height: 90, gap: 16, schoolCount: schools.length),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('home.sectionSchools'.tr(),
                          style: _pjs(20, FontWeight.w700, _T.ink, ls: -0.2)),
                      const Spacer(),
                      _tap(
                        Container(
                          height: 38,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_T.purple, _T.purpleLt],
                            ),
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x447C5CFC),
                                  offset: Offset(0, 3),
                                  blurRadius: 10),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text('school.addTitle'.tr(),
                                  style: _pjs(13, FontWeight.w600,
                                      Colors.white)),
                            ],
                          ),
                        ),
                        onTap: onAddSchool,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (loading)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(
                          color: _T.purple, strokeWidth: 2.5),
                    ))
                  else if (schools.isEmpty)
                    _SchoolsEmptyState()
                  else
                    IntrinsicHeight(
                      child: Row(children: [
                        ...schools.asMap().entries.map((e) => Expanded(
                          child: Row(children: [
                            if (e.key > 0) const SizedBox(width: 16),
                            Expanded(child: _SchoolImageCard(
                                school: e.value, index: e.key, onEnter: () {})),
                          ]),
                        )),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add School FAB (mobile + tablet, tab 0 only) ────────────────────────────
class _AddSchoolFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddSchoolFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _tap(
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_T.purple, _T.purpleLt],
          ),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
                color: Color(0x557C5CFC),
                offset: Offset(0, 4),
                blurRadius: 18),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  FLOATING TAB BAR  (mobile + tablet)
// ═══════════════════════════════════════════════════════════════════════════════

class _FloatingTabBar extends StatelessWidget {
  final int current;
  final double safeBottom;
  final ValueChanged<int> onSelect;
  final double maxWidth;

  const _FloatingTabBar({
    required this.current,
    required this.safeBottom,
    required this.onSelect,
    this.maxWidth = _T.maxW,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              _T.tabPadH, _T.tabPadV, _T.tabPadH, _T.tabPadV + safeBottom),
          child: Container(
            height: _T.tabH,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _T.tabSurface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: _T.border),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x147C5CFC),
                    offset: Offset(0, -4), blurRadius: 20),
                BoxShadow(
                    color: Color(0x0A1A1525),
                    offset: Offset(0, 4), blurRadius: 16),
              ],
            ),
            child: Row(children: [
              _TabItem(idx: 0, current: current,
                  icon: Icons.dashboard_rounded,
                  label: 'home.tabHome'.tr(), onTap: onSelect),
              _TabItem(idx: 1, current: current,
                  icon: Icons.explore_rounded,
                  label: 'home.tabExplore'.tr(), onTap: onSelect),
              _TabItem(idx: 2, current: current,
                  icon: Icons.calendar_today_rounded,
                  label: 'home.tabCalendar'.tr(), onTap: onSelect),
              _TabItem(idx: 3, current: current,
                  icon: Icons.person_outline_rounded,
                  label: 'home.tabProfile'.tr(), onTap: onSelect),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final int idx;
  final int current;
  final IconData icon;
  final String label;
  final ValueChanged<int> onTap;

  const _TabItem({
    required this.idx,
    required this.current,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = idx == current;
    return Expanded(
      child: _tap(
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [_T.purple, _T.purpleLt])
                : null,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: active ? Colors.white : _T.tabInactive),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: _pjs(9,
                    active ? FontWeight.w700 : FontWeight.w500,
                    active ? Colors.white : _T.tabInactive,
                    ls: 0.4),
                child: Text(label),
              ),
            ],
          ),
        ),
        onTap: () => onTap(idx),
        behavior: HitTestBehavior.opaque,
      ),
    );
  }
}
