import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // Pastikan OneSignal di-import

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

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Sesuaikan dengan IP Jaringan laptop Anda
  final String serverUrl = 'http://192.168.1.41:8000/api';

  // ─── Color palette ───────────────────────────────────────────────────────
  static const Color _bgDeep = Color(0xFF080E1C);
  static const Color _fieldBg = Color(0xFF1A2336);
  static const Color _accent = Color(0xFF3B8BEB);
  static const Color _accentGlow = Color(0xFF5BA3F5);
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

    _animController.forward();
  }

  // =========================================================================
  // FUNGSI LOGIN MANUAL MENGGUNAKAN ID SAJA
  // =========================================================================
  Future<void> _loginProcess() async {
    final String userId = _idController.text.trim();

    if (userId.isEmpty) {
      _showSnack("Silakan masukkan ID terlebih dahulu", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Sesuaikan string role untuk dikirim ke backend
      String roleYangDikirim = widget.roleTitle.toLowerCase().contains("admin")
          ? "admin"
          : "tim_lapangan";

      final response = await http.post(
        Uri.parse('$serverUrl/login'),
        headers: {'Accept': 'application/json'},
        body: {'user_id': userId, 'role': roleYangDikirim},
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _routeToDashboard(data);
      } else {
        if (!mounted) return;
        _showSnack(
          data['message'] ?? "Login Gagal. Cek kembali ID Anda.",
          Colors.red,
        );
      }
    } catch (e) {
      debugPrint("Error Login: $e");
      if (!mounted) return;
      _showSnack("Gagal menghubungi server. Periksa koneksi/IP.", Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // =========================================================================
  // ROUTING & ONESIGNAL TAGGING
  // =========================================================================
  void _routeToDashboard(Map<String, dynamic> data) {
    if (!mounted) return;

    String userIdStr = data['user']['user_id'].toString();
    String userRole = data['user']['role'].toString().toLowerCase();

    // 1. Daftarkan user ID ke OneSignal
    OneSignal.login(userIdStr);

    // 2. Arahkan ke dashboard sesuai role & berikan Tag OneSignal
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

                    Expanded(child: _buildMainBody()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MAIN BODY (Input ID & Tombol Login) ────────────────────────────────────
  Widget _buildMainBody() {
    return SingleChildScrollView(
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

          const SizedBox(height: 40),

          // Label
          const Text(
            'User ID',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          // Input Field
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

          const SizedBox(height: 30),

          // Button Login
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _loginProcess,
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
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.login_rounded, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'MASUK SEKARANG',
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

          const SizedBox(height: 40),

          const Center(
            child: Text(
              '© 2026 Maintenance System',
              style: TextStyle(color: Color(0xFF374151), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
