import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;

abstract class EventBase {
  final String event;
  final String source;

  const EventBase({required this.event, required this.source});

  factory EventBase.fromJson(Map<String, dynamic> j) {
    final src = (j['source'] ?? '').toString().toLowerCase();
    final ty = (j['type'] ?? j['event'] ?? '').toString().toLowerCase();

    // YOLO
    if (src == 'yolo' ||
        ty == 'yolo' ||
        ty == 'snapshot' ||
        ty == 'yolo_recording_done') {
      return YoloEvent.fromJson(j);
    }

    // YAMNet
    final hasYamKeys =
        j.containsKey('cat') ||
        j.containsKey('raw') ||
        j.containsKey('danger') ||
        j.containsKey('group') ||
        j.containsKey('dbfs') ||
        j.containsKey('latency');
    if (src == 'yamnet' || ty == 'yamnet' || hasYamKeys) {
      return YamnetEvent.fromJson(j);
    }

    // STT (clova/whisper 공용 처리)
    if (src == 'clova' ||
        src == 'whisper' ||
        ty == 'clova' ||
        ty == 'stt' ||
        ty == 'whisper') {
      return ClovaEvent.fromJson(j);
    }

    debugPrint(
      '[EVT] Unknown route: src="$src", ty="$ty", keys=${j.keys.toList()}',
    );
    return UnknownEvent(j);
  }

  @override
  String toString() => '$runtimeType(event=$event, source=$source)';
}

double _asDouble(dynamic v, [double d = 0]) =>
    (v is num) ? v.toDouble() : (double.tryParse((v ?? '').toString()) ?? d);
int _asInt(dynamic v, [int d = 0]) =>
    (v is num) ? v.toInt() : (int.tryParse((v ?? '').toString()) ?? d);
num? _asNumNullable(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString());
}

List<num> _asNumList(dynamic v) => (v is List)
    ? v.map<num>((e) => _asNumNullable(e) ?? 0).toList(growable: false)
    : const <num>[];

/* ---------- YOLO ---------- */
class YoloEvent extends EventBase {
  final String label;
  final double confidence;
  final List<num> bbox;
  final int? time;
  final String? file;
  final String? thumbnail;

  YoloEvent({
    required super.event,
    required super.source,
    required this.label,
    required this.confidence,
    required this.bbox,
    this.time,
    this.file,
    this.thumbnail,
  });

  factory YoloEvent.fromJson(Map<String, dynamic> j) {
    final ty = (j['type'] ?? j['event'] ?? '').toString().toLowerCase();
    final dataUrl = j['data']?.toString();

    return YoloEvent(
      event: (j['event'] ?? j['type'] ?? '').toString(),
      source: (j['source'] ?? 'yolo').toString(),
      label:
          (j['group_label'] ??
                  j['label'] ??
                  (ty == 'snapshot' ? 'snapshot' : ''))
              .toString(),
      confidence: _asDouble(j['group_conf'] ?? j['confidence'] ?? 0),

      bbox: _asNumList(j['bbox']),

      time: (j['time'] ?? j['ts'] ?? j['timestamp']) == null
          ? null
          : _asInt(j['time'] ?? j['ts'] ?? j['timestamp']),

      file: _pickFileUrl(j) ?? dataUrl,
      thumbnail: (j['thumbnail'] ?? j['thumb'] ?? dataUrl)?.toString(),
    );
  }

