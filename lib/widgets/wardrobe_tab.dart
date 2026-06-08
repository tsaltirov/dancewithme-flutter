import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/costume_service.dart';
import '../services/event_service.dart';
import '../services/school_service.dart';
import '../utils/app_toast.dart';

// ─── Design tokens (light lavender palette) ───────────────────────────────────
class _W {
  _W._();
  static const bg         = Color(0xFFF5F0FE);
  static const surface    = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEDE8FF);
  static const border     = Color(0xFFD4C8F5);
  static const purple     = Color(0xFF7C3AED);
  static const purpleDim  = Color(0x197C3AED);
  static const green      = Color(0xFF16A34A);
  static const greenDim   = Color(0x1516A34A);
  static const red        = Color(0xFFDC2626);
  static const ink        = Color(0xFF1A1033);
  static const muted      = Color(0xFF4B4069);
  static const hint       = Color(0xFF8B7DAA);
  static const fieldBg    = Color(0xFFF9F7FF);
}

TextStyle _wt(double sz, FontWeight w, Color c, {double? ls}) =>
    GoogleFonts.outfit(fontSize: sz, fontWeight: w, color: c, letterSpacing: ls);

// Card gradient presets (cycling by id)
const _kGradients = [
  [Color(0xFF7C3AED), Color(0xFF4F46E5)],
  [Color(0xFFDB2777), Color(0xFF9333EA)],
  [Color(0xFFD97706), Color(0xFFEA580C)],
  [Color(0xFF0891B2), Color(0xFF7C3AED)],
  [Color(0xFF059669), Color(0xFF0891B2)],
  [Color(0xFFDC2626), Color(0xFF9333EA)],
];

List<Color> _gradientFor(int id) => _kGradients[id % _kGradients.length];

/// Renders the costume image: network photo when imageUrl is set,
/// gradient + icon fallback otherwise.
Widget _costumeImage({
  required Costume costume,
  required double iconSize,
  List<Widget> overlays = const [],
}) {
  final grad    = _gradientFor(costume.id);
  final hasImg  = costume.imageUrl?.isNotEmpty == true;

  return Stack(fit: StackFit.expand, children: [
    if (hasImg)
      Image.network(
        costume.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: grad,
            ),
          ),
        ),
      )
    else
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: costume.active
                ? grad
                : [const Color(0xFF9CA3AF), const Color(0xFF6B7280)],
          ),
        ),
      ),
    // Dim overlay so badges/text are readable on both photos and gradients
    if (hasImg)
      Container(color: Colors.black.withValues(alpha: 0.25)),
    // Icon watermark — only when no photo
    if (!hasImg)
      Center(
        child: Icon(Icons.checkroom_rounded,
            size: iconSize,
            color: Colors.white.withValues(alpha: 0.25)),
      ),
    ...overlays,
  ]);
}

void _openImageViewer(BuildContext context, String imageUrl, String name) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: const Color(0xE8000000),
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
    pageBuilder: (_, __, ___) =>
        _CostumeImageViewer(imageUrl: imageUrl, name: name),
  );
}

// Whether this context is a desktop/web surface (for layout decisions)
bool _isDesktopOrWebEnv() =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

// ─── WardrobeTab ──────────────────────────────────────────────────────────────
class WardrobeTab extends StatefulWidget {
  final School school;
  const WardrobeTab({super.key, required this.school});

  @override
  State<WardrobeTab> createState() => _WardrobeTabState();
}

class _WardrobeTabState extends State<WardrobeTab> {
  List<Costume>           _costumes  = [];
  List<CostumeAssignment> _pending   = [];
  final List<CostumeAssignment> _returned  = [];
  bool    _loading        = true;
  String? _error;
  int     _filter         = 1; // 0=all 1=active 2=inactive
  String  _query          = '';
  final   _searchCtrl     = TextEditingController();

