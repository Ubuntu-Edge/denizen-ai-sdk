import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../models/flashcard.dart';

class FlashcardView extends StatefulWidget {
  const FlashcardView({super.key});

  @override
  State<FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<FlashcardView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;
  int _currentIndex = 0;

  final List<Flashcard> _flashcards = [
    Flashcard(
      id: 'fc_1',
      front: 'What is the functional group suffix of Alcohols in IUPAC naming?',
      back: 'The functional group suffix is "-ol" (e.g., Ethanol).',
      subject: 'Chemistry',
      difficulty: 1,
    ),
    Flashcard(
      id: 'fc_2',
      front: 'What are the products of cellular respiration?',
      back: 'Carbon dioxide (CO2), water (H2O), and energy (ATP).',
      subject: 'Biology',
      difficulty: 2,
    ),
    Flashcard(
      id: 'fc_3',
      front: 'Define Spontaneity in thermodynamic terms.',
      back: 'A reaction is spontaneous if its Gibbs Free Energy change is negative (ΔG < 0).',
      subject: 'Physics/Chemistry',
      difficulty: 3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_controller.isAnimating) return;
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  void _nextCard() {
    if (_controller.isAnimating) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _flashcards.length;
      _isFront = true;
      _controller.reset();
    });
  }

  void _prevCard() {
    if (_controller.isAnimating) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _flashcards.length) % _flashcards.length;
      _isFront = true;
      _controller.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = _flashcards[_currentIndex];

    return Column(
      children: [
        // Flashcard 3D Card Container
        GestureDetector(
          onTap: _flipCard,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final angle = _animation.value * pi;
              final isBackHalf = angle >= pi / 2;

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: isBackHalf
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi), // counter-rotate content
                        child: _buildCardFace(card.back, false, card.subject),
                      )
                    : _buildCardFace(card.front, true, card.subject),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Navigation Controllers
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(TablerIcons.chevron_left, color: UEColors.textMuted),
              onPressed: _prevCard,
            ),
            const SizedBox(width: 20),
            Text(
              '${_currentIndex + 1} / ${_flashcards.length}',
              style: UETypography.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: UEColors.textPrimary,
              ),
            ),
            const SizedBox(width: 20),
            IconButton(
              icon: Icon(TablerIcons.chevron_right, color: UEColors.textMuted),
              onPressed: _nextCard,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardFace(String text, bool isFrontFace, String subject) {
    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: UEColors.surface,
        border: Border.all(
          color: isFrontFace ? UEColors.border : UEColors.accent,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: UEColors.iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subject.toUpperCase(),
                  style: UETypography.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: UEColors.accent,
                  ),
                ),
              ),
              Text(
                isFrontFace ? 'TAP TO REVEAL' : 'ANSWER',
                style: UETypography.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isFrontFace ? UEColors.textMuted : UEColors.accent,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: UETypography.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: UEColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
