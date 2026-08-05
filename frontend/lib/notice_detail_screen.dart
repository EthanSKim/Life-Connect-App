import 'package:flutter/material.dart';
import '../widgets/responsive.dart';

class NoticeDetailScreen extends StatelessWidget {
  final dynamic notice;
  const NoticeDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("공지사항")),
      body: SingleChildScrollView(
        child: ResponsiveBody(
          maxWidth: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notice['title'] ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                notice['date'] ?? '',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Text(
                (notice['content'] == null || (notice['content'] as String).trim().isEmpty)
                    ? "내용이 없습니다."
                    : notice['content'],
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
