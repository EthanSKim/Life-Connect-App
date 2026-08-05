import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../api_client.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

/// Result of a single scan, shown as a brief auto-dismissing overlay instead
/// of a dialog the admin has to tap through - during check-in, people are
/// scanning one after another and a confirm button between every scan just
/// slows the line down.
class _ScanResult {
  final bool success;
  final String title;
  final String message;
  const _ScanResult({required this.success, required this.title, required this.message});
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isScanning = true;
  final MobileScannerController _controller = MobileScannerController();
  _ScanResult? _lastResult;
  Timer? _resultTimer;

  @override
  void dispose() {
    _resultTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String scannedToken) async {
    if (!_isScanning) return;
    setState(() => _isScanning = false);

    _ScanResult result;
    try {
      // QR은 회원가입 시 한 번 발급되는 전용 토큰만 담는다 (로그인 PIN과
      // 무관 - PIN이 바뀌어도 이 QR은 계속 유효하다).
      final data = await ApiClient.post('/api/attendance/scan', body: {"token": scannedToken});
      result = _ScanResult(success: true, title: data['name'] ?? '', message: data['message'] ?? '출석 확인되었습니다.');
    } on ApiException catch (e) {
      result = _ScanResult(success: false, title: "오류", message: e.message);
    }

    if (!mounted) return;
    setState(() => _lastResult = result);

    // 3초 후 자동으로 사라지고, 다음 사람을 바로 스캔할 수 있도록 재개된다 -
    // 관리자가 확인 버튼을 누를 필요가 없다.
    _resultTimer?.cancel();
    _resultTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _lastResult = null;
        _isScanning = true;
      });
    });
  }

  // 카메라 초기화 실패 시 원인을 알 수 있는 안내 화면
  // (기존에는 mobile_scanner의 기본 "!" 아이콘만 표시되어 원인을 알 수 없었음)
  //
  // QR이 이제 사람이 타이핑할 수 없는 무작위 토큰이라, 카메라를 못 쓸 때의
  // 대안은 "직접 입력" 다이얼로그가 아니라 출석 확인 화면의 체크박스다 -
  // 그 화면은 이미 개별/일괄 수동 체크를 지원하므로 그쪽으로 안내한다.
  Widget _buildScannerError(MobileScannerException error) {
    String message;
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        message = "카메라 권한이 거부되었습니다.\n기기 설정에서 이 앱의 카메라 권한을 허용해주세요.";
        break;
      case MobileScannerErrorCode.unsupported:
        message = "이 기기 또는 브라우저에서는 카메라를 지원하지 않습니다.";
        break;
      default:
        message = "카메라를 시작할 수 없습니다.\n"
            "웹으로 접속 중이라면 https 주소(또는 localhost)로 접속했는지 확인해주세요.\n"
            "(${error.errorDetails?.message ?? error.errorCode.name})";
    }

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          const Text(
            "카메라를 사용할 수 없다면 출석 확인 화면에서 직접 체크해주세요.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text("출석 확인 화면으로 돌아가기"),
          ),
        ],
      ),
    );
  }

  Widget _buildResultOverlay(_ScanResult result) {
    final color = result.success ? const Color(0xFF2F6FED) : const Color(0xFFE24B4A);
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: AnimatedScale(
          scale: 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(32)),
                  child: Icon(result.success ? Icons.check : Icons.close, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                if (result.success)
                  Text(result.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(result.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("출석 체크 스캐너")),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            errorBuilder: (context, error, child) => _buildScannerError(error),
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null) {
                  _handleScan(code);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(20)),
            ),
          ),
          if (_lastResult != null) _buildResultOverlay(_lastResult!),
        ],
      ),
    );
  }
}