  // How many units of each costume are currently out (ENTREGADO or PENDIENTE_DEVOLUCION)
  Map<int, int> get _assignedCountMap {
    final map = <int, int>{};
    for (final a in _pending) {
      map[a.costumeId] = (map[a.costumeId] ?? 0) + 1;
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    await Future.wait([_loadCostumes(), _loadPending()]);
  }

  Future<void> _loadCostumes() async {
    try {
      // Load active and inactive in parallel so the client-side filter works for all 3 tabs
      final results = await Future.wait([
        CostumeService.getCostumes(schoolId: widget.school.id),               // active (default)
        CostumeService.getCostumes(schoolId: widget.school.id, active: false), // inactive
      ]);
      if (!mounted) return;
      final combined = [...results[0], ...results[1]]
        ..sort((a, b) => a.name.compareTo(b.name));
      setState(() { _costumes = combined; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadPending() async {
    try {
      final list = await CostumeService.getPendingAssignments();
      if (!mounted) return;
      // Filter to assignments belonging to this school's costumes
      final schoolCostumeIds = _costumes.map((c) => c.id).toSet();
      setState(() => _pending = list
          .where((a) => schoolCostumeIds.isEmpty || schoolCostumeIds.contains(a.costumeId))
          .toList());
    } catch (_) {
      // pending section failure is non-critical
    }
  }

  List<Costume> get _filtered {
    var list = _costumes;
    if (_filter == 1) list = list.where((c) =>  c.active).toList();
    if (_filter == 2) list = list.where((c) => !c.active).toList();
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.description.toLowerCase().contains(q),
      ).toList();
    }
    return list;
  }

  int get _totalUnits => _costumes.fold(0, (s, c) => s + c.quantity);

  // ── Assignment handlers ───────────────────────────────────────────────────
  Future<void> _handleAssign(Costume c) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignSheet(costume: c, schoolId: widget.school.id),
    );
    if (ok == true) {
      _load();
      if (mounted) AppToast.success(context, 'wardrobe.assignSuccess'.tr());
    }
  }

  Future<void> _handleReturn(CostumeAssignment a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ReturnConfirmDialog(assignment: a),
    );
    if (!(confirmed ?? false) || !mounted) return;

    try {
      final updated = await CostumeService.returnAssignment(a.id);
      if (!mounted) return;
      setState(() {
        _pending.removeWhere((x) => x.id == a.id);
        _returned.insert(0, updated);
      });
      AppToast.success(context, 'wardrobe.returnSuccess'.tr());
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.toString());
    }
  }

  // ── CRUD handlers ────────────────────────────────────────────────────────────
  Future<void> _handleCreate() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AddEditDialog(schoolId: widget.school.id),
    );
    if (result == true) {
      _load();
      if (mounted) AppToast.success(context, 'wardrobe.createSuccess'.tr());
    }
  }

  Future<void> _handleEdit(Costume c) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AddEditDialog(schoolId: widget.school.id, existing: c),
    );
    if (result == true) {
      _load();
      if (mounted) AppToast.success(context, 'wardrobe.updateSuccess'.tr());
    }
  }

  Future<void> _handleToggleActive(Costume c) async {
    try {
      if (c.active) {
        await CostumeService.deleteCostume(c.id);
      } else {
        await CostumeService.activateCostume(c.id);
      }
      if (!mounted) return;
      _load();
      AppToast.success(context,
        c.active ? 'wardrobe.deactivateSuccess'.tr() : 'wardrobe.activateSuccess'.tr());
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.toString());
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _W.bg,
      child: LayoutBuilder(builder: (ctx, bc) {
        final isMobile = bc.maxWidth < 600;
        final isTablet = bc.maxWidth >= 600 &&
            (bc.maxWidth < 1100 || !_isDesktopOrWebEnv());
        final hPad = isMobile ? 16.0 : (isTablet ? 24.0 : 48.0);
        final vPad = isMobile ? 14.0 : 20.0;

        if (isMobile) return _buildMobile(hPad, vPad);
        return _buildTabletWeb(hPad, vPad, isTablet);
      }),
    );
  }

  // ── Shared content ────────────────────────────────────────────────────────────
  Widget _buildContent({
    required double hPad,
    required double vPad,
    required int    cols,
    required bool   isMobile,
  }) {
    final list = _filtered;
    return RefreshIndicator(
      color: _W.purple,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            hPad, vPad, hPad,
            32 + MediaQuery.of(context).viewPadding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WardrobeToolbar(
              query: _query, ctrl: _searchCtrl, filter: _filter,
              isMobile: isMobile,
              totalItems: _costumes.length,
              totalUnits: _totalUnits,
              onSearch: (v) => setState(() => _query = v),
              onFilter: (f) => setState(() => _filter = f),
            ),
            SizedBox(height: isMobile ? 16 : 24),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator(
                    color: _W.purple, strokeWidth: 2.5)),
              )
            else if (_error != null)
              _ErrorState(message: _error!, onRetry: _load)
            else if (list.isEmpty)
              _EmptyWardrobe(onAdd: _handleCreate)
            else ...[
              // Pending / returned section
              if (_pending.isNotEmpty || _returned.isNotEmpty) ...[
                _PendingSection(
                  pending:  _pending,
                  returned: _returned,
                  onReturn: _handleReturn,
                ),
                const SizedBox(height: 20),
              ],
              // Collection header with inline add button
              // NOTE: no Spacer + no alignment on Container to avoid bounded-constraint expansion
              Row(children: [
                Flexible(
                  child: Text('wardrobe.collectionSection'.tr(),
                      style: _wt(11, FontWeight.w700, _W.ink, ls: 0.8),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _W.purpleDim,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${list.length} ${'wardrobe.prendas'.tr()}',
                      style: _wt(10, FontWeight.w600, _W.purple)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _handleCreate,
                  child: Container(
                    // padding-based height — no alignment to prevent full-width expansion
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _W.purple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('wardrobe.addBtn'.tr(),
                          style: _wt(12, FontWeight.w600, Colors.white)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _CostumeGrid(
                items:            list,
                cols:             cols,
                assignedCountMap: _assignedCountMap,
                onAssign:         _handleAssign,
                onEdit:           _handleEdit,
                onToggle:         _handleToggleActive,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Mobile ───────────────────────────────────────────────────────────────────
  Widget _buildMobile(double hPad, double vPad) =>
      _buildContent(hPad: hPad, vPad: vPad, cols: 1, isMobile: true);

  // ── Tablet / Web ──────────────────────────────────────────────────────────────
  Widget _buildTabletWeb(double hPad, double vPad, bool isTablet) =>
      _buildContent(
          hPad: hPad, vPad: vPad,
          cols: isTablet ? 2 : 3,
          isMobile: false);
}

// ─── Toolbar ──────────────────────────────────────────────────────────────────
class _WardrobeToolbar extends StatelessWidget {
  final String  query;
  final TextEditingController ctrl;
  final int     filter;
  final bool    isMobile;
  final int     totalItems;
  final int     totalUnits;
  final void Function(String)  onSearch;
  final void Function(int)     onFilter;

  const _WardrobeToolbar({
    required this.query, required this.ctrl, required this.filter,
    required this.isMobile, required this.totalItems, required this.totalUnits,
    required this.onSearch, required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final stats = Row(mainAxisSize: MainAxisSize.min, children: [
      _StatPill(
        value: '$totalItems',
        label: 'wardrobe.prendas'.tr(),
        valueColor: _W.purple,
      ),
      const SizedBox(width: 8),
      _StatPill(
        value: '$totalUnits',
        label: 'wardrobe.units'.tr(),
        valueColor: _W.green,
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search field
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: _W.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _W.border),
            boxShadow: const [
              BoxShadow(color: Color(0x0A7C3AED), offset: Offset(0, 2), blurRadius: 8),
            ],
          ),
          child: TextField(
            controller: ctrl,
            onChanged: onSearch,
            style: _wt(14, FontWeight.normal, _W.ink),
            decoration: InputDecoration(
              hintText: 'wardrobe.searchHint'.tr(),
              hintStyle: _wt(14, FontWeight.normal, _W.hint),
              prefixIcon: const Icon(Icons.search_rounded, color: _W.hint, size: 20),
              suffixIcon: query.isNotEmpty
                  ? GestureDetector(
                      onTap: () => onSearch(''),
                      child: const Icon(Icons.close_rounded, color: _W.hint, size: 18),
                    )
                  : null,
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (isMobile) ...[
          Row(children: [
            _FilterPill(label: 'wardrobe.filterAll'.tr(),      index: 0, selected: filter, onTap: onFilter),
            const SizedBox(width: 8),
            _FilterPill(label: 'wardrobe.filterActive'.tr(),   index: 1, selected: filter, onTap: onFilter),
            const SizedBox(width: 8),
            _FilterPill(label: 'wardrobe.filterInactive'.tr(), index: 2, selected: filter, onTap: onFilter),
          ]),
          const SizedBox(height: 10),
          stats,
        ] else
          Row(children: [
            _FilterPill(label: 'wardrobe.filterAll'.tr(),      index: 0, selected: filter, onTap: onFilter),
            const SizedBox(width: 8),
            _FilterPill(label: 'wardrobe.filterActive'.tr(),   index: 1, selected: filter, onTap: onFilter),
            const SizedBox(width: 8),
            _FilterPill(label: 'wardrobe.filterInactive'.tr(), index: 2, selected: filter, onTap: onFilter),
            const Spacer(),
            stats,
          ]),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final int    index;
  final int    selected;
  final void Function(int) onTap;

  const _FilterPill({required this.label, required this.index,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = selected == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:  active ? _W.purple : _W.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? _W.purple : _W.border),
          boxShadow: active ? null : const [
            BoxShadow(color: Color(0x087C3AED), offset: Offset(0, 1), blurRadius: 4),
          ],
        ),
        child: Text(label,
            style: _wt(12, FontWeight.w600, active ? Colors.white : _W.muted)),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color  valueColor;

  const _StatPill({required this.value, required this.label, required this.valueColor});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: _wt(16, FontWeight.w800, valueColor)),
        const SizedBox(width: 4),
        Text(label, style: _wt(11, FontWeight.w500, _W.hint)),
      ]);
}

// ─── Costume grid ─────────────────────────────────────────────────────────────
class _CostumeGrid extends StatelessWidget {
  final List<Costume>          items;
  final int                    cols;
  final Map<int, int>          assignedCountMap;
  final void Function(Costume) onAssign;
  final void Function(Costume) onEdit;
  final void Function(Costume) onToggle;

  const _CostumeGrid({
    required this.items, required this.cols,
    required this.assignedCountMap,
    required this.onAssign, required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, bc) {
      const spacing = 14.0;
      final cardW = (bc.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing, runSpacing: spacing,
        children: items.map((c) => SizedBox(
          width: cardW,
          child: _CostumeGridCard(
            costume:       c,
            assignedCount: assignedCountMap[c.id] ?? 0,
            onAssign:      () => onAssign(c),
            onEdit:        () => onEdit(c),
            onToggle:      () => onToggle(c),
          ),
        )).toList(),
      );
    });
  }
}

class _CostumeGridCard extends StatelessWidget {
  final Costume      costume;
  final int          assignedCount;
  final VoidCallback onAssign;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _CostumeGridCard({
    required this.costume, required this.assignedCount,
    required this.onAssign, required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final grad     = _gradientFor(costume.id);
    final isActive = costume.active;

    return Container(
      decoration: BoxDecoration(
        color: _W.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _W.border),
        boxShadow: [
          BoxShadow(
            color: grad[0].withValues(alpha: isActive ? 0.12 : 0.04),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Image header (clip only here for rounded top corners) ───────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13)),
            child: GestureDetector(
              onTap: costume.imageUrl?.isNotEmpty == true
                  ? () => _openImageViewer(context, costume.imageUrl!, costume.name)
                  : null,
              child: SizedBox(
                height: 140,
                child: _costumeImage(
                costume: costume,
                iconSize: 44,
                overlays: [
                  Positioned(
                    top: 8, left: 8,
                    child: _StatusBadge(active: isActive, small: true),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: _QtyBadge(
                      assigned: assignedCount,
                      total:    costume.quantity,
                    ),
                  ),
                  if (!isActive)
                    Container(color: Colors.white.withValues(alpha: 0.35)),
                  // Zoom hint when image is available
                  if (costume.imageUrl?.isNotEmpty == true)
                    Positioned(
                      bottom: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.zoom_in_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),          // closes _costumeImage
            ),            // closes SizedBox
          ),              // closes GestureDetector
        ),              // closes ClipRRect
          // ── Body ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(costume.name,
                    style: _wt(14, FontWeight.w700,
                        isActive ? _W.ink : _W.hint),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(costume.description,
                    style: _wt(11, FontWeight.normal, _W.hint),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),

                // ── PRIMARY: Asignar ───────────────────────────────────
                Tooltip(
                  message: isActive ? '' : 'wardrobe.inactiveTooltip'.tr(),
                  child: GestureDetector(
                    onTap: isActive ? onAssign : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                              )
                            : null,
                        color: isActive ? null : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isActive
                            ? const [BoxShadow(
                                color: Color(0x337C3AED),
                                offset: Offset(0, 3), blurRadius: 10)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.assignment_outlined, size: 15,
                            color: isActive ? Colors.white : _W.hint),
                        const SizedBox(width: 6),
                        Text('wardrobe.assignBtn'.tr(),
                            style: _wt(13, FontWeight.w600,
                                isActive ? Colors.white : _W.hint)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── SECONDARY: Desactivar/Activar + Edit ───────────────
                Row(children: [
                  // Desactivar / Activar — padding-based sizing, no alignment (avoids
                  // Container expanding to Row's full bounded width)
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? _W.greenDim : _W.purpleDim,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? _W.green.withValues(alpha: 0.3)
                              : _W.purple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          isActive ? Icons.block_outlined : Icons.check_circle_outline_rounded,
                          size: 12,
                          color: isActive ? _W.green : _W.purple,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isActive
                              ? 'wardrobe.deactivateBtn'.tr()
                              : 'wardrobe.activateBtn'.tr(),
                          style: _wt(10, FontWeight.w600,
                              isActive ? _W.green : _W.purple),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Edit (expanded — takes remaining space)
                  Expanded(
                    child: GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: _W.purpleDim,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _W.purple.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.edit_outlined, size: 12, color: _W.purple),
                          const SizedBox(width: 4),
                          Text('wardrobe.editBtn'.tr(),
                              style: _wt(11, FontWeight.w600, _W.purple)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pending / returned section with tabs ─────────────────────────────────────
class _PendingSection extends StatefulWidget {
  final List<CostumeAssignment>          pending;
  final List<CostumeAssignment>          returned;
  final void Function(CostumeAssignment) onReturn;

  const _PendingSection({
    required this.pending, required this.returned,
    required this.onReturn,
  });

  @override
  State<_PendingSection> createState() => _PendingSectionState();
}

class _PendingSectionState extends State<_PendingSection> {
  int _tab = 0; // 0 = entregados, 1 = devueltos

  @override
  Widget build(BuildContext context) {
    final items = _tab == 0 ? widget.pending : widget.returned;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
                color: Color(0xFFF59E0B), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('wardrobe.assignmentsSection'.tr(),
              style: _wt(11, FontWeight.w700, _W.ink, ls: 0.8)),
        ]),
        const SizedBox(height: 10),
        // Tab pills
        Row(children: [
          _TabPill(
            label: 'wardrobe.tabEntregados'.tr(),
            count: widget.pending.length,
            selected: _tab == 0,
            activeColor: const Color(0xFF3B82F6),
            activeBg: const Color(0xFFEFF6FF),
            onTap: () => setState(() => _tab = 0),
          ),
          const SizedBox(width: 8),
          _TabPill(
            label: 'wardrobe.tabDevueltos'.tr(),
            count: widget.returned.length,
            selected: _tab == 1,
            activeColor: _W.green,
            activeBg: _W.greenDim,
            onTap: () => setState(() => _tab = 1),
          ),
        ]),
        const SizedBox(height: 10),
        // Content
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                _tab == 0
                    ? 'wardrobe.noPending'.tr()
                    : 'wardrobe.noReturned'.tr(),
                style: _wt(13, FontWeight.normal, _W.hint),
              ),
            ),
          )
        else
          ...items.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PendingCard(
              assignment: a,
              onReturn: _tab == 0 ? () => widget.onReturn(a) : null,
            ),
          )),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  final String     label;
  final int        count;
  final bool       selected;
  final Color      activeColor;
  final Color      activeBg;
  final VoidCallback onTap;

  const _TabPill({
    required this.label, required this.count, required this.selected,
    required this.activeColor, required this.activeBg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? activeBg : _W.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? activeColor.withValues(alpha: 0.5) : _W.border,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: _wt(11, FontWeight.w600,
                selected ? activeColor : _W.muted)),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: selected ? activeColor : _W.border,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: _wt(9, FontWeight.w700,
                    selected ? Colors.white : _W.muted)),
          ),
        ],
      ]),
    ),
  );
}

class _PendingCard extends StatelessWidget {
  final CostumeAssignment assignment;
  final VoidCallback?     onReturn; // null → devueltos tab, no button

  const _PendingCard({
    required this.assignment, this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final isReturned = assignment.isReturned;
    final isPending  = assignment.isPendingReturn;

    final Color stripColor;
    final Color statusColor;
    final Color statusBg;
    final String statusLabel;

    if (isReturned) {
      stripColor  = _W.green;
      statusColor = _W.green;
      statusBg    = _W.greenDim;
      statusLabel = 'wardrobe.statusDevuelto'.tr();
    } else if (isPending) {
      stripColor  = const Color(0xFFF59E0B);
      statusColor = const Color(0xFFD97706);
      statusBg    = const Color(0xFFFEF3C7);
      statusLabel = 'wardrobe.statusPendiente'.tr();
    } else {
      stripColor  = const Color(0xFF3B82F6);
      statusColor = const Color(0xFF2563EB);
      statusBg    = const Color(0xFFEFF6FF);
      statusLabel = 'wardrobe.statusEntregado'.tr();
    }

    final dateLabel = isReturned
        ? assignment.returnDate   ?? ''
        : assignment.deliveryDate;
    final dateIcon = isReturned
        ? Icons.assignment_turned_in_outlined
        : Icons.local_shipping_outlined;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: _W.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _W.border),
        boxShadow: const [
          BoxShadow(color: Color(0x077C3AED), offset: Offset(0, 2), blurRadius: 8),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Status strip — stretches to match content height
        Container(
          width: 4,
          decoration: BoxDecoration(
              color: stripColor, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(assignment.costumeName,
                  style: _wt(13, FontWeight.w700, _W.ink),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.person_outline_rounded,
                    size: 11, color: _W.hint),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(assignment.studentName,
                      style: _wt(11, FontWeight.normal, _W.muted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Icon(dateIcon, size: 11, color: _W.hint),
                const SizedBox(width: 3),
                Text(dateLabel,
                    style: _wt(10, FontWeight.w600, _W.muted)),
              ]),
              if (assignment.observations?.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.notes_outlined, size: 11, color: _W.hint),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(assignment.observations!,
                        style: _wt(10, FontWeight.normal, _W.muted),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusBg, borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusLabel,
                  style: _wt(9, FontWeight.w700, statusColor)),
            ),
            if (onReturn != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onReturn,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _W.greenDim,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _W.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.assignment_return_outlined,
                        size: 12, color: _W.green),
                    const SizedBox(width: 4),
                    Text('wardrobe.returnBtn'.tr(),
                        style: _wt(10, FontWeight.w600, _W.green)),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ]),
      ),
    );
  }
}

// ─── Assign costume bottom sheet ──────────────────────────────────────────────
class _AssignSheet extends StatefulWidget {
  final Costume costume;
  final int     schoolId;
  const _AssignSheet({required this.costume, required this.schoolId});

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  // Step 1
  List<Event>? _events;
  Event?       _selectedEvent;
  bool         _loadingEvents = true;

  // Step 2
  List<EventParticipation>? _participations;
  EventParticipation?       _selectedPart;
  bool                      _loadingParts = false;

  // Step 3
  final _obsCtrl = TextEditingController();
  bool   _assigning = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final list = await EventService.getBySchool(widget.schoolId);
      if (!mounted) return;
      setState(() {
        _events = list.where((e) => e.active).toList();
        _loadingEvents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingEvents = false);
    }
  }

  Future<void> _selectEvent(Event ev) async {
    setState(() {
      _selectedEvent  = ev;
      _participations = null;
      _selectedPart   = null;
      _loadingParts   = true;
    });
    try {
      final list = await EventService.getParticipations(ev.id);
      if (!mounted) return;
      setState(() { _participations = list; _loadingParts = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingParts = false);
    }
  }

  Future<void> _confirm() async {
    if (_selectedPart == null) return;
    setState(() => _assigning = true);
    try {
      await CostumeService.assignCostume(
        participationId: _selectedPart!.id,
        costumeId:       widget.costume.id,
        observations:    _obsCtrl.text.trim().isEmpty
            ? null : _obsCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _assigning = false);
      AppToast.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: _W.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: _gradientFor(widget.costume.id),
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.checkroom_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('wardrobe.assignTitle'.tr(),
                        style: _wt(16, FontWeight.w700, _W.ink)),
                    Text(widget.costume.name,
                        style: _wt(12, FontWeight.normal, _W.hint),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _W.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: _W.muted),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // Scrollable content
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, mq.viewInsets.bottom + 24),
              children: [
                // ── Step 1: Select event ─────────────────────────────
                _SheetLabel(
                  icon: Icons.event_outlined,
                  label: 'wardrobe.selectEvent'.tr(),
                ),
                const SizedBox(height: 8),
                if (_loadingEvents)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                        color: _W.purple, strokeWidth: 2.5),
                  ))
                else if (_events == null || _events!.isEmpty)
                  _SheetEmpty(label: 'wardrobe.noEvents'.tr())
                else
                  ..._events!.map((ev) {
                    final sel = ev.id == _selectedEvent?.id;
                    return GestureDetector(
                      onTap: () => _selectEvent(ev),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: sel ? _W.purpleDim : _W.fieldBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel ? _W.purple : _W.border,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.event_outlined, size: 16,
                              color: sel ? _W.purple : _W.hint),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ev.title,
                                    style: _wt(13, FontWeight.w600,
                                        sel ? _W.purple : _W.ink),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(ev.venue,
                                    style: _wt(11, FontWeight.normal, _W.hint),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (sel)
                            const Icon(Icons.check_circle_rounded,
                                size: 16, color: _W.purple),
                        ]),
                      ),
                    );
                  }),

                // ── Step 2: Select participant ───────────────────────
                if (_selectedEvent != null) ...[
                  const SizedBox(height: 16),
                  _SheetLabel(
                    icon: Icons.person_outline_rounded,
                    label: 'wardrobe.selectParticipant'.tr(),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingParts)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          color: _W.purple, strokeWidth: 2.5),
                    ))
                  else if (_participations == null || _participations!.isEmpty)
                    _SheetEmpty(label: 'wardrobe.noParticipants'.tr())
                  else
                    ..._participations!.map((p) {
                      final sel      = p.id == _selectedPart?.id;
                      final hasCostume = p.costumeAssignmentId != null;
                      return GestureDetector(
                        onTap: hasCostume ? null : () =>
                            setState(() => _selectedPart = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: hasCostume
                                ? const Color(0xFFF9FAFB)
                                : sel ? _W.purpleDim : _W.fieldBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel ? _W.purple : _W.border,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  sel ? _W.purple : _W.surfaceAlt,
                              child: Text(
                                p.studentName.isNotEmpty
                                    ? p.studentName[0].toUpperCase() : '?',
                                style: _wt(12, FontWeight.w700,
                                    sel ? Colors.white : _W.muted),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(p.studentName,
                                  style: _wt(13, FontWeight.w600,
                                      hasCostume ? _W.hint : _W.ink),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            if (hasCostume)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('wardrobe.alreadyAssigned'.tr(),
                                    style: _wt(9, FontWeight.w600, _W.hint)),
                              )
                            else if (sel)
                              const Icon(Icons.check_circle_rounded,
                                  size: 16, color: _W.purple),
                          ]),
                        ),
                      );
                    }),
                ],

                // ── Step 3: Observations ─────────────────────────────
                if (_selectedPart != null) ...[
                  const SizedBox(height: 16),
                  _SheetLabel(
                    icon: Icons.notes_outlined,
                    label: 'wardrobe.observationsField'.tr(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _obsCtrl,
                    maxLines: 2,
                    style: _wt(13, FontWeight.normal, _W.ink),
                    decoration: InputDecoration(
                      hintText: 'wardrobe.observationsHint'.tr(),
                      hintStyle: _wt(13, FontWeight.normal, _W.hint),
                      filled: true,
                      fillColor: _W.fieldBg,
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _W.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _W.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: _W.purple, width: 1.5),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
          // Footer — confirm button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: GestureDetector(
                onTap: (_selectedPart == null || _assigning) ? null : _confirm,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: (_selectedPart != null && !_assigning)
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                          )
                        : null,
                    color: (_selectedPart == null || _assigning)
                        ? const Color(0xFFE5E7EB)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: (_selectedPart != null && !_assigning)
                        ? const [BoxShadow(
                            color: Color(0x337C3AED),
                            offset: Offset(0, 3), blurRadius: 10)]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: _assigning
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.assignment_turned_in_outlined,
                              size: 17,
                              color: _selectedPart != null
                                  ? Colors.white : _W.hint),
                          const SizedBox(width: 8),
                          Text('wardrobe.confirmAssign'.tr(),
                              style: _wt(14, FontWeight.w600,
                                  _selectedPart != null
                                      ? Colors.white : _W.hint)),
                        ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Sheet helper widgets ─────────────────────────────────────────────────────
class _SheetLabel extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _SheetLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: _W.purple),
    const SizedBox(width: 6),
    Text(label, style: _wt(12, FontWeight.w700, _W.ink, ls: 0.3)),
  ]);
}