  static String? _pickFileUrl(Map<String, dynamic> j) {
    final top = j['file'];
    if (top is String && top.trim().isNotEmpty) return top.trim();

    final files = j['files'];
    if (files is Map) {
      for (final key in const ['snapshot_url', 'video_url', 'file', 'url']) {
        final v = files[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    return null;
  }
}

/* ---------- CLOVA ---------- */
class ClovaEvent extends EventBase {
  final String text;
  final String? kind;
  final int? sr;
  final double? dur;
  final double? dbfs;

  const ClovaEvent({
    required super.event,
    required super.source,
    required this.text,
    this.kind,
    this.sr,
    this.dur,
    this.dbfs,
  });

  factory ClovaEvent.fromJson(Map<String, dynamic> j) => ClovaEvent(
    event: (j['event'] ?? '').toString(),
    source: (j['source'] ?? 'clova').toString(),
    text: (j['text'] ?? '').toString(),
    kind: j['kind']?.toString(),
    sr: (j['sr'] is int)
        ? j['sr'] as int
        : int.tryParse(j['sr']?.toString() ?? ''),
    dur: (j['dur'] is num)
        ? (j['dur'] as num).toDouble()
        : double.tryParse(j['dur']?.toString() ?? ''),
    dbfs: (j['dbfs'] is num)
        ? (j['dbfs'] as num).toDouble()
        : double.tryParse(j['dbfs']?.toString() ?? ''),
  );

  @override
  String toString() =>
      'ClovaEvent(text="$text", kind=$kind, sr=$sr, dur=$dur, dbfs=$dbfs)';
}

/* ---------- YAMNet ---------- */
class YamnetEvent extends EventBase {
  final String label;
  final double confidence;
  final num? direction;
  final num? energy;
  final int? ms;
  final bool? danger;
  final String? group;
  final double? dbfs;
  final double? latencySec;

  const YamnetEvent({
    required super.event,
    required super.source,
    required this.label,
    required this.confidence,
    this.direction,
    this.energy,
    this.ms,
    this.danger,
    this.group,
    this.dbfs,
    this.latencySec,
  });

  factory YamnetEvent.fromJson(Map<String, dynamic> j) {
    // 1) label 후보: label/name/raw/cat 중 앞부분
    String? label = (j['label'] ?? j['name'])?.toString().trim();
    label ??= _headText((j['raw'] ?? j['cat'])?.toString());

    // 2) confidence 후보: confidence/conf/score 또는 raw/cat의 괄호값
    double? conf =
        _asNumNullable(j['confidence'])?.toDouble() ??
        _asNumNullable(j['conf'])?.toDouble() ??
        _asNumNullable(j['score'])?.toDouble() ??
        _extractParenScore(j['raw']?.toString()) ??
        _extractParenScore(j['cat']?.toString());
    conf ??= 0;

    // 3) 기타 필드
    final dir = _asNumNullable(j['direction'] ?? j['dir']);
    final energy = _asNumNullable(j['energy'] ?? j['rms'] ?? j['db']);
    final ms = (j['ms'] == null)
        ? (j['timestamp'] is int ? j['timestamp'] as int : null)
        : _asInt(j['ms']);

    final danger = (j['danger'] is bool) ? j['danger'] as bool : null;
    final group = j['group']?.toString();
    final dbfs = _asNumNullable(j['dbfs'])?.toDouble();
    final latencySec = _parseLatencySeconds(j['latency']);

    return YamnetEvent(
      event: (j['event'] ?? j['type'] ?? 'yamnet').toString(),
      source: (j['source'] ?? 'yamnet').toString(),
      label: (label ?? '').trim(),
      confidence: conf,
      direction: dir,
      energy: energy,
      ms: ms,
      danger: danger,
      group: group,
      dbfs: dbfs,
      latencySec: latencySec,
    );
  }

  @override
  String toString() =>
      'YamnetEvent(label=$label, conf=$confidence, dir=$direction, energy=$energy, ms=$ms)';
}

String? _headText(String? s) {
  if (s == null) return null;
  final i = s.indexOf('(');
  return (i > 0 ? s.substring(0, i) : s).trim();
}

double? _extractParenScore(String? s) {
  if (s == null) return null;
  final i = s.indexOf('(');
  final j = s.indexOf(')', i + 1);
  if (i >= 0 && j > i) {
    return double.tryParse(s.substring(i + 1, j));
  }
  return null;
}

double? _parseLatencySeconds(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString();
  final numStr = s.replaceAll(RegExp('[^0-9\\.-]'), '');
  return double.tryParse(numStr);
}

class UnknownEvent extends EventBase {
  final Map<String, dynamic> raw;

  UnknownEvent(this.raw)
    : super(
        event: (raw['event'] ?? raw['type'] ?? 'info').toString(),
        source: (raw['source'] ?? 'unknown').toString(),
      );

  @override
  String toString() => 'UnknownEvent(raw=$raw)';
}

String prettyJsonBody(List<int> bodyBytes) {
  final s = utf8.decode(bodyBytes);
  try {
    return const JsonEncoder.withIndent('  ').convert(json.decode(s));
  } catch (_) {
    return s;
  }
}
