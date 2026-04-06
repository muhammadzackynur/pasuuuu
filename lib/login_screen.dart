import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

// Pastikan file import ini sesuai dengan nama file Anda
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

  // --- VARIABEL UNTUK BIOMETRIK & PENYIMPANAN ---
  final LocalAuthentication auth = LocalAuthentication();
  bool _hasSavedId = false;
  String _savedUserId = '';

  @override
  void initState() {
    super.initState();
    // Mengecek apakah sudah ada ID tersimpan saat halaman pertama kali dibuka
    _checkSavedLogin();
  }

  // --- FUNGSI CEK PENYIMPANAN ---
  Future<void> _checkSavedLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Kita bedakan simpanan ID Admin dan Tim Lapangan
    String? savedId = prefs.getString('saved_user_id_${widget.roleTitle}');

    if (savedId != null && savedId.isNotEmpty) {
      setState(() {
        _hasSavedId = true;
        _savedUserId = savedId;
        _idController.text = savedId; // Mengisi controller secara diam-diam
      });

      // Jika ada ID tersimpan, langsung munculkan pop-up Sidik Jari secara otomatis!
      _authenticateWithBiometric();
    }
  }

  // --- FUNGSI MEMANGGIL SIDIK JARI ---
  Future<void> _authenticateWithBiometric() async {
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      bool isSupported = await auth.isDeviceSupported();

      if (!canCheckBiometrics || !isSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perangkat tidak mendukung Sidik Jari")),
        );
        return;
      }

      bool authenticated = await auth.authenticate(
        localizedReason: 'Gunakan Sidik Jari untuk masuk sebagai $_savedUserId',
        options: const AuthenticationOptions(
          biometricOnly: true, // Hanya menerima Sidik Jari/Face ID
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        // Jika sidik jari benar, otomatis tembak API Login
        _login();
      }
    } catch (e) {
      print("Error Biometrik: $e");
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

  // --- FUNGSI UTAMA LOGIN KE SERVER API ---
  Future<void> _login() async {
    if (_idController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("ID tidak boleh kosong")));
      return;
    }

    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('http://192.168.1.83:8000/api/login');

      String roleYangDikirim = widget.roleTitle.toLowerCase().contains("admin")
          ? "admin"
          : "tim_lapangan";
      String idYangDikirim = _idController.text.trim();

      final response = await http.post(
        url,
        body: {'user_id': idYangDikirim, 'role': roleYangDikirim},
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // --- JIKA LOGIN BERHASIL, SIMPAN ID PERMANEN KE MEMORI HP ---
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'saved_user_id_${widget.roleTitle}',
          idYangDikirim,
        );

        if (!mounted) return;

        String userRole = data['user']['role'].toString().toLowerCase();

        // Routing pindah halaman
        if (userRole == 'admin' ||
            userRole.contains('administrasi') ||
            roleYangDikirim == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDashboardScreen(
                userName: data['user']['name'],
                role: data['user']['role'],
                // Melemparkan data user_id agar diterima di Profil Admin
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
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Login Gagal"),
            backgroundColor: Colors.red,
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
                    _hasSavedId
                        ? Icons.fingerprint
                        : Icons
                              .wifi_tethering, // Icon berubah jika pakai sidik jari
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Operasi Pemeliharaan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // =========================================================================
              // TAMPILAN 1: JIKA SUDAH ADA ID TERSIMPAN (MODE SIDIK JARI)
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
                    onPressed: _isLoading ? null : _authenticateWithBiometric,
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
                            Icons.fingerprint,
                            color: Colors.white,
                            size: 28,
                          ),
                    label: Text(
                      _isLoading ? 'MOHON TUNGGU...' : 'LOGIN SIDIK JARI',
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
              // TAMPILAN 2: JIKA BARU PERTAMA KALI BUKA APLIKASI (MODE KETIK ID)
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
                      if (value.trim().isNotEmpty) _login();
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
                const SizedBox(height: 60),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _login,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.login, color: Colors.white),
                    label: Text(
                      _isLoading ? 'MOHON TUNGGU...' : 'MASUK',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
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
