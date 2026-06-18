import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

class EccHelper {
  // TODO: Masukkan 32-byte Public Key dari Server (Base64 format)
  // Ini adalah contoh format statis. Anda harus generate key X25519 di Laravel.
  static final String serverPublicKeyBase64 =
      "TU9+kceeOQHNbtwK+RYUmUkUX47HqAt9lFzKbZNVMTg=";

  static Future<String> encryptData(String plaintext) async {
    if (plaintext.isEmpty) return plaintext;

    final stopwatch = Stopwatch()..start(); // ← mulai timer

    final ecdh = X25519();
    // Generate sepasang kunci ECC (Public & Private) sementara untuk sesi ini
    final clientKeyPair = await ecdh.newKeyPair();
    final clientPublicKey = await clientKeyPair.extractPublicKey();

    final serverPublicKeyBytes = base64Decode(serverPublicKeyBase64);
    final serverPublicKey = SimplePublicKey(
      serverPublicKeyBytes,
      type: KeyPairType.x25519,
    );

    // 1. ECDH: Dapatkan Shared Secret antara Client dan Server
    final sharedSecret = await ecdh.sharedSecretKey(
      keyPair: clientKeyPair,
      remotePublicKey: serverPublicKey,
    );

    final sharedSecretBytes = await sharedSecret.extractBytes();
    final aesSecretKey = SecretKey(sharedSecretBytes);

    // 2. AES-GCM Enkripsi menggunakan Shared Secret
    final aesGcm = AesGcm.with256bits();
    final secretBox = await aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: aesSecretKey,
    );

    // 3. Gabungkan komponen agar Backend dapat mendekripsinya
    final payload = {
      'client_pub_key': base64Encode(clientPublicKey.bytes),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'ciphertext': base64Encode(secretBox.cipherText),
    };

stopwatch.stop(); // ← stop timer
  debugPrint('⏱️ [ECC ENKRIPSI] "$plaintext" => ${stopwatch.elapsedMilliseconds} ms (${stopwatch.elapsedMicroseconds} µs)');
    // Return dalam bentuk Base64 String yang siap dikirim lewat form-data
    return base64Encode(utf8.encode(jsonEncode(payload)));
  }
}
