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

  final String serverUrl = 'http://192.168.100.192:8000/api';

  @override
  void initState() {
    super.initState();
    _initializeCameraAndCheckLogin();
  }

  // Inisialisasi Kamera selalu dilakukan di awal
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

      // Setelah kamera siap, baru cek apakah ada ID tersimpan
      _checkSavedLogin();
    } catch (e) {
      print("Error kamera: $e");
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
      // Jika ada ID tersimpan, langsung OTOMATIS SCAN wajah
      _autoScanLogin();
    }
  }

  // =========================================================================
  // FUNGSI 1: DAFTAR WAJAH (KAMERA DITAMPILKAN)
  // =========================================================================
  Future<void> _registerFace() async {
    if (!_isCameraInitialized) return;
    setState(() => _isLoading = true);

    try {
      // Jepret Foto dari Kamera yang sedang Tampil
      XFile picture = await _cameraController!.takePicture();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/register-fingerprint'),
      );

      // --- TAMBAHAN HEADER AGAR LARAVEL MENGEMBALIKAN JSON ---
      request.headers.addAll({'Accept': 'application/json'});

      request.fields['user_id'] = _idController.text.trim();
      request.files.add(
        await http.MultipartFile.fromPath('fingerprint_image', picture.path),
      );

      var response = await request.send();
      var responseData = await http.Response.fromStream(response);

      // --- MENCEGAH CRASH FORMAT EXCEPTION JIKA SERVER MENGIRIM HTML ---
      if (responseData.statusCode >= 500) {
        print("ERROR DARI LARAVEL: ${responseData.body}");

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Internal Server Error (500). Cek Terminal Laravel."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      var data = json.decode(responseData.body);

      if (data['success'] == true) {
        // Simpan ID ke Memori HP agar besok bisa auto-login
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'saved_user_id_${widget.roleTitle}',
          _idController.text.trim(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: Colors.green,
          ),
        );

        // Langsung Login Biasa setelah daftar wajah
        _loginLanjutkan();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // =========================================================================
  // FUNGSI 2: AUTO LOGIN WAJAH (KAMERA TERSEMBUNYI)
  // =========================================================================
  Future<void> _autoScanLogin() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    setState(() {
      _isLoading = true;
      _isAutoScanning = true;
    });

    try {
      // JEDA 1.5 DETIK SANGAT PENTING: Memberi waktu kamera menyesuaikan cahaya (exposure)
      // agar foto tidak gelap dan menyebabkan "Wajah tidak dikenali"
      await Future.delayed(const Duration(milliseconds: 1500));

      XFile picture = await _cameraController!.takePicture();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/login-fingerprint'),
      );

      // --- TAMBAHAN HEADER AGAR LARAVEL MENGEMBALIKAN JSON ---
      request.headers.addAll({'Accept': 'application/json'});

      request.fields['user_id'] = _savedUserId;
      request.files.add(
        await http.MultipartFile.fromPath('fingerprint_image', picture.path),
      );

      var response = await request.send();
      var responseData = await http.Response.fromStream(response);

      // --- MENCEGAH CRASH FORMAT EXCEPTION JIKA SERVER MENGIRIM HTML ---
      if (responseData.statusCode >= 500) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Internal Server Error (500). Cek Terminal Laravel."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isAutoScanning = false);
        return;
      }

      var data = json.decode(responseData.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _routeToDashboard(data);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Wajah Tidak Dikenali"),
            backgroundColor: Colors.red,
          ),
        );
        setState(
          () => _isAutoScanning = false,
        ); // Beri kesempatan user mengulang
      }
    } catch (e) {
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
  Future<void> _loginLanjutkan() async {
    try {
      String roleYangDikirim = widget.roleTitle.toLowerCase().contains("admin")
          ? "admin"
          : "tim_lapangan";
      final response = await http.post(
        Uri.parse('$serverUrl/login'),
        headers: {
          'Accept': 'application/json', // Tambahan header disini juga
        },
        body: {'user_id': _idController.text.trim(), 'role': roleYangDikirim},
      );

      if (response.statusCode >= 500) return; // Mencegah crash jika error HTML

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _routeToDashboard(data);
      }
    } catch (e) {
      // Tangani error diam-diam atau tambahkan log
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
              // =========================================================
              // WIDGET KAMERA TERSEMBUNYI (HIDDEN BACKGROUND SCANNER)
              // Hanya merender jika BUKAN sedang mode daftar wajah
              // =========================================================
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

              // =========================================================================
              // TAMPILAN 1: SUDAH ADA ID (MODE AUTO SCAN WAJAH)
              // =========================================================================
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
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 40),

                if (_isAutoScanning) ...[
                  const CircularProgressIndicator(color: Color(0xFF00D1F3)),
                  const SizedBox(height: 20),
                  const Text(
                    'Mengidentifikasi Wajah Anda...\nHarap lihat ke layar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ] else ...[
                  const Text(
                    'Wajah tidak dikenali atau proses gagal.',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                TextButton(
                  onPressed: _clearSavedData,
                  child: const Text(
                    "Bukan Anda? Ganti Akun",
                    style: TextStyle(
                      color: Colors.grey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ]
              // =========================================================================
              // TAMPILAN 2: DAFTAR WAJAH (KAMERA DITAMPILKAN DI LAYAR)
              // =========================================================================
              else if (_isRegisteringFace && _isCameraInitialized) ...[
                const Text(
                  'Posisikan Wajah Anda di Tengah Layar',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 16),
                ),
                const SizedBox(height: 20),

                // Kamera ditampilkan berbentuk lingkaran
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
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.white),
                    label: Text(
                      _isLoading ? 'MENYIMPAN...' : 'JEPRET & DAFTAR',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => setState(() => _isRegisteringFace = false),
                  child: const Text(
                    "Batal",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ]
              // =========================================================================
              // TAMPILAN 3: LOGIN PERTAMA KALI (KETIK ID)
              // =========================================================================
              else ...[
                const Icon(
                  Icons.person_add_alt_1,
                  color: Colors.blueAccent,
                  size: 80,
                ),
                const SizedBox(height: 30),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Masukkan ID Anda yang Terdaftar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 10),
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
                      if (_idController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Isi ID terlebih dahulu!"),
                          ),
                        );
                        return;
                      }
                      setState(
                        () => _isRegisteringFace = true,
                      ); // Pindah ke Mode Tampil Kamera
                    },
                    icon: const Icon(Icons.face, color: Colors.white),
                    label: const Text(
                      'DAFTARKAN WAJAH SAYA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
