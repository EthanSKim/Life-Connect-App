import 'package:flutter/material.dart';
import 'main_tab_screen.dart';
import 'api_client.dart';

/// Shown right after a successful login when the account is still using its
/// default PIN (last 6 digits of phone, or 123456 as a fallback). Requires
/// setting a new PIN before entering the app - closes the "everyone can log
/// in with the same default PIN forever" gap.
class SetPinScreen extends StatefulWidget {
  final String userName;
  final int personId;
  final String oldPin; // 방금 로그인에 사용한 기본 PIN
  final bool isAdmin;
  final String userTitle;
  final String attendanceToken;

  const SetPinScreen({
    super.key,
    required this.userName,
    required this.personId,
    required this.oldPin,
    required this.isAdmin,
    required this.userTitle,
    required this.attendanceToken,
  });

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _isBusy = false;

  Future<void> _submit() async {
    if (_newPinController.text.length != 6) {
      _showAlert("6자리 숫자로 입력해주세요.");
      return;
    }
    if (_newPinController.text != _confirmPinController.text) {
      _showAlert("새 PIN 번호가 서로 일치하지 않습니다.");
      return;
    }
    if (_newPinController.text == widget.oldPin) {
      _showAlert("기본 PIN과 다른 번호로 설정해주세요.");
      return;
    }

    setState(() => _isBusy = true);
    try {
      await ApiClient.put('/api/members/${widget.personId}/pin', body: {
        "old_pin": widget.oldPin,
        "new_pin": _newPinController.text,
      });
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainTabScreen(
            userName: widget.userName,
            personId: widget.personId,
            attendanceToken: widget.attendanceToken,
            isAdmin: widget.isAdmin,
            userTitle: widget.userTitle,
          ),
        ),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 48, color: theme.primaryColor),
              const SizedBox(height: 20),
              Text(
                "${widget.userName}님, 환영합니다!",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "처음 로그인하셨네요. 안전한 이용을 위해\n나만의 새로운 PIN 번호를 설정해주세요.",
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 40),
              _label("새 PIN 번호 (6자리)"),
              _pinField(_newPinController),
              const SizedBox(height: 20),
              _label("새 PIN 번호 확인"),
              _pinField(_confirmPinController),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                onPressed: _isBusy ? null : _submit,
                child: _isBusy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("PIN 설정하고 시작하기", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
      );

  Widget _pinField(TextEditingController controller) => TextField(
        controller: controller,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: const TextStyle(letterSpacing: 10, fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          hintText: "숫자 6자리",
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        ),
      );
}
