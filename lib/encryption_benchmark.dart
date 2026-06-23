import 'package:benchmark_harness/benchmark_harness.dart';

// --- SKENARIO 1: DATA KECIL (Kirim Status Saja) ---
class EccSmallDataBenchmark extends BenchmarkBase {
  // Anggap ini hanya kirim ID dan Status (sekitar 30 karakter)
  final String textAsli = '{"id":"MAINT-001", "status":"selesai"}';

  EccSmallDataBenchmark() : super('ECC_256_Small_Data');

  @override
  void run() {
    // EccHelper.encrypt(textAsli, publicKey);
  }
}

// --- SKENARIO 2: DATA MENENGAH (Laporan Lengkap Tanpa Foto) ---
class EccMediumDataBenchmark extends BenchmarkBase {
  // Anggap ini laporan teks lengkap dengan uraian panjang (sekitar 500 karakter)
  final String textAsli =
      '{"id":"MAINT-001", "sto":"KBL", "kategori":"Kabel Putus", "uraian":"Telah dilakukan penyambungan kabel fiber optik di sektor A...", "teknisi":"Zacky"}';

  EccMediumDataBenchmark() : super('ECC_256_Medium_Data');

  @override
  void run() {
    // EccHelper.encrypt(textAsli, publicKey);
  }
}

// --- SKENARIO 3: DATA BESAR (Laporan + Foto Base64) ---
class EccLargeDataBenchmark extends BenchmarkBase {
  // Kita buat teks palsu yang sangat panjang (misal 50.000 karakter)
  // untuk mensimulasikan teks laporan ditambah string Base64 dari foto evidence.
  late String textAsli;

  EccLargeDataBenchmark() : super('ECC_256_Large_Data');

  @override
  void setup() {
    // Membuat string panjang otomatis sebelum waktu mulai dihitung
    textAsli = "DATA_LAPORAN" + ("A" * 50000);
  }

  @override
  void run() {
    // EccHelper.encrypt(textAsli, publicKey);
  }
}

void main() {
  print("Memulai Benchmark Berdasarkan Ukuran Data...\n");

  EccSmallDataBenchmark().report();
  EccMediumDataBenchmark().report();
  EccLargeDataBenchmark().report();
}
