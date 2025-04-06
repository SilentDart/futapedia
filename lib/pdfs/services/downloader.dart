import 'dart:io';
import 'dart:async';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:futapedia/pdfs/past%20questions/drive_past_question.dart';
import 'package:futapedia/pdfs/past%20questions/encrypt_util_past_question.dart';
import 'package:futapedia/pdfs/past%20questions/google_drive_past_question.dart';
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:connectivity_plus/connectivity_plus.dart';

// Enum to represent download status
// Enum to represent download status
enum DownloadStatus {
  queued,
  downloading,
  paused,
  failed,
  completed
}

// Improved download task model
class DownloadTask {
  final drive.File file;
  final String downloadPath;
  List<FolderBreadcrumb> breadcrumbs;
  final bool isFolder;
  String? taskId;
  DownloadStatus status;
  double progress;
  int retryCount;
  DateTime createdAt;
  DateTime? completedAt;

  DownloadTask({
    required this.file,
    required this.downloadPath,
    required this.breadcrumbs,
    this.isFolder = false,
    this.taskId,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.retryCount = 0,
  }) : createdAt = DateTime.now();
  
  // Add a method to mark task as completed
  void markComplete() {
    status = DownloadStatus.completed;
    progress = 1.0;
    completedAt = DateTime.now();
  }
  
  // Add a method to get the full path for this file
  String get fullPath => '$downloadPath/${file.name}';
  
  // Add a unique identifier for this task (useful for deduplication)
  String get uniqueId => '${file.id}-${isFolder ? 'folder' : 'file'}';
  
  @override
  String toString() {
    return 'DownloadTask(name: ${file.name}, id: ${file.id}, status: $status, progress: $progress)';
  }
}

@pragma('vm:entry-point')
class EnhancedBackgroundDownloadService {
  static final EnhancedBackgroundDownloadService _instance = 
      EnhancedBackgroundDownloadService._internal();

  factory EnhancedBackgroundDownloadService() => _instance;

  final FlutterLocalNotificationsPlugin _notificationPlugin = 
      FlutterLocalNotificationsPlugin();

  final Connectivity _connectivity = Connectivity();

  final List<DownloadTask> _downloadQueue = [];
  static const int MAX_CONCURRENT_DOWNLOADS = 4;
  static const int MAX_RETRY_ATTEMPTS = 3;

  final _downloadStreamController = StreamController<DownloadTask>.broadcast();
  Stream<DownloadTask> get downloadStream => _downloadStreamController.stream;

  // Static callback for Flutter Downloader
  @pragma('vm:entry-point')
  static void downloadCallback(
    String id, 
    int status, 
    int progress
  ) {
    // Ensure this method is accessible in background
    final service = EnhancedBackgroundDownloadService();
    service._handleDownloadCallback(id, DownloadTaskStatus.values[status], progress);
  }

  EnhancedBackgroundDownloadService._internal() {
    // _initializeServices();
    _setupConnectivityMonitoring();
  }

  // Future<void> _initializeServices() async {
  //   // Initialize Local Notifications
  //   const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  //   const initializationSettingsIOS = DarwinInitializationSettings(); 
  //   const initializationSettings = InitializationSettings(
  //     android: initializationSettingsAndroid,
  //     iOS: initializationSettingsIOS,
  //   );

  //   await _notificationPlugin.initialize(
  //     initializationSettings,
  //     onDidReceiveNotificationResponse: (details) {
  //       // Optional: Handle notification tap
  //     },
  //   );
  // }

