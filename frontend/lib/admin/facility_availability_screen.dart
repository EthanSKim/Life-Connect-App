import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/responsive.dart';
import '../widgets/facility_icons.dart';

/// Lets an admin open/close specific 30-min slots for a specific facility on
/// a specific date, overriding the default Mon-Sat 10:00-18:00 / Sunday-
/// closed schedule (e.g. open a Sunday slot for a special event, or close a
/// normally-open weekday slot for maintenance). The backend for this
/// (GET/POST /api/facilities/:id/overrides) already existed from the
/// reservation system build-out - this screen is the UI that was never built
/// for it.
class FacilityAvailabilityScreen extends StatefulWidget {
  const FacilityAvailabilityScreen({super.key});

  @override
  State<FacilityAvailabilityScreen> createState() => _FacilityAvailabilityScreenState();
}

class _FacilityAvailabilityScreenState extends State<FacilityAvailabilityScreen> {
  List<dynamic> _facilities = [];
  dynamic _selectedFacility;
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _slots = [];
  bool _isLoadingFacilities = true;
  bool _isLoadingSlots = false;
  bool _isSaving = false;

  // 슬롯별 저장 전 임시 상태: null=기본값 사용, true=강제 열림, false=강제 닫힘.
  // "저장" 누르기 전까지는 서버에 반영되지 않는다.
  final Map<String, bool?> _pending = {};

  static const _weekdaysKo = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    _fetchFacilities();
  }

  Future<void> _fetchFacilities() async {
    try {
      final data = await ApiClient.get('/api/facilities');
      setState(() {
        _facilities = data;
        _isLoadingFacilities = false;
        if (_facilities.isNotEmpty) {
          _selectedFacility = _facilities.first;
          _fetchSlots();
        }
      });
    } on ApiException catch (e) {
      debugPrint("Facilities Load Error: ${e.message}");
      if (mounted) setState(() => _isLoadingFacilities = false);
    }
  }

  String get _dateStr =>
      "${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

  Future<void> _fetchSlots() async {
    if (_selectedFacility == null) return;
    setState(() {
      _isLoadingSlots = true;
      _pending.clear();
    });
    try {
      final data = await ApiClient.get('/api/facilities/${_selectedFacility['facility_id']}/overrides?date=$_dateStr');
      setState(() {
        _slots = data['slots'];
        _isLoadingSlots = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isLoadingSlots = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _cycleSlot(dynamic slot) {
    final start = slot['start'] as String;
    final current = _pending.containsKey(start) ? _pending[start] : slot['override'];
    setState(() {
      // 기본값 사용 -> 강제 열림 -> 강제 닫힘 -> 기본값 사용 순으로 순환
      if (current == null) {
        _pending[start] = true;
      } else if (current == true) {
        _pending[start] = false;
      } else {
        _pending[start] = null;
      }
    });
  }

  Future<void> _save() async {
    if (_selectedFacility == null || _pending.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await ApiClient.post('/api/facilities/${_selectedFacility['facility_id']}/overrides', body: {
        "date": _dateStr,
        "slots": _pending.entries.map((e) => {"start_time": e.key, "is_open": e.value}).toList(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("저장되었습니다.")));
      await _fetchSlots();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetAllToDefault() async {
    if (_selectedFacility == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("기본값으로 초기화"),
        content: Text("$_dateStr의 모든 슬롯을 기본 일정으로 되돌리시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("초기화")),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await ApiClient.post('/api/facilities/${_selectedFacility['facility_id']}/overrides', body: {
        "date": _dateStr,
        "slots": _slots.map((s) => {"start_time": s['start'], "is_open": null}).toList(),
      });
      await _fetchSlots();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchSlots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(title: const Text("예약 시간 설정"), backgroundColor: const Color(0xFFF7F8FB), elevation: 0, foregroundColor: Colors.black),
      body: _isLoadingFacilities
          ? const Center(child: CircularProgressIndicator())
          : _facilities.isEmpty
              ? const Center(child: Text("등록된 장소가 없습니다. 먼저 장소를 등록해주세요.", style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  child: ResponsiveBody(
                    maxWidth: 800,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ResponsiveFieldRow(children: [
                          DropdownButtonFormField<dynamic>(
                            value: _selectedFacility,
                            decoration: const InputDecoration(labelText: "장소"),
                            items: _facilities
                                .map((f) => DropdownMenuItem(
                                      value: f,
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(facilityIconFor(f['icon_key']), size: 18),
                                        const SizedBox(width: 8),
                                        Text(f['name']),
                                      ]),
                                    ))
                                .toList(),
                            onChanged: (f) {
                              setState(() => _selectedFacility = f);
                              _fetchSlots();
                            },
                          ),
                          InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: "날짜"),
                              child: Text("$_dateStr (${_weekdaysKo[_selectedDate.weekday - 1]})"),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        if (_isLoadingSlots)
                          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                        else ...[
                          Row(
                            children: [
                              const Text("10:00 - 18:00, 30분 단위", style: TextStyle(fontSize: 13, color: Colors.grey)),
                              const Spacer(),
                              TextButton(onPressed: _isSaving ? null : _resetAllToDefault, child: const Text("전체 기본값으로")),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _slots.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.6,
                            ),
                            itemBuilder: (context, i) => _buildSlotCell(_slots[i]),
                          ),
                          const SizedBox(height: 16),
                          _buildLegend(),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_isSaving || _pending.isEmpty) ? null : _save,
                              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                              child: _isSaving
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(_pending.isEmpty ? "변경 사항 없음" : "변경 사항 저장 (${_pending.length}개)"),
                            ),
                          ),
                        ],
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSlotCell(dynamic slot) {
    final start = slot['start'] as String;
    final pendingValue = _pending.containsKey(start) ? _pending[start] : slot['override'];
    final effectiveOpen = pendingValue ?? slot['default_open'];
    final hasOverride = pendingValue != null;
    final isDirty = _pending.containsKey(start) && _pending[start] != slot['override'];

    Color bg = effectiveOpen ? Colors.white : Colors.grey.shade100;
    Color border = hasOverride ? (effectiveOpen ? Colors.green : Colors.red) : Colors.grey.shade300;
    Color fg = effectiveOpen ? Colors.black87 : Colors.grey;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _cycleSlot(slot),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: hasOverride ? 2 : 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(start.substring(0, 5), style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
            if (isDirty)
              const Positioned(top: 4, right: 4, child: Icon(Icons.circle, size: 6, color: Color(0xFF2F6FED))),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    Widget item(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]);
    return Wrap(spacing: 16, runSpacing: 8, children: [
      item(Colors.white, "기본값(열림)"),
      item(Colors.grey.shade100, "기본값(닫힘)"),
      item(Colors.green, "강제 열림 (테두리)"),
      item(Colors.red, "강제 닫힘 (테두리)"),
    ]);
  }
}
