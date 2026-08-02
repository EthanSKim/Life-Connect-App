import 'package:flutter/material.dart';
import 'api_client.dart';

const List<String> _weekdayLabelsKo = ['일', '월', '화', '수', '목', '금', '토'];

class FacilityBookingScreen extends StatefulWidget {
  final Map<String, dynamic> facility;
  final int personId;

  const FacilityBookingScreen({
    super.key,
    required this.facility,
    required this.personId,
  });

  @override
  State<FacilityBookingScreen> createState() => _FacilityBookingScreenState();
}

class _FacilityBookingScreenState extends State<FacilityBookingScreen> {
  late DateTime _selectedDate;
  bool _isLoading = true;
  String? _loadError;
  List<dynamic> _slots = [];
  Map<String, dynamic>? _myActiveReservation;
  bool _isReservable = true;

  int? _rangeStart;
  int? _rangeEnd;
  bool _isSubmitting = false;

  final ScrollController _dateStripController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _isReservable = widget.facility['is_reservable'] ?? true;
    _fetchAvailability();
  }

  String get _dateStr =>
      "${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

  Future<void> _fetchAvailability() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _rangeStart = null;
      _rangeEnd = null;
    });
    try {
      final data = await ApiClient.get(
        '/api/facilities/${widget.facility['facility_id']}/availability?date=$_dateStr',
      );
      if (!mounted) return;
      setState(() {
        _slots = data['slots'];
        _myActiveReservation = data['my_active_reservation'];
        _isReservable = data['is_reservable'] ?? true;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Theme.of(context).primaryColor,
      ),
    );
  }

  void _onSlotTap(int index) {
    if (_isSubmitting) return; // 이전 예약 요청이 진행 중이면 추가 선택을 막는다
    final slot = _slots[index];
    final status = slot['status'];

    if (status == 'mine') {
      _confirmCancel(slot['reservation_id']);
      return;
    }
    if (status != 'available') return; // past / closed / booked(다른 사람) -> 탭 불가
    if (_myActiveReservation != null) {
      // 조용히 막기만 하지 않고, 실제로 새 예약을 시도하는 이 시점에만
      // 안내한다 (예약 성공 직후 바로 뜨는 배너는 실패처럼 보일 수 있음).
      _showSnack("이 장소는 오늘 이미 예약하셨습니다. 새로 예약하려면 먼저 기존 예약을 취소해주세요.", isError: true);
      return;
    }

    bool rangeCompleted = false;

    setState(() {
      // 이미 범위가 완성된 상태(시작+종료 모두 선택됨)에서 다시 탭하면 새로 선택 시작
      if (_rangeStart != null && _rangeEnd != null) {
        _rangeStart = index;
        _rangeEnd = null;
        return;
      }

      // 1번째 탭: 시작 시간만 지정하고 종료 시간 선택을 기다림
      if (_rangeStart == null) {
        _rangeStart = index;
        _rangeEnd = null;
        return;
      }

      // 2번째 탭: 종료 시간 지정 -> 범위 완성 (같은 슬롯을 다시 누르면 30분만 예약)
      final lo = index < _rangeStart! ? index : _rangeStart!;
      final hi = index < _rangeStart! ? _rangeStart! : index;
      final allAvailable = List.generate(hi - lo + 1, (i) => lo + i)
          .every((i) => _slots[i]['status'] == 'available');

      if (allAvailable) {
        _rangeStart = lo;
        _rangeEnd = hi;
        rangeCompleted = true;
      } else {
        _showSnack("선택한 범위에 예약할 수 없는 시간이 포함되어 있습니다.", isError: true);
        _rangeStart = index;
        _rangeEnd = null;
      }
    });

    // 범위가 막 완성된 경우 (2번째 탭) 바로 확인 다이얼로그를 띄운다 -
    // 별도의 하단 확인 바 없이 즉시 리뷰 화면으로 넘어간다.
    if (rangeCompleted) _confirmAndSubmit();
  }

  void _clearSelection() {
    setState(() {
      _rangeStart = null;
      _rangeEnd = null;
    });
  }

  Future<void> _confirmCancel(int reservationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("예약 취소", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("이 예약을 취소하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("닫기", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("예약 취소", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient.post('/api/reservations/cancel', body: {"reservation_id": reservationId});
      _showSnack("예약이 취소되었습니다.");
      _fetchAvailability();
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  Future<void> _confirmAndSubmit() async {
    if (_rangeStart == null || _rangeEnd == null) return;
    final startLabel = _slots[_rangeStart!]['start'];
    final endLabel = _slots[_rangeEnd!]['end'];
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("예약 확인", style: TextStyle(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("아래 내용으로 예약하시겠습니까?", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            _summaryRow(Icons.location_on_outlined, widget.facility['name'] ?? ''),
            const SizedBox(height: 10),
            _summaryRow(Icons.calendar_today_outlined, _formatDateKo(_selectedDate)),
            const SizedBox(height: 10),
            _summaryRow(Icons.access_time, "$startLabel - $endLabel"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary, foregroundColor: const Color(0xFF4A2E00)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("예약 확정", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _submitReservation();
    } else {
      _clearSelection();
    }
  }

  Widget _summaryRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
      ],
    );
  }

  String _formatDateKo(DateTime d) {
    return "${d.month}월 ${d.day}일 (${_weekdayLabelsKo[d.weekday % 7]})";
  }

  Future<void> _submitReservation() async {
    if (_rangeStart == null || _rangeEnd == null) return;
    setState(() => _isSubmitting = true);
    try {
      await ApiClient.post('/api/reservations', body: {
        "facility_id": widget.facility['facility_id'],
        "date": _dateStr,
        "start_time": _slots[_rangeStart!]['start'],
        "end_time": _slots[_rangeEnd!]['end'],
      });
      _showSnack("${widget.facility['name']} 예약이 완료되었습니다!");
      await _fetchAvailability();
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickDateFromCalendar() async {
    final theme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: theme.primaryColor, onPrimary: Colors.white, onSurface: Colors.black),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
      _fetchAvailability();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.facility['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          _buildDateStrip(theme),
          const Divider(height: 1),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildDateStrip(ThemeData theme) {
    final today = DateTime.now();
    final days = List.generate(30, (i) => DateTime(today.year, today.month, today.day).add(Duration(days: i)));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 68,
              child: ListView.builder(
                controller: _dateStripController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: days.length,
                itemBuilder: (context, i) {
                  final d = days[i];
                  final isSelected = d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day;
                  final isSunday = d.weekday == DateTime.sunday;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = d);
                      _fetchAvailability();
                    },
                    child: Container(
                      width: 52,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? theme.primaryColor : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekdayLabelsKo[d.weekday % 7],
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white70 : (isSunday ? Colors.redAccent : Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${d.day}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.calendar_month, color: theme.primaryColor),
            onPressed: _pickDateFromCalendar,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.grey, size: 40),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchAvailability, child: const Text("다시 시도")),
            ],
          ),
        ),
      );
    }

    if (!_isReservable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_busy, color: Colors.grey, size: 40),
              const SizedBox(height: 12),
              const Text("현재 예약을 받지 않는 장소입니다.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              const Text("자세한 사항은 교회 사무실로 문의해주세요.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_myActiveReservation != null) _buildActiveReservationBanner(theme),
        _buildSelectionHint(theme),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _slots.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
          ),
          itemBuilder: (context, i) => _buildSlotCell(theme, i),
        ),
        const SizedBox(height: 20),
        _buildLegend(theme),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSelectionHint(ThemeData theme) {
    if (_rangeStart != null && _rangeEnd == null) {
      // 시작 시간은 선택했고 종료 시간을 기다리는 중
      final startLabel = _slots[_rangeStart!]['start'];
      return Row(
        children: [
          Expanded(
            child: Text(
              "시작: $startLabel · 종료 시간을 선택하세요 (같은 시간을 다시 누르면 30분만 예약)",
              style: TextStyle(fontSize: 13, color: theme.primaryColor, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _clearSelection,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
        ],
      );
    }
    return const Text("30분 단위로 시작 시간을 선택하세요", style: TextStyle(fontSize: 13, color: Colors.grey));
  }

  Widget _buildActiveReservationBanner(ThemeData theme) {
    final r = _myActiveReservation!;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: theme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "오늘 예약이 확정되었습니다 (${r['start_time'].toString().substring(0, 5)}~${r['end_time'].toString().substring(0, 5)})",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => _confirmCancel(r['reservation_id']),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCell(ThemeData theme, int i) {
    final slot = _slots[i];
    final status = slot['status'];
    final hasCompleteRange = _rangeStart != null && _rangeEnd != null;
    final inSelectedRange = hasCompleteRange && i >= _rangeStart! && i <= _rangeEnd!;
    final isRangeStartOnly = _rangeStart != null && _rangeEnd == null && i == _rangeStart;

    Color bg;
    Color fg;
    Widget? badge;

    if (inSelectedRange) {
      bg = theme.colorScheme.secondary;
      fg = const Color(0xFF4A2E00);
    } else if (isRangeStartOnly) {
      // 시작 시간은 선택되었지만 아직 종료 시간을 기다리는 중
      bg = theme.primaryColor.withOpacity(0.12);
      fg = theme.primaryColor;
    } else {
      switch (status) {
        case 'available':
          bg = Colors.white;
          fg = Colors.black87;
          break;
        case 'mine':
          bg = theme.primaryColor;
          fg = Colors.white;
          badge = const Icon(Icons.check_circle, size: 12, color: Colors.white);
          break;
        case 'booked':
          bg = Colors.grey.shade200;
          fg = Colors.grey;
          break;
        case 'closed':
          bg = Colors.grey.shade100;
          fg = Colors.grey.shade400;
          badge = Icon(Icons.lock_outline, size: 11, color: Colors.grey.shade400);
          break;
        case 'past':
        default:
          bg = Colors.grey.shade100;
          fg = Colors.grey.shade400;
      }
    }

    return GestureDetector(
      onTap: () => _onSlotTap(i),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: inSelectedRange
                ? theme.colorScheme.secondary
                : isRangeStartOnly
                    ? theme.primaryColor
                    : (status == 'available' ? Colors.grey.shade300 : Colors.transparent),
            width: isRangeStartOnly ? 2 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(slot['start'], style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
            if (badge != null) Positioned(top: 4, right: 4, child: badge),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    Widget dot(Color c) => Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));
    Widget item(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          dot(c),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]);

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(Colors.white, "선택 가능"),
        item(theme.primaryColor.withOpacity(0.12), "시작 시간"),
        item(theme.colorScheme.secondary, "선택된 범위"),
        item(theme.primaryColor, "내 예약"),
        item(Colors.grey.shade200, "예약됨/마감"),
      ],
    );
  }

}