class _SheetEmpty extends StatelessWidget {
  final String label;
  const _SheetEmpty({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    alignment: Alignment.center,
    child: Text(label, style: _wt(13, FontWeight.normal, _W.hint)),
  );
}

// ─── Quantity badge: "available / total" ─────────────────────────────────────
class _QtyBadge extends StatelessWidget {
  final int assigned;
  final int total;
  const _QtyBadge({required this.assigned, required this.total});

  @override
  Widget build(BuildContext context) {
    final available = (total - assigned).clamp(0, total);
    final isFull    = available == 0 && total > 0;
    final isPartial = available > 0 && assigned > 0;
    final badgeBg   = isFull
        ? const Color(0xCCEF4444)    // red — none available
        : isPartial
            ? const Color(0xCCF59E0B) // amber — some available
            : Colors.black.withValues(alpha: 0.35); // neutral — all available

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.layers_rounded, size: 10, color: Colors.white),
        const SizedBox(width: 3),
        Text(
          '$available/$total',
          style: _wt(11, FontWeight.w700, Colors.white),
        ),
      ]),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyWardrobe extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyWardrobe({required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: _W.purpleDim, shape: BoxShape.circle),
        child: const Icon(Icons.checkroom_outlined, color: _W.purple, size: 38),
      ),
      const SizedBox(height: 16),
      Text('wardrobe.empty'.tr(),
          style: _wt(17, FontWeight.w700, _W.ink)),
      const SizedBox(height: 6),
      Text('wardrobe.emptyDesc'.tr(),
          style: _wt(13, FontWeight.normal, _W.hint),
          textAlign: TextAlign.center),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: onAdd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _W.purple,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('wardrobe.addBtn'.tr(),
              style: _wt(13, FontWeight.w600, Colors.white)),
        ),
      ),
    ]),
  );
}

