class Task {
  final String title;
  final DateTime? reminder;
  final String id;

  Task({required this.title, this.reminder, required this.id});

  Map<String, dynamic> toMap() => {
        'title': title,
        'reminder': reminder?.toIso8601String(),
      };

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      title: map['title'],
      reminder: map['reminder'] != null
          ? DateTime.parse(map['reminder'])
          : null,
    );
  }
}




