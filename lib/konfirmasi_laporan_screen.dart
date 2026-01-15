import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class KonfirmasiLaporanScreen extends StatefulWidget {
  final String lokasi;
  final double? lat;
  final double? lng;
  final String jenisMaintenance;
  final String deskripsi;
  final String durasi;
  final String tanggal;
  final List<String> teknisi;
  final List<File> fotoDokumentasi;

  const KonfirmasiLaporanScreen({
    super.key,
    required this.lokasi,
    this.lat,
    this.lng,
    required this.jenisMaintenance,
    required this.deskripsi,
    required this.durasi,
    required this.tanggal,
    required this.teknisi,
    required this.fotoDokumentasi,
  });

  @override
  State<KonfirmasiLaporanScreen> createState() =>
      _KonfirmasiLaporanScreenState();
}

class _KonfirmasiLaporanScreenState extends State<KonfirmasiLaporanScreen> {
  String _detailAlamat = "Mengambil data wilayah...";

  @override
  void initState() {
    super.initState();
    if (widget.lat != null && widget.lng != null) {
      _getAddressFromLatLng();
    } else {
      _detailAlamat = "Koordinat GPS tidak tersedia.";
    }
  }

  // Fungsi Reverse Geocoding untuk mendapatkan Kota, Kec, Kel
  Future<void> _getAddressFromLatLng() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.lat!,
        widget.lng!,
      );
      Placemark place = placemarks[0];
      setState(() {
        _detailAlamat =
            "Kota: ${place.subAdministrativeArea ?? '-'}\n"
            "Kecamatan: ${place.locality ?? '-'}\n"
            "Kelurahan/Desa: ${place.subLocality ?? '-'}";
      });
    } catch (e) {
      setState(() {
        _detailAlamat = "Gagal memproses detail wilayah: $e";
      });
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
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "RINGKASAN LAPORAN",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              icon: Icons.location_on,
              title: "LOKASI PEKERJAAN",
              value: widget.lokasi,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              icon: Icons.calendar_month,
              title: "TIME PLAN / TANGGAL",
              value: widget.tanggal,
              iconColor: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              icon: Icons.settings,
              title: "JENIS & DURASI",
              value: "${widget.jenisMaintenance} • ${widget.durasi}",
              iconColor: Colors.orange,
            ),
            const SizedBox(height: 12),

            // WIDGET TAMPILAN PETA (Google Maps)
            if (widget.lat != null && widget.lng != null)
              Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.withOpacity(0.5)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(widget.lat!, widget.lng!),
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('currentLocation'),
                        position: LatLng(widget.lat!, widget.lng!),
                      ),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                ),
              ),

            // KETERANGAN WILAYAH (Reverse Geocoding Result)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "KETERANGAN WILAYAH",
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _detailAlamat,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            _buildDescriptionCard(
              title: "DESKRIPSI MASALAH",
              content: widget.deskripsi.isEmpty
                  ? "Tidak ada deskripsi"
                  : widget.deskripsi,
            ),
            const SizedBox(height: 12),
            _buildTechnicianCard(widget.teknisi),
            const SizedBox(height: 24),
            _buildPhotoGrid(),
            const SizedBox(height: 30),
            _buildSubmitButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color iconColor = Colors.blue,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
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
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildDescriptionCard({
    required String title,
    required String content,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _buildTechnicianCard(List<String> names) => Wrap(
    spacing: 8,
    children: names
        .map(
          (n) => Chip(
            label: Text(
              n,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            backgroundColor: Colors.blue.withOpacity(0.1),
          ),
        )
        .toList(),
  );

  Widget _buildPhotoGrid() => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: widget.fotoDokumentasi.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
    ),
    itemBuilder: (context, index) => ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(widget.fotoDokumentasi[index], fit: BoxFit.cover),
    ),
  );

  Widget _buildSubmitButton(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 60,
    child: ElevatedButton(
      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2196F3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
