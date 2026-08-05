import 'package:flutter/material.dart';

class NoticeCard extends StatelessWidget {
  final dynamic notice;
  final VoidCallback onTap;

  const NoticeCard({super.key, required this.notice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isNew = notice['is_new'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEEF1)),
      ),
      child: ListTile(
        onTap: onTap,
        title: Row(
          children: [
            if (isNew)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "NEW",
                  style: TextStyle(fontSize: 10, color: Color(0xFF4A2E00), fontWeight: FontWeight.w600),
                ),
              ),
            Expanded(
              child: Text(
                notice['title'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(notice['date'] ?? '', style: const TextStyle(color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }
}
