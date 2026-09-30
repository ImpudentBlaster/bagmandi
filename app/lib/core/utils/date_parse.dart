import 'package:cloud_firestore/cloud_firestore.dart';

DateTime parseAppDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return DateTime.now();
  }
}

dynamic encodeAppDate(DateTime value, {bool forFirestore = false}) {
  if (forFirestore) return Timestamp.fromDate(value);
  return value.toIso8601String();
}
