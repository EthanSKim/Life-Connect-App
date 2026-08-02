import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'login_screen.dart';
import 'api_client.dart';
import 'auth_session.dart';

// lib/profile_screen.dart

class ProfileScreen extends StatefulWidget {
  final bool isAdmin;
  final int? personId; // 정보를 불러올 성도의 ID

  const ProfileScreen({
    super.key,
    this.isAdmin = false,
    this.personId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false; // 편집 모드 상태
  bool _isLoading = true;
  Map<String, dynamic>? _memberData;
  List<dynamic> _familyMembers = [];

  // 편집용 컨트롤러
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _teamController = TextEditingController();
  String? _selectedTitle;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    if (widget.personId == null) return;

    try {
      final data = await ApiClient.get('/api/members/${widget.personId}');
      if (mounted) {
        setState(() {
          _memberData = data['member'];
          _familyMembers = data['family'];

          _phoneController.text = _memberData!['mobile_phone'] ?? "";
          _addressController.text = _memberData!['address_street'] ?? "";
          _teamController.text = _memberData!['life_team'] ?? "";
          _selectedTitle = _memberData!['church_title'] ?? "성도";
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      debugPrint("Profile Fetch Error: ${e.message}");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _saveProfile() async {
    try {
      await ApiClient.put('/api/members/${widget.personId}', body: {
        ..._memberData!,
        "mobile_phone": _phoneController.text,
        "address_street": _addressController.text,
        "life_team": _teamController.text,
        "church_title": _selectedTitle,
      });
      _fetchProfile(); // 최신 데이터 다시 불러오기
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  // PIN 번호 변경 다이얼로그
  void _showChangePinDialog(BuildContext context) {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final primary = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("PIN 번호 변경", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: "현재 PIN 번호", hintText: "기존 6자리 입력"),
            ),
            TextField(
              controller: newPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: "새 PIN 번호", hintText: "새로운 6자리 입력"),
            ),
            TextField(
              controller: confirmPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: "새 PIN 번호 확인", hintText: "다시 한 번 입력"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            onPressed: () async {
              if (newPinController.text != confirmPinController.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("새 PIN 번호가 서로 일치하지 않습니다.")));
                return;
              }
              try {
                final data = await ApiClient.put('/api/members/${widget.personId}/pin', body: {
                  "old_pin": oldPinController.text,
                  "new_pin": newPinController.text,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
                }
              } on ApiException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
            child: const Text("변경하기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "정보 없음";
    return dateStr.split('T')[0].replaceAll('-', '. '); // YYYY. MM. DD 형식
  }

  // --- [공통] 애니메이션 위젯 (유지) ---
  Widget _buildAnimatedItem({required int delayMs, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Interval(
        (delayMs / 1000).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? "성도 상세 정보" : "내 정보",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _memberData == null
          ? const Center(child: Text("사용자 정보를 찾을 수 없습니다."))
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. 프로필 요약 (유지)
          _buildAnimatedItem(
            delayMs: 0,
            child: Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.secondary.withOpacity(
                      0.2,
                    ),
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "${_memberData!['last_name']}${_memberData!['first_name']} ${_isEditing ? '' : (_selectedTitle ?? '성도')}",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  if (_isEditing) 
                    DropdownButton<String>(
                      value: _selectedTitle,
                      items: ['성도', '집사', '권사', '안수집사', '전도사', '목사', '담임목사', '사모']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _selectedTitle = v),
                    ),
                  Text(
                    _memberData!['life_team'] ?? "소속 팀 없음",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

          // 2. 상세 정보 섹션 (유지)
          _buildAnimatedItem(
            delayMs: 150,
            child: _buildInfoTile(
              Icons.cake_outlined,
              "생년월일",
              _formatDate(_memberData!['birthdate']),
              primary,
            ),
          ),
          _buildAnimatedItem(
            delayMs: 250,
            child: _buildInfoTile(
              Icons.phone_android_outlined,
              "연락처",
              _memberData!['mobile_phone'] ?? "정보 없음",
              primary,
              controller: _phoneController,
            ),
          ),
          _buildAnimatedItem(
            delayMs: 350,
            child: _buildInfoTile(
              Icons.house_outlined,
              "주소",
              "${_memberData!['address_street'] ?? ''} ${_memberData!['address_city'] ?? ''}",
              primary,
              controller: _addressController,
            ),
          ),
          _buildAnimatedItem(
            delayMs: 450,
            child: _buildInfoTile(
              Icons.groups_outlined,
              "소속 라이프 팀",
              _memberData!['life_team'] ?? "정보 없음",
              primary,
              controller: _teamController,
            ),
          ),

          const SizedBox(height: 30),
          
          // PIN 번호 변경 항목 (본인 정보일 때만 표시 추천하거나 관리자 기능으로 활용)
          _buildAnimatedItem(
            delayMs: 500,
            child: GestureDetector(
              onTap: () => _showChangePinDialog(context),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEDEEF1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: primary),
                    const SizedBox(width: 15),
                    const Expanded(child: Text("PIN 번호 변경", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),

          // 3. 가족 관계 섹션 (유지)
          _buildAnimatedItem(
            delayMs: 600,
            child: const Text(
              "연결된 가족",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 15),
          if (_familyMembers.isEmpty)
            const Text("등록된 가족 정보가 없습니다.", style: TextStyle(color: Colors.grey)),
          ..._familyMembers.asMap().entries.map((entry) {
            int idx = entry.key;
            var person = entry.value;
            return _buildAnimatedItem(
              delayMs: 700 + (idx * 100),
              child: _buildFamilyCard("${person['last_name']}${person['first_name']}", person['relationship_to_head'] ?? "가족"),
            );
          }).toList(),

          const SizedBox(height: 50),

          // --- 4. 하단 버튼 영역 (수정됨) ---
          _buildAnimatedItem(
            delayMs: 950,
            child: widget.isAdmin
                ? ElevatedButton.icon(
                    // 목사님일 때: 수정하기 버튼
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    icon: Icon(
                      _isEditing ? Icons.check : Icons.edit,
                      color: Colors.black,
                    ),
                    label: Text(
                      _isEditing ? "저장 완료" : "정보 수정하기",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      if (_isEditing) await _saveProfile();
                      setState(() => _isEditing = !_isEditing);
                      if (_isEditing == false) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("성도 정보가 저장되었습니다.")),
                        );
                      }
                    },
                  )
                : OutlinedButton.icon(
                    // 일반 성도일 때: 로그아웃 버튼 (기존 유지)
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: Icon(Icons.logout, color: Colors.red.shade300),
                    label: Text(
                      "로그아웃",
                      style: TextStyle(
                        color: Colors.red.shade300,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _showLogoutDialog(context),
                  ),
          ),
        ],
      ),
    );
  }

  // _buildInfoTile, _buildFamilyCard, _showLogoutDialog 등은 기존 코드와 100% 동일하므로 생략 가능 (본인 코드 붙여넣기 하시면 됩니다)
  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value,
    Color color,
    {TextEditingController? controller}
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEEF1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                _isEditing && controller != null
                  ? TextField(
                      controller: controller,
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 5)),
                    )
                  : Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyCard(String name, String relation) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFEEEEEE)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person_outline, size: 20),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(relation, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("로그아웃"),
        content: const Text("초기 화면으로 이동하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              AuthSession.token = null;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("확인", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
