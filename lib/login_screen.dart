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

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  bool _isLoading = false;

  bool _hasSavedId = false;
  String _savedUserId = '';

  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // Mode UI
  bool _isRegisteringFace = false; // Jika true, tampilkan kamera besar
  bool _isAutoScanning = false; // Jika true, sedang proses auto-login

  // Ganti IP ini sesuai dengan IP Laptop/Server Laravel Anda
  final String serverUrl = 'http://192.168.100.192:8000/api';

  @override
  void initState() {
    super.initState();
    _initializeCameraAndCheckLogin();
  }

  // Inisialisasi Kamera
  Future<void> _initializeCameraAndCheckLogin() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });

      _checkSavedLogin();
    } catch (e) {
      debugPrint("Error kamera: $e");
    }
  }

  Future<void> _checkSavedLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedId = prefs.getString('saved_user_id_${widget.roleTitle}');

    if (savedId != null && savedId.isNotEmpty) {
      setState(() {
        _hasSavedId = true;
        _savedUserId = savedId;
      });
      // Jika ada ID tersimpan, jalankan auto scan
      _autoScanLogin();
    }
  }

  // =========================================================================
  // FUNGSI 1: DAFTAR WAJAH (DENGAN VALIDASI ID KETAT)
  // =========================================================================
  Future<void> _registerFace() async {
    if (!_isCameraInitialized) return;

    // Pastikan ID diambil langsung dari controller dan di-trim
    final String userId = _idController.text.trim();

    if (userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("ID tidak boleh kosong!")));
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

      // Mengirim user_id hasil trim
      request.fields['user_id'] = userId;

      debugPrint("Mengirim pendaftaran untuk ID: $userId");

      request.files.add(
        await http.MultipartFile.fromPath('fingerprint_image', picture.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint("Response Server (${response.statusCode}): ${response.body}");

      if (response.statusCode >= 500) {
        throw "Terjadi kesalahan di server (500)";
      }

      var data = json.decode(response.body);

      if (data['success'] == true) {
        // Simpan ID ke SharedPreferences agar bisa auto-login nanti
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_user_id_${widget.roleTitle}', userId);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: Colors.green,
          ),
        );

        // Setelah daftar sukses, lanjutkan ke dashboard
        _loginLanjutkan(userId);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Gagal Daftar"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error Register: $e");
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // =========================================================================
  // FUNGSI 2: AUTO LOGIN WAJAH (PERBAIKAN: AMBIL ID SEBELUM KIRIM)
  // =========================================================================
  Future<void> _autoScanLogin() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    // Pastikan mengambil ID terbaru dari SharedPreferences agar tidak null
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? currentSavedId = prefs.getString(
      'saved_user_id_${widget.roleTitle}',
    );

    if (currentSavedId == null || currentSavedId.isEmpty) {
      setState(() => _hasSavedId = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _isAutoScanning = true;
      _savedUserId = currentSavedId;
    });

    try {
      // Tunggu kamera menyesuaikan exposure
      await Future.delayed(const Duration(milliseconds: 1500));

      XFile picture = await _cameraController!.takePicture();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/login-fingerprint'),
      );

      request.headers.addAll({'Accept': 'application/json'});

      // Mengirim ID yang sudah dipastikan ada dari SharedPreferences
      request.fields['user_id'] = currentSavedId;

      debugPrint("Auto Scanning Login untuk ID: $currentSavedId");

      request.files.add(
        await http.MultipartFile.fromPath('fingerprint_image', picture.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint(
        "Response Auto-Login (${response.statusCode}): ${response.body}",
      );

      if (response.statusCode >= 500) {
        throw "Internal Server Error";
      }

      var data = json.decode(response.body);

      if (data['success'] == true) {
        _routeToDashboard(data);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Wajah Tidak Dikenali"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isAutoScanning = false);
      }
    } catch (e) {
      debugPrint("Error Auto Login: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal menghubungi server"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isAutoScanning = false);
    } finally {
      if (mounted && !_isAutoScanning) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // FUNGSI PENDUKUNG
  // =========================================================================
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
        if (data['success'] == true) {
          _routeToDashboard(data);
        }
      }
    } catch (e) {
      debugPrint("Error Login Lanjutan: $e");
    }
  }

  Future<void> _clearSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_user_id_${widget.roleTitle}');
    setState(() {
      _hasSavedId = false;
      _savedUserId = '';
      _idController.clear();
      _isRegisteringFace = false;
      _isAutoScanning = false;
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

  @override
  void dispose() {
    _cameraController?.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: [
              // Kamera tersembunyi untuk auto-scan
              if (_isCameraInitialized && !_isRegisteringFace)
                Offstage(
                  offstage: true,
                  child: SizedBox(
                    width: 1,
                    height: 1,
                    child: CameraPreview(_cameraController!),
                  ),
                ),

              Text(
                widget.roleTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              if (_hasSavedId) ...[
                const SizedBox(height: 40),
                const Icon(
                  Icons.face_retouching_natural,
                  color: Color(0xFF00D1F3),
                  size: 100,
                ),
                const SizedBox(height: 30),
                Text(
                  "User ID : $_savedUserId",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                if (_isAutoScanning) ...[
                  const CircularProgressIndicator(color: Color(0xFF00D1F3)),
                  const SizedBox(height: 20),
                  const Text(
                    'Mengidentifikasi Wajah...\nHarap lihat ke layar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ] else ...[
                  const Text(
                    'Wajah tidak dikenali.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _autoScanLogin,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'COBA SCAN LAGI',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D1F3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                TextButton(
                  onPressed: _clearSavedData,
                  child: const Text(
                    "Ganti Akun",
                    style: TextStyle(
                      color: Colors.grey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ] else if (_isRegisteringFace && _isCameraInitialized) ...[
                const Text(
                  'Posisikan Wajah di Tengah',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 16),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.orangeAccent, width: 4),
                  ),
                  child: ClipOval(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _registerFace,
                    icon: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.camera_alt, color: Colors.white),
                    label: Text(
                      _isLoading ? 'MENYIMPAN...' : 'JEPRET & DAFTAR',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isRegisteringFace = false),
                  child: const Text(
                    "Batal",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.person_add_alt_1,
                  color: Colors.blueAccent,
                  size: 80,
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _idController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ketik User ID...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.person, color: Colors.blue),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_idController.text.trim().isEmpty) return;
                      setState(() => _isRegisteringFace = true);
                    },
                    icon: const Icon(Icons.face, color: Colors.white),
                    label: const Text(
                      'DAFTARKAN WAJAH SAYA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
