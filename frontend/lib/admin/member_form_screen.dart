import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/responsive.dart';

/// Full-screen add/edit form for a member, used by admin CRUD. Pass
/// [personId] to edit an existing member; leave it null to create a new one.
class MemberFormScreen extends StatefulWidget {
  final int? personId;
  const MemberFormScreen({super.key, this.personId});

  bool get isEdit => personId != null;

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _gradeController = TextEditingController();

  DateTime? _birthdate;
  DateTime? _anniversary;
  String _gender = 'Male';
  String _maritalStatus = 'Single';
  bool _isChild = false;
  String _membershipRole = 'Member';
  String _churchTitle = '성도';
  String _campusName = 'Louisville Woori Church';

  // 라이프팀 - 자유 텍스트가 아니라 life_teams 테이블에서 가져온 드롭다운.
  // 리더 지정/변경은 이 화면이 아니라 라이프팀 관리 화면에서만 한다.
  List<dynamic> _lifeTeams = [];
  int? _lifeTeamId;

  // 세대 정보 (조회 결과로만 채워짐 - 변경은 별도 다이얼로그를 통해서만)
  int? _householdId;
  String? _householdName;
  String? _relationshipToHead;
  bool _isHeadOfHousehold = false;

  bool _isLoading = false;
  bool _isSaving = false;

  static const _titles = ['성도', '집사', '권사', '안수집사', '전도사', '목사', '담임목사', '사모'];

