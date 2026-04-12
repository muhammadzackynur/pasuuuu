import 'dart:convert';
import 'dart:io'; // Tambahan untuk membaca file gambar
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

  // DATA FOTO BARU
  final String? fotoBeforePath;
  final String? fotoProgressPath;
  final String? fotoAfterPath;

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
    this.fotoBeforePath,
    this.fotoProgressPath,
    this.fotoAfterPath,
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
      // URL API
      var url = Uri.parse("http://192.168.1.45:8000/api/maintenance/report");

      // MENGGUNAKAN MULTIPART REQUEST UNTUK MENGIRIM FILE + TEKS
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll({"Accept": "application/json"});

      // 1. Masukkan Data Teks
      request.fields['user_id'] = widget.userId;
      request.fields['area'] = widget.area;
      request.fields['district'] = widget.district;
      request.fields['witel'] = widget.witel;
      request.fields['sto'] = widget.sto;
      request.fields['mitra_pelaksana'] = widget.mitraPelaksana;
      request.fields['kategori_kegiatan'] = widget.kategoriKegiatan;
      request.fields['uraian_pekerjaan'] = widget.uraianPekerjaan;
      request.fields['teknisi'] = widget.userName; // Mengirim nama user

      // 2. Masukkan Data File (FOTO) jika ada
      if (widget.fotoBeforePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto_before',
            widget.fotoBeforePath!,
          ),
        );
      }
      if (widget.fotoProgressPath != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto_progress',
            widget.fotoProgressPath!,
          ),
        );
      }
      if (widget.fotoAfterPath != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto_after',
            widget.fotoAfterPath!,
          ),
        );
      }

      // 3. Kirim ke server
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Laporan & Foto berhasil dikirim!"),
            backgroundColor: Colors.green,
          ),
        );

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
          (route) => false,
        );
      } else {
        // Menangkap error detail dari Laravel
        var errorMsg = "Gagal mengirim data";
        try {
          var jsonResp = jsonDecode(response.body);
          errorMsg = jsonResp['message'] ?? response.body;

          if (jsonResp['errors'] != null) {
            Map<String, dynamic> errors = jsonResp['errors'];
            String detailedErrors = errors.values
                .map((e) => e[0].toString())
                .join('\n');
            errorMsg += "\n$detailedErrors";
          }
        } catch (_) {
          errorMsg = "Error Server: Status ${response.statusCode}";
        }

        throw Exception(errorMsg);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              const SizedBox(height: 25),

              // --- TAMBAHAN PREVIEW FOTO ---
              const Text(
                "Bukti Foto:",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPhotoPreview("Before", widget.fotoBeforePath),
                  _buildPhotoPreview("Progress", widget.fotoProgressPath),
                  _buildPhotoPreview("After", widget.fotoAfterPath),
                ],
              ),

              // -----------------------------
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

  // WIDGET KOTAK PREVIEW FOTO
  Widget _buildPhotoPreview(String label, String? path) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.5)),
          ),
          child: path != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(path), fit: BoxFit.cover),
                )
              : const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
