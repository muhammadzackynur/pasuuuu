import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dashboard_screen.dart';

class KonfirmasiLaporanScreen extends StatefulWidget {
  final String userName,
      role,
      userId,
      area,
      district,
      witel,
      sto,
      mitraPelaksana,
      kategoriKegiatan,
      uraianPekerjaan;
  final int databaseId;
  final List<String> fotoBeforePaths, fotoProgressPaths, fotoAfterPaths;
  final String? latitude, longitude, mapsLink;

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
    this.fotoBeforePaths = const [],
    this.fotoProgressPaths = const [],
    this.fotoAfterPaths = const [],
    this.latitude,
    this.longitude,
    this.mapsLink,
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
      var url = Uri.parse("http://192.168.1.164:8000/api/maintenance/report");
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll({"Accept": "application/json"});

      request.fields['user_id'] = widget.userId;
      request.fields['area'] = widget.area;
      request.fields['district'] = widget.district;
      request.fields['witel'] = widget.witel;
      request.fields['sto'] = widget.sto;
      request.fields['mitra_pelaksana'] = widget.mitraPelaksana;
      request.fields['kategori_kegiatan'] = widget.kategoriKegiatan;
      request.fields['uraian_pekerjaan'] = widget.uraianPekerjaan;
      request.fields['teknisi'] = widget.userName;
      request.fields['latitude'] = widget.latitude ?? "";
      request.fields['longitude'] = widget.longitude ?? "";

      // MENGIRIM LINK MAPS KE KOLOM LOKASI PEKERJAAN DI DATABASE
      request.fields['lokasi_pekerjaan'] = widget.mapsLink ?? "";

      for (String p in widget.fotoBeforePaths)
        request.files.add(
          await http.MultipartFile.fromPath('foto_before[]', p),
        );
      for (String p in widget.fotoProgressPaths)
        request.files.add(
          await http.MultipartFile.fromPath('foto_progress[]', p),
        );
      for (String p in widget.fotoAfterPaths)
        request.files.add(await http.MultipartFile.fromPath('foto_after[]', p));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Laporan berhasil dikirim!"),
            backgroundColor: Colors.green,
          ),
        );
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
        throw Exception("Gagal mengirim data: ${response.body}");
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
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
        title: const Text(
          'Konfirmasi Laporan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoCard("Data Laporan", {
              "Area": widget.area,
              "District": widget.district,
              "Witel": widget.witel,
              "STO": widget.sto,
              "Teknisi": widget.userName,
            }),
            const SizedBox(height: 15),

            _buildInfoCard("Rincian Pekerjaan", {
              "Mitra": widget.mitraPelaksana,
              "Kategori": widget.kategoriKegiatan,
              "Uraian": widget.uraianPekerjaan,
            }),
            const SizedBox(height: 15),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Lokasi & Link Maps",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  Text(
                    "Latitude: ${widget.latitude ?? '-'}",
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Longitude: ${widget.longitude ?? '-'}",
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    widget.mapsLink ?? "-",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (widget.mapsLink != null &&
                            widget.mapsLink!.isNotEmpty &&
                            widget.mapsLink != "-") {
                          await launchUrl(
                            Uri.parse(widget.mapsLink!),
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Link lokasi belum tersedia."),
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        "Buka di Google Maps",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bukti Foto",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPhotoPreview("Before", widget.fotoBeforePaths),
                      _buildPhotoPreview("Progress", widget.fotoProgressPaths),
                      _buildPhotoPreview("After", widget.fotoAfterPaths),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitLaporan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, Map<String, String> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const Divider(color: Colors.white10, height: 20),
          ...data.entries
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
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

  Widget _buildPhotoPreview(String label, List<String> paths) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1424),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: paths.isNotEmpty
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(paths.last), fit: BoxFit.cover),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "${paths.length} File",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
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