  @override
  void initState() {
    super.initState();
    _fetchLifeTeams();
    if (widget.isEdit) _loadMember();
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _fetchLifeTeams() async {
    try {
      final data = await ApiClient.get('/api/life-teams');
      if (mounted) setState(() => _lifeTeams = data);
    } on ApiException catch (e) {
      debugPrint("Life Teams Load Error: ${e.message}");
    }
  }

  Future<void> _loadMember() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiClient.get('/api/members/${widget.personId}');
      final m = data['member'];
      setState(() {
        _lastNameController.text = m['last_name'] ?? '';
        _firstNameController.text = m['first_name'] ?? '';
        _phoneController.text = m['mobile_phone'] ?? '';
        _emailController.text = m['email'] ?? '';
        _addressController.text = m['address_street'] ?? '';
        _cityController.text = m['address_city'] ?? '';
        _stateController.text = m['address_state'] ?? '';
        _zipController.text = m['address_zip'] ?? '';
        _gradeController.text = m['grade']?.toString() ?? '';
        _lifeTeamId = m['life_team_id'] is int ? m['life_team_id'] : int.tryParse('${m['life_team_id']}');
        _birthdate = m['birthdate'] != null ? DateTime.tryParse(m['birthdate']) : null;
        _anniversary = m['anniversary'] != null ? DateTime.tryParse(m['anniversary']) : null;
        _gender = m['gender'] ?? 'Male';
        _maritalStatus = m['marital_status'] ?? 'Single';
        _isChild = m['is_child'] ?? false;
        _membershipRole = m['membership_role'] ?? 'Member';
        _churchTitle = _titles.contains(m['church_title']) ? m['church_title'] : '성도';
        _campusName = m['campus_name'] ?? 'Louisville Woori Church';
        _householdId = m['household_id'] is int ? m['household_id'] : int.tryParse('${m['household_id']}');
        _householdName = m['household_name'];
        _relationshipToHead = m['relationship_to_head'];
        _isHeadOfHousehold = m['is_primary_contact'] ?? false;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      "first_name": _firstNameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "mobile_phone": _phoneController.text.trim(),
      "email": _emailController.text.trim(),
      "birthdate": _birthdate != null ? _isoDate(_birthdate!) : null,
      "anniversary": _anniversary != null ? _isoDate(_anniversary!) : null,
      "gender": _gender,
      "marital_status": _maritalStatus,
      "is_child": _isChild,
      "grade": _isChild && _gradeController.text.trim().isNotEmpty ? int.tryParse(_gradeController.text.trim()) : null,
      "address_street": _addressController.text.trim(),
      "address_city": _cityController.text.trim(),
      "address_state": _stateController.text.trim(),
      "address_zip": _zipController.text.trim(),
      "membership_role": _membershipRole,
      "church_title": _churchTitle,
      "life_team_id": _lifeTeamId,
      "campus_name": _campusName,
    };
  }

  String _isoDate(DateTime d) => "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> _save() async {
    if (_firstNameController.text.trim().isEmpty || _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("성과 이름을 입력해주세요.")));
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.isEdit) {
        await ApiClient.put('/api/members/${widget.personId}', body: _buildPayload());
      } else {
        await ApiClient.post('/api/members', body: _buildPayload());
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isEdit ? "수정되었습니다." : "성도가 등록되었습니다.")),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("성도 삭제"),
        content: Text("${_lastNameController.text}${_firstNameController.text}님을 삭제하시겠습니까?\n출석/예약 기록은 보존되며, 목록에서만 제외됩니다."),
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
      await ApiClient.delete('/api/members/${widget.personId}');
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("성도가 삭제되었습니다.")));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickDate({required DateTime? initial, required void Function(DateTime) onPicked}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _openHouseholdLink() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _HouseholdLinkSheet(
        personId: widget.personId!,
        currentHouseholdId: _householdId,
        currentHouseholdName: _householdName,
      ),
    );
    if (result == true) _loadMember();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? "성도 정보 수정" : "신규 성도 추가"),
        actions: [
          if (widget.isEdit)
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _confirmDelete),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ResponsiveBody(
                maxWidth: 700,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("기본 정보"),
                    ResponsiveFieldRow(children: [
                      TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: "성")),
                      TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: "이름")),
                    ]),
                    const SizedBox(height: 12),
                    ResponsiveFieldRow(children: [
                      _dateField("생년월일", _birthdate, (d) => setState(() => _birthdate = d)),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(labelText: "성별"),
                        items: const [DropdownMenuItem(value: 'Male', child: Text("남성")), DropdownMenuItem(value: 'Female', child: Text("여성"))],
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("어린이 (미성년 자녀)"),
                      subtitle: const Text("로그인 없이 세대에만 등록되는 자녀"),
                      value: _isChild,
                      onChanged: (v) => setState(() => _isChild = v),
                    ),
                    if (_isChild) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: _gradeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "학년 (유치부 이하는 음수, 예: -1)"),
                      ),
                    ],
                    if (!_isChild) ...[
                      const SizedBox(height: 12),
                      ResponsiveFieldRow(children: [
                        DropdownButtonFormField<String>(
                          value: _maritalStatus,
                          decoration: const InputDecoration(labelText: "결혼 여부"),
                          items: const [DropdownMenuItem(value: 'Single', child: Text("미혼")), DropdownMenuItem(value: 'Married', child: Text("기혼"))],
                          onChanged: (v) => setState(() => _maritalStatus = v!),
                        ),
                        if (_maritalStatus == 'Married')
                          _dateField("결혼기념일", _anniversary, (d) => setState(() => _anniversary = d))
                        else
                          const SizedBox.shrink(),
                      ]),
                    ],

                    const SizedBox(height: 24),
                    _sectionLabel("연락처"),
                    TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "휴대폰 번호")),
                    const SizedBox(height: 12),
                    TextField(controller: _emailController, decoration: const InputDecoration(labelText: "이메일")),
                    const SizedBox(height: 12),
                    TextField(controller: _addressController, decoration: const InputDecoration(labelText: "주소 (도로명)")),
                    const SizedBox(height: 12),
                    ResponsiveFieldRow(children: [
                      TextField(controller: _cityController, decoration: const InputDecoration(labelText: "도시")),
                      TextField(controller: _stateController, decoration: const InputDecoration(labelText: "주")),
                      TextField(controller: _zipController, decoration: const InputDecoration(labelText: "우편번호")),
                    ]),

                    const SizedBox(height: 24),
                    _sectionLabel("교회 정보"),
                    ResponsiveFieldRow(children: [
                      DropdownButtonFormField<String>(
                        value: _churchTitle,
                        decoration: const InputDecoration(labelText: "직분"),
                        items: _titles.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _churchTitle = v!),
                      ),
                      DropdownButtonFormField<String>(
                        value: _membershipRole,
                        decoration: const InputDecoration(labelText: "앱 권한"),
                        items: const [DropdownMenuItem(value: 'Member', child: Text("일반 성도")), DropdownMenuItem(value: 'Admin', child: Text("관리자"))],
                        onChanged: (v) => setState(() => _membershipRole = v!),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      value: _lifeTeamId,
                      decoration: const InputDecoration(labelText: "라이프팀"),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text("없음")),
                        ..._lifeTeams.map((t) => DropdownMenuItem<int?>(
                              value: int.tryParse(t['life_team_id'].toString()),
                              child: Text(t['name']),
                            )),
                      ],
                      onChanged: (v) => setState(() => _lifeTeamId = v),
                    ),

                    const SizedBox(height: 24),
                    _sectionLabel("세대 (가족)"),
                    _buildHouseholdSummary(),

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
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey)),
      );

  Widget _dateField(String label, DateTime? value, void Function(DateTime) onPicked) {
    return InkWell(
      onTap: () => _pickDate(initial: value, onPicked: onPicked),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value != null ? _isoDate(value) : "선택 안 함"),
      ),
    );
  }

  Widget _buildHouseholdSummary() {
    if (!widget.isEdit) {
      return const Text("성도를 먼저 등록한 후, 수정 화면에서 세대를 연결할 수 있습니다.", style: TextStyle(color: Colors.grey, fontSize: 13));
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEEF1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _householdId == null
                ? const Text("연결된 세대가 없습니다.", style: TextStyle(color: Colors.grey))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_householdName ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (_isHeadOfHousehold)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFFFC229), borderRadius: BorderRadius.circular(6)),
                              child: const Text("세대주", style: TextStyle(fontSize: 10, color: Color(0xFF4A2E00), fontWeight: FontWeight.w600)),
                            ),
                          Text(_relationshipToHead ?? '관계 미지정', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
          ),
          TextButton(onPressed: _openHouseholdLink, child: const Text("변경")),
        ],
      ),
    );
  }
}

