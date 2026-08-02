import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/responsive.dart';
import '../widgets/facility_icons.dart';

class FacilityManagementScreen extends StatefulWidget {
  const FacilityManagementScreen({super.key});

  @override
  State<FacilityManagementScreen> createState() => _FacilityManagementScreenState();
}

class _FacilityManagementScreenState extends State<FacilityManagementScreen> {
  List<dynamic> _facilities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFacilities();
  }

  Future<void> _fetchFacilities() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiClient.get('/api/facilities?include_inactive=true');
      setState(() {
        _facilities = data;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      debugPrint("Facilities Load Error: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openForm({dynamic facility}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FacilityFormSheet(facility: facility),
    );
    if (changed == true) _fetchFacilities();
  }

  Future<void> _confirmDelete(dynamic facility) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("장소 삭제"),
        content: Text("'${facility['name']}'을(를) 삭제하시겠습니까?\n기존 예약 이력은 보존되며, 성도용 예약 목록에서만 제외됩니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient.delete('/api/facilities/${facility['facility_id']}');
      _fetchFacilities();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _restore(dynamic facility) async {
    try {
      await ApiClient.post('/api/facilities/${facility['facility_id']}/restore');
      _fetchFacilities();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(title: const Text("장소 관리"), backgroundColor: const Color(0xFFF7F8FB), elevation: 0, foregroundColor: Colors.black),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ResponsiveBody(
                maxWidth: 1100,
                child: _facilities.isEmpty
                    ? const Padding(padding: EdgeInsets.all(20), child: Text("등록된 장소가 없습니다.", style: TextStyle(color: Colors.grey)))
                    : TwoColumnList(children: _facilities.map((f) => _buildFacilityCard(f)).toList()),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F6FED),
        onPressed: () => _openForm(),
        child: const Icon(Icons.add_location_alt_outlined, color: Colors.white),
      ),
    );
  }

  Future<void> _toggleReservable(dynamic facility, bool value) async {
    try {
      await ApiClient.post('/api/facilities/${facility['facility_id']}/toggle-reservable', body: {"is_reservable": value});
      _fetchFacilities();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _buildFacilityCard(dynamic facility) {
    final isActive = facility['is_active'] ?? true;
    final isReservable = facility['is_reservable'] ?? true;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFEDEEF1))),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.5,
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFF0F4FF),
                child: Icon(facilityIconFor(facility['icon_key']), color: const Color(0xFF2F6FED)),
              ),
              title: Text(facility['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                [
                  if (!isActive) "삭제됨" else if (!isReservable) "예약 비활성화됨",
                  if (facility['description'] != null && facility['description'].isNotEmpty) facility['description'],
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive) ...[
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _openForm(facility: facility)),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => _confirmDelete(facility)),
                  ] else
                    TextButton(onPressed: () => _restore(facility), child: const Text("복구")),
                ],
              ),
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.event_available_outlined, size: 16, color: isReservable ? const Color(0xFF2F6FED) : Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      isReservable ? "예약 가능" : "예약 불가 (성도용 목록에는 계속 표시됨)",
                      style: TextStyle(fontSize: 12, color: isReservable ? const Color(0xFF2F6FED) : Colors.grey),
                    ),
                    const Spacer(),
                    Switch(
                      value: isReservable,
                      activeColor: const Color(0xFF2F6FED),
                      onChanged: (v) => _toggleReservable(facility, v),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FacilityFormSheet extends StatefulWidget {
  final dynamic facility; // null = 새 장소 등록
  const _FacilityFormSheet({this.facility});

  @override
  State<_FacilityFormSheet> createState() => _FacilityFormSheetState();
}

class _FacilityFormSheetState extends State<_FacilityFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String _iconKey = 'church';
  bool _isSaving = false;

  bool get _isEdit => widget.facility != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.facility?['name'] ?? '');
    _descriptionController = TextEditingController(text: widget.facility?['description'] ?? '');
    _iconKey = widget.facility?['icon_key'] ?? 'church';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("장소 이름을 입력해주세요.")));
      return;
    }
    setState(() => _isSaving = true);
    final payload = {
      "name": _nameController.text.trim(),
      "icon_key": _iconKey,
      "description": _descriptionController.text.trim(),
    };
    try {
      if (_isEdit) {
        await ApiClient.put('/api/facilities/${widget.facility['facility_id']}', body: payload);
      } else {
        await ApiClient.post('/api/facilities', body: payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEdit ? "장소 수정" : "새 장소 등록", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: "장소 이름")),
              const SizedBox(height: 12),
              TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: "설명 (선택)")),
              const SizedBox(height: 16),
              const Text("아이콘", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kFacilityIcons.entries.map((e) {
                  final selected = _iconKey == e.key;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _iconKey = e.key),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF2F6FED) : const Color(0xFFF7F8FB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? const Color(0xFF2F6FED) : const Color(0xFFEDEEF1)),
                      ),
                      child: Icon(e.value.icon, color: selected ? Colors.white : Colors.grey.shade700),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isEdit ? "저장" : "등록"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
