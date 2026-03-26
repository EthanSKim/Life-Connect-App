import 'package:flutter/material.dart';
import 'login_screen.dart';

// lib/profile_screen.dart

class ProfileScreen extends StatefulWidget {
  // 기본값을 false로 설정하여, 값이 전달되지 않아도 null 에러가 나지 않게 합니다.
  final bool isAdmin;

  const ProfileScreen({
    super.key,
    this.isAdmin = false, // 이 부분을 확인하세요!
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false; // 편집 모드 상태

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
      body: ListView(
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
                    "김수환 성도",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  const Text(
                    "Mz's Us 라이프팀",
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
              "2000년 12월 06일",
              primary,
            ),
          ),
          _buildAnimatedItem(
            delayMs: 250,
            child: _buildInfoTile(
              Icons.phone_android_outlined,
              "연락처",
              "5125669091",
              primary,
            ),
          ),
          _buildAnimatedItem(
            delayMs: 350,
            child: _buildInfoTile(
              Icons.house_outlined,
              "주소",
              "342 S Dorsey Ln Louisville, KY 40223",
              primary,
            ),
          ),
          _buildAnimatedItem(
            delayMs: 450,
            child: _buildInfoTile(
              Icons.groups_outlined,
              "소속 라이프 팀",
              "Mz's Us 라이프팀 (팀장: 이종민)",
              primary,
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
          _buildAnimatedItem(
            delayMs: 700,
            child: _buildFamilyCard("최수지 성도", "배우자"),
          ),
          _buildAnimatedItem(
            delayMs: 800,
            child: _buildFamilyCard("최이레 성도", "자녀"),
          ),

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
                        borderRadius: BorderRadius.circular(15),
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
                    onPressed: () {
                      setState(() => _isEditing = !_isEditing);
                      if (!_isEditing) {
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
                        borderRadius: BorderRadius.circular(15),
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
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
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
                Text(
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
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            ),
            child: const Text("확인", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
