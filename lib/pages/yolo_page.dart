import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_fonts/google_fonts.dart';
import '../models/events.dart';
import '../widgets/yolo_card.dart';

class YoloPage extends StatefulWidget {
  const YoloPage({
    super.key,
    required this.items,
    this.imageBaseUrl, // 예: http://<host>:<port>
  });

  final List<YoloEvent> items;
  final String? imageBaseUrl;

  @override
  State<YoloPage> createState() => _YoloPageState();
}

class _YoloPageState extends State<YoloPage> {
  DateTime? _selectedDate;

  // URL 정규화(절대/상대/127.0.0.1 교정)
  String? _normalizeUrl(String? url) {
    if (url == null) return null;
    final s = url.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('data:')) return s;

    final baseStr = widget.imageBaseUrl?.trim();
    final base = (baseStr != null && baseStr.isNotEmpty)
        ? Uri.tryParse(baseStr)
        : null;

    final u = Uri.tryParse(s);
    if (u != null && u.hasScheme) {
      final host = u.host.toLowerCase();
      if ((host == '127.0.0.1' || host == 'localhost') && base != null) {
        return Uri(
          scheme: base.scheme,
          host: base.host,
          port: base.hasPort ? base.port : null,
          path: u.path,
          query: u.query.isEmpty ? null : u.query,
          fragment: u.fragment.isEmpty ? null : u.fragment,
        ).toString();
      }
      return s;
    }

    if (base == null) return null;
    return base.resolve(s).toString();
  }

  // 썸네일 선택: thumbnail > jpg/png file > mp4→jpg 유추 > time 기반 파일명
  String? _pickDisplayImage(YoloEvent y) {
    final thumb = y.thumbnail?.trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;

    final file = (y.file ?? '').trim();
    final lower = file.toLowerCase();

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png')) {
      return file;
    }

    if (lower.endsWith('.mp4')) {
      return file.replaceFirst(RegExp(r'\.mp4$', caseSensitive: false), '.jpg');
    }

    final name = _fileNameFromEpoch(y.time);
    if (name != null && widget.imageBaseUrl != null) {
      final base = widget.imageBaseUrl!.replaceAll(RegExp(r'/+$'), '');
      return '$base/$name';
    }
    return null;
  }

  String? _fileNameFromEpoch(int? sec) {
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

  String _dateKeyFromEpoch(int? epochSec) {
    if (epochSec == null) return 'unknown';
    final dt = DateTime.fromMillisecondsSinceEpoch(
      epochSec * 1000,
      isUtc: true,
    ).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  bool _isSameCalendarDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate(BuildContext context, List<YoloEvent> pool) async {
    final times = pool.map((e) => e.time ?? 0).where((t) => t > 0).toList();
    times.sort();
    final now = DateTime.now();
    final first = times.isEmpty
        ? now.subtract(const Duration(days: 365))
        : DateTime.fromMillisecondsSinceEpoch(
            times.first * 1000,
            isUtc: true,
          ).toLocal();
    final last = times.isEmpty
        ? now
        : DateTime.fromMillisecondsSinceEpoch(
            times.last * 1000,
            isUtc: true,
          ).toLocal();

    final initial = _selectedDate ?? last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(last.year, last.month, last.day),
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
      locale: const Locale('ko', 'KR'),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    // 1) 유효 항목만 필터
    final visibleItems = <YoloEvent>[];
    for (final y in widget.items) {
      final rawLabel = y.label.trim();
      if (rawLabel.isEmpty || rawLabel.toLowerCase() == 'null') continue;

      final raw = _pickDisplayImage(y);
      final url = _normalizeUrl(raw);
      final ok = url != null && (Uri.tryParse(url)?.hasScheme ?? false);
      if (!ok) continue;

      if (_selectedDate != null && y.time != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(
          y.time! * 1000,
          isUtc: true,
        ).toLocal();
        if (!_isSameCalendarDate(dt, _selectedDate!)) continue;
      }
      visibleItems.add(y);
    }

    // 2) 시간 내림차순 정렬
    visibleItems.sort((a, b) => (b.time ?? 0).compareTo(a.time ?? 0));

    // 3) 날짜별 그룹핑
    final Map<String, List<YoloEvent>> grouped = {};
    for (final y in visibleItems) {
      final key = _dateKeyFromEpoch(y.time);
      grouped.putIfAbsent(key, () => []).add(y);
    }
    final sectionKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final appBar = AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFFF9FBFD),
      centerTitle: true,
      title: Text(
        'SOUND SENSE',
        style: GoogleFonts.gowunDodum(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: const Color(0xFF78B8C4),
        ),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF78B8C4)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.3),
        child: Container(
          color: const Color.fromARGB(255, 151, 198, 206),
          height: 1.3,
        ),
      ),
      actions: [
        IconButton(
          tooltip: '날짜 선택',
          onPressed: () => _pickDate(context, widget.items),
          icon: const Icon(Icons.calendar_today_outlined, color: Colors.grey),
        ),
        if (_selectedDate != null)
          IconButton(
            tooltip: '필터 해제',
            onPressed: () => setState(() => _selectedDate = null),
            icon: const Icon(Icons.clear, color: Colors.grey),
          ),
      ],
    );

    if (visibleItems.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FBFD),
        appBar: appBar,
        body: const _EmptyState(),
      );
    }

    final selectedDateChip = (_selectedDate != null)
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(
                  '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')} 선택됨',
                ),
                deleteIcon: const Icon(Icons.close),
                onDeleted: () => setState(() => _selectedDate = null),
                backgroundColor: const Color(0xFFE8F4F7),
                side: const BorderSide(color: Color(0xFFB7D7DE)),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFD),
      appBar: appBar,
      body: Column(
        children: [
          selectedDateChip,
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sectionKeys.fold<int>(
                0,
                (sum, k) => sum + 1 + grouped[k]!.length,
              ),
              itemBuilder: (context, index) {
                int cursor = 0;
                for (final key in sectionKeys) {
                  if (index == cursor) {
                    return _SectionHeader(title: key);
                  }
                  cursor++;

                  final list = grouped[key]!;
                  final localIndex = index - cursor;
                  if (localIndex >= 0 && localIndex < list.length) {
                    final y = list[localIndex];

                    final rawDisplayImageUrl = _pickDisplayImage(y);
                    final rawLinkUrl = (y.file?.trim().isNotEmpty == true)
                        ? y.file!.trim()
                        : rawDisplayImageUrl;

                    final imageUrl = _normalizeUrl(rawDisplayImageUrl)!;
                    final linkUrl = _normalizeUrl(rawLinkUrl);

                    debugPrint(
                      '[YOLO] $key label=${y.label} time=${y.time} '
                      'file=${y.file} thumb=${y.thumbnail} → display=$imageUrl | link=$linkUrl',
                    );

                    return YoloCard(
                      imageUrl: imageUrl,
                      linkUrl: linkUrl, // 버튼/탭 타깃
                      fileName: _fileNameFromEpoch(y.time),
                    );
                  }
                  cursor += list.length;
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        title, // 날짜
        style: GoogleFonts.gowunDodum(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: const Color.fromARGB(255, 50, 50, 50),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera_back_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 10),
          Text('현재 등록된 사진이 없습니다', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
