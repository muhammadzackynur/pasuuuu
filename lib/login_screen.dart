import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'api_config.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  final String roleTitle;

  const LoginScreen({super.key, required this.roleTitle});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _idController = TextEditingController();
  bool _isLoading = false;

  bool _hasSavedId = false;
  String _savedUserId = '';

  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  bool _isRegisteringFace = false;
  bool _isAutoScanning = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ─── Color palette untuk Dark Mode (bawaan) ───────────────────────────────
  static const Color _bgDeepDark = Color(0xFF080E1C);
  static const Color _fieldBgDark = Color(0xFF1A2336);
  static const Color _accent = Color(0xFF3B8BEB);
  static const Color _accentGlow = Color(0xFF5BA3F5);
  static const Color _orange = Color(0xFFF97316);

  // ─── Color palette untuk Light Mode ───────────────────────────────────────
  static const Color _bgDeepLight = Color(0xFFF8FAFC);
  static const Color _fieldBgLight = Colors.white;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _initializeCameraAndCheckLogin();
    _animController.forward();
  }

  // =========================================================================
  // INIT KAMERA & PENGECEKAN SESI WAJAH
  // =========================================================================
  Future<void> _initializeCameraAndCheckLogin() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);

      _checkSavedLogin();
    } catch (e) {
      debugPrint("Error kamera: $e");
      _checkSavedLogin();
    }
  }

  Future<void> _checkSavedLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedId = prefs.getString('saved_user_id_${widget.roleTitle}');
    if (savedId != null && savedId.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _hasSavedId = true;
        _savedUserId = savedId;
      });
      _autoScanLogin();
    }
  }

  // =========================================================================
  // FUNGSI FACE RECOGNITION (REGISTER & LOGIN)
  // =========================================================================
  Future<void> _registerFace() async {
    if (!_isCameraInitialized) return;
    final String userId = _idController.text.trim();
    if (userId.isEmpty) {
      _showSnack("ID tidak boleh kosong!", Colors.red);
      return;
    }
    setState(() => _isLoading = true);
    try {
      XFile picture = await _cameraController!.takePicture();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/register-fingerprint'),
      );
      request.headers.addAll({'Accept': 'application/json'});
      request.fields['user_id'] = userId;
      request.files.add(
        await http.MultipartFile.fromPath('fingerprint_image', picture.path),
      );
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode >= 500) {
        throw "Terjadi kesalahan di server (500)";
      }
      var data = json.decode(response.body);
      if (data['success'] == true) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_user_id_${widget.roleTitle}', userId);
        if (!mounted) return;
        _showSnack(data['message'], Colors.green);
        _loginLanjutkan(userId);
      } else {
        if (!mounted) return;
        _showSnack(data['message'] ?? "Gagal Daftar", Colors.red);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error Register: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack("Error: $e", Colors.red);
    }
  }

  Future<void> _autoScanLogin() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? currentSavedId = prefs.getString(
      'saved_user_id_${widget.roleTitle}',
    );
    if (currentSavedId == null || currentSavedId.isEmpty) {
      if (mounted) setState(() => _hasSavedId = false);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isAutoScanning = true;
      _savedUserId = currentSavedId;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 1500));
      XFile picture = await _cameraController!.takePicture();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/login-fingerprint'),
      );
      request.headers.addAll({'Accept': 'application/json'});
      request.fields['user_id'] = currentSavedId;
      request.files.add(
        await http.MultipartFile.fromPath('fingerprint_image', picture.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode >= 500) throw "Internal Server Error";

      var data = json.decode(response.body);
      if (data['success'] == true) {
        _routeToDashboard(data);
      } else {
        if (!mounted) return;
        _showSnack(data['message'] ?? "Kredensial tidak valid", Colors.red);
      }
    } catch (e) {
      debugPrint("Error Auto Login: $e");
      if (!mounted) return;
      _showSnack("Gagal menghubungi server", Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAutoScanning = false;
        });
      }
    }
  }

  Future<void> _loginLanjutkan(String userId) async {
    try {
      String roleYangDikirim = widget.roleTitle.toLowerCase().contains("admin")
          ? "admin"
          : "tim_lapangan";
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login'),
        headers: {'Accept': 'application/json'},
        body: {'user_id': userId, 'role': roleYangDikirim},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) _routeToDashboard(data);
      }
    } catch (e) {
      debugPrint("Error Login Lanjutan: $e");
    }
  }

  Future<void> _clearSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_user_id_${widget.roleTitle}');

    if (!mounted) return;

    setState(() {
      _hasSavedId = false;
      _savedUserId = '';
      _idController.clear();
      _isRegisteringFace = false;
      _isAutoScanning = false;
      _isLoading = false;
    });

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  // =========================================================================
  // ROUTING & ONESIGNAL TAGGING
  // =========================================================================
  void _routeToDashboard(Map<String, dynamic> data) {
    if (!mounted) return;

    String userIdStr = data['user']['user_id'].toString();
    String userRole = data['user']['role'].toString().toLowerCase();

    OneSignal.login(userIdStr);
    OneSignal.User.addTagWithKey("user_id", userIdStr);

    if (userRole.contains('admin')) {
      OneSignal.User.addTagWithKey("role", "tim_administrasi");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboardScreen(
            userName: data['user']['name'],
            role: data['user']['role'],
            userId: userIdStr,
          ),
        ),
      );
    } else {
      OneSignal.User.addTagWithKey("role", "tim_lapangan");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            userName: data['user']['name'],
            role: data['user']['role'],
            userId: userIdStr,
            databaseId: data['user']['id'],
          ),
        ),
      );
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white, fontSize: 19),
        ), // Diubah menjadi 19
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _cameraController?.dispose();
    _idController.dispose();
    super.dispose();
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color bgColor = isLightMode ? _bgDeepLight : _bgDeepDark;
    Color iconColor = isLightMode ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Background radial glow ────────────────────────────────────
          Positioned(
            top: -100,
            left: MediaQuery.of(context).size.width / 2 - 180,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accent.withOpacity(isLightMode ? 0.1 : 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    // ── AppBar row ───────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: iconColor,
                              size: 24, // Disesuaikan agar seimbang
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: _hasSavedId
                          ? _buildAutoScanBody(isLightMode)
                          : _isRegisteringFace && _isCameraInitialized
                          ? _buildRegisterFaceBody(isLightMode)
                          : _buildMainBody(isLightMode),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MAIN BODY (input ID + daftar wajah — hanya untuk user baru) ──────────
  Widget _buildMainBody(bool isLightMode) {
    Color textPrimary = isLightMode ? Colors.black : Colors.white;
    Color textSecondary = isLightMode
        ? Colors.grey[700]!
        : const Color(0xFF94A3B8);
    Color fieldBg = isLightMode ? _fieldBgLight : _fieldBgDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Role chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withOpacity(0.4)),
            ),
            child: Text(
              widget.roleTitle,
              style: const TextStyle(
                color: _accentGlow,
                fontSize: 19, // Diubah menjadi 19
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Icon circle
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(isLightMode ? 0.2 : 0.45),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.cell_tower_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Operasi Pemeliharaan',
            style: TextStyle(
              color: textPrimary,
              fontSize: 22, // Judul Utama, tetap >20
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Masukkan ID untuk mendaftarkan Wajah',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondary,
              fontSize: 19, // Diubah menjadi 19
            ),
          ),

          const Spacer(flex: 1),

          // ── ID Field ────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Masukkan ID',
              style: TextStyle(
                color: textSecondary,
                fontSize: 19, // Diubah menjadi 19
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isLightMode
                    ? Colors.grey.withOpacity(0.3)
                    : Colors.white.withOpacity(0.07),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isLightMode ? 0.05 : 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _idController,
              style: TextStyle(
                color: textPrimary,
                fontSize: 19, // Diubah menjadi 19
              ),
              cursorColor: _accentGlow,
              decoration: InputDecoration(
                hintText: 'Masukkan ID Anda',
                hintStyle: TextStyle(
                  color: isLightMode
                      ? Colors.grey[400]
                      : const Color(0xFF4B5563),
                  fontSize: 19, // Diubah menjadi 19
                ),
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF3B8BEB),
                  size: 24,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
            ),
          ),

          const Spacer(flex: 2),

          // ── Primary button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () {
                if (_idController.text.trim().isEmpty) {
                  _showSnack(
                    "Silakan masukkan ID terlebih dahulu",
                    Colors.orange,
                  );
                  return;
                }
                setState(() => _isRegisteringFace = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(isLightMode ? 0.3 : 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.face_retouching_natural_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'DAFTARKAN WAJAH SAYA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20, // Diubah menjadi 20
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            '© 2026 Maintenance System',
            style: TextStyle(
              color: Color(0xFF374151),
              fontSize: 19, // Diubah menjadi 19
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── REGISTER FACE BODY ────────────────────────────────────────────────────
  Widget _buildRegisterFaceBody(bool isLightMode) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cameraWidth = screenWidth - 56;
    double cameraHeight = cameraWidth * (4 / 3);
    Color textSecondary = isLightMode
        ? Colors.grey[700]!
        : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text(
            'Posisikan Wajah Memenuhi Layar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _orange,
              fontSize: 20, // Diubah menjadi 20
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // Camera Frame Portrait
          Container(
            width: cameraWidth,
            height: cameraHeight,
            decoration: BoxDecoration(
              color: const Color(0xFF0F2040),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _orange, width: 3),
              boxShadow: [
                BoxShadow(
                  color: _orange.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),
          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _registerFace,
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isLoading ? 'MENYIMPAN...' : 'JEPRET & DAFTAR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20, // Diubah menjadi 20
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 14),

          TextButton(
            onPressed: _clearSavedData,
            child: Text(
              'Ganti Akun / Batal',
              style: TextStyle(
                color: textSecondary,
                fontSize: 19, // Diubah menjadi 19
                decoration: TextDecoration.underline,
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── AUTO SCAN BODY ────────────────────────────────────────────────────────
  Widget _buildAutoScanBody(bool isLightMode) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cameraWidth = screenWidth - 56;
    double cameraHeight = cameraWidth * (4 / 3);

    Color textPrimary = isLightMode ? Colors.black : Colors.white;
    Color textSecondary = isLightMode
        ? Colors.grey[700]!
        : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 10),

          // Role chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withOpacity(0.4)),
            ),
            child: Text(
              widget.roleTitle,
              style: const TextStyle(
                color: _accentGlow,
                fontSize: 19, // Diubah menjadi 19
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Live Camera Preview Portrait
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: cameraWidth + 12,
                height: cameraHeight + 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: _isAutoScanning
                        ? _accentGlow.withOpacity(0.3)
                        : Colors.redAccent.withOpacity(0.2),
                    width: 6,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: cameraWidth,
                height: cameraHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: const Color(0xFF0F2040),
                  border: Border.all(
                    color: _isAutoScanning
                        ? _accentGlow.withOpacity(0.8)
                        : Colors.redAccent.withOpacity(0.6),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isAutoScanning ? _accent : Colors.redAccent)
                          .withOpacity(0.3),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(27),
                  child: _isCameraInitialized && _cameraController != null
                      ? AspectRatio(
                          aspectRatio: 3 / 4,
                          child: CameraPreview(_cameraController!),
                        )
                      : const Center(
                          child: Icon(
                            Icons.face_retouching_natural_rounded,
                            color: Colors.white54,
                            size: 60,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),

          Text(
            'User ID : $_savedUserId',
            style: TextStyle(
              color: textPrimary,
              fontSize: 20, // Diubah menjadi 20
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isAutoScanning
                ? Column(
                    key: const ValueKey('scanning'),
                    children: [
                      const SizedBox(height: 10),
                      const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: _accentGlow,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Mengidentifikasi Wajah…\nPosisikan wajah Anda di tengah layar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 19, // Diubah menjadi 19
                          height: 1.5,
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('failed'),
                    children: [
                      const Text(
                        'Wajah tidak dikenali.',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 19, // Diubah menjadi 19
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _autoScanLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.refresh_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        SizedBox(width: 8),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'COBA SCAN LAGI',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize:
                                                    20, // Diubah menjadi 20
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          const Spacer(flex: 2),

          TextButton(
            onPressed: _clearSavedData,
            child: Text(
              'Ganti Akun',
              style: TextStyle(
                color: textSecondary,
                fontSize: 19, // Diubah menjadi 19
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
