import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 공용 YOLO 카드
/// - 이미지 로드 성공 시에만 렌더링(프로빙)
/// - 아래 메타(라벨/칩)는 숨김, '다운로드 하기' 버튼만 유지
class YoloCard extends StatefulWidget {
  const YoloCard({
    super.key,
    required this.imageUrl, // 실제 썸네일/이미지 URL (필수)
    this.fileName, // 상단에 표시(클릭 시 링크 열기)
    this.linkUrl, // '다운로드 하기' 및 탭 시 열 링크(없으면 imageUrl 사용)
  });

  final String imageUrl;
  final String? fileName;
  final String? linkUrl;

  @override
  State<YoloCard> createState() => _YoloCardState();
}

class _YoloCardState extends State<YoloCard> {
  bool _imageOk = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _probeImage(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant YoloCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _disposeStream();
      _imageOk = false;
      _probeImage(widget.imageUrl);
    }
  }

  void _probeImage(String url) {
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

  String get _targetUrl {
    final t = (widget.linkUrl?.trim().isNotEmpty == true)
        ? widget.linkUrl!.trim()
        : widget.imageUrl.trim();
    return t;
  }

  bool get _hasLink => (Uri.tryParse(_targetUrl)?.hasScheme ?? false);

  Future<void> _openExternal(BuildContext context) async {
    if (!_hasLink) return;
    final ok = await launchUrl(
      Uri.parse(_targetUrl),
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
    if (!_imageOk) return const SizedBox.shrink();

    final hasLink = _hasLink;

    return Card(
      elevation: 4,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.fileName != null && widget.fileName!.isNotEmpty) ...[
              InkWell(
                onTap: hasLink ? () => _openExternal(context) : null,
                borderRadius: BorderRadius.circular(6),
                child: Text(
                  widget.fileName!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: hasLink ? const Color(0xFF78B8C4) : Colors.grey,
                    decoration: hasLink
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    decorationColor: const Color(0xFF78B8C4),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            GestureDetector(
              onTap: hasLink ? () => _openExternal(context) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 190, 213, 215),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(widget.imageUrl, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (hasLink)
              TextButton.icon(
                onPressed: () => _openExternal(context),
                icon: const Icon(Icons.open_in_new, color: Color(0xFF78B8C4)),
                label: const Text(
                  '다운로드 하기',
                  style: TextStyle(color: Color(0xFF78B8C4)),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF78B8C4),
                ),
              ),
            // ⬆️ 버튼만 유지, 그 외 라벨/칩 등은 렌더링하지 않음
          ],
        ),
      ),
    );
  }
}
