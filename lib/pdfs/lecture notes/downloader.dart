import 'dart:async';
import 'dart:io';
import 'package:flutter_downloader/flutter_downloader.dart';
// import 'package:futapedia/pdfs/lecture%20notes/google_drive_pdf.dart';
import 'package:futapedia/study_material/pdf/pdf_drive.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as path;

class BackgroundDownloaderService {
  static final BackgroundDownloaderService _instance = BackgroundDownloaderService._internal();
  
  // Singleton pattern
  factory BackgroundDownloaderService() {
    return _instance;
  }
  
  BackgroundDownloaderService._internal();
  
  // Stream controllers for download progress updates
  final _downloadProgressController = StreamController<DownloadProgress>.broadcast();
  final _downloadStatusController = StreamController<DownloadStatus>.broadcast();
  
  // Keep track of task IDs and their corresponding Drive file IDs
  final Map<String, String> _taskIdToDriveId = {};
  final Map<String, String> _taskIdToFileName = {};
  
  // Expose streams
  Stream<DownloadProgress> get downloadProgressStream => _downloadProgressController.stream;
  Stream<DownloadStatus> get downloadStatusStream => _downloadStatusController.stream;
  
  // Initialize the downloader
  // Future<void> initializeFlutterDownloader() async {
  //   await FlutterDownloader.initialize(
  //     debug: false, // Set to false for production
  //     ignoreSsl: false,
  //   );
    
  //   // Register the callback with the correct type
  //   FlutterDownloader.registerCallback(downloadCallback);
  // }
  
  // Static callback function for Flutter Downloader with the correct signature
  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final BackgroundDownloaderService service = BackgroundDownloaderService();
    final driveId = service._taskIdToDriveId[id];
    final fileName = service._taskIdToFileName[id];
    
    // Convert the int status to DownloadTaskStatus
    final downloadStatus = DownloadTaskStatus.values[status];
    
