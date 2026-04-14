import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'konfirmasi_laporan_screen.dart';

class InputLaporanScreen extends StatefulWidget {
  final String userName;
  final String role;
  final String userId;
  final int databaseId;

  const InputLaporanScreen({
    super.key,
    required this.userName,
    required this.role,
    required this.userId,
    required this.databaseId,
  });

  @override
  State<InputLaporanScreen> createState() => _InputLaporanScreenState();
}

class _InputLaporanScreenState extends State<InputLaporanScreen> {
  final TextEditingController _areaController = TextEditingController(
    text: "2",
  );
  final TextEditingController _districtController = TextEditingController(
    text: "SURAMADU",
  );
  final TextEditingController _witelController = TextEditingController(
    text: "SURABAYA UTARA",
  );
  final TextEditingController _uraianController = TextEditingController();

  String? _selectedKategori;
  String? _selectedSTO;
  String? _selectedMitra;
  bool _isPredictingKategori = false;

  final ImagePicker _picker = ImagePicker();
  List<XFile> _fotoBefore = [];
  List<XFile> _fotoProgress = [];
  List<XFile> _fotoAfter = [];

  String? _latitude;
  String? _longitude;
  String? _mapsLink; // TAMBAHAN: Variabel penyimpan Link Maps
  bool _isFetchingLocation = true;

