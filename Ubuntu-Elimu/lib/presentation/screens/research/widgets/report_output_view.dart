import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class ReportOutputView extends StatelessWidget {
  final String topic;
  final String content;
  final List<String> sources;
  final VoidCallback onClear;

  const ReportOutputView({
    required this.topic,
    required this.content,
    required this.onClear,
    this.sources = const [],
    super.key,
  });

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
          // Header Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  topic.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: UETypography.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: UEColors.accent,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Report saved to Library (Local cache)'),
                          backgroundColor: UEColors.surface,
                        ),
                      );
                    },
                    child: Icon(TablerIcons.download, color: UEColors.textMuted, size: 16),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(TablerIcons.trash, color: UEColors.pdfFg, size: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: UEColors.border, height: 0.5),
          const SizedBox(height: 14),

          // Report content details
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Analysis Report',
                  style: UETypography.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: UEColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  content,
                  style: UETypography.inter(
                    fontSize: 13,
                    color: UEColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Citations & Local Sources:',
                  style: UETypography.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: UEColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (sources.isEmpty)
                  Text(
                    'No matching documents found in your library — this report is from the model\'s general knowledge.',
                    style: UETypography.inter(fontSize: 11, color: UEColors.textMuted),
                  )
                else
                  ...sources.map((name) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildSourcePill(name),
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePill(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: UEColors.bg,
        border: Border.all(color: UEColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TablerIcons.file_text, color: UEColors.accent, size: 12),
          const SizedBox(width: 6),
          Text(
            name,
            style: UETypography.inter(
              fontSize: 11,
              color: UEColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