  void _handleDownloadCallback(String id, DownloadTaskStatus status, int progress) {
    try {
      // Find the corresponding download task
      final taskIndex = _downloadQueue.indexWhere((task) => task.taskId == id);
      if (taskIndex == -1) {
        print('Download callback: task $id not found in queue');
        return;
      }
      
      final task = _downloadQueue[taskIndex];

      // Update task status based on download status
      switch (status) {
        case DownloadTaskStatus.running:
          task.status = DownloadStatus.downloading;
          task.progress = progress / 100.0;
          break;
        case DownloadTaskStatus.complete:
          task.status = DownloadStatus.completed;
          task.progress = 1.0;
          _handleCompletedDownload(task);
          break;
        case DownloadTaskStatus.failed:
          _handleDownloadFailure(task);
          break;
        case DownloadTaskStatus.paused:
          task.status = DownloadStatus.paused;
          break;
        default:
          break;
      }

      // Emit update to stream
      _downloadStreamController.add(task);
    } catch (e, stackTrace) {
      print('Download callback error: $e');
      print('Stacktrace: $stackTrace');
    }
  }

  void _handleCompletedDownload(DownloadTask task) {
    _showCompletedNotification(task);
    
    // Encrypt the downloaded file if needed
    if (!task.isFolder) {
      final downloadedFilePath = '${task.downloadPath}/${task.file.name}';
      _encryptDownloadedFile(downloadedFilePath);
    }

    // Remove completed task from queue
    _downloadQueue.removeWhere((t) => t.taskId == task.taskId);

    // Process next download in queue
    _processNextDownload();
  }

  void _encryptDownloadedFile(String filePath) {
    if (PastQuestionEncryptionUtils.shouldEncrypt(filePath)) {
      final encryptedPath = '${filePath}_encrypted';
      PastQuestionEncryptionUtils.encryptFile(filePath, encryptedPath)
        .then((_) async {
          await File(filePath).delete();
          await File(encryptedPath).rename(filePath);
        });
    }
  }

  Future<void> downloadWithConnectivityCheck({
    required drive.File file,
    required List<FolderBreadcrumb> breadcrumbs,
    bool isFolder = false,
  }) async {
    // Get the application documents directory
    final directory = await getApplicationDocumentsDirectory();
    final basePath = '${directory.path}/PastQuestion';

    // Generate relative path from breadcrumbs
    final relativePath = _generateRelativePath(breadcrumbs);
    final downloadPath = relativePath.isNotEmpty 
      ? '$basePath/$relativePath' 
      : basePath;

    // Ensure the directory exists
    await Directory(downloadPath).create(recursive: true);

    // Check network connectivity
    var connectivityResult = await _connectivity.checkConnectivity();
    
    if (connectivityResult == ConnectivityResult.none) {
      // No internet connection
      _showConnectivityErrorNotification();
      return;
    }

    // Create download task
    final task = DownloadTask(
      file: file,
      downloadPath: downloadPath,
      breadcrumbs: breadcrumbs,
      isFolder: isFolder,
    );

    // Enqueue task
    await _enqueueDownload(task);
  }

  Future<void> _enqueueDownload(DownloadTask task) async {
    print('Enqueing download: ${task.file.name}');
    
    // Check if this file is already in the queue
    final existingTaskIndex = _downloadQueue.indexWhere((t) => 
      t.file.id == task.file.id && t.status != DownloadStatus.completed);
    
    if (existingTaskIndex != -1) {
      print('File already in download queue: ${task.file.name}');
      return;
    }
    
    // Add to queue first
    _downloadQueue.add(task);
    
    // Then check if we can start download immediately
    if (_downloadQueue.where((t) => 
      t.status == DownloadStatus.downloading).length < MAX_CONCURRENT_DOWNLOADS) {
      await _startDownload(task);
    } else {
      _showQueuedNotification(task);
    }
  }

