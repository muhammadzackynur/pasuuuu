import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dashboard_screen.dart';
import 'api_config.dart';

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
      var url = Uri.parse("${ApiConfig.baseUrl}/maintenance/report");
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

      for (String p in widget.fotoBeforePaths) {
        request.files.add(
          await http.MultipartFile.fromPath('foto_before[]', p),
        );
      }
      for (String p in widget.fotoProgressPaths) {
        request.files.add(
          await http.MultipartFile.fromPath('foto_progress[]', p),
        );
      }
      for (String p in widget.fotoAfterPaths) {
        request.files.add(await http.MultipartFile.fromPath('foto_after[]', p));
      }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color bgColor = isLightMode
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0D1424);
    Color cardColor = isLightMode ? Colors.white : const Color(0xFF1E293B);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Konfirmasi Laporan',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 25, // Diubah menjadi 20
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
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
            }, isLightMode),
            const SizedBox(height: 15),

            _buildInfoCard("Rincian Pekerjaan", {
              "Mitra": widget.mitraPelaksana,
              "Kategori": widget.kategoriKegiatan,
              "Uraian": widget.uraianPekerjaan,
            }, isLightMode),
            const SizedBox(height: 15),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isLightMode
                    ? [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Lokasi & Link Maps",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 20, // Diubah menjadi 20
                    ),
                  ),
                  Divider(
                    color: isLightMode ? Colors.grey[300] : Colors.white10,
                    height: 20,
                  ),
                  Text(
                    "Latitude: ${widget.latitude ?? '-'}",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 19,
                    ), // Diubah menjadi 19
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Longitude: ${widget.longitude ?? '-'}",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 19,
                    ), // Diubah menjadi 19
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    widget.mapsLink ?? "-",
                    style: TextStyle(
                      color: isLightMode
                          ? Colors.blue[700]
                          : Colors.greenAccent,
                      fontSize: 19, // Diubah menjadi 19
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 55, // Sedikit diperbesar
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
                        size: 24, // Ikon diperbesar
                      ),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Buka di Google Maps",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20, // Diubah menjadi 20
                          ),
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
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isLightMode
                    ? [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bukti Foto",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 20, // Diubah menjadi 20
                    ),
                  ),
                  Divider(
                    color: isLightMode ? Colors.grey[300] : Colors.white10,
                    height: 20,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPhotoPreview(
                        "Before",
                        widget.fotoBeforePaths,
                        isLightMode,
                      ),
                      _buildPhotoPreview(
                        "Progress",
                        widget.fotoProgressPaths,
                        isLightMode,
                      ),
                      _buildPhotoPreview(
                        "After",
                        widget.fotoAfterPaths,
                        isLightMode,
                      ),
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
                    : const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "KIRIM LAPORAN SEKARANG",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20, // Diubah menjadi 20
                          ),
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

  Widget _buildInfoCard(
    String title,
    Map<String, String> data,
    bool isLightMode,
  ) {
    Color cardColor = isLightMode ? Colors.white : const Color(0xFF1E293B);
    Color textColor = isLightMode ? Colors.black : Colors.white;
    Color subtitleColor = isLightMode ? Colors.grey[700]! : Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: isLightMode
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 20, // Diubah menjadi 20
            ),
          ),
          Divider(
            color: isLightMode ? Colors.grey[300] : Colors.white10,
            height: 20,
          ),
          ...data.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90, // Diperlebar sedikit agar muat font besar
                    child: Text(
                      e.key,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 19,
                      ), // Diubah menjadi 19
                    ),
                  ),
                  Text(
                    ": ",
                    style: TextStyle(color: subtitleColor, fontSize: 19),
                  ), // Diubah menjadi 19
                  Expanded(
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 19, // Diubah menjadi 19
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(
    String label,
    List<String> paths,
    bool isLightMode,
  ) {
    Color boxBg = isLightMode ? Colors.grey[200]! : const Color(0xFF0D1424);
    Color borderColor = isLightMode
        ? Colors.grey[300]!
        : Colors.grey.withOpacity(0.3);

    return Column(
      children: [
        Container(
          width: 90, // Sedikit diperbesar
          height: 90, // Sedikit diperbesar
          decoration: BoxDecoration(
            color: boxBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
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
                            fontSize: 14, // Diperbesar
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Icon(
                  Icons.image_not_supported,
                  color: isLightMode ? Colors.grey[400] : Colors.grey,
                  size: 30, // Ikon diperbesar
                ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: isLightMode ? Colors.grey[800] : Colors.white70,
              fontSize: 19, // Diubah menjadi 19
            ),
          ),
        ),
      ],
    );
  }
}
