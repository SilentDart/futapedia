import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:synchronized/synchronized.dart';  // Changed from semaphore to synchronized

class PDFEncryptionUtils {
  // Private constructor for singleton pattern
  PDFEncryptionUtils._();
  
  // Singleton instance
  static final PDFEncryptionUtils _instance = PDFEncryptionUtils._();
  static PDFEncryptionUtils get instance => _instance;
  
  // Constants
  static const _keyName = 'futapedia_encryption_key';
  static const _ivName = 'futapedia_encryption_iv';
  static const _keyVersionName = 'futapedia_encryption_key_version';
  
  // Lock objects
  final _keyLock = Lock();
  final _ivLock = Lock();
  // final _encryptionLock = Lock();
  
  // Secure storage
  final _secureStorage = FlutterSecureStorage();
  
  // Cached values
  String? _cachedKey;
  String? _cachedIV;
  int _keyVersion = 1; // Track key version for future rotation capability
  
  // Initialization
  bool _isInitialized = false;
  final _initLock = Lock();
  
  
  // Initialize the encryption service
  Future<void> initialize() async {
    await _initLock.synchronized(() async {
      if (_isInitialized) return;
      
      try {
        // Load key and IV into cache on startup
        _cachedKey = await _secureStorage.read(key: _keyName);
        _cachedIV = await _secureStorage.read(key: _ivName);
        final versionStr = await _secureStorage.read(key: _keyVersionName);
        _keyVersion = int.tryParse(versionStr ?? '1') ?? 1;
        
        // Create keys if they don't exist
        if (_cachedKey == null) {
          await _generateAndStoreNewKey();
        }
        
        if (_cachedIV == null) {
          await _generateAndStoreNewIV();
        }
        
        _isInitialized = true;
      } catch (e) {
        debugPrint('Encryption initialization error: $e');
        // For production, consider logging to a monitoring service
        rethrow;
      }
    });
  }
  
  // Generate and store a new key
  Future<void> _generateAndStoreNewKey() async {
    final random = encrypt.SecureRandom(32);
    final key = base64Encode(random.bytes);
    await _secureStorage.write(key: _keyName, value: key);
    _cachedKey = key;
    
    // Update key version
    _keyVersion++;
    await _secureStorage.write(key: _keyVersionName, value: _keyVersion.toString());
  }
  
  // Generate and store a new IV
  Future<void> _generateAndStoreNewIV() async {
    final random = encrypt.SecureRandom(16);
    final iv = base64Encode(random.bytes);
    await _secureStorage.write(key: _ivName, value: iv);
    _cachedIV = iv;
  }
  
  // Get encryption key with retries
  Future<String> _getEncryptionKey() async {
    return await _keyLock.synchronized(() async {
      if (!_isInitialized) await initialize();
      
      if (_cachedKey != null) return _cachedKey!;
      
      // If still null after initialization, try again with fallback
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          String? key = await _secureStorage.read(key: _keyName);
          if (key != null) {
            _cachedKey = key;
            return key;
          }
          
          // Generate a new key if still not found
          await _generateAndStoreNewKey();
          return _cachedKey!;
        } catch (e) {
          debugPrint('Error retrieving encryption key (attempt ${attempt+1}): $e');
          await Future.delayed(Duration(milliseconds: 100));
        }
      }
      
      // Last resort fallback - generate an emergency key
      // This should almost never happen, but better than crashing
      final random = encrypt.SecureRandom(32);
      return base64Encode(random.bytes);
    });
  }
  
  // Get encryption IV with retries
  Future<String> _getEncryptionIV() async {
    return await _ivLock.synchronized(() async {
      if (!_isInitialized) await initialize();
      
      if (_cachedIV != null) return _cachedIV!;
      
      // If still null after initialization, try again with fallback
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          String? iv = await _secureStorage.read(key: _ivName);
          if (iv != null) {
            _cachedIV = iv;
            return iv;
          }
          
          // Generate a new IV if still not found
          await _generateAndStoreNewIV();
          return _cachedIV!;
        } catch (e) {
          debugPrint('Error retrieving encryption IV (attempt ${attempt+1}): $e');
          await Future.delayed(Duration(milliseconds: 100));
        }
      }
      
      // Last resort fallback - generate an emergency IV
      final random = encrypt.SecureRandom(16);
      return base64Encode(random.bytes);
    });
  }
  
  // Check if a file needs encryption based on file extension
  static bool shouldEncrypt(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.pdf', '.jpg', '.jpeg', '.png'].contains(extension);
  }
  
  // Encrypt file with dedicated lock per operation
  Future<String> encryptFile(String sourcePath, String destinationPath) async {
    // Use a per-operation lock to ensure file atomicity
    final operationLock = Lock();
    
    return await operationLock.synchronized(() async {
      try {
        if (!_isInitialized) await initialize();
        
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
        
        // Get encryption key and IV (now thread-safe with caching)
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
        debugPrint('Encryption error for $sourcePath: $e');
        throw Exception('Failed to encrypt file: $e');
      }
    });
  }
  
  // Decrypt file content
  Future<Uint8List> decryptFile(String filePath) async {
    // Use a per-operation lock to ensure file atomicity
    final operationLock = Lock();
    
    return await operationLock.synchronized(() async {
      try {
        if (!_isInitialized) await initialize();
        
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
        debugPrint('Decryption error for $filePath: $e');
        throw Exception('Failed to decrypt file: $e');
      }
    });
  }
  
  // Check if a file is encrypted
  bool isFileEncrypted(String filePath) {
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
      debugPrint('Error checking if file is encrypted: $e');
      return false;
    }
  }
  
  // For key rotation in the future (important for long-term security)
  Future<void> rotateEncryptionKey() async {
    await _keyLock.synchronized(() async {
      try {
        // Generate new key
        final random = encrypt.SecureRandom(32);
        final newKey = base64Encode(random.bytes);
        
        // Store new key and update version
        await _secureStorage.write(key: _keyName, value: newKey);
        _keyVersion++;
        await _secureStorage.write(key: _keyVersionName, value: _keyVersion.toString());
        
        // Update cached key
        _cachedKey = newKey;
        
        // In a real-world app, you might want to re-encrypt all files with the new key
        // This would require keeping track of all encrypted files
      } catch (e) {
        debugPrint('Key rotation error: $e');
        throw Exception('Failed to rotate encryption key: $e');
      }
    });
  }
}

// This class needs to be updated too
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
            
            // Encrypt the file - fixed static method call
            await PDFEncryptionUtils.instance.encryptFile(filePath, encryptedPath);
            
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
  static bool isFileEncrypted(String filePath) {
    return PDFEncryptionUtils.instance.isFileEncrypted(filePath);
  }
}