// ─── Error state ──────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(children: [
      Container(
        width: 72, height: 72,
        decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
        child: const Icon(Icons.wifi_off_rounded, color: _W.red, size: 32),
      ),
      const SizedBox(height: 14),
      Text('wardrobe.loadError'.tr(),
          style: _wt(16, FontWeight.w600, _W.ink),
          textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text(message, style: _wt(12, FontWeight.normal, _W.hint),
          textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: onRetry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _W.purple, borderRadius: BorderRadius.circular(20),
          ),
          child: Text('form.retry'.tr(),
              style: _wt(13, FontWeight.w600, Colors.white)),
        ),
      ),
    ]),
  );
}

// ─── Reusable small widgets ───────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool active;
  final bool small;
  const _StatusBadge({required this.active, this.small = false});

  @override
  Widget build(BuildContext context) {
    final bg  = active ? _W.greenDim : const Color(0xFFE5E7EB);
    final clr = active ? _W.green    : const Color(0xFF6B7280);
    final lbl = active ? 'wardrobe.filterActive'.tr() : 'wardrobe.filterInactive'.tr();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 7 : 10, vertical: small ? 3 : 4),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: clr.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: small ? 5 : 6, height: small ? 5 : 6,
          decoration: BoxDecoration(color: clr, shape: BoxShape.circle),
        ),
        SizedBox(width: small ? 4 : 5),
        Text(lbl, style: _wt(small ? 9 : 10, FontWeight.w700, clr)),
      ]),
    );
  }
}


