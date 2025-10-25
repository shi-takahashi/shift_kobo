import 'package:flutter/material.dart';
import '../models/announcement.dart';

/// お知らせダイアログ
class AnnouncementDialog extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback onClose;

  const AnnouncementDialog({
    super.key,
    required this.announcement,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(announcement.title),
      content: SingleChildScrollView(
        child: Text(
          announcement.message,
          style: const TextStyle(fontSize: 14),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: onClose,
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
