import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import 'widgets/score_breakdown.dart';
import 'widgets/flashcard_view.dart';
import 'widgets/past_paper_form.dart';

class ExamPrepScreen extends StatelessWidget {
  const ExamPrepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScoreBreakdown(),
          const SizedBox(height: 24),
          Text(
            'ACTIVE FLASHCARDS',
            style: UETypography.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: UEColors.textMuted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          const FlashcardView(),
          const SizedBox(height: 28),
          const PastPaperForm(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