// ─── Return confirmation dialog ───────────────────────────────────────────────
class _ReturnConfirmDialog extends StatelessWidget {
  final CostumeAssignment assignment;
  const _ReturnConfirmDialog({required this.assignment});

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    backgroundColor: Colors.white,
    contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
    actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: _W.greenDim, shape: BoxShape.circle,
          border: Border.all(color: _W.green.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.assignment_return_outlined,
            color: _W.green, size: 26),
      ),
      const SizedBox(height: 14),
      Text('wardrobe.returnConfirmTitle'.tr(),
          style: _wt(17, FontWeight.w700, _W.ink),
          textAlign: TextAlign.center),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _W.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _W.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.checkroom_outlined, size: 13, color: _W.purple),
            const SizedBox(width: 6),
            Expanded(child: Text(assignment.costumeName,
                style: _wt(13, FontWeight.w600, _W.ink),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.person_outline_rounded, size: 13, color: _W.hint),
            const SizedBox(width: 6),
            Expanded(child: Text(assignment.studentName,
                style: _wt(12, FontWeight.normal, _W.muted),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.event_outlined, size: 13, color: _W.hint),
            const SizedBox(width: 6),
            Expanded(child: Text(assignment.eventTitle,
                style: _wt(12, FontWeight.normal, _W.muted),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          if (assignment.observations?.isNotEmpty == true) ...[
            const SizedBox(height: 5),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.notes_outlined, size: 13, color: _W.hint),
              const SizedBox(width: 6),
              Expanded(child: Text(assignment.observations!,
                  style: _wt(12, FontWeight.normal, _W.muted),
                  maxLines: 3, overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Text('wardrobe.returnConfirmDesc'.tr(),
          style: _wt(12, FontWeight.normal, _W.muted),
          textAlign: TextAlign.center),
      const SizedBox(height: 4),
    ]),
    actions: [
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _W.border),
              ),
              alignment: Alignment.center,
              child: Text('form.cancel'.tr(),
                  style: _wt(14, FontWeight.w600, _W.muted)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: _W.green,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text('wardrobe.returnConfirmBtn'.tr(),
                    style: _wt(14, FontWeight.w600, Colors.white)),
              ]),
            ),
          ),
        ),
      ]),
    ],
  );
}

