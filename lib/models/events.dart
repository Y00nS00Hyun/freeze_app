// lib/models/events.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;

/// 모든 수신 이벤트의 공통 베이스
abstract class EventBase {
  final String event; // ex) 'yamnet', 'transcript', 'yolo'
  final String source; // ex) 'yamnet', 'whisper', 'clova', 'yolo'

  const EventBase({required this.event, required this.source});

  /// 서버에서 온 JSON을 적절한 이벤트 클래스로 라우팅
  factory EventBase.fromJson(Map<String, dynamic> j) {
    final src = (j['source'] ?? '').toString().toLowerCase();
    final ty = (j['type'] ?? j['event'] ?? '').toString().toLowerCase();
    final ev = (j['event'] ?? j['type'] ?? '').toString().toLowerCase();

    debugPrint('[EVT][RAW.keys] ${j.keys.toList()}');
    debugPrint(
      '[EVT][RAW.route] src="$src" ty="$ty" ev="$ev" '
      'hasTranscript=${j.containsKey('transcript')}',
    );

    // 1) YOLO 먼저
    if (src == 'yolo' ||
        ty == 'yolo' ||
        ty == 'snapshot' ||
        ty == 'yolo_recording_done') {
      debugPrint('[EVT][ROUTE] -> YOLO');
      return YoloEvent.fromJson(j);
    }

    // 2) STT (Clova/Whisper/Transcript)
    if (src == 'clova' ||
        src == 'whisper' ||
        ty == 'clova' ||
        ty == 'stt' ||
        ty == 'whisper' ||
        ty == 'transcript' ||
        ev == 'transcript' ||
        j.containsKey('transcript')) {
      debugPrint('[EVT][ROUTE] -> CLOVA/WHISPER (STT)');
      return ClovaEvent.fromJson(j);
    }

    // 3) YAMNet
    final hasYamKeys =
        j.containsKey('cat') ||
        j.containsKey('raw') ||
        j.containsKey('danger') ||
        j.containsKey('group') ||
        j.containsKey('dbfs') ||
        j.containsKey('latency') ||
        ((j.containsKey('label') || j.containsKey('name')) &&
            (j.containsKey('confidence') ||
                j.containsKey('conf') ||
                j.containsKey('score'))) ||
        (j.containsKey('direction') ||
            j.containsKey('dir') ||
            j.containsKey('energy') ||
            j.containsKey('rms') ||
            j.containsKey('db')) ||
        (j.containsKey('ms') || j.containsKey('timestamp'));

    if (src == 'yamnet' || ty == 'yamnet' || hasYamKeys) {
      debugPrint('[EVT][ROUTE] -> YAMNet');
      return YamnetEvent.fromJson(j);
    }

    // 4) Unknown
    debugPrint('[EVT][ROUTE] -> UNKNOWN (src="$src" ty="$ty" ev="$ev")');
    return UnknownEvent(j);
  }

  @override
  String toString() => '$runtimeType(event=$event, source=$source)';
}

/// ─────────────────────────────────────────────────────────────────
/// 공용 파서 유틸
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

/// ─────────────────────────────────────────────────────────────────
/// YOLO 이벤트
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

/// ─────────────────────────────────────────────────────────────────
/// STT(Clova/Whisper/Transcript) 이벤트
class ClovaEvent extends EventBase {
  final String text; // 화면에 보여줄 문장
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

  factory ClovaEvent.fromJson(Map<String, dynamic> j) {
    final t = (j['transcript'] ?? j['text'] ?? j['sentence'] ?? '').toString();
    final ev = (j['event'] ?? j['type'] ?? 'transcript').toString();
    final src = (j['source'] ?? 'clova').toString();
    debugPrint('[CLOVA][PARSE] src=$src ev=$ev text="$t"');
    return ClovaEvent(
      event: ev,
      source: src,
      text: t,
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
  }

  @override
  String toString() =>
      'ClovaEvent(text="$text", kind=$kind, sr=$sr, dur=$dur, dbfs=$dbfs)';
}

/// ─────────────────────────────────────────────────────────────────
/// YAMNet 이벤트
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
    String? label = (j['label'] ?? j['name'])?.toString().trim();
    label ??= _headText((j['raw'] ?? j['cat'])?.toString());

    double? _numMaybePercent(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString().trim();
      final n = double.tryParse(s.replaceAll('%', ''));
      if (n == null) return null;
      return s.endsWith('%') ? n / 100.0 : n;
    }

    double conf =
        _numMaybePercent(j['confidence']) ??
        _numMaybePercent(j['conf']) ??
        _numMaybePercent(j['score']) ??
        _extractParenScore(j['raw']?.toString()) ??
        _extractParenScore(j['cat']?.toString()) ??
        0.0;

    if (conf > 1.0) conf = conf / 100.0;
    conf = conf.clamp(0.0, 1.0);

    final dir = _asNumNullable(j['direction'] ?? j['dir']);
    final energy = _asNumNullable(j['energy'] ?? j['rms'] ?? j['db']);
    final ms = (j['ms'] == null)
        ? (j['timestamp'] is int ? j['timestamp'] as int : null)
        : _asInt(j['ms']);
    final danger = (j['danger'] is bool) ? j['danger'] as bool : null;
    final group = j['group']?.toString();
    final dbfs = _asNumNullable(j['dbfs'])?.toDouble();
    final latency = _parseLatencySeconds(j['latency']);

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
      latencySec: latency,
    );
  }

  @override
  String toString() =>
      'YamnetEvent(label=$label, conf=$confidence, dir=$direction, energy=$energy, ms=$ms)';
}

/// ─────────────────────────────────────────────────────────────────
/// 알 수 없는 이벤트
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

/// 디버깅용 pretty JSON
String prettyJsonBody(List<int> bodyBytes) {
  final s = utf8.decode(bodyBytes);
  try {
    return const JsonEncoder.withIndent('  ').convert(json.decode(s));
  } catch (_) {
    return s;
  }
}
