import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:futapedia/study_material/services/encrypt_utils.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;


class GoogleDriveServicePDF {
  static final _scopes = [drive.DriveApi.driveScope];
  static final _parentFolderId = dotenv.env['PARENT_FOLDER_ID_PDF']?? '';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  drive.DriveApi? _driveApi;

   // Initialize Google Drive API
  Future<void> initialize() async {
    // Just initialize, but don't force sign in
    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Silent sign-in failed: $e');
    }
  }
  
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  // InEnitialize Google Drive API
  Future<drive.DriveApi?> get driveApi async {
    if (_driveApi != null) {
      return _driveApi;
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final authHeaders = await googleUser.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    _driveApi = drive.DriveApi(client);
    return _driveApi;
  }

  // Get root folder ID (parent folder)
  String getRootFolderId() {
    return _parentFolderId;
  }

  Future<String> downloadFileWithProgress(
    drive.File file,
    String destinationFolder,
    Function(double) onProgress,
  ) async {
    // Determine a safe file name
    final fileName = file.name ?? 'unnamed_file';
    final tempFilePath = '$destinationFolder/.temp_$fileName';
    final finalFilePath = '$destinationFolder/$fileName';
    final tempFile = File(tempFilePath);
    final finalFile = File(finalFilePath);
    
    // Create destination directory if needed
    final dir = Directory(destinationFolder);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    try {
      // Get the media download link
      final driveApi = await this.driveApi;
      if (driveApi == null) throw Exception('Drive API not initialized');
      
      // Create temporary file for initial download
      await tempFile.create(recursive: true);
      final fileStream = tempFile.openWrite();
      
      // Track download size for progress reporting
      int totalBytes = int.tryParse(file.size ?? '0') ?? 0;
      int downloadedBytes = 0;
      
      // Download the file with progress tracking
      final media = await driveApi.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      
      final reader = media.stream;
      
      await for (final chunk in reader) {
        fileStream.add(chunk);
        downloadedBytes += chunk.length;
        
        // Report progress (80% for download, 20% for encryption)
        if (totalBytes > 0) {
          onProgress(0.8 * (downloadedBytes / totalBytes));
        } else {
          // If we don't know the total size, use indeterminate progress
          onProgress(0.4); // Show some progress
        }
      }
      
      await fileStream.flush();
      await fileStream.close();
      
      // Report progress before encryption
      onProgress(0.8);
      await PDFEncryptionUtils.instance.initialize();
      
      // Encrypt the file if it's a supported type
      if (PDFEncryptionUtils.shouldEncrypt(tempFilePath)) {
        // Encrypt the downloaded file
        await PDFEncryptionUtils.instance.encryptFile(tempFilePath, finalFilePath);
        
        // Delete the temporary file after encryption
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } else {
        // For non-encrypting file types, just move the file
        await tempFile.rename(finalFilePath);
      }
      
      // Report completion
      onProgress(1.0);
      
      return finalFilePath;
    } catch (e) {
      // Clean up temporary files
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      // If there was an error and partial final file exists, delete it
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      
      rethrow;
    }
  }

  Future<void> downloadFolderWithProgress(
    drive.File folder,
    String destinationFolder,
    Function(double) onProgress,
  ) async {
    // Create the destination folder
    final folderName = folder.name ?? 'unnamed_folder';
    final folderPath = '$destinationFolder/$folderName';
    final directory = Directory(folderPath);
    
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    try {
      // Get all files in the folder
      final folderContents = await listFolderContents(folder.id!);
      final totalItems = folderContents.length;
      // ignore: unused_local_variable
      int completedItems = 0;
      
      // Count total folders for recursive progress
      int totalFolders = folderContents.where((file) => isFolder(file)).length;
      int processingWeight = totalFolders > 0 ? totalItems + totalFolders * 5 : totalItems;
      int processedWeight = 0;
      
      // Update progress
      onProgress(0);
      
      // Download each item
      for (var item in folderContents) {
        if (isFolder(item)) {
          // Recursively download subfolders
          await downloadFolderWithProgress(
            item, 
            folderPath,
            (subProgress) {
              // Calculate overall progress
              double currentItemContribution = subProgress / processingWeight;
              double previousProgress = processedWeight / processingWeight;
              onProgress(previousProgress + currentItemContribution);
            }
          );
          processedWeight += 5; // Give more weight to folders
        } else {
          // Download file with encryption
          await downloadFileWithProgress(
            item, 
            folderPath,
            (fileProgress) {
              // Calculate overall progress
              double currentItemContribution = fileProgress / processingWeight;
              double previousProgress = processedWeight / processingWeight;
              onProgress(previousProgress + currentItemContribution);
            }
          );
          processedWeight++;
        }
        completedItems++;
      }
      
      // Ensure all files in the folder are encrypted
      await DownloadedFolderEncryptionService.processDirectory(Directory(folderPath));
      
      // Ensure final progress is 100%
      onProgress(1.0);
      
    } catch (e) {
      rethrow;
    }
  }

  // List folders and files in a specific folder
  Future<List<drive.File>> listFolderContents(String folderId) async {
    final api = await driveApi;
    if (api == null) throw Exception('Drive API not initialized');

    final fileList = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name, mimeType, size)',
    );

    return fileList.files ?? [];
  }

  // Check if a file is a folder
  bool isFolder(drive.File file) {
    return file.mimeType == 'application/vnd.google-apps.folder';
  }

  // Check if a file should be encrypted
  bool shouldEncrypt(drive.File file) {
    if (file.name == null) return false;
    return PDFEncryptionUtils.shouldEncrypt(file.name!);
  }

  
}


