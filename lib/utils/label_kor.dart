String koreanizeLabel(String label) {
  final raw = label.trim();
  final s = raw.toLowerCase();

  // 비어있으면
  if (s.isEmpty) return '대기 중';

  // 간단 헬퍼
  bool hasAny(List<String> keys) => keys.any((k) => s.contains(k));

  // ✅ 안전/무음/말소리
  if (hasAny(['safe'])) return '위험상황 아님';
  if (hasAny(['silence', 'quiet'])) return '무음';
  if (hasAny([
    'speech',
    'talk',
    'conversation',
    'narration',
    'monologue',
    'debate',
    'dialogue',
    'chant',
    'narrator',
    'singing',
    'vocal',
  ]))
    return '대화/말소리';

  // ✅ 사이렌/화재 경보
  // - 데이터에 따라 'smoke alarm', 'fire alarm', 'siren', 'alarm beeping' 등 다양
  final isSiren = hasAny([
    'siren',
    'emergency siren',
    'police siren',
    'ambulance',
  ]);
  final isFireAlarm =
      hasAny(['smoke alarm', 'fire alarm', 'alarm bell']) ||
      (s.contains('alarm') && hasAny(['smoke', 'fire', 'beep', 'beeping']));
  if (isSiren) return '사이렌';
  if (isFireAlarm) return '화재 경보음';

  // ✅ 차량/엔진/경적
  if (hasAny([
    'engine',
    'vehicle ',
    'truck',
    'motorcycle',
    'idling',
    'revving',
  ])) {
    return '차량 엔진 소리';
  }
  if (hasAny(['car horn', 'air horn', 'horn', 'honk'])) return '차량 경적';

  // ✅ 비명/울음/폭발/유리/누출
  if (hasAny(['scream', 'shout', 'yell', 'shriek'])) return '비명 소리';
  if (hasAny(['infant', 'baby cry', 'crying'])) return '아기 울음';
  if (hasAny(['explosion', 'bang', 'blast', 'boom'])) return '폭발음';
  if (hasAny(['glass'])) return '유리 깨짐';
  if (hasAny(['hiss', 'gas leak', 'steam leak', 'air leak']))
    return '가스/증기 누출음';

  // ✅ 잡음/효과음/기타
  if (hasAny(['rustle'])) return '바스락 소리';
  if (hasAny(['squish'])) return '찌부딪히는 소리';
  if (hasAny(['burst', 'pop'])) return '펑/터지는 소리';
  if (hasAny(['sound effect', 'sfx'])) return '효과음';
  if (s == 'vehicle' || s.contains('vehicle')) return '차량 소리';

  // ⛑ 매핑 실패: 원본 라벨도 함께 보여 줘서 디버깅/식별 용이
  return '기타 소리 (${raw.isEmpty ? 'unknown' : raw})';
}
