import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Library Peta
import 'package:geocoding/geocoding.dart'; // Library Alamat

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
  String _detailAlamat = "Sedang mengambil data alamat...";

  @override
  void initState() {
    super.initState();
    if (widget.lat != null && widget.lng != null) {
      _getAddressFromLatLng(); // Jalankan pencarian alamat
    }
  }

  // Fungsi mengubah koordinat menjadi Nama Kota/Kecamatan
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
            "Kelurahan/Desa: ${place.subLocality}";
      });
    } catch (e) {
      setState(() => _detailAlamat = "Gagal memuat detail wilayah.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1424),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Konfirmasi Laporan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              Icons.calendar_month,
              "TIME PLAN / TANGGAL",
              widget.tanggal,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              Icons.settings,
              "JENIS & DURASI",
              "${widget.jenisMaintenance} • ${widget.durasi}",
              Colors.orange,
            ),

            const SizedBox(height: 20),
            const Text(
              "LOKASI PEKERJAAN (PETA)",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),

            // WIDGET PETA
            if (widget.lat != null && widget.lng != null)
              Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 12),
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
                        markerId: const MarkerId("lokasi"),
                        position: LatLng(widget.lat!, widget.lng!),
                      ),
                    },
                    zoomControlsEnabled: false,
                  ),
                ),
              ),

            // KETERANGAN ALAMAT
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
                    "DETAIL WILAYAH",
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

            const SizedBox(height: 24),
            const Text(
              "DOKUMENTASI FOTO",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPhotoGrid(),
            const SizedBox(height: 30),
            _buildSubmitButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String title,
    String value,
    Color color,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 15),
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
                ),
              ),
            ],
          ),
        ),
      ],
    ),
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
