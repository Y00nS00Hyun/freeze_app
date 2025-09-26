// lib/widgets/yamnet_card.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/events.dart';

/// YAMNet 이벤트 표시 카드 (7초 유지 로직을 타임스탬프 기반으로 개선)
class YamnetCard extends StatefulWidget {
  const YamnetCard({super.key, this.event});
  final YamnetEvent? event;

  // 라벨/신뢰도 정규화: {label: ..., conf: ...} 형태 문자열도 파싱
  static (String, double) _normalizeLabelAndConf(
    String rawLabel,
    double rawConf,
  ) {
    String label = rawLabel;
    double conf = rawConf;

    final s = rawLabel.trim();
    if (s.startsWith('{') && s.contains('label')) {
      // 매우 관대한 파서: label: xxx, conf: yyy
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

  // 화면표시용 한국어 라벨(단순화)
  static String _labelKo(String label) {
    final s = label.trim().toLowerCase();
    if (s == 'safe') return '안전';
    if (s == '사이렌') return '사이렌';
    if (s == '경적소리' || s == 'horn' || s == 'car horn') return '경적소리';
    return label.isEmpty ? '대기 중' : label;
  }

  // 비위험 판정: safe/안전
  static bool _isNonDanger(String label) {
    final s = label.trim().toLowerCase();
    return s == 'safe' || s == '안전';
  }

  // 7초 유지 대상: 사이렌/경적소리
  static bool _shouldDelay(String label) {
    final s = label.trim().toLowerCase();
    return s == '사이렌' || s == '경적소리' || s == 'horn' || s == 'car horn';
  }

  @override
  State<YamnetCard> createState() => _YamnetCardState();
}

class _YamnetCardState extends State<YamnetCard>
    with AutomaticKeepAliveClientMixin {
  // 유지 종료 시각(있으면 그때까지 위험 유지)
  DateTime? _dangerUntil;

  // 유지 중 실시간 갱신용 타이머(250ms)
  Timer? _tick;

  // 유지 중 표시할 "마지막 위험 라벨(한글화)" 저장
  String? _lastDangerKo;

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

  // 이벤트 적용: 유지 대상이면 _dangerUntil 갱신
  void _applyEvent(YamnetEvent? e) {
    if (e == null) {
      // 이벤트가 잠깐 null이어도 기존 유지시간은 보존
      _startOrStopTicker();
      setState(() {});
      return;
    }

    final normalized = YamnetCard._normalizeLabelAndConf(e.label, e.confidence);
    final label = normalized.$1;

    // 이번 이벤트 위험 여부 계산 후, 위험이면 마지막 위험 라벨 저장
    final isNonDangerLocal = YamnetCard._isNonDanger(label);
    final isDangerLocal = e.danger ?? !isNonDangerLocal;
    if (isDangerLocal) {
      _lastDangerKo = YamnetCard._labelKo(label);
    }

    if (YamnetCard._shouldDelay(label)) {
      final now = DateTime.now();
      // 이미 유지 중이면 그대로 두되, 종료 시각이 지났다면 새로 7초 부여
      if (_dangerUntil == null || now.isAfter(_dangerUntil!)) {
        _dangerUntil = now.add(const Duration(seconds: 7));
      }
    } else {
      // safe여도 남은 유지 시간이 있으면 끝날 때까지 유지 (변경 없음)
    }

    _startOrStopTicker();
    setState(() {});
  }

  bool get _isDelayActive {
    final until = _dangerUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  // 유지 중이면 주기적으로 setState()해서 남은 시간/상태 반영
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

  // 방향(0~360 deg) 파서
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

    // 라벨/신뢰도 정규화
    final normalized = YamnetCard._normalizeLabelAndConf(e.label, e.confidence);
    final label = normalized.$1;
    final conf = normalized.$2;
    final safeConf = conf.isFinite ? conf.clamp(0.0, 1.0) : 0.0;

    // 방향 정규화
    final double? rawDirDeg = _parseDirection(e.direction);
    final double? dirDeg = (rawDirDeg == null || !rawDirDeg.isFinite)
        ? null
        : ((rawDirDeg % 360) + 360) % 360;

    final energy = e.energy;
    final ko = YamnetCard._labelKo(label);
    final isNonDanger = YamnetCard._isNonDanger(label);
    final isDanger = e.danger ?? !isNonDanger;

    // 지연(유지) 중이면 무조건 위험
    final effectiveIsDanger = _isDelayActive ? true : isDanger;

    // 유지 중에 현재 라벨이 safe면, 마지막 위험 라벨을 제목으로 표시
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

    // 남은 유지 시간(초) 표기용 (옵션)
    final int remainMs = _dangerUntil == null
        ? 0
        : (_dangerUntil!.millisecondsSinceEpoch -
                  DateTime.now().millisecondsSinceEpoch)
              .clamp(0, 7000);
    final double remainSec = remainMs / 1000.0;

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

                  // 🔴/🟢 큰 제목: 유지 중이면 마지막 위험 라벨, 아니면 안전/현재 라벨
                  Text(
                    titleText,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                    ).copyWith(color: titleColor),
                    textAlign: TextAlign.center,
                  ),

                  // 유지 안내 칩을 활성화하면 UX가 더 명확해집니다 (원하면 주석 해제)
                  // if (_isDelayActive) ...[
                  //   const SizedBox(height: 8),
                  //   Chip(
                  //     label: Text(
                  //       '최근 위협 감지로 표시 유지 중 • ${remainSec.toStringAsFixed(1)}s',
                  //       style: const TextStyle(
                  //         fontSize: 14,
                  //         fontWeight: FontWeight.w600,
                  //       ),
                  //     ),
                  //     backgroundColor: const Color(0xFFFFF3F3),
                  //     side: const BorderSide(color: Color(0xFFFFE0E0)),
                  //     avatar: const Icon(
                  //       Icons.timer,
                  //       size: 18,
                  //       color: Colors.redAccent,
                  //     ),
                  //   ),
                  // ],
                  const SizedBox(height: 30),

                  if (dirDeg != null) ...[
                    const Text(
                      '방향 정보',
                      style: TextStyle(fontSize: 30, color: Colors.black87),
                    ),
                    const SizedBox(height: 25),

                    // 회전만 적용(0°=위, 90°=오른쪽, 180°=아래, 270°=왼쪽)
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

                  // 📊 보조 정보 (신뢰도/에너지) - 필요 시 주석 해제
                  // Padding(
                  //   padding: const EdgeInsets.only(top: 20),
                  //   child: Wrap(
                  //     alignment: WrapAlignment.center,
                  //     spacing: 12,
                  //     runSpacing: 12,
                  //     children: [
                  //       Chip(
                  //         label: Text(
                  //           '신뢰도 ${(safeConf * 100).toStringAsFixed(1)}%',
                  //           style: const TextStyle(
                  //             fontSize: 18,
                  //             fontWeight: FontWeight.w600,
                  //             color: Color(0xFF333333),
                  //           ),
                  //         ),
                  //         backgroundColor: const Color(0xFFF3F6F9),
                  //         side: const BorderSide(color: Color(0xFFE3E8EE)),
                  //       ),
                  //       if (energy != null)
                  //         Chip(
                  //           label: Text(
                  //             '에너지 ${energy.toStringAsFixed(1)}',
                  //             style: const TextStyle(
                  //               fontSize: 18,
                  //               fontWeight: FontWeight.w600,
                  //               color: Color(0xFF333333),
                  //             ),
                  //           ),
                  //           backgroundColor: const Color(0xFFF6F9FC),
                  //           side: const BorderSide(color: Color(0xFFE3E8EE)),
                  //         ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
