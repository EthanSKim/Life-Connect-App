import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/responsive.dart';

class NoticeFormScreen extends StatefulWidget {
  final dynamic notice; // null = 새 공지사항 작성
  const NoticeFormScreen({super.key, this.notice});

  bool get isEdit => notice != null;

  @override
  State<NoticeFormScreen> createState() => _NoticeFormScreenState();
}

class _NoticeFormScreenState extends State<NoticeFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.notice?['title'] ?? '');
    _contentController = TextEditingController(text: widget.notice?['content'] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("제목을 입력해주세요.")));
      return;
    }

    setState(() => _isSaving = true);
    final payload = {"title": _titleController.text.trim(), "content": _contentController.text.trim()};
    try {
      if (widget.isEdit) {
        await ApiClient.put('/api/notices/${widget.notice['notice_id']}', body: payload);
      } else {
        await ApiClient.post('/api/notices', body: payload);
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isEdit ? "수정되었습니다." : "공지사항이 등록되었습니다.")),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? "공지사항 수정" : "새 공지사항")),
      body: SingleChildScrollView(
        child: ResponsiveBody(
          maxWidth: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "제목"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: "내용", alignLabelWithHint: true),
                maxLines: 12,
                minLines: 8,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(widget.isEdit ? "저장" : "등록"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
