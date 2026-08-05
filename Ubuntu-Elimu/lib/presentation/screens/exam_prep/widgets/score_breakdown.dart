import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class ScoreBreakdown extends StatelessWidget {
  const ScoreBreakdown({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UEColors.surface,
        border: Border.all(color: UEColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR WEEKLY PROGRESS',
            style: UETypography.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: UEColors.textMuted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('85%', 'Correct Rate', UEColors.green),
              _buildMetric('148', 'Questions Solved', UEColors.accent),
              _buildMetric('3.5h', 'Practice Time', UEColors.violet),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: UEColors.border, height: 0.5),
          const SizedBox(height: 14),
          Text(
            'Weakest Area: IUPAC stereochemistry nomenclature (55% success rate)',
            style: UETypography.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: UEColors.pdfFg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: UETypography.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: UETypography.inter(
            fontSize: 11,
            color: UEColors.textMuted,
          ),
        ),
      ],
    );
  }
}
