class ChatMessage {
  final String id;
  final String patientId;
  final String sessionId;
  final String sender;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.patientId,
    required this.sessionId,
    required this.sender,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'session_id': sessionId,
      'sender': sender,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      patientId: map['patient_id'],
      sessionId: map['session_id'],
      sender: map['sender'],
      message: map['message'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  ChatMessage copyWith({
    String? id,
    String? patientId,
    String? sessionId,
    String? sender,
    String? message,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      sessionId: sessionId ?? this.sessionId,
      sender: sender ?? this.sender,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
