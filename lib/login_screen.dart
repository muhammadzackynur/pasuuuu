import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dashboard_screen.dart'; // Pastikan file dashboard_screen.dart sudah dibuat

class LoginScreen extends StatefulWidget {
  final String roleTitle;

  const LoginScreen({super.key, required this.roleTitle});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controller untuk mengambil input dari TextField
  final TextEditingController _idController = TextEditingController();
  bool _isLoading = false;

  // Fungsi untuk memanggil API Laravel
  Future<void> _login() async {
    // Validasi input kosong
    if (_idController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("ID tidak boleh kosong")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // GANTI IP INI dengan IP Laptop Anda atau gunakan 10.0.2.2 untuk Emulator Android
      // Jika menggunakan Chrome/Web gunakan 127.0.0.1
      final url = Uri.parse('http://192.168.1.28:8000/api/login');

      final response = await http.post(
        url,
        body: {'user_id': _idController.text, 'role': widget.roleTitle},
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Jika Berhasil, pindah ke Dashboard
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              userName: data['user']['name'],
              role: data['user']['role'],
              // Tambahan: Mengirim ID Tampilan dan ID Database ke Dashboard
              userId: data['user']['user_id'] ?? '-',
              databaseId: data['user']['id'],
            ),
          ),
        );
      } else {
        // Jika Gagal, tampilkan pesan error dari Laravel
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Login Gagal")),
        );
      }
    } catch (e) {
      // Jika tidak bisa terhubung ke server
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal terhubung ke server. Pastikan Backend menyala."),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF0F172A,
      ), // Warna background gelap sesuai tema
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
          child: Padding(
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
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2196F3),
                    ),
                    child: const Icon(
                      Icons.wifi_tethering,
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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Masukkan ID',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _idController, // Menghubungkan controller
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Masukkan ID Anda',
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
                const SizedBox(height: 100),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : _login, // Disable tombol saat loading
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.fingerprint, color: Colors.white),
                    label: Text(
                      _isLoading ? 'MOHON TUNGGU...' : 'LOGIN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
                const SizedBox(height: 40),
                const Text(
                  '© 2025 Maintenance System',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