  Future<void> _startDownload(DownloadTask task) async {
  try {
    print('Starting download: ${task.file.name}');
    // Determine download URL
    final driveService = PastQuestionsDriveService();
    final driveApi = await driveService.driveApi;
    
    if (driveApi == null) {
      throw Exception('Drive API not initialized');
    }

    print('Got Drive API, fetching download URL');
    
    // Handle download differently based on whether it's a folder or file
    if (task.isFolder) {
      task.status = DownloadStatus.downloading;
      _showDownloadStartNotification(task);
      await _downloadFolderInternal(task);
    } else {
      final downloadUrl = await _getDownloadUrl(driveApi, task.file);
      print('Download URL: $downloadUrl'); // Log the URL
      
      if (downloadUrl == null) {
        throw Exception('Could not retrieve download URL');
      }
      
      // Create the target directory first
      await Directory(task.downloadPath).create(recursive: true);
      
      // Ensure we have a valid filename
      final fileName = task.file.name ?? 'unnamed_file';
      print('Downloading file to: ${task.downloadPath}/$fileName');
      
      // Get authentication token
      final token = await driveService.getUserToken();
      print('Auth token available: ${token != null}');
      
      // Start the download with headers
      task.taskId = await FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: task.downloadPath,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: false,
        headers: {'Authorization': 'Bearer $token'},
      );
      
      print('Download enqueued with task ID: ${task.taskId}');
      
      if (task.taskId == null) {
        throw Exception('Failed to enqueue download');
      }
      
      task.status = DownloadStatus.downloading;
      _showDownloadStartNotification(task);
      
      // Emit download started event
      _downloadStreamController.add(task);
    }
  } catch (e, stackTrace) {
    print('Error starting download: $e');
    print('Stacktrace: $stackTrace');
    _handleDownloadFailure(task);
  }
}

  void _processNextDownload() {
    if (_downloadQueue.where((t) => 
      t.status == DownloadStatus.downloading).length >= MAX_CONCURRENT_DOWNLOADS) {
      return;
    }
    
    try {
      final nextTaskIndex = _downloadQueue.indexWhere(
        (task) => task.status == DownloadStatus.queued
      );
      
      if (nextTaskIndex != -1) {
        _startDownload(_downloadQueue[nextTaskIndex]);
      }
    } catch (e) {
      // No queued downloads found or other error
      print('Error processing next download: $e');
    }
  }

  void _handleDownloadFailure(DownloadTask task) {
    task.retryCount++;
    if (task.retryCount < MAX_RETRY_ATTEMPTS) {
      // Retry download
      task.status = DownloadStatus.queued;
      _retryDownload(task);
    } else {
      task.status = DownloadStatus.failed;
      _showFailureNotification(task);
      
      // Remove failed task from queue
      _downloadQueue.removeWhere((t) => t.taskId == task.taskId);
      
      _processNextDownload();
    }
  }

  Future<void> _retryDownload(DownloadTask task) async {
    try {
      // Reset task for retry
      task.progress = 0.0;
      task.status = DownloadStatus.queued;
      
      // Implement retry logic
      await _startDownload(task);
      _showRetryNotification(task);
    } catch (e) {
      task.status = DownloadStatus.failed;
      _showFailureNotification(task);
    }
  }

  // Notification methods
  void _showDownloadStartNotification(DownloadTask task) {
    _showNotification(
      title: 'Download Started',
      body: 'Downloading ${task.file.name}',
      id: task.file.id.hashCode,
    );
  }

  void _showCompletedNotification(DownloadTask task) {
    _showNotification(
      title: 'Download Complete', 
      body: '${task.file.name} downloaded successfully',
      id: task.file.id.hashCode,
    );
  }

  void _showFailureNotification(DownloadTask task) {
    _showNotification(
      title: 'Download Failed', 
      body: 'Failed to download ${task.file.name}',
      id: task.file.id.hashCode,
    );
  }

  void _showRetryNotification(DownloadTask task) {
    _showNotification(
      title: 'Retrying Download', 
      body: 'Attempting to download ${task.file.name}',
      id: task.file.id.hashCode,
    );
  }

  void _showQueuedNotification(DownloadTask task) {
    _showNotification(
      title: 'Download Queued', 
      body: '${task.file.name} added to download queue',
      id: task.file.id.hashCode,
    );
  }

  void _showConnectivityErrorNotification() {
    _showNotification(
      title: 'No Internet Connection', 
      body: 'Please check your network and try again',
      id: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _showNotification({
    required String title, 
    required String body,
    required int id,
  }) async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
    );
    const notificationDetails = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    
    await _notificationPlugin.show(
      id, 
      title, 
      body, 
      notificationDetails
    );
  }

  Future<String?> _getDownloadUrl(drive.DriveApi driveApi, drive.File file) async {
  try {
    final fileMetadata = await driveApi.files.get(file.id!) as drive.File;
    final String? mimeType = fileMetadata.mimeType;

    if (mimeType != null && mimeType.contains('google-apps')) {
      return await _getExportLink(driveApi, file, mimeType);
    }

    // For direct file download
    final driveService = PastQuestionsDriveService();
    final token = await driveService.getUserToken();
    if (token == null) {
      throw Exception('Unable to retrieve authentication token');
    }
    
    return 'https://www.googleapis.com/drive/v3/files/${file.id}?alt=media&access_token=$token';
  } catch (e) {
    print('Error getting download URL: $e');
    return null;
  }
}