// ─── Image source picker sheet ────────────────────────────────────────────────
class _ImageSourceSheet extends StatelessWidget {
  final void Function(ImageSource) onPick;
  const _ImageSourceSheet({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewPadding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 6),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: _W.border, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('wardrobe.imgSourceTitle'.tr(),
              style: _wt(14, FontWeight.w700, _W.ink)),
        ),
        const SizedBox(height: 12),
        _SourceOption(
          icon: Icons.camera_alt_rounded,
          label: 'wardrobe.imgSourceCamera'.tr(),
          color: _W.purple,
          bg: _W.purpleDim,
          onTap: () {
            Navigator.pop(context);
            onPick(ImageSource.camera);
          },
        ),
        const SizedBox(height: 8),
        _SourceOption(
          icon: Icons.photo_library_outlined,
          label: 'wardrobe.imgSourceGallery'.tr(),
          color: _W.muted,
          bg: _W.surfaceAlt,
          onTap: () {
            Navigator.pop(context);
            onPick(ImageSource.gallery);
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _W.border),
              ),
              alignment: Alignment.center,
              child: Text('form.cancel'.tr(),
                  style: _wt(14, FontWeight.w600, _W.muted)),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final Color        bg;
  final VoidCallback onTap;
  const _SourceOption({required this.icon, required this.label,
      required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Text(label, style: _wt(14, FontWeight.w600, color)),
        ]),
      ),
    ),
  );
}

