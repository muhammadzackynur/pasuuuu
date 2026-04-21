import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';

import 'dashboard_screen.dart';
import 'admin_dashboard_screen.dart';

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

  final String serverUrl = 'http://10.253.130.116:8000/api';

  // ─── Color palette ───────────────────────────────────────────────────────
  static const Color _bgDeep = Color(0xFF080E1C);
  static const Color _bgCard = Color(0xFF111827);
  static const Color _fieldBg = Color(0xFF1A2336);
  static const Color _accent = Color(0xFF3B8BEB);
  static const Color _accentGlow = Color(0xFF5BA3F5);
  static const Color _orange = Color(0xFFF97316);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFF94A3B8);

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

      // Setelah kamera siap, langsung cek apakah ada saved ID
      _checkSavedLogin();
    } catch (e) {
      debugPrint("Error kamera: $e");
      // Tetap cek saved login meski kamera gagal
      _checkSavedLogin();
    }
  }

  /// Cek apakah user sudah pernah login sebelumnya.
  Future<void> _checkSavedLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedId = prefs.getString('saved_user_id_${widget.roleTitle}');
    if (savedId != null && savedId.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _hasSavedId = true;
        _savedUserId = savedId;
      });
      // Langsung mulai auto scan wajah
      _autoScanLogin();
    }
  }

  // =========================================================================
  /// Daftarkan wajah baru untuk user yang baru pertama kali login.
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
        Uri.parse('$serverUrl/register-fingerprint'),
      );
      request.headers.addAll({'Accept': 'application/json'});
      request.fields['user_id'] = userId;
      request.files.add(
        await http.MultipartFile.fromPath('fingerprint_image', picture.path),
      );
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      var data = json.decode(response.body);
      if (data['success'] == true) {
        // Simpan user_id agar login berikutnya langsung auto scan
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

  /// Auto scan wajah menggunakan saved_user_id yang tersimpan.
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
      // Jeda singkat agar kamera benar-benar siap menangkap frame
      await Future.delayed(const Duration(milliseconds: 1500));
      XFile picture = await _cameraController!.takePicture();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/login-fingerprint'),
      );
      request.headers.addAll({'Accept': 'application/json'});
      request.fields['user_id'] = currentSavedId;
      request.files.add(
        await http.MultipartFile.fromPath('fingerprint_image', picture.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

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

  /// Login lanjutan setelah registrasi wajah berhasil.
  Future<void> _loginLanjutkan(String userId) async {
    try {
      String roleYangDikirim = widget.roleTitle.toLowerCase().contains("admin")
          ? "admin"
          : "tim_lapangan";
      final response = await http.post(
        Uri.parse('$serverUrl/login'),
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

  /// FUNGSI GANTI AKUN:
  /// Menghapus saved ID dari storage dan mengembalikan UI ke menu input ID.
  Future<void> _clearSavedData() async {
    setState(() => _isLoading = true);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    // 1. Hapus data dari SharedPreferences
    await prefs.remove('saved_user_id_${widget.roleTitle}');

    // Memberikan delay kecil agar transisinya halus
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    setState(() {
      _hasSavedId = false; // Kembali ke tampilan _buildMainBody()
      _savedUserId = ''; // Reset variabel ID
      _idController.clear(); // Bersihkan text field
      _isRegisteringFace = false; // Pastikan tidak dalam mode kamera jepret
      _isAutoScanning = false; // Matikan status scanning
      _isLoading = false; // Selesai loading
    });
  }

  void _routeToDashboard(Map<String, dynamic> data) {
    if (!mounted) return;
    String userRole = data['user']['role'].toString().toLowerCase();
    if (userRole.contains('admin')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboardScreen(
            userName: data['user']['name'],
            role: data['user']['role'],
            userId: data['user']['user_id'].toString(),
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            userName: data['user']['name'],
            role: data['user']['role'],
            userId: data['user']['user_id']?.toString() ?? '-',
            databaseId: data['user']['id'],
          ),
        ),
      );
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      body: Stack(
        children: [
          // Background radial glow
          Positioned(
            top: -100,
            left: MediaQuery.of(context).size.width / 2 - 180,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_accent.withOpacity(0.18), Colors.transparent],
                ),
              ),
            ),
          ),

          // Hidden camera untuk auto scan (selalu siap di background jika ada saved ID)
          if (_isCameraInitialized && !_isRegisteringFace)
            Offstage(
              offstage: true,
              child: SizedBox(
                width: 1,
                height: 1,
                child: CameraPreview(_cameraController!),
              ),
            ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    // AppBar row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: _hasSavedId
                          ? _buildAutoScanBody()
                          : _isRegisteringFace && _isCameraInitialized
                          ? _buildRegisterFaceBody()
                          : _buildMainBody(),
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

  // ── MAIN BODY (Input ID) ───────────────────────────────────────────────────
  Widget _buildMainBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          // Role chip
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withOpacity(0.4)),
              ),
              child: Text(
                widget.roleTitle,
                style: const TextStyle(
                  color: _accentGlow,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Icon
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                ),
                boxShadow: [
                  BoxShadow(color: _accent.withOpacity(0.45), blurRadius: 20),
                ],
              ),
              child: const Icon(
                Icons.cell_tower_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Title
          const Center(
            child: Text(
              'Operasi Pemeliharaan',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 6),

          const Center(
            child: Text(
              'Masukkan ID untuk melanjutkan',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ),

          const SizedBox(height: 20),

          // Label
          const Text(
            'Masukkan ID',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          // Input
          Container(
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: TextField(
              controller: _idController,
              style: const TextStyle(color: _textPrimary, fontSize: 15),
              cursorColor: _accentGlow,
              decoration: const InputDecoration(
                hintText: 'Masukkan ID Anda',
                hintStyle: TextStyle(color: Color(0xFF4B5563)),
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF3B8BEB),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Button (lebih dekat ke input)
          SizedBox(
            width: double.infinity,
            height: 56,
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
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: _accent.withOpacity(0.5), blurRadius: 16),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.face_retouching_natural_rounded,
                        color: Colors.white,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'DAFTARKAN WAJAH SAYA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Center(
            child: Text(
              '© 2025 Maintenance System',
              style: TextStyle(color: Color(0xFF374151), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── REGISTER FACE BODY (Kamera Aktif untuk Jepret) ──────────────────────────
  Widget _buildRegisterFaceBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text(
            'Posisikan Wajah di Tengah',
            style: TextStyle(
              color: _orange,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // --- PERUBAHAN BENTUK KAMERA MENJADI KOTAK PORTRAIT 4:3 ---
          Container(
            width: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                20,
              ), // Sudut kotak sedikit melengkung
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
              borderRadius: BorderRadius.circular(
                17,
              ), // Sedikit lebih kecil dari border luar
              child: AspectRatio(
                aspectRatio: 3 / 4, // Rasio 4:3 versi portrait
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

          // -----------------------------------------------------------
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _registerFace,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.camera_alt_rounded, color: Colors.white),
              label: Text(
                _isLoading ? 'MENYIMPAN...' : 'JEPRET & DAFTAR',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => setState(() => _isRegisteringFace = false),
            child: const Text(
              'Batal',
              style: TextStyle(color: _textSecondary, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── AUTO SCAN BODY (Tampilan Identifikasi Wajah Otomatis) ───────────────────
  Widget _buildAutoScanBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withOpacity(0.4)),
            ),
            child: Text(
              widget.roleTitle,
              style: const TextStyle(
                color: _accentGlow,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isAutoScanning
                        ? _accentGlow.withOpacity(0.3)
                        : Colors.redAccent.withOpacity(0.2),
                    width: 8,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F2040),
                  border: Border.all(
                    color: _isAutoScanning
                        ? _accentGlow.withOpacity(0.8)
                        : Colors.redAccent.withOpacity(0.6),
                    width: 2,
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
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  _isAutoScanning
                      ? Icons.face_retouching_natural_rounded
                      : Icons.face_retouching_off_rounded,
                  key: ValueKey(_isAutoScanning),
                  color: _isAutoScanning ? _accentGlow : Colors.redAccent,
                  size: 60,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'User ID : $_savedUserId',
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 20,
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
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: _accentGlow,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Mengidentifikasi Wajah…\nHarap lihat ke layar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 15,
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
                        style: TextStyle(color: Colors.redAccent, fontSize: 15),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
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
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
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
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'COBA SCAN LAGI',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
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
          // TOMBOL GANTI AKUN
          TextButton(
            onPressed: _clearSavedData,
            child: const Text(
              'Ganti Akun',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