Future<String?> _handleAuthToken() async {
  try {
    final driveService = PastQuestionsDriveService();
    return await driveService.getUserToken();
  } catch (e) {
    print('Error getting auth token: $e');
    return null;
  }
}


  Future<String?> _getExportLink(
    drive.DriveApi driveApi, 
    drive.File file, 
    String mimeType
  ) async {
    try {
      String? exportMimeType;
      switch (mimeType) {
        case 'application/vnd.google-apps.document':
          exportMimeType = 'application/pdf';
          break;
        case 'application/vnd.google-apps.spreadsheet':
          exportMimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          break;
        case 'application/vnd.google-apps.presentation':
          exportMimeType = 'application/pdf';
          break;
        default:
          return null;
      }

      final exportLinks = await driveApi.files.export(
        file.id!, 
        exportMimeType,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      return exportLinks.toString();
    } catch (e) {
      print('Error getting export link: $e');
      return null;
    }
  }

  // Encrypt entire downloaded folder
  void _encryptDownloadedFolder(String folderPath) {
    final dir = Directory(folderPath);
    PastQuestionDownloadedFolderEncryptionService.processDirectory(dir);
  }

  String _generateRelativePath(List<FolderBreadcrumb> breadcrumbs) {
    return breadcrumbs
        .skip(1)  // Skip the root 'FUTApedia'
        .map((crumb) => crumb.name)
        .join('/');
  }

  // Fixed folder download method with proper handling of files inside folders
  // Fix for the _downloadFolderInternal method
Future<void> _downloadFolderInternal(DownloadTask folderTask) async {
  try {
    final driveService = PastQuestionsDriveService();
    final folderContents = await driveService.listFolderContents(folderTask.file.id!);
    
    if (folderContents.isEmpty) {
      print('Folder is empty: ${folderTask.file.name}');
      folderTask.status = DownloadStatus.completed;
      folderTask.progress = 1.0;
      _downloadStreamController.add(folderTask);
      _handleCompletedDownload(folderTask);
      return;
    }
    
    // Create folder directory
    final folderPath = '${folderTask.downloadPath}/${folderTask.file.name}';
    await Directory(folderPath).create(recursive: true);
    
    // Track total items for progress calculation
    final totalItems = folderContents.length;
    int completedItems = 0;
    
    // Create a completer to track when all downloads are complete
    final completer = Completer<void>();
    
    // Create a map to track all child task statuses
    final Map<String, DownloadStatus> childTasksStatus = {};
    
    // Initialize all child tasks as not started
    for (var item in folderContents) {
      childTasksStatus[item.id!] = DownloadStatus.queued;
    }
    
    // Listen for child task updates
    final subscription = downloadStream.listen((task) {
      final taskId = task.file.id;
      
      if (childTasksStatus.containsKey(taskId)) {
        // Update the status in our tracking map
        childTasksStatus[taskId as String] = task.status;
        
        // If this task just completed, increment our counter
        if (task.status == DownloadStatus.completed) {
          completedItems++;
          
          // Update parent task progress
          folderTask.progress = completedItems / totalItems;
          _downloadStreamController.add(folderTask);
          
          print('Child task completed: $taskId, Progress: ${folderTask.progress}');
          
          // Check if all child tasks are complete
          if (completedItems >= totalItems) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        } 
        // If this task failed, we might want to retry or mark the folder as failed
        else if (task.status == DownloadStatus.failed) {
          print('Child task failed: $taskId');
          // We could implement retry logic here, or mark the whole folder as failed
          // For now, we'll continue with the other downloads
        }
      }
    });
    
    // Process each item in the folder
    for (var item in folderContents) {
      // Create new breadcrumbs for nested items
      final newBreadcrumbs = [...folderTask.breadcrumbs, 
        FolderBreadcrumb(name: folderTask.file.name ?? 'Unnamed', id: folderTask.file.id!)];
      
      if (driveService.isFolder(item)) {
        // Create a new download task for nested folder
        final nestedTask = DownloadTask(
          file: item,
          downloadPath: folderPath, // Important: use the folder path here
          breadcrumbs: newBreadcrumbs,
          isFolder: true,
        );
        await _enqueueDownload(nestedTask);
      } else {
        // Download file directly
        final fileTask = DownloadTask(
          file: item,
          downloadPath: folderPath, // Important: use the folder path here
          breadcrumbs: newBreadcrumbs,
          isFolder: false,
        );
        await _enqueueDownload(fileTask);
      }
    }
    
    // Wait for all downloads to complete or timeout
    await completer.future.timeout(
      const Duration(minutes: 30),
      onTimeout: () {
        print('Folder download timed out: ${folderTask.file.name}');
        subscription.cancel();
        throw TimeoutException('Folder download timed out');
      }
    );
    
    // Cancel the subscription
    subscription.cancel();
    
    // Mark folder download as complete
    folderTask.status = DownloadStatus.completed;
    folderTask.progress = 1.0;
    _downloadStreamController.add(folderTask);
    
    // Encrypt the entire downloaded folder after contents are downloaded
    _encryptDownloadedFolder(folderPath);
    
    // Show completion notification
    _showCompletedNotification(folderTask);
    
    // Remove folder task from queue
    _downloadQueue.removeWhere((task) => task.file.id == folderTask.file.id);
    
    // Process next download in queue
    _processNextDownload();
  } catch (e, stackTrace) {
    print('Folder download error: $e');
    print('Stacktrace: $stackTrace');
    folderTask.status = DownloadStatus.failed;
    _showFailureNotification(folderTask);
    
    // Remove failed folder task from queue
    _downloadQueue.removeWhere((task) => task.file.id == folderTask.file.id);
    
    // Process next download
    _processNextDownload();
  }
}

  // Cancellation method
  Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
    
    // Remove from queue
    _downloadQueue.removeWhere((task) => task.taskId == taskId);
    
    _showNotification(
      title: 'Download Cancelled', 
      body: 'Download has been cancelled',
      id: taskId.hashCode,
    );
    
    // Process next download
    _processNextDownload();
  }

  // Cleanup method
  void dispose() {
    _downloadStreamController.close();
  }

  Future<String> downloadFileWithProgress(
    drive.File file, 
    String downloadPath, 
    void Function(double)? onProgress
  ) async {
    // Get breadcrumbs
    final List<FolderBreadcrumb> breadcrumbs = [
      FolderBreadcrumb(name: 'Past Questions', id: ''),
    ];
    
    final downloadTask = DownloadTask(
      file: file,
      downloadPath: downloadPath,
      breadcrumbs: breadcrumbs,
      isFolder: false,
    );

    // Use the existing download mechanism
    await _enqueueDownload(downloadTask);

    // Add a stream listener to track progress
    final progressCompleter = Completer<String>();
    
    StreamSubscription? subscription;
    subscription = downloadStream.listen((task) {
      if (task.file.id == file.id) {
        // Notify progress if callback is provided
        onProgress?.call(task.progress);

        if (task.status == DownloadStatus.completed) {
          final downloadedFilePath = '${task.downloadPath}/${task.file.name}';
          progressCompleter.complete(downloadedFilePath);
          subscription?.cancel();
        } else if (task.status == DownloadStatus.failed) {
          progressCompleter.completeError('Download failed');
          subscription?.cancel();
        }
      }
    });

    return progressCompleter.future;
  }

  Future<void> downloadFolderWithProgress(
    drive.File folder, 
    String downloadPath, 
    void Function(double)? onProgress
  ) async {
    // Get breadcrumbs
    final List<FolderBreadcrumb> breadcrumbs = [
      FolderBreadcrumb(name: 'Past Questions', id: ''),
    ];
    
    final downloadTask = DownloadTask(
      file: folder,
      downloadPath: downloadPath,
      breadcrumbs: breadcrumbs,
      isFolder: true,
    );

    // Use the existing download mechanism
    await _enqueueDownload(downloadTask);

    // Add a stream listener to track progress
    final progressCompleter = Completer<void>();
    
    StreamSubscription? subscription;
    subscription = downloadStream.listen((task) {
      if (task.file.id == folder.id) {
        // Notify progress if callback is provided
        onProgress?.call(task.progress);

        if (task.status == DownloadStatus.completed) {
          progressCompleter.complete();
          subscription?.cancel();
        } else if (task.status == DownloadStatus.failed) {
          progressCompleter.completeError('Folder download failed');
          subscription?.cancel();
        }
      }
    });

    return progressCompleter.future;
  }

  Future<void> _setupConnectivityMonitoring() async {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Check if any of the connectivity results indicate we're online
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      
      if (hasConnection) {
        print('Network connectivity restored - retrying failed downloads');
        // We have connectivity again - retry failed downloads
        final failedTasks = _downloadQueue.where(
          (t) => t.status == DownloadStatus.failed
        ).toList();
        
        for (var failedTask in failedTasks) {
          if (failedTask.retryCount < MAX_RETRY_ATTEMPTS) {
            _retryDownload(failedTask);
          }
        }
      }
    });
  }
}