// Background task configuration
const String BACKGROUND_SERVICE_ID = "com.futapedia.backgroundDownloadService";
const String DOWNLOAD_TASK_EVENT = "download_task_even";
const String NOTIFICATION_CHANNEL_ID = "download_service_channel";
const String NOTIFICATION_CHANNEL_NAME = "Download Service";

// Class to track download progress
class DownloadProgress {
  final String id;
  final DownloadTaskStatus status;
  final int progress;
  
  DownloadProgress(this.id, this.status, this.progress);
}




// Helper class for Google Drive API operations
class GoogleDriveService {
  static final _scopes = [drive.DriveApi.driveScope];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  drive.DriveApi? _driveApi;

  // Initialize Google Drive API
  Future<void> initialize() async {
    // Just initialize, but don't force sign in
    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Silent sign-in failed: $e');
    }
  }

  // Check if user is signed in
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  // Get or initialize Drive API
  Future<drive.DriveApi?> get driveApi async {
    if (_driveApi != null) {
      return _driveApi;
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final authHeaders = await googleUser.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    _driveApi = drive.DriveApi(client);
    return _driveApi;
  }

  // Download a file with progress tracking
  Future<String> downloadFileWithProgress(
    drive.File file,
    String destinationFolder,
    Function(double) onProgress,
  ) async {
    // Determine a safe file name
    final fileName = file.name ?? 'unnamed_file';
    final tempFilePath = '$destinationFolder/.temp_$fileName';
    final finalFilePath = '$destinationFolder/$fileName';
    final tempFile = File(tempFilePath);
    final finalFile = File(finalFilePath);
    
    // Create destination directory if needed
    final dir = Directory(destinationFolder);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    try {
      // Get the media download link
      final api = await driveApi;
      if (api == null) throw Exception('Drive API not initialized');
      
      // Create temporary file for initial download
      await tempFile.create(recursive: true);
      final fileStream = tempFile.openWrite();
      
      // Track download size for progress reporting
      int totalBytes = int.tryParse(file.size ?? '0') ?? 0;
      int downloadedBytes = 0;
      
      // Download the file with progress tracking
      final media = await api.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      
      final reader = media.stream;
      
      await for (final chunk in reader) {
        fileStream.add(chunk);
        downloadedBytes += chunk.length;
        
        // Report progress (80% for download, 20% for encryption)
        if (totalBytes > 0) {
          onProgress(0.8 * (downloadedBytes / totalBytes));
        } else {
          // If we don't know the total size, use indeterminate progress
          onProgress(0.4); // Show some progress
        }
      }
      
      await fileStream.flush();
      await fileStream.close();
      
      // Report progress before encryption
      onProgress(0.8);
      
      // Encrypt the file if it's a supported type
      if (PDFEncryptionUtils.shouldEncrypt(tempFilePath)) {
        // Encrypt the downloaded file
        await PDFEncryptionUtils.instance.encryptFile(tempFilePath, finalFilePath);
        
        // Delete the temporary file after encryption
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } else {
        // For non-encrypting file types, just move the file
        await tempFile.rename(finalFilePath);
      }
      
      // Report completion
      onProgress(1.0);
      
      return finalFilePath;
    } catch (e) {
      // Clean up temporary files
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      // If there was an error and partial final file exists, delete it
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      
      rethrow;
    }
  }



  // Download a folder and its contents
  Future<void> downloadFolderWithProgress(
    drive.File folder,
    String destinationFolder,
    Function(double) onProgress,
  ) async {
    // Create the destination folder
    final folderName = folder.name ?? 'unnamed_folder';
    final folderPath = '$destinationFolder/$folderName';
    final directory = Directory(folderPath);
    
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    try {
      // Get all files in the folder
      final folderContents = await listFolderContents(folder.id!);
      final totalItems = folderContents.length;
      // ignore: unused_local_variable
      int completedItems = 0;
      
      // Count total folders for recursive progress
      int totalFolders = folderContents.where((file) => isFolder(file)).length;
      int processingWeight = totalFolders > 0 ? totalItems + totalFolders * 5 : totalItems;
      int processedWeight = 0;
      
      // Update progress
      onProgress(0);
      
      // Download each item
      for (var item in folderContents) {
        if (isFolder(item)) {
          // Recursively download subfolders
          await downloadFolderWithProgress(
            item, 
            folderPath,
            (subProgress) {
              // Calculate overall progress
              double currentItemContribution = subProgress / processingWeight;
              double previousProgress = processedWeight / processingWeight;
              onProgress(previousProgress + currentItemContribution);
            }
          );
          processedWeight += 5; // Give more weight to folders
        } else {
          // Download file with encryption
          await downloadFileWithProgress(
            item, 
            folderPath,
            (fileProgress) {
              // Calculate overall progress
              double currentItemContribution = fileProgress / processingWeight;
              double previousProgress = processedWeight / processingWeight;
              onProgress(previousProgress + currentItemContribution);
            }
          );
          processedWeight++;
        }
        completedItems++;
      }
      
      // Ensure all files in the folder are encrypted
      await DownloadedFolderEncryptionService.processDirectory(Directory(folderPath));
      
      // Ensure final progress is 100%
      onProgress(1.0);
      
    } catch (e) {
      rethrow;
    }
  }

  // List folders and files in a specific folder
  Future<List<drive.File>> listFolderContents(String folderId) async {
    final api = await driveApi;
    if (api == null) throw Exception('Drive API not initialized');

    final fileList = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name, mimeType, size)',
    );

    return fileList.files ?? [];
  }

  // Check if a file is a folder
  bool isFolder(drive.File file) {
    return file.mimeType == 'application/vnd.google-apps.folder';
  }

  
}

// Google Auth Client for authenticated requests
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}