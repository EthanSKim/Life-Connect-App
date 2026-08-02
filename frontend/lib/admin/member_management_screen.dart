import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/responsive.dart';
import 'member_form_screen.dart';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  List<dynamic> _members = [];
  bool _isLoadingMembers = true;
  bool _groupedView = false; // 전체 보기(false) / 세대별 보기(true)
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    try {
      final data = await ApiClient.get('/api/members');
      setState(() {
        _members = data;
        _isLoadingMembers = false;
      });
    } on ApiException catch (e) {
      debugPrint("Members Load Error: ${e.message}");
      setState(() => _isLoadingMembers = false);
    }
  }

  // 검색어와 이름이 일치하는 성도뿐 아니라, 그 성도와 같은 세대에 속한
  // 다른 가족 구성원도 함께 보여준다 (가족 단위로 찾기 쉽도록).
  List<dynamic> get _filteredMembers {
    if (_searchQuery.trim().isEmpty) return _members;
    final query = _searchQuery.trim().toLowerCase();

    final matchedHouseholdIds = <String>{};
    final matchedWithNoHousehold = <dynamic>[];
    for (final m in _members) {
      final fullName = "${m['last_name']}${m['first_name']}".toLowerCase();
      if (fullName.contains(query)) {
        final hid = m['household_id']?.toString();
        if (hid != null) {
          matchedHouseholdIds.add(hid);
        } else {
          matchedWithNoHousehold.add(m);
        }
      }
    }

    return _members.where((m) {
      final hid = m['household_id']?.toString();
      return (hid != null && matchedHouseholdIds.contains(hid)) || matchedWithNoHousehold.contains(m);
    }).toList();
  }

  Future<void> _openMemberForm({int? personId}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => MemberFormScreen(personId: personId)),
    );
    if (changed == true) _fetchMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(title: const Text("성도 관리"), backgroundColor: const Color(0xFFF7F8FB), elevation: 0, foregroundColor: Colors.black),
      body: _isLoadingMembers
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ResponsiveBody(
                maxWidth: 1100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "이름으로 검색 (가족 전체가 함께 표시됩니다)",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Spacer(),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text("전체 보기"), icon: Icon(Icons.list)),
                            ButtonSegment(value: true, label: Text("세대별 보기"), icon: Icon(Icons.groups)),
                          ],
                          selected: {_groupedView},
                          onSelectionChanged: (s) => setState(() => _groupedView = s.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _groupedView ? _buildGroupedList() : _buildFlatList(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F6FED),
        onPressed: () => _openMemberForm(),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildFlatList() {
    final members = _filteredMembers;
    if (members.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("검색 결과가 없습니다.", style: TextStyle(color: Colors.grey)));
    return TwoColumnList(children: members.map((m) => _buildMemberCard(m)).toList());
  }

  Widget _buildMemberCard(dynamic member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFEDEEF1))),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text("${member['last_name']}${member['first_name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${member['church_title'] ?? '성도'} | ${member['life_team'] ?? '팀 없음'}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.key, size: 20, color: Colors.grey),
              tooltip: "PIN 조회",
              onPressed: () => _showMemberPin(member),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
        onTap: () => _openMemberForm(personId: int.tryParse(member['person_id'].toString())),
      ),
    );
  }

  // household_id별로 그룹화. household_id가 없는 성도는 "소속 없음" 버킷으로.
  Map<String, List<dynamic>> _groupByHousehold(List<dynamic> members) {
    final Map<String, List<dynamic>> groups = {};
    for (final m in members) {
      final key = m['household_id']?.toString() ?? 'none';
      groups.putIfAbsent(key, () => []).add(m);
    }
    return groups;
  }

  Widget _buildGroupedList() {
    final groups = _groupByHousehold(_filteredMembers);
    if (groups.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("검색 결과가 없습니다.", style: TextStyle(color: Colors.grey)));
    final entries = groups.entries.toList()
      ..sort((a, b) {
        if (a.key == 'none') return 1;
        if (b.key == 'none') return -1;
        return (a.value.first['household_name'] ?? '').compareTo(b.value.first['household_name'] ?? '');
      });

    return TwoColumnList(children: entries.map((e) => _buildHouseholdCard(e.key, e.value)).toList());
  }

  Widget _buildHouseholdCard(String householdKey, List<dynamic> members) {
    final isUngrouped = householdKey == 'none';
    final householdName = isUngrouped ? "소속 없음" : (members.first['household_name'] ?? '이름 없는 세대');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFEDEEF1))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isUngrouped ? Icons.person_off_outlined : Icons.home_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(householdName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                if (!isUngrouped)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (action) {
                      if (action == 'rename') _showRenameHouseholdDialog(householdKey, householdName);
                      if (action == 'head') _showChangeHeadDialog(householdKey, members);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text("세대 이름 변경")),
                      PopupMenuItem(value: 'head', child: Text("세대주 변경")),
                    ],
                  ),
              ],
            ),
            const Divider(height: 20),
            ...members.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _openMemberForm(personId: int.tryParse(m['person_id'].toString())),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text("${m['last_name']}${m['first_name']}", style: const TextStyle(fontSize: 14)),
                        ),
                        if (m['is_primary_contact'] == true)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFFC229), borderRadius: BorderRadius.circular(6)),
                            child: const Text("세대주", style: TextStyle(fontSize: 10, color: Color(0xFF4A2E00), fontWeight: FontWeight.w600)),
                          ),
                        if (m['relationship_to_head'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(100)),
                            child: Text(m['relationship_to_head'], style: const TextStyle(fontSize: 11, color: Color(0xFF2F6FED))),
                          ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameHouseholdDialog(String householdId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("세대 이름 변경"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "세대 이름")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text("저장")),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;

    try {
      await ApiClient.put('/api/households/$householdId', body: {"household_name": newName});
      _fetchMembers();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showChangeHeadDialog(String householdId, List<dynamic> members) async {
    final selected = await showDialog<dynamic>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("세대주 변경"),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: members
                .map((m) => ListTile(
                      title: Text("${m['last_name']}${m['first_name']}"),
                      trailing: m['is_primary_contact'] == true ? const Icon(Icons.check, color: Color(0xFF2F6FED)) : null,
                      onTap: () => Navigator.pop(context, m),
                    ))
                .toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소"))],
      ),
    );
    if (selected == null) return;

    try {
      await ApiClient.put('/api/households/$householdId', body: {"head_of_household_id": selected['person_id']});
      _fetchMembers();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showMemberPin(dynamic member) async {
    try {
      final data = await ApiClient.get('/api/members/${member['person_id']}/pin');
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("${member['last_name']}${member['first_name']}님의 PIN"),
          content: Text(
            data['pin_code'] ?? '-',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 6),
            textAlign: TextAlign.center,
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("닫기"))],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}
