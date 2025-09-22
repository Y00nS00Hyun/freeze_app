// lib/widgets/image_tile.dart
import 'package:flutter/material.dart';

class ImageTile extends StatelessWidget {
  const ImageTile({super.key, required this.url, this.onTap});

  final String? url;
  final VoidCallback? onTap;

  bool get _valid =>
      url != null &&
      url!.trim().isNotEmpty &&
      (Uri.tryParse(url!)?.hasScheme ?? false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _valid ? onTap : null,
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
            child: _valid
                ? Image.network(
                    url!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, color: Colors.grey),
                  )
                : const _ImagePlaceholder(),
          ),
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