/// Bottom sheet for attaching a member to an existing household, creating a
/// new household, or detaching them - the actual "connect members as one
/// household, select head" flow the admin uses.
class _HouseholdLinkSheet extends StatefulWidget {
  final int personId;
  final int? currentHouseholdId;
  final String? currentHouseholdName;

  const _HouseholdLinkSheet({required this.personId, this.currentHouseholdId, this.currentHouseholdName});

  @override
  State<_HouseholdLinkSheet> createState() => _HouseholdLinkSheetState();
}

class _HouseholdLinkSheetState extends State<_HouseholdLinkSheet> {
  int _mode = 0; // 0 = 기존 세대에 연결, 1 = 새 세대 만들기
  final _searchController = TextEditingController();
  final _newHouseholdNameController = TextEditingController();
  String _relationship = '본인';
  bool _isHead = false;
  bool _isSearching = false;
  bool _isSubmitting = false;
  List<dynamic> _searchResults = [];
  dynamic _selectedTarget; // 검색해서 고른, 연결하고자 하는 기존 세대원

  static const _relationshipOptions = ['본인', '배우자', '자녀', '부모', '형제자매', '기타'];

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final data = await ApiClient.get('/api/members?search=${Uri.encodeComponent(query)}');
      setState(() {
        _searchResults = (data as List).where((m) => m['person_id'].toString() != widget.personId.toString()).toList();
        _isSearching = false;
      });
    } on ApiException {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _submit({bool detach = false}) async {
    if (!detach && _mode == 0 && _selectedTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("연결할 세대원을 먼저 선택해주세요.")));
      return;
    }
    if (!detach && _mode == 1 && _newHouseholdNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("새 세대 이름을 입력해주세요.")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiClient.post('/api/households/link', body: {
        "person_id": widget.personId,
        if (!detach && _mode == 0) "household_id": _selectedTarget['household_id'],
        if (!detach && _mode == 1) "new_household_name": _newHouseholdNameController.text.trim(),
        "relationship_to_head": detach ? null : _relationship,
        "is_head": !detach && _isHead,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
              const Text("세대 연결", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text("기존 세대에 연결")),
                  ButtonSegment(value: 1, label: Text("새 세대 만들기")),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 16),
              if (_mode == 0) ...[
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(labelText: "이름으로 검색", prefixIcon: Icon(Icons.search)),
                  onChanged: _search,
                ),
                const SizedBox(height: 8),
                if (_isSearching) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
                ..._searchResults.map((m) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline),
                      title: Text("${m['last_name']}${m['first_name']}"),
                      subtitle: Text(m['household_name'] ?? '소속 세대 없음'),
                      selected: _selectedTarget != null && _selectedTarget['person_id'] == m['person_id'],
                      selectedTileColor: const Color(0xFFF0F4FF),
                      onTap: () => setState(() => _selectedTarget = m),
                    )),
              ] else
                TextField(
                  controller: _newHouseholdNameController,
                  decoration: const InputDecoration(labelText: "새 세대 이름", hintText: "예: 박민우's Household"),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _relationship,
                decoration: const InputDecoration(labelText: "세대주와의 관계"),
                items: _relationshipOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _relationship = v ?? '본인'),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("이 성도를 세대주로 지정"),
                value: _isHead,
                onChanged: (v) => setState(() => _isHead = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.currentHouseholdId != null)
                    TextButton(
                      onPressed: _isSubmitting ? null : () => _submit(detach: true),
                      child: const Text("세대에서 분리", style: TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _submit(),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text("연결하기"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
