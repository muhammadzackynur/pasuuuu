import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart'; // IMPORT BARU UNTUK FOTO
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
  // Controller Data Otomatis
  final TextEditingController _areaController = TextEditingController(
    text: "2",
  );
  final TextEditingController _districtController = TextEditingController(
    text: "SURAMADU",
  );
  final TextEditingController _witelController = TextEditingController(
    text: "SURABAYA UTARA",
  );

  // Controller Input Manual
  final TextEditingController _uraianController = TextEditingController();

  // State Dropdowns
  String? _selectedKategori;
  String? _selectedSTO;
  String? _selectedMitra;

  // Loading state untuk AI
  bool _isPredictingKategori = false;

  // --- STATE UNTUK FOTO ---
  final ImagePicker _picker = ImagePicker();
  XFile? _fotoBefore;
  XFile? _fotoProgress;
  XFile? _fotoAfter;

  // Data Dropdown Options
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

  // --- FUNGSI AMBIL FOTO ---
  Future<void> _pickImage(String type, ImageSource source) async {
    try {
      // Mengambil foto dan langsung di-compress kualitasnya 70% agar tidak terlalu berat saat dikirim
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          if (type == "Before")
            _fotoBefore = pickedFile;
          else if (type == "Progress")
            _fotoProgress = pickedFile;
          else if (type == "After")
            _fotoAfter = pickedFile;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal mengambil foto: $e")));
    }
  }

  // --- POPUP PILIH KAMERA ATAU GALERI ---
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
                'Ambil dari Galeri',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(type, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.green),
              title: const Text(
                'Buka Kamera',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(type, ImageSource.camera);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- FUNGSI GENAI ---
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
      const apiKey =
          'AIzaSyCLISveaCxKj9NYm4OxGAdKcyOukdbkTk0'; // Sebaiknya simpan ini di .env untuk produksi
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final prompt =
          '''
      Kamu adalah asisten sistem pelaporan perbaikan jaringan.
      Saya memiliki daftar kategori pekerjaan berikut:
      ${_kategoriOptions.join('\n')}

      Berdasarkan uraian pekerjaan teknisi berikut: "$uraian"
      Tugasmu adalah memilih SATU kategori yang paling tepat dan relevan dari daftar di atas.
      Hanya balas dengan nama kategori yang persis sama dengan yang ada di daftar (termasuk huruf besar dan tanda baca). Jangan tambahkan penjelasan.
      ''';

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

              // --- SEKSI BUKTI FOTO ---
              _buildFieldLabel("BUKTI FOTO (Opsional)"),
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

              // --- TOMBOL LANJUT KE KONFIRMASI ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    // Validasi Text & Dropdown
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

                    // Navigasi Langsung ke Konfirmasi dengan membawa Data FOTO
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
                          // Mengirim path foto jika sudah dipilih
                          fotoBeforePath: _fotoBefore?.path,
                          fotoProgressPath: _fotoProgress?.path,
                          fotoAfterPath: _fotoAfter?.path,
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

  // --- WIDGET HELPER BAWAAN ANDA ---
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
      style: const TextStyle(color: Colors.white70, fontSize: 15),
    ),
  );

  Widget _buildDropdownField(
    String hint,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) => Container(
    margin: const EdgeInsets.only(top: 5),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
    ),
    child: DropdownButtonFormField<String>(
      dropdownColor: const Color(0xFF1E293B),
      value: value,
      isExpanded: true,
      hint: Text(
        hint,
        style: const TextStyle(color: Colors.grey, fontSize: 14),
      ),
      style: const TextStyle(color: Colors.white),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
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

  // --- WIDGET HELPER KOTAK PEMILIH FOTO ---
  Widget _buildPhotoPickerBox(String label, XFile? file) {
    return GestureDetector(
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
                color: file != null
                    ? Colors.blue
                    : Colors.grey.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(file.path), fit: BoxFit.cover),
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
}
