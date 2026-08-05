import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../models/past_paper.dart';

class PastPaperForm extends StatelessWidget {
  const PastPaperForm({super.key});

  @override
  Widget build(BuildContext context) {
    final List<PastPaper> papers = [
      PastPaper(
        id: 'pp_1',
        title: 'National Chemistry Exam — Paper 1',
        subject: 'Chemistry',
        year: 2024,
        questionsCount: 50,
        completedPercentage: 0.8,
      ),
      PastPaper(
        id: 'pp_2',
        title: 'NECTA Biology Past Paper',
        subject: 'Biology',
        year: 2023,
        questionsCount: 45,
        completedPercentage: 0.4,
      ),
      PastPaper(
        id: 'pp_3',
        title: 'Physics Mock Exam — Form 4',
        subject: 'Physics',
        year: 2024,
        questionsCount: 60,
        completedPercentage: 0.0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PAST PAPERS',
              style: UETypography.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: UEColors.textMuted,
                letterSpacing: 1.1,
              ),
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Local server check: all past papers cached offline'),
                    backgroundColor: UEColors.surface,
                  ),
                );
              },
              child: Text(
                'Sync Papers',
                style: UETypography.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: UEColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...papers.map((paper) => _buildPaperCard(context, paper)),
      ],
    );
  }

  Widget _buildPaperCard(BuildContext context, PastPaper paper) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UEColors.surface,
        border: Border.all(color: UEColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${paper.subject} · ${paper.year}',
                style: UETypography.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: UEColors.accent,
                ),
              ),
              Text(
                '${paper.questionsCount} Questions',
                style: UETypography.inter(
                  fontSize: 11,
                  color: UEColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            paper.title,
            style: UETypography.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: UEColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: paper.completedPercentage,
                    backgroundColor: UEColors.iconBg,
                    color: paper.completedPercentage == 1.0 ? UEColors.green : UEColors.accent,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(paper.completedPercentage * 100).toInt()}% Done',
                style: UETypography.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: UEColors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Starting ${paper.title} (offline session)...'),
                      backgroundColor: UEColors.surface,
                    ),
                  );
                },
                child: Icon(
                  TablerIcons.player_play,
                  color: UEColors.green,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
