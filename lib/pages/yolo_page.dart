// lib/pages/yolo_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_fonts/google_fonts.dart';
import '../models/events.dart';

class YoloPage extends StatelessWidget {
  const YoloPage({
    super.key,
    required this.items,
    this.imageBaseUrl, // 예: http://<host>:<port>
  });

  final List<YoloEvent> items;
  final String? imageBaseUrl;

  // URL 정규화(절대/상대/127.0.0.1 교정)
  String? _normalizeUrl(String? url) {
    if (url == null) return null;
    final s = url.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('data:')) return s;

    final baseStr = imageBaseUrl?.trim();
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
      // 같은 경로에서 확장자만 jpg로
      final a = file.replaceFirst(
        RegExp(r'\.mp4$', caseSensitive: false),
        '.jpg',
      );
      return a;
    }

    final name = _fileNameFromEpoch(y.time);
    if (name != null && imageBaseUrl != null) {
      final base = imageBaseUrl!.replaceAll(RegExp(r'/+$'), '');
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

  @override
  Widget build(BuildContext context) {
    final visibleItems = <YoloEvent>[];
    for (final y in items) {
      // ★ label 유효성 체크(비어있거나 "null"은 스킵)
      final rawLabel = y.label.trim();
      if (rawLabel.isEmpty || rawLabel.toLowerCase() == 'null') {
        continue;
      }

      final raw = _pickDisplayImage(y);
      final url = _normalizeUrl(raw);
      final ok = url != null && (Uri.tryParse(url)?.hasScheme ?? false);
      if (ok) visibleItems.add(y);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF9FBFD),
        centerTitle: true,
        title: Text(
          'SOUND SENSE',
          style: GoogleFonts.gowunDodum(
            fontSize: 16, // 글씨 크기 축소
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
      ),
      body: visibleItems.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visibleItems.length,
              itemBuilder: (context, i) {
                final y = visibleItems[i];

                final rawDisplayImageUrl = _pickDisplayImage(y);
                final rawLinkUrl = (y.file?.trim().isNotEmpty == true)
                    ? y.file!.trim()
                    : rawDisplayImageUrl;

                final imageUrl = _normalizeUrl(
                  rawDisplayImageUrl,
                )!; // null 아님(1차 필터됨)
                final linkUrl = _normalizeUrl(rawLinkUrl);

                debugPrint(
                  '[YOLO] #$i label=${y.label} time=${y.time} '
                  'file=${y.file} thumb=${y.thumbnail} '
                  '→ displayImage=$imageUrl | link=$linkUrl',
                );

                // 2차: 카드 내부에서 실제 이미지 로딩 확인 → 실패면 자체적으로 숨김
                return _YoloCard(
                  label: y.label,
                  bbox: y.bbox,
                  fileName: _fileNameFromEpoch(y.time),
                  displayImageUrl: imageUrl,
                  linkUrl: linkUrl,
                );
              },
            ),
    );
  }
}

/// 실제 이미지 로딩에 성공한 경우에만 자신을 렌더링하는 카드
class _YoloCard extends StatefulWidget {
  const _YoloCard({
    required this.label,
    required this.bbox,
    required this.fileName,
    required this.displayImageUrl,
    required this.linkUrl,
  });

  final String label;
  final List<num> bbox;
  final String? fileName;
  final String displayImageUrl; // ← non-null
  final String? linkUrl;

  @override
  State<_YoloCard> createState() => _YoloCardState();
}

class _YoloCardState extends State<_YoloCard> {
  bool _imageOk = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _probeImage(widget.displayImageUrl);
  }

  @override
  void didUpdateWidget(covariant _YoloCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.displayImageUrl != widget.displayImageUrl) {
      _disposeStream();
      _imageOk = false;
      _timedOut = false;
      _probeImage(widget.displayImageUrl);
    }
  }

  void _probeImage(String url) {
    // 3초 타임아웃(네트워크 정지 등)
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || _imageOk) return;
      setState(() => _timedOut = true);
    });

    final provider = NetworkImage(url);
    final stream = provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener(
      (ImageInfo _, bool __) {
        if (!mounted) return;
        setState(() => _imageOk = true);
      },
      onError: (dynamic _, StackTrace? __) {
        if (!mounted) return;
        setState(() => _imageOk = false);
      },
    );
    stream.addListener(_listener!);
    _stream = stream;
  }

  void _disposeStream() {
    if (_listener != null && _stream != null) {
      _stream!.removeListener(_listener!);
    }
    _listener = null;
    _stream = null;
  }

  @override
  void dispose() {
    _disposeStream();
    super.dispose();
  }

  Future<void> _openExternal(BuildContext context) async {
    final target = widget.linkUrl;
    if (target == null || target.trim().isEmpty) return;
    final ok = await launchUrl(
      Uri.parse(target),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 이미지 실패/타임아웃이면 카드 자체를 숨김
    if (!_imageOk) {
      // 타임아웃 되었거나 에러가 확정된 경우만 숨김.
      // 로딩 중이면 공간 차지 안 하도록 shrink.
      return const SizedBox.shrink();
    }

    final hasLink =
        widget.linkUrl != null &&
        widget.linkUrl!.trim().isNotEmpty &&
        (Uri.tryParse(widget.linkUrl!)?.hasScheme ?? false);

    return Card(
      elevation: 4,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.fileName != null) ...[
              InkWell(
                onTap: hasLink ? () => _openExternal(context) : null,
                child: Text(
                  widget.fileName!,
                  style: TextStyle(
                    fontSize: 16,
                    color: hasLink ? const Color(0xFF5AAFC0) : Colors.grey,
                    decoration: hasLink
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    decorationColor: hasLink
                        ? const Color(0xFF5AAFC0)
                        : Colors.transparent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 실제 이미지
            GestureDetector(
              onTap: hasLink ? () => _openExternal(context) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      widget.displayImageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            Text(
              _koreanizeLabel(widget.label),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),

            if (widget.bbox.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      'bbox ${widget.bbox.map((e) => e.toStringAsFixed(0)).toList()}',
                    ),
                    backgroundColor: const Color.fromARGB(255, 182, 208, 213),
                    side: const BorderSide(color: Color(0xFFE0EEF5)),
                  ),
                ],
              ),

            if (hasLink) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _openExternal(context),
                icon: const Icon(Icons.open_in_new),
                label: const Text('다운로드 하기'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _koreanizeLabel(String l) {
    final s = l.toLowerCase();
    if (s.contains('bus')) return '버스';
    if (s.contains('car')) return '자동차';
    if (s.contains('person')) return '사람';
    if (s.contains('bicycle')) return '자전거';
    if (s.contains('truck')) return '트럭';
    return l;
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
