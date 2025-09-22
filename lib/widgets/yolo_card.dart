// lib/widgets/yolo_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/yolo_utils.dart';

class YoloCard extends StatelessWidget {
  const YoloCard({
    super.key,
    required this.label,
    required this.bbox,
    this.fileName,
    this.imageUrl,
  });

  final String label;
  final List<num> bbox;
  final String? fileName;
  final String? imageUrl;

  bool get _hasLink =>
      imageUrl != null &&
      imageUrl!.trim().isNotEmpty &&
      (Uri.tryParse(imageUrl!)?.hasScheme ?? false);

  Future<void> _openExternal(BuildContext context) async {
    if (!_hasLink) return;
    final ok = await launchUrl(
      Uri.parse(imageUrl!),
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
            if (fileName != null && fileName!.isNotEmpty) ...[
              InkWell(
                onTap: hasLink ? () => _openExternal(context) : null,
                borderRadius: BorderRadius.circular(6),
                child: Text(
                  fileName!,
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
                  color: const Color(0xFFD9F0F1),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: hasLink
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          )
                        : const _ImagePlaceholder(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              koreanizeLabel(label),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),

            if (bbox.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      'bbox ${bbox.map((e) => e.toStringAsFixed(0)).toList()}',
                    ),
                    backgroundColor: const Color(0xFFF7FBFF),
                    side: const BorderSide(color: Color(0xFFE0EEF5)),
                  ),
                ],
              ),

            if (hasLink) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _openExternal(context),
                icon: const Icon(Icons.open_in_new, color: Color(0xFF78B8C4)),
                label: const Text(
                  '링크로 열기',
                  style: TextStyle(color: Color(0xFF78B8C4)),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF78B8C4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFF7FA),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
          size: 38,
        ),
      ),
    );
  }
}
