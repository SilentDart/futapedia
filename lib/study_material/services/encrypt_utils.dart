import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
// import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;

class PDFEncryptionUtils {
  // Store the encryption key securely
  static const _keyName = 'futapedia_encryption_key';
  static const _ivName = 'futapedia_encryption_iv';
  static final _secureStorage = FlutterSecureStorage();
  
  // Get or generate encryption key
  static Future<String> _getEncryptionKey() async {
    String? key = await _secureStorage.read(key: _keyName);
    if (key == null) {
      // Generate a new key
      final random = encrypt.SecureRandom(32);
      key = base64Encode(random.bytes);
      await _secureStorage.write(key: _keyName, value: key);
    }
    return key;
  }
  
  // Get or generate IV
  static Future<String> _getEncryptionIV() async {
    String? iv = await _secureStorage.read(key: _ivName);
    if (iv == null) {
      // Generate a new IV
      final random = encrypt.SecureRandom(16);
      iv = base64Encode(random.bytes);
      await _secureStorage.write(key: _ivName, value: iv);
    }
    return iv;
  }
  
  // Check if a file needs encryption based on file extension
  static bool shouldEncrypt(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.pdf', '.jpg', '.jpeg', '.png'].contains(extension);
  }
  
  // Encrypt file
  static Future<String> encryptFile(String sourcePath, String destinationPath) async {
    try {
      final File sourceFile = File(sourcePath);
      final File destFile = File(destinationPath);
      
      // Create destination directory if it doesn't exist
      final destDir = path.dirname(destinationPath);
      final directory = Directory(destDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      // Check if file requires encryption
      if (!shouldEncrypt(sourcePath)) {
        // For non-encrypting file types, just copy the file
        await sourceFile.copy(destinationPath);
        return destinationPath;
      }
      
      // Read file as bytes
      final Uint8List fileBytes = await sourceFile.readAsBytes();
      
      // Get encryption key and IV
      final keyString = await _getEncryptionKey();
      final ivString = await _getEncryptionIV();
      
      // Create encrypter
      final key = encrypt.Key.fromBase64(keyString);
      final iv = encrypt.IV.fromBase64(ivString);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      
      // Encrypt the file
      final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);
      
      // Write to destination file
      await destFile.writeAsBytes(encrypted.bytes);
      
      return destinationPath;
    } catch (e) {
      throw Exception('Failed to encrypt file: $e');
    }
  }
  
  // Decrypt file content
  static Future<Uint8List> decryptFile(String filePath) async {
    try {
      final File file = File(filePath);
      final Uint8List encryptedBytes = await file.readAsBytes();
      
      // Get encryption key and IV
      final keyString = await _getEncryptionKey();
      final ivString = await _getEncryptionIV();
      
      // Create encrypter
      final key = encrypt.Key.fromBase64(keyString);
      final iv = encrypt.IV.fromBase64(ivString);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      
      // Decrypt the file
      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(encryptedBytes),
        iv: iv
      );
      
      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw Exception('Failed to decrypt file: $e');
    }
  }
  

  static bool isFileEncrypted(String filePath) {
    try {
      // Read first few bytes of the file
      final file = File(filePath);
      if (!file.existsSync()) return false;
      
      final bytes = file.openSync().readSync(16);
      
      // A very basic check - encrypted files typically have high entropy
      // and don't start with expected file signatures
      // PDF signature check (starts with %PDF-)
      if (filePath.toLowerCase().endsWith('.pdf')) {
        return !String.fromCharCodes(bytes).startsWith('%PDF-');
      }
      
      // PNG signature check
      if (filePath.toLowerCase().endsWith('.png')) {
        return bytes[0] != 0x89 || bytes[1] != 0x50 || bytes[2] != 0x4E || bytes[3] != 0x47;
      }
      
      // JPEG signature check
      if (filePath.toLowerCase().endsWith('.jpg') || filePath.toLowerCase().endsWith('.jpeg')) {
        return bytes[0] != 0xFF || bytes[1] != 0xD8;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
}



// This class is referenced but not implemented in your code
// You would need to implement this properly
// For handling directory encryption
class DownloadedFolderEncryptionService {
  
  // Process a directory to ensure all files are encrypted
  static Future<void> processDirectory(Directory directory) async {
    try {
      final entities = directory.listSync(recursive: true);
      
      for (final entity in entities) {
        if (entity is File) {
          final filePath = entity.path;
          
          // Skip already encrypted files
          if (isFileEncrypted(filePath)) continue;
          
          // Check if file should be encrypted
          if (PDFEncryptionUtils.shouldEncrypt(filePath)) {
            final encryptedPath = '$filePath.enc';
            
            // Encrypt the file
            await PDFEncryptionUtils.encryptFile(filePath, encryptedPath);
            
            // Replace original with encrypted
            final encryptedFile = File(encryptedPath);
            if (await encryptedFile.exists()) {
              await File(filePath).delete();
              await encryptedFile.rename(filePath);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing directory for encryption: $e');
    }
  }
  
  // Basic check to determine if a file is already encrypted
  // You might want to implement a more sophisticated approach
  static bool isFileEncrypted(String filePath) {
    try {
      // Read first few bytes of the file
      final file = File(filePath);
      if (!file.existsSync()) return false;
      
      final bytes = file.openSync().readSync(16);
      
      // A very basic check - encrypted files typically have high entropy
      // and don't start with expected file signatures
      // PDF signature check (starts with %PDF-)
      if (filePath.toLowerCase().endsWith('.pdf')) {
        return !String.fromCharCodes(bytes).startsWith('%PDF-');
      }
      
      // PNG signature check
      if (filePath.toLowerCase().endsWith('.png')) {
        return bytes[0] != 0x89 || bytes[1] != 0x50 || bytes[2] != 0x4E || bytes[3] != 0x47;
      }
      
      // JPEG signature check
      if (filePath.toLowerCase().endsWith('.jpg') || filePath.toLowerCase().endsWith('.jpeg')) {
        return bytes[0] != 0xFF || bytes[1] != 0xD8;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
}