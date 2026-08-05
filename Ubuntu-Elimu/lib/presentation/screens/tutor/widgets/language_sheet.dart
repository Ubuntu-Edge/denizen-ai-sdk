import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../models/chat_message.dart';

class LanguageSheet extends StatelessWidget {
  final Language current;
  final ValueChanged<Language> onSelected;

  const LanguageSheet({
    super.key,
    required this.current,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required Language current,
    required ValueChanged<Language> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: UEColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LanguageSheet(current: current, onSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: UEColors.bgBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Response language',
              style: UETypography.h3.copyWith(fontSize: 16),
            ),
            Text(
              'AI will respond in your chosen language this session',
              style: UETypography.bodySm.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...Language.values.map((lang) {
              final isSelected = lang == current;
              return GestureDetector(
                onTap: () {
                  onSelected(lang);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? UEColors.bgElevated : UEColors.bgPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? UEColors.indigo : UEColors.bgBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        lang.fullName,
                        style: UETypography.bodyMd.copyWith(
                          color: isSelected
                              ? UEColors.textPrimary
                              : UEColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? UEColors.indigo.withOpacity(0.15)
                              : UEColors.bgCard,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          lang.label,
                          style: UETypography.label.copyWith(
                            color: isSelected
                                ? UEColors.indigo
                                : UEColors.textMuted,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_rounded,
                            size: 16, color: UEColors.indigo),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}