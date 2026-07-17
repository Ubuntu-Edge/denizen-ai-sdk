/// Extracts medical information from natural language symptoms
class SymptomParser {
  static final SymptomParser instance = SymptomParser._init();
  SymptomParser._init();

  /// Extract key symptoms from text
  List<String> extractSymptoms(String text) {
    final symptoms = <String>[];
    final lowerText = text.toLowerCase();

    // Common symptom keywords
    final symptomMap = {
      'fever': ['fever', 'hot', 'temperature'],
      'cough': ['cough', 'coughing'],
      'breathing': ['breathing fast', 'difficulty breathing', 'breathless'],
      'vomiting': ['vomit', 'vomiting', 'throwing up'],
      'diarrhea': ['diarrhea', 'loose stool', 'watery stool'],
      'headache': ['headache', 'head pain'],
      'pain': ['pain', 'ache', 'hurts'],
      'rash': ['rash', 'skin problem', 'spots'],
      'weakness': ['weak', 'tired', 'fatigue', 'lethargic'],
    };

    for (final entry in symptomMap.entries) {
      for (final keyword in entry.value) {
        if (lowerText.contains(keyword)) {
          symptoms.add(entry.key);
          break;
        }
      }
    }

    return symptoms;
  }

  /// Extract duration from text (e.g., "3 days", "2 weeks")
  String? extractDuration(String text) {
    final match = RegExp(r'(\d+)\s*(day|week|hour|month)s?').firstMatch(text.toLowerCase());
    return match?.group(0);
  }

  /// Check if text indicates emergency
  bool isEmergency(String text) {
    final emergencyKeywords = [
      'unconscious',
      'not breathing',
      'severe bleeding',
      'convuls',
      'seizure',
      'very pale',
      'unable to drink',
      'chest pain',
    ];

    final lowerText = text.toLowerCase();
    return emergencyKeywords.any((keyword) => lowerText.contains(keyword));
  }
}