// import 'dart:io';
// import 'dart:async';
// import 'package:dio/dio.dart';
// import 'package:futapedia/pdfs/past%20questions/google_drive_past_question.dart';
// import 'package:googleapis/drive/v3.dart' as drive;

// class BackgroundDownloadService {
//   static final BackgroundDownloadService _instance = BackgroundDownloadService._internal();
//   final Dio _dio = Dio();
//   final PastQuestionsDriveService _driveService = PastQuestionsDriveService();
  
//   factory BackgroundDownloadService() {
//     return _instance;
//   }
  
//   BackgroundDownloadService._internal();

//   Future<void> downloadFile({
//     required drive.File file,
//     required String destinationFolder,
//     required Function(double) onProgress,
//     required Function(String) onComplete,
//     required Function(dynamic) onError,
//   }) async {
//     try {
//       // Ensure destination folder exists
//       final destinationDir = Directory(destinationFolder);
//       if (!await destinationDir.exists()) {
//         await destinationDir.create(recursive: true);
//       }

//       // Determine file name and paths
//       final fileName = file.name ?? 'unnamed_file';
//       final finalFilePath = '$destinationFolder/$fileName';
//       final tempFilePath = '$destinationFolder/.temp_$fileName';

//       // Get download URL from Drive API
//       final driveApi = await _driveService.driveApi;
//       if (driveApi == null) throw Exception('Drive API not initialized');

