class PastPaper {
  final String id;
  final String title;
  final String subject;
  final int year;
  final int questionsCount;
  final double completedPercentage;

  PastPaper({
    required this.id,
    required this.title,
    required this.subject,
    required this.year,
    required this.questionsCount,
    this.completedPercentage = 0.0,
  });
}