// ─── Add / Edit dialog ────────────────────────────────────────────────────────
class _AddEditDialog extends StatefulWidget {
  final int      schoolId;
  final Costume? existing;

  const _AddEditDialog({required this.schoolId, this.existing});

  @override
  State<_AddEditDialog> createState() => _AddEditDialogState();
}

class _AddEditDialogState extends State<_AddEditDialog> {
  final _nameCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _imgCtrl   = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _qtyCtrl    = TextEditingController(text: '1');
  bool      _active     = true;
  bool      _saving     = false;
  String?   _err;
  Uint8List? _imageBytes;
  String    _imageExt   = 'jpg';
  bool      _pickingImg = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final c = widget.existing!;
      _nameCtrl.text  = c.name;
      _descCtrl.text  = c.description;
      _imgCtrl.text   = c.imageUrl ?? '';
      _notesCtrl.text = c.notes   ?? '';
      _qtyCtrl.text   = '${c.quantity}';
      _active         = c.active;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose();
    _imgCtrl.dispose();  _notesCtrl.dispose(); _qtyCtrl.dispose();
    super.dispose();
  }

  // On web there is no camera — skip the sheet and go straight to gallery.
  Future<void> _showImageSourceSheet() async {
    if (_pickingImg) return;
    if (kIsWeb) {
      await _pickImageFrom(ImageSource.gallery);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(onPick: _pickImageFrom),
    );
  }

  Future<void> _pickImageFrom(ImageSource source) async {
    setState(() => _pickingImg = true);
    try {
      final file = await ImagePicker()
          .pickImage(source: source, imageQuality: 85);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final ext   = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';
      setState(() {
        _imageBytes = bytes;
        _imageExt   = ext.isNotEmpty ? ext : 'jpg';
        _imgCtrl.clear();
      });
    } finally {
      if (mounted) setState(() => _pickingImg = false);
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final qty  = int.tryParse(_qtyCtrl.text.trim());

    if (name.isEmpty) {
      setState(() => _err = 'form.required'.tr()); return;
    }
    if (qty == null || qty < 0) {
      setState(() => _err = 'wardrobe.invalidQty'.tr()); return;
    }

    setState(() { _saving = true; _err = null; });
    try {
      // Upload image if picked, otherwise use manual URL if provided
      String? imageUrl;
      if (_imageBytes != null) {
        imageUrl = await CostumeService.uploadImage(_imageBytes!, _imageExt);
      } else if (_imgCtrl.text.trim().isNotEmpty) {
        imageUrl = _imgCtrl.text.trim();
      }

      if (_isEdit) {
        await CostumeService.updateCostume(
          id: widget.existing!.id, schoolId: widget.schoolId,
          name: name, description: desc,
          imageUrl: imageUrl,
          notes:    _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          quantity: qty, active: _active,
        );
      } else {
        await CostumeService.createCostume(
          schoolId: widget.schoolId, name: name, description: desc,
          imageUrl: imageUrl,
          notes:    _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          quantity: qty,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _err = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isMobile = w < 600;

    final mq         = MediaQuery.of(context);
    final keyboard   = mq.viewInsets.bottom;
    final sysBars    = mq.viewPadding.top + mq.viewPadding.bottom;
    // Exact height the dialog can occupy: screen minus system bars, keyboard, and margins
    final dialogMaxH = (mq.size.height - sysBars - keyboard - 48.0)
        .clamp(300.0, 700.0);

    return Dialog(
      insetPadding: isMobile
          ? const EdgeInsets.fromLTRB(12, 24, 12, 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: dialogMaxH),
        child: Column(
          mainAxisSize: MainAxisSize.max, // fills maxHeight → Expanded works correctly
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.checkroom_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEdit
                        ? 'wardrobe.editTitle'.tr()
                        : 'wardrobe.addTitle'.tr(),
                    style: _wt(17, FontWeight.w700, _W.ink),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: _W.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.close_rounded, size: 16, color: _W.muted),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            // Form — Expanded fills the remaining Column space exactly
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Field(ctrl: _nameCtrl, label: 'wardrobe.nameField'.tr(),     required: true),
                    const SizedBox(height: 12),
                    _Field(ctrl: _descCtrl, label: 'wardrobe.descField'.tr(),     maxLines: 3),
                    const SizedBox(height: 12),
                    _Field(ctrl: _qtyCtrl,  label: 'wardrobe.quantityField'.tr(), keyboard: TextInputType.number),
                    const SizedBox(height: 12),
                    // Image picker
                    Text('wardrobe.imageField'.tr(),
                        style: _wt(12, FontWeight.w600, _W.muted)),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: _showImageSourceSheet,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: _W.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _W.border, width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _pickingImg
                            ? const Center(
                                child: SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color: _W.purple, strokeWidth: 2.5),
                                ),
                              )
                            : _imageBytes != null
                                ? Stack(fit: StackFit.expand, children: [
                                    Image.memory(_imageBytes!, fit: BoxFit.cover),
                                    Positioned(
                                      bottom: 6, right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('school.changeImage'.tr(),
                                            style: _wt(10, FontWeight.w600,
                                                Colors.white)),
                                      ),
                                    ),
                                  ])
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined,
                                          size: 28, color: _W.purple),
                                      const SizedBox(height: 6),
                                      Text('school.addImage'.tr(),
                                          style: _wt(12, FontWeight.w600,
                                              _W.purple)),
                                    ],
                                  ),
                      ),
                    ),
                    // Fallback: manual URL (only shown when no image picked)
                    if (_imageBytes == null) ...[
                      const SizedBox(height: 8),
                      _Field(ctrl: _imgCtrl,
                          label: 'wardrobe.imageUrlFallback'.tr()),
                    ],
                    const SizedBox(height: 12),
                    _Field(ctrl: _notesCtrl, label: 'wardrobe.notesField'.tr(), maxLines: 2),
                    if (_isEdit) ...[
                      const SizedBox(height: 14),
                      Row(children: [
                        Switch(
                          value: _active,
                          activeThumbColor: _W.purple,
                          activeTrackColor: _W.purpleDim,
                          onChanged: (v) => setState(() => _active = v),
                        ),
                        const SizedBox(width: 8),
                        Text('wardrobe.activeLabel'.tr(),
                            style: _wt(14, FontWeight.w600, _W.ink)),
                      ]),
                    ],
                    if (_err != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _W.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(_err!,
                            style: _wt(12, FontWeight.w500, _W.red)),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _W.border),
                      ),
                      alignment: Alignment.center,
                      child: Text('form.cancel'.tr(),
                          style: _wt(14, FontWeight.w600, _W.muted)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _saving ? null : _submit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _saving ? null : const LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                        ),
                        color: _saving ? const Color(0xFFD4C8F5) : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _saving ? null : const [
                          BoxShadow(color: Color(0x337C3AED),
                              offset: Offset(0, 3), blurRadius: 8),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text('form.save'.tr(),
                              style: _wt(14, FontWeight.w600, Colors.white)),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String            label;
  final bool              required;
  final int               maxLines;
  final TextInputType     keyboard;

  const _Field({
    required this.ctrl, required this.label,
    this.required = false, this.maxLines = 1,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(children: [
        Text(label, style: _wt(12, FontWeight.w600, _W.muted)),
        if (required) ...[
          const SizedBox(width: 3),
          Text('*', style: _wt(12, FontWeight.w700, _W.red)),
        ],
      ]),
      const SizedBox(height: 5),
      TextField(
        controller:   ctrl,
        maxLines:     maxLines,
        keyboardType: keyboard,
        style:        _wt(14, FontWeight.normal, _W.ink),
        decoration: InputDecoration(
          isDense:        true,
          filled:         true,
          fillColor:      _W.fieldBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border:         OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   BorderSide(color: _W.border)),
          enabledBorder:  OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   BorderSide(color: _W.border)),
          focusedBorder:  OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   const BorderSide(color: _W.purple, width: 1.5)),
        ),
      ),
    ],
  );
}

// ─── Full-screen image viewer ─────────────────────────────────────────────────
class _CostumeImageViewer extends StatelessWidget {
  final String imageUrl;
  final String name;

  const _CostumeImageViewer({required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            // Tap anywhere outside to close
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            // Pinch-zoomable image
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 80),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(
                              width: 200, height: 200,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white)),
                            ),
                      errorBuilder: (_, __, ___) => Container(
                        width: 200, height: 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.broken_image_rounded,
                            color: Colors.white38, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Costume name — bottom pill
            Positioned(
              left: 24, right: 24, bottom: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20)),
                  ),
                  child: Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            // Close button — top right
            Positioned(
              top: 12, right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

