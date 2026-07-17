/// Completion parameters for offline AI inference
class OfflineCompletionParams {
  // Generation settings
  final int nPredict; // Max tokens to generate
  final double temperature; // Randomness (0.0 - 2.0)
  final int topK; // Top-K sampling
  final double topP; // Nucleus sampling
  final double minP; // Minimum probability

  // Repetition control
  final int penaltyLastN; // Lookback for penalties
  final double penaltyRepeat; // Repetition penalty
  final double penaltyFreq; // Frequency penalty
  final double penaltyPresent; // Presence penalty

  // Mirostat sampling
  final int mirostat; // Mirostat sampling mode (0 = disabled)
  final double mirostatTau; // Mirostat target entropy
  final double mirostatEta; // Mirostat learning rate

  // Other
  final int seed; // Random seed (-1 = random)
  final List<String> stop; // Stop sequences

  const OfflineCompletionParams({
    this.nPredict = 1024,
    this.temperature = 0.7,
    this.topK = 40,
    this.topP = 0.95,
    this.minP = 0.05,
    this.penaltyLastN = 64,
    this.penaltyRepeat = 1.0,
    this.penaltyFreq = 0.0,
    this.penaltyPresent = 0.0,
    this.mirostat = 0,
    this.mirostatTau = 5.0,
    this.mirostatEta = 0.1,
    this.seed = -1,
    this.stop = const ['</s>'],
  });

  /// Create default parameters
  factory OfflineCompletionParams.defaults() => const OfflineCompletionParams();

  /// Create a copy with modified fields
  OfflineCompletionParams copyWith({
    int? nPredict,
    double? temperature,
    int? topK,
    double? topP,
    double? minP,
    int? penaltyLastN,
    double? penaltyRepeat,
    double? penaltyFreq,
    double? penaltyPresent,
    int? mirostat,
    double? mirostatTau,
    double? mirostatEta,
    int? seed,
    List<String>? stop,
  }) {
    return OfflineCompletionParams(
      nPredict: nPredict ?? this.nPredict,
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      minP: minP ?? this.minP,
      penaltyLastN: penaltyLastN ?? this.penaltyLastN,
      penaltyRepeat: penaltyRepeat ?? this.penaltyRepeat,
      penaltyFreq: penaltyFreq ?? this.penaltyFreq,
      penaltyPresent: penaltyPresent ?? this.penaltyPresent,
      mirostat: mirostat ?? this.mirostat,
      mirostatTau: mirostatTau ?? this.mirostatTau,
      mirostatEta: mirostatEta ?? this.mirostatEta,
      seed: seed ?? this.seed,
      stop: stop ?? this.stop,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'nPredict': nPredict,
        'temperature': temperature,
        'topK': topK,
        'topP': topP,
        'minP': minP,
        'penaltyLastN': penaltyLastN,
        'penaltyRepeat': penaltyRepeat,
        'penaltyFreq': penaltyFreq,
        'penaltyPresent': penaltyPresent,
        'mirostat': mirostat,
        'mirostatTau': mirostatTau,
        'mirostatEta': mirostatEta,
        'seed': seed,
        'stop': stop,
      };

  /// Create from JSON
  factory OfflineCompletionParams.fromJson(Map<String, dynamic> json) {
    return OfflineCompletionParams(
      nPredict: json['nPredict'] as int? ?? 1024,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      topK: json['topK'] as int? ?? 40,
      topP: (json['topP'] as num?)?.toDouble() ?? 0.95,
      minP: (json['minP'] as num?)?.toDouble() ?? 0.05,
      penaltyLastN: json['penaltyLastN'] as int? ?? 64,
      penaltyRepeat: (json['penaltyRepeat'] as num?)?.toDouble() ?? 1.0,
      penaltyFreq: (json['penaltyFreq'] as num?)?.toDouble() ?? 0.0,
      penaltyPresent: (json['penaltyPresent'] as num?)?.toDouble() ?? 0.0,
      mirostat: json['mirostat'] as int? ?? 0,
      mirostatTau: (json['mirostatTau'] as num?)?.toDouble() ?? 5.0,
      mirostatEta: (json['mirostatEta'] as num?)?.toDouble() ?? 0.1,
      seed: json['seed'] as int? ?? -1,
      stop: (json['stop'] as List<dynamic>?)?.cast<String>() ?? const ['</s>'],
    );
  }

  @override
  String toString() => 'OfflineCompletionParams(temp: $temperature, topP: $topP, maxTokens: $nPredict)';
}
