// lib/widgets/yamnet_card.dart
import 'dart:async'; // ⬅️ 추가
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/events.dart';

/// YAMNet 이벤트 표시 카드
class YamnetCard extends StatefulWidget {
  // ⬅️ StatefulWidget로 변경
  const YamnetCard({super.key, this.event});
  final YamnetEvent? event;

  // ─────────────────────────────────────────────
  // 서버 카테고리 키워드(소문자 비교)
  static const List<String> _KW_HORN = <String>[
    'car horn',
    'vehicle horn',
    'air horn',
    'horn',
    'honk',
    'honking',
    'klaxon',
  ];
  static const List<String> _KW_FIRE_ALARM = <String>[
    'fire alarm',
    'smoke alarm',
    'carbon monoxide alarm',
    'co alarm',
    'evacuation alarm',
    'emergency alarm',
    'alarm bell',
    'fire bell',
    'fire engine siren',
    'fire truck siren',
    'fire siren',
    'siren',
    'warning siren',
  ];
  static bool _containsAny(String s, List<String> kws) {
    for (final kw in kws) {
      if (s.contains(kw)) return true;
    }
    return false;
  }

  // 라벨/신뢰도 정규화
  static (String, double) _normalizeLabelAndConf(
    String rawLabel,
    double rawConf,
  ) {
    final s = rawLabel.trim();
    if (s.startsWith('{') && s.contains('label:')) {
      String label = rawLabel;
      double conf = rawConf;
      for (final part in s.substring(1, s.length - 1).split(',')) {
        final kv = part.split(':');
        if (kv.length >= 2) {
          final key = kv[0].trim();
          final val = kv.sublist(1).join(':').trim();
          if (key == 'label') label = val;
          if (key == 'conf') conf = double.tryParse(val) ?? conf;
        }
      }
      return (label, conf);
    }
    return (rawLabel, rawConf);
  }

  // 화면에 보여줄 한국어 라벨 매핑 (단순화 버전)
  static String _labelKo(String label) {
    final s = label.trim().toLowerCase();
    if (s == 'safe') return '안전';
    if (s == '사이렌') return '사이렌';
    if (s == '경적소리') return '경적소리';
    return label.isEmpty ? '대기 중' : label;
  }

  // safe만 비위험
  static bool _isNonDanger(String label) {
    final s = label.trim().toLowerCase();
    return s == 'safe';
  }

  // 사이렌/경적소리면 지연 대상
  static bool _shouldDelay(String label) {
    final s = label.trim().toLowerCase();
    return s == '사이렌' || s == '경적소리';
  }

  @override
  State<YamnetCard> createState() => _YamnetCardState();
}

class _YamnetCardState extends State<YamnetCard> {
  Timer? _delayTimer;
  bool _delayActive = false; // 지연 중인지

  void _setupDelay() {
    _delayTimer?.cancel();
    final e = widget.event;
    if (e == null) {
      setState(() => _delayActive = false);
      return;
    }
    final normalized = YamnetCard._normalizeLabelAndConf(e.label, e.confidence);
    final label = normalized.$1;

    if (YamnetCard._shouldDelay(label)) {
      // 사이렌/경적소리면 7초 지연
      setState(() => _delayActive = true);
      _delayTimer = Timer(const Duration(seconds: 7), () {
        if (mounted) setState(() => _delayActive = false);
      });
    } else {
      setState(() => _delayActive = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _setupDelay();
  }

  @override
  void didUpdateWidget(covariant YamnetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 새 이벤트가 오면 라벨 기준으로 지연 상태 갱신
    if (oldWidget.event?.label != widget.event?.label) {
      _setupDelay();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event == null) return const SizedBox.shrink();
    final e = widget.event!;

    // 라벨/신뢰도 정규화
    final normalized = YamnetCard._normalizeLabelAndConf(e.label, e.confidence);
    final label = normalized.$1;
    final conf = normalized.$2;
    final safeConf = (conf.isFinite) ? conf.clamp(0.0, 1.0) : 0.0;

    // 방향 파싱
    double? _parseDirection(dynamic dir) {
      if (dir == null) return null;
      if (dir is num) {
        final v = dir.toDouble();
        final isRad = v.abs() <= 2 * math.pi + 1e-6;
        return isRad ? (v * 180.0 / math.pi) : v;
      }
      if (dir is String) {
        final direct = double.tryParse(dir);
        if (direct != null) return direct;
        final m = RegExp(
          r'(-?\d+(?:\.\d+)?)\s*(deg|°|rad)?',
          caseSensitive: false,
        ).firstMatch(dir);
        if (m != null) {
          final v = double.parse(m.group(1)!);
          final unit = (m.group(2) ?? 'deg').toLowerCase();
          return unit.contains('rad') ? (v * 180.0 / math.pi) : v;
        }
      }
      return null;
    }

    final double? rawDirDeg = _parseDirection(e.direction);
    final double? dirDeg = (rawDirDeg == null || !rawDirDeg.isFinite)
        ? null
        : ((rawDirDeg % 360) + 360) % 360;

    final energy = e.energy;
    final ko = YamnetCard._labelKo(label);
    final isNonDanger = YamnetCard._isNonDanger(label);
    final isDanger = e.danger ?? !isNonDanger;

    // ⬇️ 지연 중에는 '위험' 대신 '안전(확인 중)'으로 표시
    final effectiveIsDanger = _delayActive ? false : isDanger;
    final titleColor = effectiveIsDanger
        ? Colors.redAccent
        : const Color(0xFF3BB273);

    final Widget mainSymbol = effectiveIsDanger
        ? const Icon(
            Icons.warning_amber_rounded,
            color: Color.fromARGB(255, 255, 4, 0),
            size: 80,
          )
        : const Icon(Icons.check_circle, color: Color(0xFF3BB273), size: 80);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  mainSymbol,
                  const SizedBox(height: 12),
                  Text(
                    effectiveIsDanger
                        ? '위험음 감지'
                        : (_delayActive ? '안전 (확인 중…)' : '안전'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ko,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  if (_delayActive) ...[
                    const SizedBox(height: 6),
                    const Text(
                      '사이렌/경적소리 감지됨 — 7초 확인 후 표시',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 20),

                  if (dirDeg != null) ...[
                    const Text(
                      '방향 정보',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    Transform.rotate(
                      angle: (dirDeg - 90) * math.pi / 180.0,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFB3E5EB),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Chip(
                        label: Text(
                          '신뢰도 ${(safeConf * 100).toStringAsFixed(1)}%',
                        ),
                        backgroundColor: const Color(0xFFF3F6F9),
                        side: const BorderSide(color: Color(0xFFE3E8EE)),
                      ),
                      if (energy != null)
                        Chip(
                          label: Text('에너지 ${energy.toStringAsFixed(1)}'),
                          backgroundColor: const Color(0xFFF6F9FC),
                          side: const BorderSide(color: Color(0xFFE3E8EE)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
