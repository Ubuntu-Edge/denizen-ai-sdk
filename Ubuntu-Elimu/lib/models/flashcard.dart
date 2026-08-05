class Flashcard {
  final String id;
  final String front;
  final String back;
  final String subject;
  final int difficulty; // 1 = Easy, 2 = Medium, 3 = Hard
  bool isLearned;

  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.subject,
    required this.difficulty,
    this.isLearned = false,
  });
}
