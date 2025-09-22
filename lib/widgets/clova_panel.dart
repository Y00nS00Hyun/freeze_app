import 'package:flutter/material.dart';
import '../models/events.dart';

class ClovaPanel extends StatelessWidget {
  const ClovaPanel({super.key, this.event});
  final ClovaEvent? event;

  @override
  Widget build(BuildContext context) {
    final header = event == null ? 'CLOVA 인식 중...' : 'CLOVA 인식 결과';
    final text = event?.text ?? '...';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFDFF3F8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              header,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 18,
                shadows: const [
                  Shadow(color: Colors.black26, offset: Offset(0, 1)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontSize: 22,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
