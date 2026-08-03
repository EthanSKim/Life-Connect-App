import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'main.dart';
import 'main_tab_screen.dart';
import 'auth_session.dart';
import 'set_pin_screen.dart';
import 'api_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  bool _isNameConfirmed = false; // 이름 입력 후 '다음'을 눌렀는지 여부
  bool _isNewUser = false; 
  int? _personId; // DB에서 받아온 사용자 ID 고정
  bool _isBusy = false; // 통신 중 여부

  // [API 호출] 성함 확인
  Future<void> _verifyMember() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isBusy = true);
    try {
      final data = await ApiClient.post('/api/auth/verify-member', body: {"name": _nameController.text});
      setState(() {
        _isNameConfirmed = true;
        _isNewUser = data['isNewUser'];
        // PostgreSQL BIGINT는 문자열로 들어올 수 있으므로 안전하게 파싱합니다.
        _personId = data['person_id'] is int
            ? data['person_id']
            : int.tryParse(data['person_id'].toString());
      });
    } on ApiException catch (e) {
      _showAlert(e.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // [API 호출] 로그인
  Future<void> _login() async {
    if (_pinController.text.length < 6) return;
    setState(() => _isBusy = true);
    try {
      final data = await ApiClient.post('/api/auth/login', body: {
        "person_id": _personId,
        "pin": _pinController.text,
      });
      if (!mounted) return;
      AuthSession.token = data['token'];
      final bool isDefaultPin = data['is_default_pin'] == true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => isDefaultPin
            ? SetPinScreen(
                userName: _nameController.text,
                personId: _personId!,
                oldPin: _pinController.text,
                isAdmin: data['membership_role'] == 'Admin',
                userTitle: data['church_title'] ?? '성도님',
                attendanceToken: data['attendance_token'] ?? '',
              )
            : MainTabScreen(
          userName: _nameController.text,
          personId: _personId!, // ID 전달
          attendanceToken: data['attendance_token'] ?? '',
          isAdmin: data['membership_role'] == 'Admin',
          userTitle: data['church_title'] ?? '성도님',
        )),
      );
    } on ApiException catch (e) {
      _showAlert(e.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("알림"),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("확인"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // 로고 마크
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Life Connect",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: kTextPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                "성함으로 로그인하세요",
                style: TextStyle(fontSize: 14, color: kTextSecondary),
              ),

              const SizedBox(height: 44),

              // 이름 입력 영역
              _buildInputLabel("성함"),
              TextField(
                controller: _nameController,
                enabled: !_isNameConfirmed, // 이름 확정 시 수정 불가 모드
                decoration: InputDecoration(
                  hintText: "이름을 입력하세요",
                  fillColor: _isNameConfirmed ? kBorder : kFieldFill,
                ),
              ),

              // PIN 입력 영역 (애니메이션 등장)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _isNameConfirmed ? 1.0 : 0.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.fastOutSlowIn,
                  height: _isNameConfirmed ? 150 : 0, // 스르륵 열리는 효과
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildInputLabel(
                          _isNewUser ? "새로운 PIN 설정 (6자리)" : "PIN 번호 입력",
                        ),
                        TextField(
                          controller: _pinController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: const TextStyle(letterSpacing: 10, fontSize: 20, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(counterText: "", hintText: "숫자 6자리"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // 메인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 58)),
                  onPressed: _isBusy ? null : (!_isNameConfirmed ? _verifyMember : _login),
                  child: _isBusy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          !_isNameConfirmed
                              ? "성함 확인"
                              : (_isNewUser ? "PIN 등록 및 입장" : "로그인"),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),

              // 성함 수정 버튼
              if (_isNameConfirmed)
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _isNameConfirmed = false),
                    child: const Text(
                      "성함을 잘못 입력하셨나요?",
                      style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.normal),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary),
      ),
    );
  }
}
