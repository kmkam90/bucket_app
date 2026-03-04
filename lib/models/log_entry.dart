import 'enums.dart';

class LogEntry {
  final DateTime date;
  final int value; // habit: 1(완료), 0(미완료); count: 수량; duration: minutes

  LogEntry({required this.date, required this.value});

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        date: DateTime.parse(json['date']),
        value: json['value'],
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'value': value,
      };
}
