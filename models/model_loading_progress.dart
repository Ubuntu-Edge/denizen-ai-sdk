/// Represents the progress of model loading operation
class ModelLoadingProgress {
  final String message;
  final int percentage;

  ModelLoadingProgress({
    required this.message,
    required this.percentage,
  });

  @override
  String toString() =>
      'ModelLoadingProgress(message: $message, percentage: $percentage%)';
}