  final List<String> _stoOptions = [
    "KENJERAN",
    "KAPASAN",
    "KEBALEN",
    "KALIANAK",
    "MERGOYOSO",
    "TANDES",
    "KANDANGAN",
    "KARANGPILANG",
    "LAKASANTRI",
    "GRESIK",
    "CERME",
    "LAMONGAN",
    "BALOPANGGANG",
    "BERONDONG",
    "DUDUKSAMPEYAN",
    "BAWEAN",
    "BABAT",
    "SUKODADI",
    "KEDAMEAN",
  ];
  final List<String> _kategoriOptions = [
    "DISMALTING TIANG",
    "SISIP TIANG (SOK)",
    "TIANG ROBOH/KEROPOS/BENGKOK/PATAH/MIRING",
    "GANTI BATERAI",
    "PEMBUATAN KERANGKENG ODC/OLT",
    "PENAMBAHAN BANDWITH UPLINK OLT",
    "PERBAIKAN CRC COUNTING",
    "PERBAIKAN T-LINE / UPLINK",
    "GANTI ODP",
    "GANTI PASSIVE SPLITTER",
    "GANTI BASEDTRAY",
    "GANTI KABINET ODC",
    "MH/HH RUSAK",
    "KU TERJUNTAI/JATUH",
    "PERBAIKAN UC",
    "REPAIR FEEDER/DISTRIBUSI",
    "PENEGAKAN ODC",
    "PENINGGIAN KU",
    "RELOKASI ALPRO",
    "TAMBAH TIANG",
  ];
  final List<String> _mitraOptions = [
    "PT. Cipta Akses Indotama",
    "PT. Bangtelindo",
    "PT. OPMC Indonesia",
    "PT. Centralindo Panca Sakti",
    "PT. Prima Akses Solusi Global",
    "PT. Akses Kwalitas Unggul",
    "PT. Telkom Akses",
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)
        setState(() {
          _latitude = "GPS Mati";
          _longitude = "GPS Mati";
          _mapsLink = "-";
          _isFetchingLocation = false;
        });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted)
          setState(() {
            _latitude = "Izin Ditolak";
            _longitude = "Izin Ditolak";
            _mapsLink = "-";
            _isFetchingLocation = false;
          });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted)
        setState(() {
          _latitude = "Izin Ditolak Permanen";
          _longitude = "Izin Ditolak Permanen";
          _mapsLink = "-";
          _isFetchingLocation = false;
        });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _latitude = position.latitude.toString();
          _longitude = position.longitude.toString();
          // Merakit Link Google Maps Otomatis
          _mapsLink =
              "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
          _isFetchingLocation = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _latitude = "Gagal";
          _longitude = "Gagal";
          _mapsLink = "-";
          _isFetchingLocation = false;
        });
    }
  }

  Future<void> _openGoogleMaps() async {
    if (_mapsLink == null || _mapsLink == "-") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lokasi GPS tidak valid atau belum ditemukan."),
        ),
      );
      return;
    }
    final url = _mapsLink!;
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak bisa membuka Google Maps.")),
        );
    }
  }

  Future<void> _pickGalleryImages(String type) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 70,
      );
      if (pickedFiles.isNotEmpty) {
        setState(() {
          if (type == "Before")
            _fotoBefore.addAll(pickedFiles);
          else if (type == "Progress")
            _fotoProgress.addAll(pickedFiles);
          else if (type == "After")
            _fotoAfter.addAll(pickedFiles);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal mengambil foto: $e")));
    }
  }

  Future<void> _pickCameraImage(String type) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          if (type == "Before")
            _fotoBefore.add(pickedFile);
          else if (type == "Progress")
            _fotoProgress.add(pickedFile);
          else if (type == "After")
            _fotoAfter.add(pickedFile);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal memotret: $e")));
    }
  }

  void _showPickerOptions(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text(
                'Ambil Banyak dari Galeri',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _pickGalleryImages(type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.green),
              title: const Text(
                'Buka Kamera (Tambah 1)',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _pickCameraImage(type);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _predictKategoriByAI() async {
    final uraian = _uraianController.text.trim();
    if (uraian.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Isi Uraian Pekerjaan terlebih dahulu!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isPredictingKategori = true);

    try {
      const apiKey = 'AIzaSyCLISveaCxKj9NYm4OxGAdKcyOukdbkTk0';
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      final prompt =
          '''Kamu adalah asisten sistem pelaporan perbaikan jaringan. Saya memiliki daftar kategori pekerjaan berikut: ${_kategoriOptions.join('\n')} \n Berdasarkan uraian pekerjaan teknisi berikut: "$uraian" \n Tugasmu adalah memilih SATU kategori yang paling tepat dan relevan dari daftar di atas. Hanya balas dengan nama kategori yang persis sama dengan yang ada di daftar (termasuk huruf besar dan tanda baca). Jangan tambahkan penjelasan.''';
      final response = await model.generateContent([Content.text(prompt)]);
      String predictedCategory = response.text?.trim() ?? '';

      if (_kategoriOptions.contains(predictedCategory)) {
        setState(() => _selectedKategori = predictedCategory);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Berhasil! Kategori diisi otomatis: $predictedCategory",
              ),
              backgroundColor: Colors.green,
            ),
          );
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "AI gagal mengklasifikasikan. Silakan pilih manual.",
              ),
              backgroundColor: Colors.red,
            ),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error koneksi AI: $e"),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isPredictingKategori = false);
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
          'Input Laporan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel("LOKASI SAAT INI (GPS)"),
              const SizedBox(height: 5),
              _isFetchingLocation
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildGPSBox("Latitude", _latitude ?? "-"),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildGPSBox(
                                "Longitude",
                                _longitude ?? "-",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        // TAMPILAN FORM LINK MAPS BARU
                        _buildFieldLabel("LINK GOOGLE MAPS"),
                        _buildReadOnlyField(
                          TextEditingController(
                            text: _mapsLink ?? "Menunggu GPS...",
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _openGoogleMaps,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.map, color: Colors.green, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  "Cek Lokasi di Google Maps",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 15),
              _buildFieldLabel("Area"),
              _buildReadOnlyField(_areaController),
              const SizedBox(height: 15),
              _buildFieldLabel("District"),
              _buildReadOnlyField(_districtController),
              const SizedBox(height: 15),
              _buildFieldLabel("Witel"),
              _buildReadOnlyField(_witelController),
              const SizedBox(height: 15),
              _buildFieldLabel("STO"),
              _buildDropdownField(
                "Pilih STO",
                _selectedSTO,
                _stoOptions,
                (val) => setState(() => _selectedSTO = val),
              ),
              const SizedBox(height: 15),
              _buildFieldLabel("MITRA PELAKSANA"),
              _buildDropdownField(
                "Pilih Mitra",
                _selectedMitra,
                _mitraOptions,
                (val) => setState(() => _selectedMitra = val),
              ),
              const SizedBox(height: 15),
              _buildFieldLabel("URAIAN PEKERJAAN"),
              _buildTextArea(
                hint: "Contoh: Perbaikan tiang keropos di karangpilang",
                controller: _uraianController,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isPredictingKategori
                      ? null
                      : _predictKategoriByAI,
                  icon: _isPredictingKategori
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 18,
                        ),
                  label: Text(
                    _isPredictingKategori
                        ? "Sedang menganalisa..."
                        : "Auto-Pilih Kategori (AI)",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D1F3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildFieldLabel("KATEGORI KEGIATAN"),
              _buildDropdownField(
                "Pilih Kategori (Bisa Auto via AI)",
                _selectedKategori,
                _kategoriOptions,
                (val) => setState(() => _selectedKategori = val),
              ),
              const SizedBox(height: 25),
              _buildFieldLabel("BUKTI FOTO (Opsional, Bisa Lebih dari 10)"),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPhotoPickerBox("Before", _fotoBefore),
                  _buildPhotoPickerBox("Progress", _fotoProgress),
                  _buildPhotoPickerBox("After", _fotoAfter),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedSTO == null ||
                        _selectedMitra == null ||
                        _selectedKategori == null ||
                        _uraianController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Mohon lengkapi semua data teks!"),
                        ),
                      );
                      return;
                    }
                    if (_isFetchingLocation) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Tunggu hingga lokasi GPS ditemukan!"),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => KonfirmasiLaporanScreen(
                          userName: widget.userName,
                          role: widget.role,
                          userId: widget.userId,
                          databaseId: widget.databaseId,
                          area: _areaController.text,
                          district: _districtController.text,
                          witel: _witelController.text,
                          sto: _selectedSTO!,
                          mitraPelaksana: _selectedMitra!,
                          kategoriKegiatan: _selectedKategori!,
                          uraianPekerjaan: _uraianController.text,
                          latitude: _latitude,
                          longitude: _longitude,
                          mapsLink: _mapsLink, // MENGIRIM LINK MAPS
                          fotoBeforePaths: _fotoBefore
                              .map((e) => e.path)
                              .toList(),
                          fotoProgressPaths: _fotoProgress
                              .map((e) => e.path)
                              .toList(),
                          fotoAfterPaths: _fotoAfter
                              .map((e) => e.path)
                              .toList(),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Lanjut ke Konfirmasi",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: Colors.grey,
      fontSize: 13,
      fontWeight: FontWeight.bold,
    ),
  );
  Widget _buildReadOnlyField(TextEditingController controller) => Container(
    margin: const EdgeInsets.only(top: 5),
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      controller.text,
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    ),
  );
  Widget _buildGPSBox(String title, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF161F2E),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blue.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.blue, size: 14),
            const SizedBox(width: 5),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
  Widget _buildDropdownField(
    String h,
    String? v,
    List<String> i,
    Function(String?) o,
  ) => Container(
    margin: const EdgeInsets.only(top: 5),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
    ),
    child: DropdownButtonFormField<String>(
      dropdownColor: const Color(0xFF1E293B),
      value: v,
      isExpanded: true,
      hint: Text(h, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      style: const TextStyle(color: Colors.white),
      items: i
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: o,
      decoration: const InputDecoration(border: InputBorder.none),
    ),
  );
  Widget _buildTextArea({
    required String hint,
    required TextEditingController controller,
  }) => Container(
    margin: const EdgeInsets.only(top: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
    ),
    child: TextField(
      controller: controller,
      maxLines: 4,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        contentPadding: const EdgeInsets.all(15),
        border: InputBorder.none,
      ),
    ),
  );
  Widget _buildPhotoPickerBox(String label, List<XFile> files) =>
      GestureDetector(
        onTap: () => _showPickerOptions(label),
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: files.isNotEmpty
                      ? Colors.blue
                      : Colors.grey.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: files.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(files.last.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              "+${files.length}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: Colors.grey, size: 30),
                        SizedBox(height: 5),
                        Text(
                          "Upload",
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}
