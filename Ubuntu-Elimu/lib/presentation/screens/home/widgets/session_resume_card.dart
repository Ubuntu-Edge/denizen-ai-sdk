import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../providers/session_provider.dart';
import '../../../../providers/navigation_provider.dart';

class SessionResumeCard extends StatelessWidget {
  const SessionResumeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);

    return GestureDetector(
      onTap: () {
        navProvider.setIndex(1); // Jump to Tutor screen
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UEColors.surface,
          border: Border.all(color: UEColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: UEColors.iconBg,
                border: Border.all(color: UEColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                TablerIcons.message_chatbot,
                color: UEColors.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESUME SESSION',
                    style: UETypography.inter(
                      fontSize: 10,
                      color: UEColors.accent,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sessionProvider.activeSessionTitle,
                    style: UETypography.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: UEColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sessionProvider.activeSessionMeta,
                    style: UETypography.inter(
                      fontSize: 12,
                      color: UEColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              TablerIcons.chevron_right,
              color: UEColors.border,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
