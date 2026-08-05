import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import 'widgets/session_resume_card.dart';
import 'widgets/quick_action_grid.dart';
import 'widgets/recent_uploads_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildGreeting(),
          const SizedBox(height: 24),
          const SessionResumeCard(),
          const SizedBox(height: 24),
          _buildSectionLabel('Quick actions'),
          const SizedBox(height: 12),
          const QuickActionGrid(),
          const SizedBox(height: 28),
          _buildSectionLabel('Recent uploads'),
          const SizedBox(height: 12),
          const RecentUploadsList(),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good morning',
          style: UETypography.inter(fontSize: 13, color: UEColors.textMuted),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: UETypography.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: UEColors.textPrimary,
              height: 1.2,
            ),
            children: const [
              TextSpan(text: 'What are we\nstudying '),
              TextSpan(
                text: 'today?',
                style: TextStyle(color: UEColors.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: UETypography.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: UEColors.textMuted,
        letterSpacing: 1.1,
      ),
    );
  }
}
