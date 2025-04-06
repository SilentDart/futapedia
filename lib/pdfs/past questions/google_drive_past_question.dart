import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';

class PastQuestionsDriveService {
  static final _scopes = [drive.DriveApi.driveScope];  
  static const _parentFolderId = '1wWhAuxkmbycTWMfyTJ3B1mPrm2pdCgAD';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  drive.DriveApi? _driveApi;

  // Initialize Google Drive API
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
    final fileName = file.name ?? 'unnamed_file';
    final tempFilePath = '$destinationFolder/.temp_$fileName';
    final finalFilePath = '$destinationFolder/$fileName';
    final tempFile = File(tempFilePath);
    final finalFile = File(finalFilePath);
    
    final dir = Directory(destinationFolder);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    try {
      final driveApi = await this.driveApi;
      if (driveApi == null) throw Exception('Drive API not initialized');
      
      await tempFile.create(recursive: true);
      final fileStream = tempFile.openWrite();
      
      int totalBytes = int.tryParse(file.size ?? '0') ?? 0;
      int downloadedBytes = 0;
      
      final media = await driveApi.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      
      final reader = media.stream;
      
      await for (final chunk in reader) {
        fileStream.add(chunk);
        downloadedBytes += chunk.length;
        
        onProgress(totalBytes > 0 
          ? downloadedBytes / totalBytes 
          : 0.4  // Indeterminate progress
        );
      }
      
      await fileStream.flush();
      await fileStream.close();
      
      await tempFile.rename(finalFilePath);
      
      onProgress(1.0);
      
      return finalFilePath;
    } catch (e) {
      // Enhanced error logging
      print('File download error for ${file.name}: $e');
      
      // Cleanup
      if (await tempFile.exists()) await tempFile.delete();
      if (await finalFile.exists()) await finalFile.delete();
      
      rethrow;
    }
  }

  Future<void> downloadFolderWithProgress(
    drive.File folder,
    String destinationFolder,
    Function(double) onProgress,
  ) async {
    final folderName = folder.name ?? 'unnamed_folder';
    final folderPath = '$destinationFolder/$folderName';
    final directory = Directory(folderPath);
    
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    try {
      final folderContents = await listFolderContents(folder.id!);
      // final totalItems = folderContents.length;
      
      // More robust progress calculation
      final processableItems = folderContents.where((item) => 
        isFolder(item) || (isImage(item) && !isFolder(item))
      ).toList();
      
      final totalProcessableItems = processableItems.length;
      int processedItems = 0;
      
      for (var item in processableItems) {
        if (isFolder(item)) {
          await downloadFolderWithProgress(
            item, 
            folderPath,
            (subProgress) {
              final itemProgress = (processedItems + subProgress) / totalProcessableItems;
              onProgress(itemProgress);
            }
          );
        } else if (isImage(item)) {
          await downloadFileWithProgress(
            item, 
            folderPath,
            (fileProgress) {
              final itemProgress = (processedItems + fileProgress) / totalProcessableItems;
              onProgress(itemProgress);
            }
          );
        }
        processedItems++;
      }
      
      onProgress(1.0);
      
    } catch (e) {
      // Enhanced error logging
      print('Folder download error for ${folder.name}: $e');
      rethrow;
    }
  }
  // List folders and image files in a specific folder
  Future<List<drive.File>> listFolderContents(String folderId) async {
    final api = await driveApi;
    if (api == null) throw Exception('Drive API not initialized');

    final fileList = await api.files.list(
      q: "'$folderId' in parents and trashed = false and (mimeType = 'application/vnd.google-apps.folder' or mimeType contains 'image/')",
      spaces: 'drive',
      $fields: 'files(id, name, mimeType, size)',
    );

    return fileList.files ?? [];
  }

  // Check if a file is a folder
  bool isFolder(drive.File file) {
    return file.mimeType == 'application/vnd.google-apps.folder';
  }

  // Check if a file is an image
  bool isImage(drive.File file) {
    return file.mimeType != null && file.mimeType!.contains('image/');
  }

  Future<String?> getUserToken() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      
      final googleAuth = await googleUser.authentication;
      return googleAuth.accessToken;
    } catch (e) {
      print('Error getting user token: $e');
      return null;
    }
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