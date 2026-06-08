import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_config.dart';

class DetailLaporanScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;

  const DetailLaporanScreen({super.key, required this.reportData});

  // Getter untuk URL storage
  String get storageBaseUrl =>
      ApiConfig.baseUrl.replaceAll('/api', '/storage/');

  // Fungsi untuk memfilter gambar berdasarkan tipenya
  List<String> _getImagesByType(String type) {
    if (reportData['images'] == null) return [];

    List<dynamic> allImages = reportData['images'];

    return allImages
        .where((img) => img['type'] == type)
        .map<String>((img) => storageBaseUrl + img['image_path'])
        .toList();
  }

  // Fungsi untuk membuka Google Maps
  Future<void> _openGoogleMaps(String? lat, String? lng) async {
    if (lat == null || lng == null || lat.isEmpty || lng.isEmpty) {
      return;
    }

    final url = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotoBefore = _getImagesByType('before');
    final fotoProgress = _getImagesByType('progress');
    final fotoAfter = _getImagesByType('after');

    return Scaffold(
      backgroundColor: const Color(0xFF0D1424),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Detail Laporan',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER STATUS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "ID: MAINT-${reportData['id']}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusBadge(reportData['status'] ?? 'Pending'),
              ],
            ),

            const SizedBox(height: 20),

            // INFORMASI PEKERJAAN
            _buildSectionTitle("Informasi Pekerjaan"),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow("Teknisi", reportData['teknisi'] ?? '-'),
                  _buildInfoRow("Mitra", reportData['mitra_pelaksana'] ?? '-'),
                  _buildInfoRow(
                    "STO / Witel",
                    "${reportData['sto'] ?? '-'} / ${reportData['witel'] ?? '-'}",
                  ),
                  _buildInfoRow(
                    "Kategori",
                    reportData['kategori_kegiatan'] ?? '-',
                  ),
                  const Divider(color: Colors.grey),
                  _buildInfoRow(
                    "Uraian Pekerjaan",
                    reportData['uraian_pekerjaan'] ?? '-',
                    isLongText: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // LOKASI GPS
            _buildSectionTitle("Lokasi (GPS)"),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    "Latitude",
                    reportData['latitude']?.toString() ?? 'Tidak ada data',
                  ),
                  _buildInfoRow(
                    "Longitude",
                    reportData['longitude']?.toString() ?? 'Tidak ada data',
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openGoogleMaps(
                        reportData['latitude']?.toString(),
                        reportData['longitude']?.toString(),
                      ),
                      icon: const Icon(Icons.map, color: Colors.green),
                      label: const Text(
                        "Buka di Google Maps",
                        style: TextStyle(color: Colors.green),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // FOTO
            _buildSectionTitle("Bukti Foto Pekerjaan"),

            _buildPhotoSection(context, "Foto Before", fotoBefore),

            _buildPhotoSection(context, "Foto Progress", fotoProgress),

            _buildPhotoSection(context, "Foto After", fotoAfter),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLongText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: isLongText
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const Text(":", style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: isLongText ? TextAlign.justify : TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status.toLowerCase().contains('verif')
        ? Colors.green
        : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPhotoSection(
    BuildContext context,
    String title,
    List<String> imageUrls,
  ) {
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),

        const SizedBox(height: 8),

        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _showFullScreenImage(context, imageUrls[index]),
                child: Hero(
                  tag: imageUrls[index],
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 15),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Hero(tag: imageUrl, child: Image.network(imageUrl)),
            ),
          ),
        ),
      ),
    );
  }
}
