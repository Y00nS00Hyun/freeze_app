// lib/widgets/yamnet_card.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/events.dart';
import '../services/notification_service.dart'; // ✅ 알림 서비스 import

/// YAMNet 이벤트 표시 카드 (7초 유지 + 위험 시 푸시 알림)
class YamnetCard extends StatefulWidget {
  const YamnetCard({super.key, this.event});
  final YamnetEvent? event;

  // 라벨/신뢰도 정규화
  static (String, double) _normalizeLabelAndConf(
    String rawLabel,
    double rawConf,
  ) {
    String label = rawLabel;
    double conf = rawConf;

    final s = rawLabel.trim();
    if (s.startsWith('{') && s.contains('label')) {
      final body = s.substring(1, s.endsWith('}') ? s.length - 1 : s.length);
      for (final part in body.split(',')) {
        final kv = part.split(':');
        if (kv.length >= 2) {
          final key = kv[0].trim().toLowerCase();
          final val = kv.sublist(1).join(':').trim();
          if (key == 'label') label = val;
          if (key == 'conf' || key == 'confidence') {
            final parsed = double.tryParse(
              val.replaceAll(RegExp('[^0-9eE+\\-.]'), ''),
            );
            if (parsed != null) conf = parsed;
          }
        }
      }
    }

    // 따옴표/공백 제거
    label = label.trim();
    if ((label.startsWith('"') && label.endsWith('"')) ||
        (label.startsWith("'") && label.endsWith("'"))) {
      label = label.substring(1, label.length - 1).trim();
    }
    return (label, conf);
  }

  // 화면표시용 한국어 라벨
  static String _labelKo(String label) {
    final s = label.trim().toLowerCase();
    if (s == 'safe') return '안전';
    if (s == '사이렌') return '사이렌';
    if (s == '경적소리' || s == 'horn' || s == 'car horn') return '경적소리';
    return label.isEmpty ? '대기 중' : label;
  }

  // 비위험 판정
  static bool _isNonDanger(String label) {
    final s = label.trim().toLowerCase();
    return s == 'safe' || s == '안전';
  }

  // 7초 유지 대상
  static bool _shouldDelay(String label) {
    final s = label.trim().toLowerCase();
    return s == '사이렌' || s == '경적소리' || s == 'horn' || s == 'car horn';
  }

  @override
  State<YamnetCard> createState() => _YamnetCardState();
}

class _YamnetCardState extends State<YamnetCard>
    with AutomaticKeepAliveClientMixin {
  DateTime? _dangerUntil;
  Timer? _tick;
  String? _lastDangerKo;

  // 🔔 알림 중복 방지
  DateTime? _lastNotifyAt;
  String? _lastNotifyLabel;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _applyEvent(widget.event);
  }

  @override
  void didUpdateWidget(covariant YamnetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event != widget.event) {
      _applyEvent(widget.event);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _applyEvent(YamnetEvent? e) {
    if (e == null) {
      _startOrStopTicker();
      setState(() {});
      return;
    }

    final normalized = YamnetCard._normalizeLabelAndConf(e.label, e.confidence);
    final label = normalized.$1;

    final isNonDangerLocal = YamnetCard._isNonDanger(label);
    final isDangerLocal = e.danger ?? !isNonDangerLocal;
    if (isDangerLocal) {
      _lastDangerKo = YamnetCard._labelKo(label);
    }

    // 7초 유지 로직
    if (YamnetCard._shouldDelay(label)) {
      final now = DateTime.now();
      if (_dangerUntil == null || now.isAfter(_dangerUntil!)) {
        _dangerUntil = now.add(const Duration(seconds: 7));
      }
    }

    // ✅ 위험이면 푸시 알림 (중복 방지 포함)
    if (isDangerLocal) {
      final ko = YamnetCard._labelKo(label);
      _notifyDangerOnce(
        labelKo: ko,
        payload: 'label=$ko;conf=${normalized.$2}',
      );
    }

    _startOrStopTicker();
    setState(() {});
  }

  bool get _isDelayActive {
    final until = _dangerUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  void _startOrStopTicker() {
    final active = _isDelayActive;
    if (active && _tick == null) {
      _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        if (!_isDelayActive) {
          _tick?.cancel();
          _tick = null;
        }
        setState(() {});
      });
    } else if (!active && _tick != null) {
      _tick?.cancel();
      _tick = null;
    }
  }

  // 🔔 푸시 알림 중복 방지 로직
  Future<void> _notifyDangerOnce({
    required String labelKo,
    String? payload,
  }) async {
    const minGap = Duration(seconds: 10); // 최소 간격
    final now = DateTime.now();

    final labelChanged = _lastNotifyLabel != labelKo;
    final timeOk =
        _lastNotifyAt == null || now.difference(_lastNotifyAt!) >= minGap;

    if (labelChanged || timeOk) {
      await NotiService.I.showNow(
        title: '위험 감지',
        body: '$labelKo 소리가 감지되었습니다',
        payload: payload ?? labelKo,
      );
      _lastNotifyAt = now;
      _lastNotifyLabel = labelKo;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.event == null) return const SizedBox.shrink();
    final e = widget.event!;

    final normalized = YamnetCard._normalizeLabelAndConf(e.label, e.confidence);
    final label = normalized.$1;
    final conf = normalized.$2;
    final safeConf = conf.isFinite ? conf.clamp(0.0, 1.0) : 0.0;

    final double? rawDirDeg = _parseDirection(e.direction);
    final double? dirDeg = (rawDirDeg == null || !rawDirDeg.isFinite)
        ? null
        : ((rawDirDeg % 360) + 360) % 360;

    final energy = e.energy;
    final ko = YamnetCard._labelKo(label);
    final isNonDanger = YamnetCard._isNonDanger(label);
    final isDanger = e.danger ?? !isNonDanger;
    final effectiveIsDanger = _isDelayActive ? true : isDanger;

    final String titleText = effectiveIsDanger
        ? (_isDelayActive && isNonDanger ? (_lastDangerKo ?? ko) : ko)
        : '안전';

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
                    titleText,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                    ).copyWith(color: titleColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  if (dirDeg != null) ...[
                    const Text(
                      '방향 정보',
                      style: TextStyle(fontSize: 30, color: Colors.black87),
                    ),
                    const SizedBox(height: 25),
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..rotateZ(-(dirDeg + 90) * math.pi / 180.0),
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
                  // 보조 정보(신뢰도/에너지) 원하면 주석 해제
                  // Chip(...) 등등
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