//       // Get file metadata and download URL
//       final fileMetadata = await driveApi.files.get(file.id!) as drive.File;
      
//       // Use the export link for Google Docs files, otherwise use direct download
//       String? downloadUrl;
//       final String? mimeType = fileMetadata.mimeType;
//       if (mimeType != null && mimeType.contains('google-apps')) {
//         // For Google Docs files, use export link
//         downloadUrl = await _getExportLink(driveApi, file, mimeType);
//       } else {
//         // For regular files, use direct download
//         downloadUrl = await _getDirectDownloadLink(driveApi, file);
//       }

//       if (downloadUrl == null) {
//         throw Exception('Could not retrieve download URL');
//       }

//       // Download with Dio
//       await _dio.download(
//         downloadUrl, 
//         tempFilePath,
//         onReceiveProgress: (received, total) {
//           double progress = total > 0 ? received / total : 0.0;
//           onProgress(progress);
//         },
//         options: Options(
//           receiveTimeout: const Duration(minutes: 15),
//           sendTimeout: const Duration(minutes: 15),
//         ),
//       );

//       // Rename temp file to final file
//       final tempFile = File(tempFilePath);
//       await tempFile.rename(finalFilePath);

//       // Complete download
//       onComplete(finalFilePath);
//     } catch (e) {
//       onError(e);
//     }
//   }

