import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; // Menggunakan Kamera untuk biometrik
import 'package:device_info_plus/device_info_plus.dart'; // Menggunakan Device ID

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
  Timer? _debounce;

  bool _hasSavedId = false;
  String _savedUserId = '';

  // Gunakan IP Server yang Anda berikan
  final String serverUrl = 'http://192.168.1.83:8000/api';

  @override
  void initState() {
    super.initState();
    // Mengecek apakah sudah ada ID tersimpan saat halaman pertama kali dibuka
    _checkSavedLogin();
  }

  // --- FUNGSI MENGAMBIL DEVICE ID UNIK DARI HP ---
  Future<String> _getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Unique ID on Android
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios'; // Unique ID on iOS
      }
    } catch (e) {
      print("Gagal mendapatkan Device ID: $e");
    }
    return 'unknown_device';
  }

  // --- FUNGSI CEK PENYIMPANAN ---
  Future<void> _checkSavedLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedId = prefs.getString('saved_user_id_${widget.roleTitle}');

    if (savedId != null && savedId.isNotEmpty) {
      setState(() {
        _hasSavedId = true;
        _savedUserId = savedId;
        _idController.text = savedId; // Mengisi controller secara diam-diam
      });
    }
  }

  // --- FUNGSI MENGHAPUS AKUN (JIKA INGIN GANTI ID) ---
  Future<void> _clearSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_user_id_${widget.roleTitle}');

    setState(() {
      _hasSavedId = false;
      _savedUserId = '';
      _idController.clear();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _idController.dispose();
    super.dispose();
  }

  // --- 1. FUNGSI DAFTAR SIDIK JARI KAMERA ---
  Future<void> _registerFingerprintCamera() async {
    if (_idController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Isi ID Anda dulu!")));
      return;
    }

    final ImagePicker picker = ImagePicker();
    // Buka Kamera HP mode makro
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 100, // Kualitas harus tinggi untuk Python OpenCV
    );

    if (photo != null) {
      setState(() => _isLoading = true);
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$serverUrl/register-fingerprint'),
        );
        request.fields['user_id'] = _idController.text.trim();
        request.files.add(
          await http.MultipartFile.fromPath('fingerprint_image', photo.path),
        );

        var response = await request.send();
        var responseData = await http.Response.fromStream(response);
        var data = json.decode(responseData.body);

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'])));

        // Jika pendaftaran jari berhasil, otomatis lanjutkan login untuk menyimpan Device ID
        if (data['success'] == true) _login();
      } catch (e) {
        print(e);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- 2. FUNGSI LOGIN MENGGUNAKAN SIDIK JARI KAMERA ---
  Future<void> _loginFingerprintCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 100,
    );

    if (photo != null) {
      setState(() => _isLoading = true);
      try {
        // Ambil Device ID untuk divalidasi juga oleh Laravel (Device Binding)
        String currentDeviceId = await _getDeviceId();

        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$serverUrl/login-fingerprint'),
        );
        request.fields['user_id'] = _savedUserId;
        request.fields['device_id'] =
            currentDeviceId; // Kirim Device ID ke backend
        request.files.add(
          await http.MultipartFile.fromPath('fingerprint_image', photo.path),
        );

        var response = await request.send();
        var responseData = await http.Response.fromStream(response);
        var data = json.decode(responseData.body);

        if (response.statusCode == 200 && data['success'] == true) {
          _routeToDashboard(data);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? "Ditolak"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        print(e);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- 3. FUNGSI UTAMA LOGIN (TANPA SIDIK JARI / LOGIN PERTAMA) ---
  Future<void> _login() async {
    if (_idController.text.trim().isEmpty) return;

    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      String roleYangDikirim = widget.roleTitle.toLowerCase().contains("admin")
          ? "admin"
          : "tim_lapangan";
      String idYangDikirim = _idController.text.trim();

      // Ambil Device ID sebelum mengirim ke server
      String currentDeviceId = await _getDeviceId();

      final response = await http.post(
        Uri.parse('$serverUrl/login'),
        body: {
          'user_id': idYangDikirim,
          'role': roleYangDikirim,
          'device_id': currentDeviceId,
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // --- JIKA LOGIN BERHASIL, SIMPAN ID PERMANEN KE MEMORI HP ---
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'saved_user_id_${widget.roleTitle}',
          idYangDikirim,
        );

        _routeToDashboard(data);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Login Gagal"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ROUTING / NAVIGASI HALAMAN ---
  void _routeToDashboard(Map<String, dynamic> data) {
    if (!mounted) return;
    String userRole = data['user']['role'].toString().toLowerCase();

    if (userRole == 'admin' ||
        userRole.contains('administrasi') ||
        widget.roleTitle.toLowerCase().contains("admin")) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AdminDashboardScreen(
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
          builder: (context) => DashboardScreen(
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
              Text(
                widget.roleTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // ICON DI TENGAH ATAS
              Center(
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2196F3),
                  ),
                  child: Icon(
                    _hasSavedId ? Icons.camera_alt : Icons.wifi_tethering,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Aplikasi GYM\nPelaporan & Monitoring',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // =========================================================================
              // TAMPILAN 1: JIKA SUDAH ADA ID TERSIMPAN (MODE KAMERA SIDIK JARI)
              // =========================================================================
              if (_hasSavedId) ...[
                const Text(
                  'Selamat Datang Kembali!',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  "User ID : $_savedUserId",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 50),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _loginFingerprintCamera,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.camera,
                            color: Colors.white,
                            size: 28,
                          ),
                    label: Text(
                      _isLoading ? 'MEMPROSES...' : 'SCAN JARI VIA KAMERA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D1F3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // TOMBOL BUKAN ANDA
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
              // TAMPILAN 2: JIKA BARU PERTAMA KALI BUKA (MODE KETIK ID & DAFTAR JARI)
              // =========================================================================
              else ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Masukkan ID Anda',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _idController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      // Hapus logika auto-login agar pengguna bisa memilih tombol di bawah
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Ketik User ID Anda...',
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
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'MASUK (Tanpa Sidik Jari)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _registerFingerprintCamera,
                    icon: const Icon(Icons.fingerprint, color: Colors.white),
                    label: const Text(
                      'DAFTARKAN SIDIK JARI KAMERA',
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
