import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../providers/navigation_provider.dart';

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);

    final List<_ActionItem> items = [
      _ActionItem(
        icon: TablerIcons.bolt,
        label: 'Ask Tutor',
        sub: 'Socratic mode on',
        isViolet: false,
        onTap: () => navProvider.setIndex(1),
      ),
      _ActionItem(
        icon: TablerIcons.upload,
        label: 'Upload Doc',
        sub: 'PDF, PPTX, DOCX',
        isViolet: true,
        onTap: () => navProvider.setIndex(2),
      ),
      _ActionItem(
        icon: TablerIcons.school,
        label: 'Practice Exam',
        sub: 'Flashcards · Past papers',
        isViolet: false,
        onTap: () => navProvider.setIndex(3),
      ),
      _ActionItem(
        icon: TablerIcons.world_search,
        label: 'Research',
        sub: 'Build a report',
        isViolet: true,
        onTap: () => navProvider.setIndex(4),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((item) => _ActionButton(item: item)).toList(),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String sub;
  final bool isViolet;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.sub,
    required this.isViolet,
    required this.onTap,
  });
}

class _ActionButton extends StatefulWidget {
  final _ActionItem item;

  const _ActionButton({required this.item});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.item.isViolet ? UEColors.violet : UEColors.accent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.item.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: UEColors.surface,
            border: Border.all(
              color: _isHovered ? accent : UEColors.border,
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.item.icon, color: accent, size: 22),
              const Spacer(),
              Text(
                widget.item.label,
                style: UETypography.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: UEColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.item.sub,
                style: UETypography.inter(
                  fontSize: 11,
                  color: UEColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
