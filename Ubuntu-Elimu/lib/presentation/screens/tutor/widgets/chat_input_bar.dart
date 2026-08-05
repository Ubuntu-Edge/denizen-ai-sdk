import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool isTyping;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.isTyping = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isTyping) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: UEColors.bgPrimary,
        border: Border(
          top: BorderSide(color: UEColors.bgCard, width: 0.5),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: BoxDecoration(
          color: UEColors.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _hasText ? UEColors.indigo.withOpacity(0.4) : UEColors.bgBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.newline,
                style: UETypography.bodyMd.copyWith(fontSize: 14),
                cursorColor: UEColors.indigo,
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle: UETypography.bodyMd.copyWith(
                    color: UEColors.textDim,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hasText && !widget.isTyping
                    ? UEColors.indigo
                    : UEColors.bgBorder,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: _hasText && !widget.isTyping ? _send : null,
                icon: Icon(
                  Icons.arrow_upward_rounded,
                  size: 18,
                  color: _hasText && !widget.isTyping
                      ? Colors.white
                      : UEColors.textDim,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}