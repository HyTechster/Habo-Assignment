/// A "keep going" reminder ping sent from one friend to another about a
/// specific shared habit (mirrors `public.nudges`).
class Nudge {
  Nudge({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.habitId,
    required this.sentAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String habitId;
  final DateTime sentAt;

  factory Nudge.fromMap(Map<String, dynamic> map) {
    return Nudge(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      habitId: map['habit_id'] as String,
      sentAt: DateTime.parse(map['sent_at'] as String),
    );
  }
}
