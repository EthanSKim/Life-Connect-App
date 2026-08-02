import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/responsive.dart';
import 'qr_scanner_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Map<String, dynamic> _familyAttendance = {};
  bool _isLoadingAttendance = true;
  bool _isFinalized = false;
  DateTime? _finalizedAt;
  bool _isFinalizing = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAttendance() async {
    try {
      final data = await ApiClient.get('/api/attendance/family-status');
      setState(() {
        _familyAttendance = data['households'];
        _isFinalized = data['is_finalized'] ?? false;
        _finalizedAt = data['finalized_at'] != null ? DateTime.tryParse(data['finalized_at']) : null;
        _isLoadingAttendance = false;
      });
    } on ApiException catch (e) {
      debugPrint("Attendance Load Error: ${e.message}");
      setState(() => _isLoadingAttendance = false);
    }
  }

  // 검색어와 일치하는 성도가 한 명이라도 있는 세대는 그 세대 전체(가족
  // 모두)를 함께 보여준다.
  List<MapEntry<String, dynamic>> get _filteredGroups {
    final entries = _familyAttendance.entries.toList();
    if (_searchQuery.trim().isEmpty) return entries;
    final query = _searchQuery.trim().toLowerCase();
    return entries.where((e) {
      final List<dynamic> members = e.value['members'];
      return members.any((m) => (m['name'] as String).toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _confirmFinalize() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("출석 마감"),
        content: const Text("오늘 출석을 마감하시겠습니까?\n마감 후에는 체크/해제 및 QR 스캔이 모두 불가능합니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("마감"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isFinalizing = true);
    try {
      await ApiClient.post('/api/attendance/finalize');
      await _fetchAttendance();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  Future<void> _openScanner() async {
    if (_isFinalized) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("오늘 출석은 이미 마감되었습니다.")));
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerScreen()));
    // 스캐너 화면에서 몇 명을 체크했는지 알 수 없으므로 돌아오면 항상 갱신
    _fetchAttendance();
  }

  // 개별 출석 체크/해제 (관리자가 직접, 또는 QR 스캔을 깜빡한 성도 대신)
  Future<void> _toggleAttendance(dynamic personId, bool isPresent) async {
    try {
      await ApiClient.post('/api/attendance', body: {"person_id": personId, "is_present": isPresent});
      _fetchAttendance();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // 세대 전체를 한 번에 출석 체크 (가족이 함께 도착했을 때)
  Future<void> _bulkCheckHousehold(List<dynamic> members) async {
    final ids = members.map((m) => m['id']).toList();
    try {
      await ApiClient.post('/api/attendance/bulk', body: {"person_ids": ids, "is_present": true});
      _fetchAttendance();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(title: const Text("출석 확인"), backgroundColor: const Color(0xFFF7F8FB), elevation: 0, foregroundColor: Colors.black),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingAttendance) return const Center(child: CircularProgressIndicator());
    final groups = _filteredGroups;
    final today = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return SingleChildScrollView(
      child: ResponsiveBody(
        maxWidth: 1100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "오늘, ${today.month}월 ${today.day}일 (${weekdays[today.weekday - 1]})",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ),
                if (_isFinalized)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(100)),
                    child: Text(
                      "마감 완료" + (_finalizedAt != null ? " · ${_finalizedAt!.hour.toString().padLeft(2, '0')}:${_finalizedAt!.minute.toString().padLeft(2, '0')}" : ""),
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ResponsiveFieldRow(children: [
              ElevatedButton.icon(
                onPressed: _isFinalized ? null : _openScanner,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("출석 스캐너 열기"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
              OutlinedButton.icon(
                onPressed: (_isFinalized || _isFinalizing) ? null : _confirmFinalize,
                icon: _isFinalizing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.lock_outline),
                label: const Text("완료 (출석 마감)"),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), foregroundColor: Colors.red),
              ),
            ]),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            if (groups.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Text("검색 결과가 없습니다.", style: TextStyle(color: Colors.grey)))
            else
              TwoColumnList(children: groups.map((e) => _buildAttendanceGroupCard(e.key, e.value)).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceGroupCard(String householdKey, dynamic group) {
    final householdName = group['household_name'] as String;
    final List<dynamic> members = group['members'];
    final allPresent = members.isNotEmpty && members.every((m) => m['isPresent'] == true);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFEDEEF1))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(householdName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  if (members.length > 1)
                    TextButton.icon(
                      onPressed: (_isFinalized || allPresent) ? null : () => _bulkCheckHousehold(members),
                      icon: Icon(allPresent ? Icons.check_circle : Icons.check_circle_outline, size: 18),
                      label: Text(allPresent ? "전체 출석 완료" : "전체 체크"),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF2F6FED)),
                    ),
                ],
              ),
            ),
            ...members.map<Widget>((m) => CheckboxListTile(
                  value: m['isPresent'] ?? false,
                  title: Text("${m['name']} (${m['title'] ?? '성도'})"),
                  activeColor: const Color(0xFF2F6FED),
                  onChanged: _isFinalized ? null : (v) => _toggleAttendance(m['id'], v ?? false),
                )),
          ],
        ),
      ),
    );
  }
}
