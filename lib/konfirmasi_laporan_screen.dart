import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dashboard_screen.dart'; // Pastikan file dashboard diimport

class KonfirmasiLaporanScreen extends StatefulWidget {
  // --- DATA USER (Untuk Session) ---
  final String userName;
  final String role;
  final String userId; // ID Tampilan (misal TEK-001)
  final int databaseId; // ID Database (PK)

  // --- DATA LAPORAN ---
  final String lokasi;
  final double? lat;
  final double? lng;
  final String jenisMaintenance;
  final String deskripsi;
  final String durasi;
  final String tanggal;
  final List<String> teknisi;
  final List<File> fotoBefore;
  final List<File> fotoProgress;
  final List<File> fotoAfter;

  const KonfirmasiLaporanScreen({
    super.key,
    // Wajib di-pass dari screen sebelumnya (InputLaporanScreen)
    required this.userName,
    required this.role,
    required this.userId,
    required this.databaseId,

    required this.lokasi,
    this.lat,
    this.lng,
    required this.jenisMaintenance,
    required this.deskripsi,
    required this.durasi,
    required this.tanggal,
    required this.teknisi,
    required this.fotoBefore,
    required this.fotoProgress,
    required this.fotoAfter,
  });

  @override
  State<KonfirmasiLaporanScreen> createState() =>
      _KonfirmasiLaporanScreenState();
}

class _KonfirmasiLaporanScreenState extends State<KonfirmasiLaporanScreen> {
  String _detailAlamat = "Sedang mengambil data alamat...";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.lat != null && widget.lng != null) {
      _getAddressFromLatLng();
    }
  }

  Future<void> _getAddressFromLatLng() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.lat!,
        widget.lng!,
      );
      Placemark place = placemarks[0];
      setState(() {
        _detailAlamat =
            "Kota: ${place.subAdministrativeArea}\n"
            "Kecamatan: ${place.locality}\n"
            "Desa/Kel: ${place.subLocality}";
      });
    } catch (e) {
      setState(() => _detailAlamat = "Gagal memuat alamat.");
    }
  }

  // Fungsi Kirim Laporan & Redirect ke Dashboard
  Future<void> _submitLaporan() async {
    setState(() => _isLoading = true);

    try {
      // GANTI IP INI SESUAI SERVER ANDA
      var uri = Uri.parse('http://192.168.100.192:8000/api/maintenance/report');
      var request = http.MultipartRequest('POST', uri);

      request.headers.addAll({'Accept': 'application/json'});

      // Formatting Tanggal ke YYYY-MM-DD untuk Laravel
      String formattedDate;
      try {
        DateTime parsedDate = DateFormat("dd/MM/yyyy").parse(widget.tanggal);
        formattedDate = DateFormat("yyyy-MM-dd").format(parsedDate);
      } catch (e) {
        formattedDate = DateFormat("yyyy-MM-dd").format(DateTime.now());
      }

      // Menggunakan ID User yang login (Dinamis)
      request.fields['user_id'] = widget.databaseId.toString();

      request.fields['lokasi_pekerjaan'] = widget.lokasi;
      request.fields['latitude'] = widget.lat?.toString() ?? "";
      request.fields['longitude'] = widget.lng?.toString() ?? "";
      request.fields['jenis_maintenance'] = widget.jenisMaintenance;
      request.fields['time_plan'] = formattedDate;
      request.fields['deskripsi_masalah'] = widget.deskripsi;
      request.fields['teknisi'] = widget.teknisi.join(', ');

      if (widget.fotoBefore.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto_before',
            widget.fotoBefore.first.path,
          ),
        );
      }
      if (widget.fotoProgress.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto_progress',
            widget.fotoProgress.first.path,
          ),
        );
      }
      if (widget.fotoAfter.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto_after',
            widget.fotoAfter.first.path,
          ),
        );
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan Berhasil Disimpan!')),
        );

        // PERBAIKAN UTAMA: Mengirimkan data user lengkap ke DashboardScreen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              userName: widget.userName, // Dinamis dari widget
              role: widget.role, // Dinamis dari widget
              userId: widget.userId, // Dinamis dari widget
              databaseId: widget.databaseId, // Dinamis dari widget
            ),
          ),
          (Route<dynamic> route) => false,
        );
      } else {
        print("Detail Error: $responseData");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal (${response.statusCode}): Cek console'),
          ),
        );
      }
    } catch (e) {
      print("Error Koneksi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1424),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Konfirmasi Laporan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(
                    Icons.calendar_month,
                    "TIME PLAN",
                    widget.tanggal,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    Icons.settings,
                    "MAINTENANCE",
                    widget.jenisMaintenance,
                    Colors.orange,
                  ),
                  const SizedBox(height: 20),
                  _buildMapSection(),
                  const SizedBox(height: 20),
                  _buildPhotoCategory("DOKUMENTASI BEFORE", widget.fotoBefore),
                  const SizedBox(height: 15),
                  _buildPhotoCategory(
                    "DOKUMENTASI PROGRESS",
                    widget.fotoProgress,
                  ),
                  const SizedBox(height: 15),
                  _buildPhotoCategory("DOKUMENTASI AFTER", widget.fotoAfter),
                  const SizedBox(height: 30),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.lat != null && widget.lng != null)
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.lat!, widget.lng!),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId("lok"),
                    position: LatLng(widget.lat!, widget.lng!),
                  ),
                },
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          _detailAlamat,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPhotoCategory(String title, List<File> images) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (context, index) => Container(
              width: 100,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: FileImage(images[index]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitLaporan,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: const Text(
          "Kirim Laporan",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
