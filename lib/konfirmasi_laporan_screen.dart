import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dashboard_screen.dart'; // Pastikan import ini ada

class KonfirmasiLaporanScreen extends StatefulWidget {
  final String userName;
  final String role;
  final String userId;
  final int databaseId;

  // Data Laporan
  final String area;
  final String district;
  final String witel;
  final String sto;
  final String mitraPelaksana;
  final String kategoriKegiatan;
  final String uraianPekerjaan;

  const KonfirmasiLaporanScreen({
    super.key,
    required this.userName,
    required this.role,
    required this.userId,
    required this.databaseId,
    required this.area,
    required this.district,
    required this.witel,
    required this.sto,
    required this.mitraPelaksana,
    required this.kategoriKegiatan,
    required this.uraianPekerjaan,
  });

  @override
  State<KonfirmasiLaporanScreen> createState() =>
      _KonfirmasiLaporanScreenState();
}

class _KonfirmasiLaporanScreenState extends State<KonfirmasiLaporanScreen> {
  bool _isLoading = false;

  Future<void> _submitLaporan() async {
    setState(() => _isLoading = true);

    try {
      // URL API (Gunakan 10.0.2.2 untuk emulator Android)
      var url = Uri.parse("http://192.168.1.28:8000/api/maintenance/report");

      var response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          'user_id': widget.userId,
          'area': widget.area,
          'district': widget.district,
          'witel': widget.witel,
          'sto': widget.sto,
          'mitra_pelaksana': widget.mitraPelaksana,
          'kategori_kegiatan': widget.kategoriKegiatan,
          'uraian_pekerjaan': widget.uraianPekerjaan,
          'teknisi': widget.userName, // Mengirim nama user sebagai inputter
        }),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Laporan berhasil dikirim!")),
        );

        // --- PERUBAHAN NAVIGASI DI SINI ---
        // Kembali ke Dashboard dan hapus history halaman Input & Konfirmasi
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              userName: widget.userName,
              role: widget.role,
              userId: widget.userId,
              databaseId: widget.databaseId,
            ),
          ),
          (route) =>
              false, // Hapus semua rute sebelumnya (Login, dll) agar Dashboard jadi halaman utama baru
        );
      } else {
        // Menampilkan pesan error detail dari backend jika ada
        var errorMsg = response.body;
        try {
          var jsonResp = jsonDecode(response.body);
          errorMsg = jsonResp['message'] ?? response.body;
        } catch (_) {}

        throw Exception(
          "Gagal mengirim (Status: ${response.statusCode}) - $errorMsg",
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1424),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Konfirmasi Laporan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      // MENGGUNAKAN SafeArea AGAR TIDAK TERTUTUP PONI/STATUS BAR
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard("Detail Lokasi", {
                "Area": widget.area,
                "District": widget.district,
                "Witel": widget.witel,
                "STO": widget.sto,
              }),
              const SizedBox(height: 15),
              _buildInfoCard("Detail Pekerjaan", {
                "Mitra": widget.mitraPelaksana,
                "Kategori": widget.kategoriKegiatan,
                "Uraian": widget.uraianPekerjaan,
                "Inputter": widget.userName,
              }),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitLaporan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "KIRIM LAPORAN SEKARANG",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, Map<String, String> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const Divider(color: Colors.grey, height: 20),
          ...data.entries
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Text(": ", style: TextStyle(color: Colors.grey)),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}
