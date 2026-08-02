import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/responsive.dart';

class LifeTeamDetailScreen extends StatefulWidget {
  final int teamId;
  const LifeTeamDetailScreen({super.key, required this.teamId});

  @override
  State<LifeTeamDetailScreen> createState() => _LifeTeamDetailScreenState();
}

class _LifeTeamDetailScreenState extends State<LifeTeamDetailScreen> {
  dynamic _team;
  List<dynamic> _members = [];
  bool _isLoading = true;
  bool _changed = false; // 관리 화면 목록을 갱신해야 하는지 (이름 변경 등)

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiClient.get('/api/life-teams/${widget.teamId}');
      setState(() {
        _team = data['team'];
        _members = data['members'];
        _isLoading = false;
      });
    } on ApiException catch (e) {
      debugPrint("Life Team Detail Load Error: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isLeader(dynamic member) {
    if (_team == null || _team['leader_id'] == null) return false;
    return _team['leader_id'].toString() == member['person_id'].toString();
  }

  Future<void> _setLeader(dynamic member) async {
    try {
      await ApiClient.post('/api/life-teams/${widget.teamId}/leader', body: {"person_id": member['person_id']});
      _changed = true;
      _fetchDetail();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _removeLeader() async {
    try {
      await ApiClient.post('/api/life-teams/${widget.teamId}/leader', body: {"person_id": null});
      _changed = true;
      _fetchDetail();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FB),
        appBar: AppBar(
          title: Text(_team?['name'] ?? "라이프팀"),
          backgroundColor: const Color(0xFFF7F8FB),
          elevation: 0,
          foregroundColor: Colors.black,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context, _changed)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: ResponsiveBody(
                  maxWidth: 800,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_team?['name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text("${_members.length}명", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 20),
                      if (_members.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: Text("아직 팀원이 없습니다.\n성도 관리 화면에서 라이프팀을 배정해주세요.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ..._members.map((m) => _buildMemberRow(m)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMemberRow(dynamic member) {
    final isLeader = _isLeader(member);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isLeader ? const Color(0xFF2F6FED) : const Color(0xFFEDEEF1), width: isLeader ? 1.5 : 1),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLeader ? const Color(0xFF2F6FED) : const Color(0xFFF0F4FF),
          child: Icon(Icons.person, color: isLeader ? Colors.white : const Color(0xFF2F6FED)),
        ),
        title: Text("${member['last_name']}${member['first_name']}", style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: member['church_title'] != null ? Text(member['church_title']) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isLeader ? const Color(0xFFFFC229) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                isLeader ? "리더" : "멤버",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isLeader ? const Color(0xFF4A2E00) : Colors.grey.shade700,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (action) {
                if (action == 'set_leader') _setLeader(member);
                if (action == 'remove_leader') _removeLeader();
              },
              itemBuilder: (context) => [
                if (!isLeader) const PopupMenuItem(value: 'set_leader', child: Text("리더로 지정")),
                if (isLeader) const PopupMenuItem(value: 'remove_leader', child: Text("리더 해제")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