    if (driveId != null) {
      // Update progress stream
      service._downloadProgressController.add(
        DownloadProgress(
          driveFileId: driveId,
          fileName: fileName ?? 'Unknown',
          progress: progress / 100,
          taskId: id,
        ),
      );
      
      // Update status stream
      if (downloadStatus == DownloadTaskStatus.complete) {
        service._downloadStatusController.add(
          DownloadStatus(
            driveFileId: driveId,
            fileName: fileName ?? 'Unknown',
            status: DownloadTaskStatus.complete,
            taskId: id,
          ),
        );
      } else if (downloadStatus == DownloadTaskStatus.failed) {
        service._downloadStatusController.add(
          DownloadStatus(
            driveFileId: driveId,
            fileName: fileName ?? 'Unknown',
            status: DownloadTaskStatus.failed,
            taskId: id,
          ),
        );
      }
    }
  }
  
  // Start a file download
  Future<String?> downloadFile(drive.File driveFile, String destination) async {
    // Ensure destination directory exists
    final downloadDir = Directory(destination);
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    
    final fileName = driveFile.name ?? 'untitled_file';
    final filePath = path.join(destination, fileName);
    
    // Get the download URL from Google Drive API
    final downloadUrl = driveFile.webContentLink;
    
    if (downloadUrl == null) {
      throw Exception('Download URL not available for ${driveFile.name}');
    }
    
    // Check if the file already exists
    final file = File(filePath);
    if (await file.exists()) {
      // Optionally check file size or hash to see if it's the same file
      return filePath;
    }
    
    // Start the download
    final taskId = await FlutterDownloader.enqueue(
      url: downloadUrl,
      savedDir: destination,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: false,
      saveInPublicStorage: false,
    );
    
    if (taskId != null) {
      // Store the mapping of task ID to Drive file ID
      _taskIdToDriveId[taskId] = driveFile.id!;
      _taskIdToFileName[taskId] = fileName;
      
      // Return the expected final path
      return filePath;
    }
    
    return null;
  }
  
  // Download a folder (recursive)
  Future<void> downloadFolder(
    drive.File folder, 
    String destination, 
    GoogleDriveServicePDF driveService, 
    void Function(double) progressCallback,
  ) async {
    // Ensure destination directory exists
    final folderName = folder.name ?? 'untitled_folder';
    final folderPath = path.join(destination, folderName);
    final folderDir = Directory(folderPath);
    
    if (!await folderDir.exists()) {
      await folderDir.create(recursive: true);
    }
    
    // List folder contents
    final contents = await driveService.listFolderContents(folder.id!);
    
    // Track progress
    int totalItems = contents.length;
    int completedItems = 0;
    
    // Download each item
    for (final item in contents) {
      try {
        if (item.mimeType == 'application/vnd.google-apps.folder') {
          // Recursively download subfolder
          await downloadFolder(
            item, 
            folderPath, 
            driveService, 
            (subProgress) {
              // Update progress based on subfolder progress
              progressCallback((completedItems + subProgress) / totalItems);
            },
          );
        } else {
          // Download file
          await downloadFile(item, folderPath);
          
          // Wait for download status via stream
          final completer = Completer<void>();
          late StreamSubscription subscription;
          
          subscription = downloadStatusStream.listen((status) {
            if (status.driveFileId == item.id) {
              subscription.cancel();
              completer.complete();
            }
          });
          
          // Set a timeout in case download status never arrives
          Timer(const Duration(minutes: 5), () {
            if (!completer.isCompleted) {
              completer.complete();
            }
          });
          
          await completer.future;
        }
        
        completedItems++;
        progressCallback(completedItems / totalItems);
      } catch (e) {
        // Log error but continue with next item
        print('Error downloading ${item.name}: $e');
      }
    }
  }
  
  // Cancel a download - Fix return type
  Future<bool> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
    // Since we can't get a boolean result directly, we'll remove the mappings
    // and return true to indicate the operation was attempted
    _taskIdToDriveId.remove(taskId);
    _taskIdToFileName.remove(taskId);
    return true;
  }
  
  // Pause a download
  Future<bool> pauseDownload(String taskId) async {
    await FlutterDownloader.pause(taskId: taskId);
    return true;
  }
  
  // Resume a download
  Future<String?> resumeDownload(String taskId) async {
    return await FlutterDownloader.resume(taskId: taskId);
  }
  
  // Retry a failed download
  Future<String?> retryDownload(String taskId) async {
    return await FlutterDownloader.retry(taskId: taskId);
  }
  
  // Get current download tasks
  Future<List<DownloadTask>?> getAllTasks() async {
    return await FlutterDownloader.loadTasks();
  }
  
  // Dispose and clean up resources
  void dispose() {
    _downloadProgressController.close();
    _downloadStatusController.close();
  }
  
  // Encrypt the downloaded file if needed
  Future<void> encryptDownloadedFile(String filePath) async {
    // Implement your encryption logic or call your existing encryption method
    // This is a placeholder - you should replace it with your actual encryption implementation
    final file = File(filePath);
    if (await file.exists()) {
      // Your encryption logic here
    }
  }
}

// Models for download progress and status
class DownloadProgress {
  final String driveFileId;
  final String fileName;
  final double progress;
  final String taskId;
  
  DownloadProgress({
    required this.driveFileId, 
    required this.fileName, 
    required this.progress,
    required this.taskId,
  });
}

class DownloadStatus {
  final String driveFileId;
  final String fileName;
  final DownloadTaskStatus status;
  final String taskId;
  
  DownloadStatus({
    required this.driveFileId, 
    required this.fileName, 
    required this.status,
    required this.taskId,
  });
}

// Extension to expose API methods for Google Drive Service
extension BackgroundDownloadGoogleDriveExtension on GoogleDriveServicePDF {
  Future<String?> downloadFileWithBackgroundService(
    drive.File file, 
    String destination,
  ) async {
    return await BackgroundDownloaderService().downloadFile(file, destination);
  }
  
  Future<void> downloadFolderWithBackgroundService(
    drive.File folder, 
    String destination,
    void Function(double) progressCallback,
  ) async {
    await BackgroundDownloaderService().downloadFolder(
      folder, 
      destination, 
      this, 
      progressCallback,
    );
  }
}