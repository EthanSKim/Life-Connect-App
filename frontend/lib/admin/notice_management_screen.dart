import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/responsive.dart';
import 'notice_form_screen.dart';

class NoticeManagementScreen extends StatefulWidget {
  const NoticeManagementScreen({super.key});

  @override
  State<NoticeManagementScreen> createState() => _NoticeManagementScreenState();
}

class _NoticeManagementScreenState extends State<NoticeManagementScreen> {
  List<dynamic> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiClient.get('/api/notices?include_inactive=true');
      setState(() {
        _notices = data;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      debugPrint("Notices Load Error: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openForm({dynamic notice}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => NoticeFormScreen(notice: notice)),
    );
    if (changed == true) _fetchNotices();
  }

  Future<void> _confirmDelete(dynamic notice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("공지사항 삭제"),
        content: Text("'${notice['title']}'을(를) 삭제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("삭제", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient.delete('/api/notices/${notice['notice_id']}');
      _fetchNotices();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _restore(dynamic notice) async {
    try {
      await ApiClient.post('/api/notices/${notice['notice_id']}/restore');
      _fetchNotices();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(title: const Text("공지사항 관리"), backgroundColor: const Color(0xFFF7F8FB), elevation: 0, foregroundColor: Colors.black),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ResponsiveBody(
                maxWidth: 1100,
                child: _notices.isEmpty
                    ? const Padding(padding: EdgeInsets.all(20), child: Text("등록된 공지사항이 없습니다.", style: TextStyle(color: Colors.grey)))
                    : TwoColumnList(children: _notices.map((n) => _buildNoticeCard(n)).toList()),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F6FED),
        onPressed: () => _openForm(),
        child: const Icon(Icons.campaign_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildNoticeCard(dynamic notice) {
    final isActive = notice['is_active'] ?? true;
    final isNew = notice['is_new'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFEDEEF1))),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.5,
        child: ListTile(
          onTap: isActive ? () => _openForm(notice: notice) : null,
          title: Row(
            children: [
              if (isNew && isActive)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFFC229), borderRadius: BorderRadius.circular(6)),
                  child: const Text("NEW", style: TextStyle(fontSize: 10, color: Color(0xFF4A2E00), fontWeight: FontWeight.w600)),
                ),
              Expanded(child: Text(notice['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          subtitle: Text(isActive ? (notice['date'] ?? '') : "삭제됨 · ${notice['date'] ?? ''}"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isActive) ...[
                IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _openForm(notice: notice)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => _confirmDelete(notice)),
              ] else
                TextButton(onPressed: () => _restore(notice), child: const Text("복구")),
            ],
          ),
        ),
      ),
    );
  }
}
