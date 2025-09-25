// lib/widgets/yamnet_card.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/events.dart';

/// YAMNet 이벤트 표시 카드
class YamnetCard extends StatefulWidget {
  const YamnetCard({super.key, this.event});
  final YamnetEvent? event;

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

  // 화면표시용 한국어 라벨 (단순화)
  static String _labelKo(String label) {
    final s = label.trim().toLowerCase();
    if (s == 'safe') return '안전';
    if (s == '사이렌') return '사이렌';
    if (s == '경적소리') return '경적소리';
    return label.isEmpty ? '대기 중' : label;
  }

  // 비위험 판정: safe만 안전
  static bool _isNonDanger(String label) {
    final s = label.trim().toLowerCase();
    return s == 'safe';
  }

  // 7초 유지 대상: 사이렌/경적소리
  static bool _shouldDelay(String label) {
    final s = label.trim().toLowerCase();
    return s == '사이렌' || s == '경적소리';
  }

  @override
  State<YamnetCard> createState() => _YamnetCardState();
}

class _YamnetCardState extends State<YamnetCard> {
  Timer? _delayTimer;
  bool _delayActive = false; // 위험 유지 중인지(7초 타이머)

  void _setupDelay() {
    final e = widget.event;
    if (e == null) {
      setState(() => _delayActive = false);
      return;
    }

    final normalized = YamnetCard._normalizeLabelAndConf(e.label, e.confidence);
    final label = normalized.$1;

    if (YamnetCard._shouldDelay(label)) {
      // 사이렌/경적소리 → 즉시 위험, 7초간 강제 유지
      if (_delayActive) return; // 이미 유지 중이면 재시작하지 않음
      setState(() => _delayActive = true);
      _delayTimer?.cancel();
      _delayTimer = Timer(const Duration(seconds: 7), () {
        if (mounted) setState(() => _delayActive = false);
      });
    } else {
      // safe일 때: 유지 중이면 그대로 두고, 아니면 바로 안전
      if (_delayActive) return;
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
    final safeConf = conf.isFinite ? conf.clamp(0.0, 1.0) : 0.0;

    // 방향 파싱 (0~360deg)
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

    // 지연(유지) 중이면 무조건 위험
    final effectiveIsDanger = _delayActive ? true : isDanger;
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

                  // 🔴/🟢 큰 제목: 위험이면 서버 라벨 그대로, 안전이면 "안전"
                  Text(
                    effectiveIsDanger ? ko : '안전',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),

                  const SizedBox(height: 30),

                  if (dirDeg != null) ...[
                    const Text(
                      '방향 정보',
                      style: TextStyle(fontSize: 30, color: Colors.black87),
                    ),
                    const SizedBox(height: 25),

                    // 좌우 반전 + 회전 (요청 반영)
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..rotateZ((dirDeg - 90) * math.pi / 180.0)
                        ..scale(-1.0, 1.0, 1.0),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFB3E5EB),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],

                  // 📊 보조 정보 (신뢰도/에너지)
                  Padding(
                    padding: const EdgeInsets.only(top: 20), // 위쪽 여백 20
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Chip(
                          label: Text(
                            '신뢰도 ${(safeConf * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 18),
                          ),
                          backgroundColor: const Color(0xFFF3F6F9),
                          side: const BorderSide(color: Color(0xFFE3E8EE)),
                        ),
                        if (energy != null)
                          Chip(
                            label: Text(
                              '에너지 ${energy.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 18),
                            ),
                            backgroundColor: const Color(0xFFF6F9FC),
                            side: const BorderSide(color: Color(0xFFE3E8EE)),
                          ),
                      ],
                    ),
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
