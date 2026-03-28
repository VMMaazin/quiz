import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String text;
  final List<String> options;
  final int correctAnswer;

  Question({
    required this.text,
    required this.options,
    required this.correctAnswer,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      text: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctAnswer: map['correctAnswer'] is int
          ? map['correctAnswer']
          : int.tryParse(map['correctAnswer']?.toString() ?? '') ?? 0,
    );
  }
}

class Quiz {
  final String id;
  final String title;
  final String assignedClass;
  final String section;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final List<Question> questions;

  Quiz({
    required this.id,
    required this.title,
    required this.assignedClass,
    required this.section,
    required this.startDateTime,
    required this.endDateTime,
    required this.questions,
  });

  factory Quiz.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final startTs = data['startDateTime'] as Timestamp?;
    final endTs = data['endDateTime'] as Timestamp?;
    final qlist = <Question>[];
    if (data['questions'] is List) {
      for (var item in data['questions']) {
        if (item is Map<String, dynamic>) {
          qlist.add(Question.fromMap(item));
        }
      }
    }
    return Quiz(
      id: doc.id,
      title: data['title'] ?? '',
      assignedClass: data['assignedClass'] ?? '',
      section: data['section'] ?? '',
      startDateTime: startTs?.toDate() ?? DateTime.now(),
      endDateTime: endTs?.toDate() ?? DateTime.now(),
      questions: qlist,
    );
  }
}
