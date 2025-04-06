import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;

class PastQuestionEncryptionUtils {
  // Store the encryption key securely
  static const _keyName = 'futapedia_encryption_key';
  static const _ivName = 'futapedia_encryption_iv';
  static final _secureStorage = FlutterSecureStorage();
  
  // Improved key generation with app-specific salt
  static Future<String> _getEncryptionKey() async {
    String? key = await _secureStorage.read(key: _keyName);
    if (key == null) {
      // Generate a new key with additional app-specific entropy
      final random = encrypt.SecureRandom(32);
      final appSalt = 'FUTApedia_Secure_Salt_2024'; // Unique app identifier
      final saltedBytes = Uint8List.fromList(
        random.bytes + utf8.encode(appSalt)
      );
      
      // Use SHA-256 to derive a consistent key
      final digest = sha256.convert(saltedBytes);
      key = base64Encode(digest.bytes);
      
      await _secureStorage.write(key: _keyName, value: key);
    }
    return key;
  }
  
  // Improved IV generation
  static Future<String> _getEncryptionIV() async {
    String? iv = await _secureStorage.read(key: _ivName);
    if (iv == null) {
      // Generate a more secure IV
      final random = encrypt.SecureRandom(16);
      iv = base64Encode(random.bytes);
      await _secureStorage.write(key: _ivName, value: iv);
    }
    return iv;
  }
  
  // Generate a filename-specific IV for enhanced security
  static Future<encrypt.IV> _getFileSpecificIV(String fileName) async {
    final baseIV = await _getEncryptionIV();
    final fileHash = sha256.convert(utf8.encode(fileName)).toString().substring(0, 16);
    
    // XOR the base IV with the file hash
    final Uint8List ivBytes = base64Decode(baseIV);
    final Uint8List hashBytes = Uint8List.fromList(utf8.encode(fileHash));
    
    for (int i = 0; i < ivBytes.length; i++) {
      ivBytes[i] = ivBytes[i] ^ (i < hashBytes.length ? hashBytes[i] : 0);
    }
    
    return encrypt.IV(ivBytes);
  }
  
  // Check if a file needs encryption based on file extension
  static bool shouldEncrypt(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.pdf', '.jpg', '.jpeg', '.png', '.gif', '.bmp'].contains(extension);
  }
  
  // Encrypt file with additional security measures
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
      
      // Get encryption key and file-specific IV
      final keyString = await _getEncryptionKey();
      final fileIV = await _getFileSpecificIV(path.basename(sourcePath));
      
      // Create encrypter with more secure settings
      final key = encrypt.Key.fromBase64(keyString);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );
      
      // Encrypt the file
      final encrypted = encrypter.encryptBytes(fileBytes, iv: fileIV);
      
      // Write to destination file
      await destFile.writeAsBytes(encrypted.bytes);
      
      return destinationPath;
    } catch (e) {
      throw Exception('Failed to encrypt file: $e');
    }
  }
  
  // Decrypt file content with error handling
  static Future<Uint8List> decryptFile(String filePath) async {
    try {
      final File file = File(filePath);
      
      // Ensure file exists and is not empty
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('File does not exist or is empty');
      }
      
      final Uint8List encryptedBytes = await file.readAsBytes();
      
      // Get encryption key and file-specific IV
      final keyString = await _getEncryptionKey();
      final fileIV = await _getFileSpecificIV(path.basename(filePath));
      
      // Create encrypter with matching settings
      final key = encrypt.Key.fromBase64(keyString);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );
      
      // Decrypt the file
      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(encryptedBytes),
        iv: fileIV
      );
      
      return Uint8List.fromList(decrypted);
    } catch (e) {
      // Log the error and rethrow
      print('Decryption error for file $filePath: $e');
      rethrow;
    }
  }
}

class PastQuestionDownloadedFolderEncryptionService {
  static Future<void> processDirectory(Directory dir) async {
    try {
      final entities = await dir.list(recursive: true).toList();
      
      for (final entity in entities) {
        if (entity is File) {
          final filePath = entity.path;
          
          // Skip already encrypted files
          if (isFileEncrypted(filePath)) continue;
          
          if (PastQuestionEncryptionUtils.shouldEncrypt(filePath)) {
            // Create temporary path
            final tempPath = '${filePath}_temp';
            
            // Encrypt file in-place
            await PastQuestionEncryptionUtils.encryptFile(filePath, tempPath);
            
            // Replace original with encrypted
            await File(tempPath).rename(filePath);
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to process directory: $e');
    }
  }
  
  // Basic check to determine if a file is already encrypted
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
  static Future<void> encryptDownloadedFolder(String folderPath) async {
    try {
      final directory = Directory(folderPath);
      
      // Check if directory exists
      if (!await directory.exists()) {
        throw Exception('Directory does not exist');
      }
      
      // Process all files in the directory recursively
      await processDirectory(directory);
    } catch (e) {
      print('Error encrypting downloaded folder: $e');
      rethrow;
    }
  }
}

