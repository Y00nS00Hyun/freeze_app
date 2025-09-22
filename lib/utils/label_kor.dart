String koreanizeLabel(String label) {
  final l = label.toLowerCase();
  if (l.contains('fire') || l.contains('siren') || l.contains('alarm'))
    return '화재 경보음';
  if (l.contains('glass')) return '유리 깨지는 소리';
  if (l.contains('speech') || l.contains('talk')) return '음성';
  return label.isEmpty ? '대기 중' : label;
}
