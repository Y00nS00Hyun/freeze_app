// lib/widgets/yamnet_card.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/events.dart';

/// YAMNet 이벤트 표시 위젯(배경 박스 없이 깔끔한 흰 배경, 한국어 전용 출력)
class YamnetCard extends StatelessWidget {
  const YamnetCard({super.key, this.event});

  final YamnetEvent? event;

  @override
  Widget build(BuildContext context) {
    if (event == null) return const SizedBox.shrink();
    final e = event!;
    final normalized = _normalizeLabelAndConf(e.label, e.confidence);
    final label = normalized.$1;
    final conf = normalized.$2;
    final dir = e.direction;
    final energy = e.energy;
    final ko = _labelKo(label);
    final isNonDanger = _isNonDanger(label);
    final isDanger = e.danger ?? !isNonDanger;
    final titleColor = isDanger ? Colors.redAccent : const Color(0xFF3BB273);

    final Widget mainSymbol = isDanger
        ? Text(
            _emojiForDanger(label),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 72),
          )
        : const Icon(Icons.check_circle, color: Color(0xFF3BB273), size: 72);

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
                    isDanger ? '위험음 감지' : '안전',
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

                  const SizedBox(height: 20),

                  if (dir != null) ...[
                    const Text(
                      '방향 정보',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    Transform.rotate(
                      angle: ((dir.toDouble()) - 90) * math.pi / 180.0,
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

                  // 📊 보조 정보 (신뢰도/에너지)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Chip(
                        label: Text('신뢰도 ${(conf * 100).toStringAsFixed(1)}%'),
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

  (String, double) _normalizeLabelAndConf(String rawLabel, double rawConf) {
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

  static String _emojiForDanger(String label) {
    final s = label.toLowerCase();
    if (s.contains('siren') || s.contains('alarm') || s.contains('buzzer')) {
      return '🚨';
    }
    if (s.contains('engine') ||
        s.contains('vehicle') ||
        s.contains('truck') ||
        s.contains('motorcycle') ||
        s.contains('idling') ||
        s.contains('revving')) {
      return '🚗';
    }
    if (s.contains('car horn') ||
        s.contains('air horn') ||
        s.contains('horn') ||
        s.contains('honk')) {
      return '📣';
    }
    if (s.contains('scream') ||
        s.contains('shout') ||
        s.contains('yell') ||
        s.contains('shriek')) {
      return '😱';
    }
    if (s.contains('explosion') ||
        s.contains('bang') ||
        s.contains('blast') ||
        s.contains('boom')) {
      return '💥';
    }
    if (s.contains('glass')) return '🪟';
    if (s.contains('hiss') ||
        s.contains('gas leak') ||
        s.contains('steam leak') ||
        s.contains('air leak')) {
      return '🫧';
    }
    if (s.contains('cry') || s.contains('infant')) return '👶😭';
    return '⚠️';
  }

  static String _labelKo(String label) {
    final s = label.toLowerCase();

    // 자주 보이는 라벨 추가 매핑
    if (s.contains('silence')) return '무음(안전)';
    if (s.contains('rustle')) return '바스락 소리';
    if (s.contains('squish')) return '찌부딪히는 소리';
    if (s.contains('burst') || s.contains('pop')) return '펑/터지는 소리';
    if (s.contains('basketball') && s.contains('bounce')) return '농구공 바운스';
    if (s == 'vehicle' || s.contains('vehicle')) return '차량 소리';
    if (s.contains('sound effect')) return '효과음';

    if (s.contains('siren') || s.contains('alarm') || s.contains('buzzer')) {
      return '화재 경보음';
    }
    if (s.contains('engine') ||
        s.contains('vehicle ') ||
        s.contains('truck') ||
        s.contains('motorcycle') ||
        s.contains('idling') ||
        s.contains('revving')) {
      return '차량 엔진 소리';
    }
    if (s.contains('car horn') ||
        s.contains('air horn') ||
        s.contains('horn') ||
        s.contains('honk')) {
      return '차량 경적';
    }
    if (s.contains('scream') ||
        s.contains('shout') ||
        s.contains('yell') ||
        s.contains('shriek')) {
      return '비명 소리';
    }
    if (s.contains('cry') || s.contains('infant')) return '아기 울음';
    if (s.contains('explosion') ||
        s.contains('bang') ||
        s.contains('blast') ||
        s.contains('boom')) {
      return '폭발음';
    }
    if (s.contains('glass')) return '유리 깨짐';
    if (s.contains('hiss') ||
        s.contains('gas leak') ||
        s.contains('steam leak') ||
        s.contains('air leak')) {
      return '가스/증기 누출음';
    }
    if (s.contains('speech') ||
        s.contains('talking') ||
        s.contains('conversation') ||
        s.contains('narration') ||
        s.contains('monologue') ||
        s.contains('debate') ||
        s.contains('dialogue') ||
        s.contains('chant') ||
        s.contains('narrator') ||
        s.contains('singing')) {
      return '대화/말소리';
    }
    if (s.contains('safe')) return '위험상황 아님';
    return label.isEmpty ? '위험음 감지' : '기타 소리';
  }

  /// 비위험 판정
  static bool _isNonDanger(String label) {
    final s = label.toLowerCase();
    final isSpeechLike =
        s.contains('speech') ||
        s.contains('talking') ||
        s.contains('conversation') ||
        s.contains('narration') ||
        s.contains('monologue') ||
        s.contains('debate') ||
        s.contains('dialogue') ||
        s.contains('chant') ||
        s.contains('narrator') ||
        s.contains('singing') ||
        s.contains('silence');
    final isSafe = s.contains('safe');
    return isSpeechLike || isSafe;
  }
}
