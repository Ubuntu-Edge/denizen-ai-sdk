import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../providers/document_provider.dart';
import '../../../../providers/navigation_provider.dart';
import '../../../../providers/session_provider.dart';
import '../../../../models/document.dart';

class RecentUploadsList extends StatelessWidget {
  const RecentUploadsList({super.key});

  @override
  Widget build(BuildContext context) {
    final docProvider = Provider.of<DocumentProvider>(context);
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);

    final recents = docProvider.recentUploads;

    if (recents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No documents uploaded yet',
            style: UETypography.inter(fontSize: 12, color: UEColors.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: recents.map((doc) {
        final iconBg = FileUtils.getIconBg(doc.type);
        final iconFg = FileUtils.getIconFg(doc.type);
        final icon = FileUtils.getIcon(doc.type);
        final sizeStr = doc.sizeLabel;
        final timeStr = DateUtilsHelper.getRelativeTime(doc.addedAt);

        // Derive tag and tagColor locally as they aren't part of the Document model
        String tag = doc.type.name.toUpperCase();
        Color tagColor = iconFg;
        
        if (doc.flashcardCount != null && doc.flashcardCount! > 0) {
          tag = '${doc.flashcardCount} cards';
        } else if (DateTime.now().difference(doc.addedAt).inHours < 24) {
          tag = 'New';
          tagColor = UEColors.accent;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              // Set session to this doc and switch to tutor
              sessionProvider.updateActiveSession(
                doc.name,
                '$sizeStr · Socratic Context Active',
              );
              navProvider.setIndex(1); // switch to tutor
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Activated Socratic context: ${doc.name}'),
                  backgroundColor: UEColors.surface,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: UEColors.surface,
                border: Border.all(color: UEColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconFg, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.name,
                          overflow: TextOverflow.ellipsis,
                          style: UETypography.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: UEColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$sizeStr · $timeStr',
                          style: UETypography.inter(
                            fontSize: 11,
                            color: UEColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: UEColors.iconBg,
                      border: Border.all(color: UEColors.border, width: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: UETypography.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: tagColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
