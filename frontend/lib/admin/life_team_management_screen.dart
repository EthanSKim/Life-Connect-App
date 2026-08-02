import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/responsive.dart';
import 'life_team_detail_screen.dart';

class LifeTeamManagementScreen extends StatefulWidget {
  const LifeTeamManagementScreen({super.key});

  @override
  State<LifeTeamManagementScreen> createState() => _LifeTeamManagementScreenState();
}

class _LifeTeamManagementScreenState extends State<LifeTeamManagementScreen> {
  List<dynamic> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiClient.get('/api/life-teams');
      setState(() {
        _teams = data;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      debugPrint("Life Teams Load Error: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDetail(dynamic team) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => LifeTeamDetailScreen(teamId: int.parse(team['life_team_id'].toString()))),
    );
    if (changed == true) _fetchTeams();
  }

  Future<void> _createTeam() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("새 라이프팀"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "라이프팀 이름"), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text("등록")),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    try {
      await ApiClient.post('/api/life-teams', body: {"name": name});
      _fetchTeams();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _renameTeam(dynamic team) async {
    final controller = TextEditingController(text: team['name']);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("라이프팀 이름 변경"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "라이프팀 이름")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text("저장")),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    try {
      await ApiClient.put('/api/life-teams/${team['life_team_id']}', body: {"name": name});
      _fetchTeams();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteTeam(dynamic team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("라이프팀 삭제"),
        content: Text("'${team['name']}'을(를) 삭제하시겠습니까?\n팀원들은 삭제되지 않고 소속만 해제됩니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("삭제", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient.delete('/api/life-teams/${team['life_team_id']}');
      _fetchTeams();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(title: const Text("라이프팀 관리"), backgroundColor: const Color(0xFFF7F8FB), elevation: 0, foregroundColor: Colors.black),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ResponsiveBody(
                maxWidth: 1100,
                child: _teams.isEmpty
                    ? const Padding(padding: EdgeInsets.all(20), child: Text("등록된 라이프팀이 없습니다.", style: TextStyle(color: Colors.grey)))
                    : TwoColumnList(children: _teams.map((t) => _buildTeamCard(t)).toList()),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F6FED),
        onPressed: _createTeam,
        child: const Icon(Icons.group_add_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildTeamCard(dynamic team) {
    final leaderFirst = team['leader_first_name'];
    final leaderLast = team['leader_last_name'];
    final leaderName = leaderFirst != null ? "$leaderLast$leaderFirst" : null;
    final memberCount = team['member_count']?.toString() ?? '0';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFEDEEF1))),
      child: ListTile(
        onTap: () => _openDetail(team),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFF0F4FF),
          child: Icon(Icons.groups_outlined, color: Color(0xFF2F6FED)),
        ),
        title: Text(team['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          leaderName != null ? "리더: $leaderName · $memberCount명" : "리더 미지정 · $memberCount명",
          style: TextStyle(color: leaderName != null ? Colors.grey.shade700 : Colors.grey),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (action) {
            if (action == 'rename') _renameTeam(team);
            if (action == 'delete') _deleteTeam(team);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'rename', child: Text("이름 변경")),
            PopupMenuItem(value: 'delete', child: Text("삭제")),
          ],
        ),
      ),
    );
  }
}
