// lib/utils/yolo_utils.dart
import 'package:flutter/foundation.dart' show debugPrint;

String? fileNameFromEpoch(int? sec) {
  if (sec == null) {
    debugPrint('[YOLO] time is null → fileName 생성 불가');
    return null;
  }
  final dt = DateTime.fromMillisecondsSinceEpoch(
    sec * 1000,
    isUtc: true,
  ).toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}_${two(dt.month)}_${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}${two(dt.second)}.jpg';
}

String koreanizeLabel(String l) {
  final s = l.toLowerCase();
  if (s.contains('bus')) return '버스';
  if (s.contains('car')) return '자동차';
  if (s.contains('person')) return '사람';
  if (s.contains('bicycle')) return '자전거';
  if (s.contains('truck')) return '트럭';
  return l;
}
