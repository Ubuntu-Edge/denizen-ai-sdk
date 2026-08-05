import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/session_provider.dart';

// Screens
import '../screens/home/home_screen.dart';
import '../screens/tutor/tutor_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/exam_prep/exam_prep_screen.dart';
import '../screens/research/research_screen.dart';
import '../screens/settings/settings_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);
    final sessionProvider = Provider.of<SessionProvider>(context);

    return Scaffold(
      backgroundColor: UEColors.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 70),
                child: Column(
                  children: [
                    _StatusBar(
                      isOffline: sessionProvider.isOffline,
                      onToggleOffline: sessionProvider.toggleOffline,
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: navProvider.selectedIndex,
                        children: const [
                          HomeScreen(),
                          TutorScreen(),
                          LibraryScreen(),
                          ExamPrepScreen(),
                          ResearchScreen(),
                          SettingsScreen(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomNav(
                selectedIndex: navProvider.selectedIndex,
                onTap: (index) => navProvider.setIndex(index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final bool isOffline;
  final VoidCallback onToggleOffline;

  const _StatusBar({
    super.key,
    required this.isOffline,
    required this.onToggleOffline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:41',
            style: UETypography.label.copyWith(
              color: UEColors.textMuted,
              fontSize: 12,
            ),
          ),
          _OfflineBadge(
            isOffline: isOffline,
            onTap: onToggleOffline,
          ),
          const Icon(Icons.battery_3_bar, size: 18, color: UEColors.textMuted),
        ],
      ),
    );
  }
}

class _OfflineBadge extends StatefulWidget {
  final bool isOffline;
  final VoidCallback onTap;

  const _OfflineBadge({
    required this.isOffline,
    required this.onTap,
  });

  @override
  State<_OfflineBadge> createState() => _OfflineBadgeState();
}

class _OfflineBadgeState extends State<_OfflineBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1, end: 0.4).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeBg = widget.isOffline ? UEColors.onlineBg : UEColors.bgElevated;
    final activeBorder =
        widget.isOffline ? UEColors.onlineBorder : UEColors.bgBorder;    final activeColor = widget.isOffline ? UEColors.online : UEColors.indigo;
    final labelText =
        widget.isOffline ? 'Offline · Ready' : 'Online · Syncing';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: activeBg,
          border: Border.all(color: activeBorder, width: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _opacity,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              labelText,
              style: UETypography.label.copyWith(
                color: activeColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final IconData icon;
  final String label;

  const _BottomNavItem({
    required this.icon,
    required this.label,
  });
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const List<_BottomNavItem> _navItems = [
    _BottomNavItem(icon: Icons.home_rounded, label: 'Home'),
    _BottomNavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Tutor'),
    _BottomNavItem(icon: Icons.folder_copy_outlined, label: 'Library'),
    _BottomNavItem(icon: Icons.menu_book_outlined, label: 'Exam'),
    _BottomNavItem(icon: Icons.travel_explore_rounded, label: 'Research'),
    _BottomNavItem(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  const _BottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: UEColors.bgPrimary,
        border: Border(
          top: BorderSide(color: UEColors.bgCard, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final active = i == selectedIndex;
              final item = _navItems[i];

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 22,
                        color: active ? UEColors.indigo : UEColors.textMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: UETypography.label.copyWith(
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? UEColors.indigo : UEColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
