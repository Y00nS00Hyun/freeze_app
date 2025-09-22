// lib/widgets/empty_state.dart
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera_back_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 10),
          Text('YOLO 데이터가 없습니다.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