//   // Get export link for Google Docs files
//   Future<String?> _getExportLink(
//     drive.DriveApi driveApi, 
//     drive.File file, 
//     String mimeType
//   ) async {
//     try {
//       // Determine appropriate export MIME type based on file type
//       String? exportMimeType;
//       switch (mimeType) {
//         case 'application/vnd.google-apps.document':
//           exportMimeType = 'application/pdf';
//           break;
//         case 'application/vnd.google-apps.spreadsheet':
//           exportMimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
//           break;
//         case 'application/vnd.google-apps.presentation':
//           exportMimeType = 'application/pdf';
//           break;
//         default:
//           return null;
//       }

//       // Get export links
//       final exportLinks = await driveApi.files.export(
//         file.id!, 
//         exportMimeType,
//         downloadOptions: drive.DownloadOptions.fullMedia,
//       );

//       return exportLinks.toString();
//     } catch (e) {
//       return null;
//     }
//   }

//   // Get direct download link for regular files
//   Future<String?> _getDirectDownloadLink(drive.DriveApi driveApi, drive.File file) async {
//     try {
//       // For regular files, construct a direct download URL
//       return 'https://www.googleapis.com/drive/v3/files/${file.id}?alt=media';
//     } catch (e) {
//       return null;
//     }
//   }

//   // Download an entire folder with background support
//   Future<void> downloadFolder({
//     required drive.File folder,
//     required String destinationFolder,
//     required Function(double) onProgress,
//     required Function(String) onComplete,
//     required Function(dynamic) onError,
//   }) async {
//     try {
//       // Get folder contents
//       final folderContents = await _driveService.listFolderContents(folder.id!);
//       final totalItems = folderContents.length;
//       int completedItems = 0;

//       // Create destination folder
//       final folderName = folder.name ?? 'unnamed_folder';
//       final folderPath = '$destinationFolder/$folderName';
//       await Directory(folderPath).create(recursive: true);

//       // Track overall progress
//       double overallProgress = 0.0;

//       // Download each item
//       for (var item in folderContents) {
//         if (_driveService.isFolder(item)) {
//           // Recursively download subfolders
//           await downloadFolder(
//             folder: item,
//             destinationFolder: folderPath,
//             onProgress: (subProgress) {
//               // Accumulate progress
//               overallProgress = (completedItems + subProgress) / totalItems;
//               onProgress(overallProgress);
//             },
//             onComplete: (_) {
//               completedItems++;
//               overallProgress = completedItems / totalItems;
//               onProgress(overallProgress);

//               if (completedItems == totalItems) {
//                 onComplete(folderPath);
//               }
//             },
//             onError: onError,
//           );
//         } else if (!_driveService.isFolder(item)) {
//           // Download all non-folder files
//           await downloadFile(
//             file: item,
//             destinationFolder: folderPath,
//             onProgress: (fileProgress) {
//               // Accumulate progress
//               overallProgress = (completedItems + fileProgress) / totalItems;
//               onProgress(overallProgress);
//             },
//             onComplete: (_) {
//               completedItems++;
//               overallProgress = completedItems / totalItems;
//               onProgress(overallProgress);

//               if (completedItems == totalItems) {
//                 onComplete(folderPath);
//               }
//             },
//             onError: onError,
//           );
//         }
//       }

//       // Ensure final progress if no items were downloaded
//       if (totalItems == 0) {
//         onComplete(folderPath);
//         onProgress(1.0);
//       }
//     } catch (e) {
//       onError(e);
//     }
//   }
// }