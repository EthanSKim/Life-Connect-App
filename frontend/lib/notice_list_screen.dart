import 'package:flutter/material.dart';
import 'api_client.dart';
import 'widgets/responsive.dart';
import 'widgets/notice_card.dart';
import 'notice_detail_screen.dart';

class NoticeListScreen extends StatefulWidget {
  const NoticeListScreen({super.key});

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  List<dynamic> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    try {
      final data = await ApiClient.get('/api/notices');
      if (mounted) {
        setState(() {
          _notices = data;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      debugPrint("공지사항 로딩 실패: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("교회 공지사항")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ResponsiveBody(
                maxWidth: 900,
                child: _notices.isEmpty
                    ? const Padding(padding: EdgeInsets.all(20), child: Text("등록된 공지사항이 없습니다.", style: TextStyle(color: Colors.grey)))
                    : TwoColumnList(
                        children: _notices
                            .map((n) => NoticeCard(
                                  notice: n,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => NoticeDetailScreen(notice: n)),
                                  ),
                                ))
                            .toList(),
                      ),
              ),
            ),
    );
  }
}
