import 'package:flutter/material.dart';
import 'main_tab_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  bool _isNameConfirmed = false; // 이름 입력 후 '다음'을 눌렀는지 여부
  bool _isNewUser = true; // DB에 핀이 없는 신규 유저인지 여부 (가상)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.secondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          // 상단 여백 유지
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // 1. 텍스트 로고 (기존 스타일 유지)
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                  children: [
                    TextSpan(
                      text: "Life ",
                      style: TextStyle(color: primaryColor),
                    ),
                    TextSpan(
                      text: "Connect",
                      style: TextStyle(color: secondaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "LOUISVILLE WOORI CHURCH",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  letterSpacing: 4.0,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 80),

              // 2. 이름 입력 영역
              _buildInputLabel("성함"),
              TextField(
                controller: _nameController,
                enabled: !_isNameConfirmed, // 이름 확정 시 수정 불가 모드
                decoration: InputDecoration(
                  hintText: "성함을 입력하세요",
                  filled: true,
                  fillColor: _isNameConfirmed ? Colors.grey[200] : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              // 3. PIN 입력 영역 (애니메이션 등장)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _isNameConfirmed ? 1.0 : 0.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.fastOutSlowIn,
                  height: _isNameConfirmed ? 160 : 0, // 스르륵 열리는 효과
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        _buildInputLabel(
                          _isNewUser ? "새로운 PIN 설정 (6자리)" : "PIN 번호 입력",
                        ),
                        TextField(
                          controller: _pinController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: const TextStyle(
                            letterSpacing: 10,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: "",
                            hintText: "숫자 6자리",
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 4. 메인 버튼
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 65),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  if (!_isNameConfirmed) {
                    // [1단계] 성함 확인 버튼 클릭 시
                    if (_nameController.text.isNotEmpty) {
                      setState(() {
                        _isNameConfirmed = true;
                        // 가상 로직: '김수환'면 기존 유저(PIN 입력), 아니면 신규(PIN 설정)
                        _isNewUser =
                            (_nameController.text != "김수환" ||
                            _nameController.text != "박민우");
                      });
                    }
                  } else {
                    // [2단계] PIN 입력 후 입장
                    if (_pinController.text.length == 6) {
                      String inputName = _nameController.text;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MainTabScreen(userName: inputName), // 이름 전달
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  !_isNameConfirmed
                      ? "성함 확인"
                      : (_isNewUser ? "PIN 등록 및 입장" : "로그인"),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 성함 수정 버튼
              if (_isNameConfirmed)
                TextButton(
                  onPressed: () => setState(() => _isNameConfirmed = false),
                  child: const Text(
                    "성함을 잘못 입력하셨나요?",
                    style: TextStyle(color: Colors.grey),
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
      padding: const EdgeInsets.only(left: 5, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black45,
          ),
        ),
      ),
    );
  }
}
