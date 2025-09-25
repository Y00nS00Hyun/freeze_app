// lib/widgets/clova_panel.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/events.dart';

class ClovaPanel extends StatelessWidget {
  const ClovaPanel({super.key, this.event});
  final ClovaEvent? event;

  @override
  Widget build(BuildContext context) {
    final header = event == null ? '인식 중...' : '인식 결과';
    final text = event?.text ?? '...';

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 210, 229, 234),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              header,
              style: GoogleFonts.gowunDodum(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 40,
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
                  style: GoogleFonts.gowunDodum(
                    color: const Color(0xFF4A4A4A),
                    fontSize: 45,
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
