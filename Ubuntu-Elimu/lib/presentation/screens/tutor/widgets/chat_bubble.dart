import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../models/chat_message.dart';
import 'citation_card.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onCitationTap;

  const ChatBubble({
    super.key,
    required this.message,
    this.onCitationTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser) _AiLabel(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isUser ? UEColors.bgElevated : UEColors.bgCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(color: UEColors.bgBorder, width: 0.5),
              ),
              child: Text(
                message.content,
                style: UETypography.bodySm.copyWith(
                  color: isUser ? UEColors.textPrimary : UEColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),
            ),
            if (message.citation != null)
              CitationCard(
                citation: message.citation!,
                onTap: onCitationTap,
              ),
            const SizedBox(height: 3),
            _MetaRow(message: message),
          ],
        ),
      ),
    );
  }
}

class _AiLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: UEColors.bgElevated,
              border: Border.all(color: UEColors.indigo, width: 0.5),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 10, color: UEColors.indigo),
          ),
          const SizedBox(width: 5),
          Text(
            'Elimu',
            style: UETypography.label.copyWith(
              color: UEColors.indigo,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final ChatMessage message;

  const _MetaRow({required this.message});

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final parts = <String>[_formatTime(message.timestamp)];
    if (message.model != null) parts.add(message.model!.label);
    if (message.language != null) parts.add(message.language!.label);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        parts.join(' · '),
        style: UETypography.caption.copyWith(fontSize: 10),
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AiLabel(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: UEColors.bgCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: UEColors.bgBorder, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    final offset = Curves.easeInOut.transform(
                      (((_controller.value * 3) - i).clamp(0.0, 1.0)),
                    );
                    final bounce = i % 2 == 0
                        ? offset < 0.5
                            ? offset * 2
                            : (1 - offset) * 2
                        : offset < 0.5
                            ? offset * 2
                            : (1 - offset) * 2;
                    return Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      child: Transform.translate(
                        offset: Offset(0, -4 * bounce),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: UEColors.indigo
                                .withOpacity(0.4 + 0.6 * bounce),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}