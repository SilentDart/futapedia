import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:futapedia/study_material/services/permission_manager.dart';
import 'package:futapedia/study_material/services/encrypt_utils.dart';
import 'package:path/path.dart' as path;
import 'dart:isolate';
import 'dart:ui';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


class GoogleDriveServicePDF {
  static final _scopes = [drive.DriveApi.driveScope];
  static const _parentFolderId = '1vhtg9JhjrrAz_8BQ-WlLGfltDF0r8Are';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  drive.DriveApi? _driveApi;

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
      
      // Encrypt the file if it's a supported type
      if (PDFEncryptionUtils.shouldEncrypt(tempFilePath)) {
        // Encrypt the downloaded file
        await PDFEncryptionUtils.encryptFile(tempFilePath, finalFilePath);
        
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
const String BACKGROUND_SERVICE_ID = "com.yourapp.backgroundDownloadService";
const String DOWNLOAD_TASK_EVENT = "download_task_even";
const String NOTIFICATION_CHANNEL_ID = "download_service_channel";
const String NOTIFICATION_CHANNEL_NAME = "Download Service";


class GoogleDriveDownloader {
  static const String _portName = 'downloader_send_port';
  static final Map<String, String> _taskIdToFilePath = {};
  static bool _isInitialized = false;
  static late ReceivePort _port;
  static GoogleDriveService? _driveService;
  static final Map<dynamic, List<Function>> _uiCallbacks = {};
  
  // Download queue management
  static final Queue<_DownloadTask> _downloadQueue = Queue<_DownloadTask>();
  static bool _isProcessingQueue = false;
  static late StreamController<DownloadProgress> _progressStreamController;
  
  // Keys for shared preferences
  static const String _keyPendingDownloads = 'pending_downloads';
  static const String _keyActiveDownloads = 'active_downloads';

  // Background service instance
  static FlutterBackgroundService? _backgroundService;
  
  // Initialize the downloader
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Initialize background service
      await _initializeBackgroundService();
      
      // Initialize FlutterDownloader
      await FlutterDownloader.initialize(
        debug: false, // Set to false in production
      );
      
      // Register callback for download progress
      await FlutterDownloader.registerCallback(downloadCallback);
      
      // Set up port for communication with isolate
      _port = ReceivePort();
      IsolateNameServer.registerPortWithName(_port.sendPort, _portName);
      _port.listen((dynamic data) {
        // Handle download status updates
        String id = data[0];
        DownloadTaskStatus status = data[1];
        int progress = data[2];
        
        // Update task status in persistent storage
        _updateTaskStatus(id, status, progress);
        
        // Emit progress event
        _progressStreamController.add(DownloadProgress(id, status, progress));
        
        // When download completes, encrypt the file and process next in queue
        if (status == DownloadTaskStatus.complete) {
          _encryptDownloadedFile(id).then((_) {
            _removeActiveTask(id);
            _processNextInQueue();
          });
        } else if (status == DownloadTaskStatus.failed) {
          // Clean up failed download and process next
          _removeActiveTask(id);
          _taskIdToFilePath.remove(id);
          _processNextInQueue();
        }
      });
      
      // Initialize stream controller for progress updates
      _progressStreamController = StreamController<DownloadProgress>.broadcast();
      
      // Initialize Google Drive service
      _driveService = GoogleDriveService();
      await _driveService!.initialize();
      
      // Resume any pending downloads from previous sessions
      await _resumePendingDownloads();
      
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing GoogleDriveDownloader: $e');
      return false;
    }
  }
  
  // Initialize Flutter Background Service
  static Future<void> _initializeBackgroundService() async {
    _backgroundService = FlutterBackgroundService();
    
    // Configure service for Android
    await _backgroundService!.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onBackgroundServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: NOTIFICATION_CHANNEL_ID,
        initialNotificationTitle: 'Download Service',
        initialNotificationContent: 'Preparing downloads',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onBackgroundServiceStart,
        onBackground: onIosBackground,
      ),
    );

    // Listen for service events
    _backgroundService!.on(DOWNLOAD_TASK_EVENT).listen((event) async {
      if (event == null) return;
      
      final action = event['action'];
      
      switch (action) {
        case 'process_queue':
          // Handle process queue request from background
          await _resumePendingDownloads();
          break;
        case 'download_progress':
          // Handle download progress update from background
          final taskId = event['taskId'];
          final status = event['status'];
          final progress = event['progress'];
          
          if (taskId != null && status != null && progress != null) {
            _progressStreamController.add(
              DownloadProgress(
                taskId, 
                DownloadTaskStatus.values[status], 
                progress
              )
            );
          }
          break;
        case 'download_completed':
          // Handle download completion from background
          final taskId = event['taskId'];
          if (taskId != null) {
            await _encryptDownloadedFile(taskId);
            _removeActiveTask(taskId);
            _processNextInQueue();
          }
          break;
      }
    });
  }
  
  // Resume downloads from previous sessions
  static Future<void> _resumePendingDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingDownloadsJson = prefs.getStringList(_keyPendingDownloads) ?? [];
      
      if (pendingDownloadsJson.isEmpty) return;
      
      debugPrint('Resuming ${pendingDownloadsJson.length} pending downloads');
      
      // Restore download queue
      for (final taskJson in pendingDownloadsJson) {
        try {
          final task = _DownloadTask.fromJson(taskJson);
          _downloadQueue.add(task);
        } catch (e) {
          debugPrint('Error parsing task: $e');
        }
      }
      
      // Process the queue
      if (!_isProcessingQueue && _downloadQueue.isNotEmpty) {
        _processNextInQueue();
      }
    } catch (e) {
      debugPrint('Error resuming pending downloads: $e');
    }
  }
  

  
  // Update task status and persist
  static Future<void> _updateTaskStatus(
    String taskId, 
    DownloadTaskStatus status, 
    int progress
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeDownloadsJson = prefs.getStringList(_keyActiveDownloads) ?? [];
      
      // Update the task status
      final updatedList = <String>[];
      for (final taskJson in activeDownloadsJson) {
        try {
          final task = _DownloadTask.fromJson(taskJson);
          if (task.flutterTaskId == taskId) {
            task.status = status.index;
            task.progressValue = progress;
          }
          updatedList.add(task.toJson());
        } catch (e) {
          updatedList.add(taskJson);
          debugPrint('Error updating task status: $e');
        }
      }
      
      await prefs.setStringList(_keyActiveDownloads, updatedList);
    } catch (e) {
      debugPrint('Error updating task status: $e');
    }
  }
  
  // Remove active task from persistent storage
  static Future<void> _removeActiveTask(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeDownloadsJson = prefs.getStringList(_keyActiveDownloads) ?? [];
      final List<String> updatedActiveDownloads = [];
      
      for (final taskJson in activeDownloadsJson) {
        final taskMap = _DownloadTask.jsonToMap(taskJson);
        if (taskMap['flutterTaskId'] != taskId) {
          updatedActiveDownloads.add(taskJson);
        }
      }
      
      await prefs.setStringList(_keyActiveDownloads, updatedActiveDownloads);
    } catch (e) {
      debugPrint('Error removing active task: $e');
    }
  }
  
  // Save the download queue to persistent storage
  static Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> pendingDownloadsJson = _downloadQueue.map((task) => task.toJson()).toList();
      await prefs.setStringList(_keyPendingDownloads, pendingDownloadsJson);
    } catch (e) {
      debugPrint('Error persisting download queue: $e');
    }
  }
  
  // Add active download to persistent storage
  static Future<void> _addActiveDownload(_DownloadTask task, String flutterTaskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeDownloadsJson = prefs.getStringList(_keyActiveDownloads) ?? [];
      final taskMap = task.toMap();
      taskMap['flutterTaskId'] = flutterTaskId;
      activeDownloadsJson.add(_DownloadTask.mapToJson(taskMap));
      await prefs.setStringList(_keyActiveDownloads, activeDownloadsJson);
    } catch (e) {
      debugPrint('Error adding active download: $e');
    }
  }
  
  // Callback function that runs in a separate isolate
  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(_portName);
    send?.send([id, DownloadTaskStatus.values[status], progress]);
  }
  
  // Entry point for iOS background execution
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    
    // Periodically check for pending downloads
    final prefs = await SharedPreferences.getInstance();
    final pendingDownloadsJson = prefs.getStringList(_keyPendingDownloads) ?? [];
    
    service.invoke(
      DOWNLOAD_TASK_EVENT,
      {
        'action': 'process_queue',
        'pendingCount': pendingDownloadsJson.length
      },
    );
    
    return true;
  }
  
  // Background service entry point for Android
  @pragma('vm:entry-point')
  static Future<void> _onBackgroundServiceStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    
    // Initialize FlutterDownloader in background service
    await FlutterDownloader.initialize(debug: false);
    
    // Register callback for download progress
    await FlutterDownloader.registerCallback(downloadCallbackBackground);
    
    // Initialize notifications for foreground service
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    
  
    // Periodic task to check downloads
    Timer.periodic(Duration(minutes: 15), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          final prefs = await SharedPreferences.getInstance();
          final pendingDownloadsJson = prefs.getStringList(_keyPendingDownloads) ?? [];
          final activeDownloadsJson = prefs.getStringList(_keyActiveDownloads) ?? [];
          
          // Update notification with download status
          service.setForegroundNotificationInfo(
            title: 'Downloads Manager',
            content: 'Active: ${activeDownloadsJson.length}, Pending: ${pendingDownloadsJson.length}',
          );
          
          // Process any pending downloads
          service.invoke(
            DOWNLOAD_TASK_EVENT,
            {
              'action': 'process_queue',
              'pendingCount': pendingDownloadsJson.length,
              'activeCount': activeDownloadsJson.length,
            },
          );
        }
      }
    });
    
    // Set up port for receiving download updates in background service
    final port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, 'background_downloader_port');
    
    port.listen((message) async {
      if (message is List && message.length == 3) {
        final String taskId = message[0];
        final DownloadTaskStatus status = message[1];
        final int progress = message[2];
        
        // Send progress to main isolate
        service.invoke(
          DOWNLOAD_TASK_EVENT,
          {
            'action': 'download_progress',
            'taskId': taskId,
            'status': status.index,
            'progress': progress,
          },
        );
        
        // Update notification with download progress
        if (service is AndroidServiceInstance) {
          if (status == DownloadTaskStatus.running) {
            service.setForegroundNotificationInfo(
              title: 'Downloading',
              content: 'Progress: $progress%',
            );
          } else if (status == DownloadTaskStatus.complete) {
            service.invoke(
              DOWNLOAD_TASK_EVENT,
              {
                'action': 'download_completed',
                'taskId': taskId,
              },
            );
          }
        }
      }
    });

    // Handle commands from main isolate
    service.on(DOWNLOAD_TASK_EVENT).listen((event) async {
      if (event == null) return;
      
      final action = event['action'];
      
      switch (action) {
        case 'start_download':
          final downloadUrl = event['url'];
          final savedDir = event['savedDir'];
          final fileName = event['fileName'];
          
          if (downloadUrl != null && savedDir != null && fileName != null) {
            final taskId = await FlutterDownloader.enqueue(
              url: downloadUrl,
              savedDir: savedDir,
              fileName: fileName,
              showNotification: true,
              openFileFromNotification: false,
              saveInPublicStorage: false,
            );
            
            service.invoke(
              DOWNLOAD_TASK_EVENT,
              {
                'action': 'download_started',
                'taskId': taskId,
              },
            );
          }
          break;
          
        case 'cancel_all':
          await FlutterDownloader.cancelAll();
          service.invoke(
            DOWNLOAD_TASK_EVENT,
            {
              'action': 'cancelled_all',
            },
          );
          break;
      }
    });
  }
  
  // Download callback for background service
  @pragma('vm:entry-point')
  static void downloadCallbackBackground(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName('background_downloader_port');
    send?.send([id, DownloadTaskStatus.values[status], progress]);
  }
  
  // Process the next item in the download queue
  static Future<void> _processNextInQueue() async {
    if (_downloadQueue.isEmpty || _isProcessingQueue) {
      _isProcessingQueue = false;
      await _persistQueue(); // Save updated queue
      
      // If queue is empty, check if we should stop the background service
      if (_downloadQueue.isEmpty) {
        final tasks = await FlutterDownloader.loadTasks();
        final activeDownloads = tasks?.where((task) => 
          task.status == DownloadTaskStatus.running || 
          task.status == DownloadTaskStatus.enqueued
        ).toList() ?? [];
        
        if (activeDownloads.isEmpty) {
          // No active downloads, stop the background service
          _backgroundService?.invoke('stopService');
        }
      }
      
      return;
    }
    
    _isProcessingQueue = true;
    final task = _downloadQueue.removeFirst();
    await _persistQueue(); // Save updated queue
    
    try {
      if (task.isFolder) {
        await _downloadFolderInternal(
          task.id,
          task.name,
          task.basePath,
          task.relativePath,
          task.onProgress,
        );
      } else {
        await _downloadFileInternal(
          task.id,
          task.name,
          task.mimeType!,
          task.basePath,
          task.relativePath,
          task.onProgress,
        );
      }
    } catch (e) {
      debugPrint('Error processing download task: $e');
      task.onProgress?.call(-1.0); // Signal error
    } finally {
      // Process next item in queue regardless of success/failure
      _isProcessingQueue = false;
      await _processNextInQueue();
    }
  }
  
  // Add a file download task to the queue
  static Future<String?> downloadFile(
    BuildContext context,
    String fileId,
    String fileName,
    String mimeType, {
    String? parentFolderPath,
    Function(double)? onProgress,
  }) async {
    // Initialize if not already done
    if (!await initialize()) {
      return null;
    }
    
    // Request storage permission
    final hasPermission = await PermissionManager.requestStoragePermission(context);
    if (!hasPermission) {
      return null;
    }
    
    try {
      // Get the base download path
      final basePath = await PermissionManager.getAppropriateDownloadPath();
      final downloadDir = parentFolderPath ?? basePath;
      
      // Create directory if it doesn't exist
      await Directory(downloadDir).create(recursive: true);
      
      // Determine the file path
      final filePath = path.join(downloadDir, fileName);
      
      // Check if file already exists
      if (await File(filePath).exists()) {
        // Consider adding logic to handle existing files (skip, overwrite, etc.)
        debugPrint('File already exists: $filePath');
      }
      
      // Register the progress callback with the UI component
      if (onProgress != null) {
        registerUICallback(context, onProgress);
      }
      
      // Create download task
      final downloadTask = _DownloadTask(
        id: fileId,
        name: fileName,
        mimeType: mimeType,
        basePath: basePath,
        relativePath: parentFolderPath != null ? 
          parentFolderPath.replaceFirst(basePath + path.separator, '') : '',
        isFolder: false,
        onProgress: onProgress,
      );
      
      // Add to download queue
      _downloadQueue.add(downloadTask);
      await _persistQueue(); // Persist queue immediately
      
      // Start processing queue if not already running
      if (!_isProcessingQueue) {
        _processNextInQueue();
      }
      
      // Ensure background service is running
      await _startBackgroundService();
      
      return filePath;
    } catch (e) {
      debugPrint('Error queueing file download: $e');
      onProgress?.call(-1.0); // Signal error
      return null;
    }
  }
  
  // Start the background service
  static Future<void> _startBackgroundService() async {
    if (_backgroundService == null) {
      await _initializeBackgroundService();
    }
    
    await _backgroundService!.startService();
  }
  
  // Internal method to actually download a file
  static Future<String?> _downloadFileInternal(
    String fileId,
    String fileName,
    String mimeType,
    String basePath,
    String relativePath,
    Function(double)? onProgress,
  ) async {
    try {
      // Determine the full path with proper folder structure
      final downloadDir = path.join(basePath, relativePath);
      
      // Create directory if it doesn't exist
      await Directory(downloadDir).create(recursive: true);
      
      // Determine the file path
      final filePath = path.join(downloadDir, fileName);
      
      // Check if we should use Google Drive API or direct download
      if (_driveService != null && await _driveService!.isSignedIn()) {
        // Use Drive API for authorized download with progress tracking
        final driveFile = drive.File()
          ..id = fileId
          ..name = fileName
          ..mimeType = mimeType;
        
        final downloadResult = await _driveService!.downloadFileWithProgress(
          driveFile, 
          downloadDir,
          onProgress ?? ((progress) {
            // Default progress callback
            debugPrint('Download progress: $progress');
          })
        );
        
        // If successful, register task completion
        _taskIdToFilePath[fileId] = downloadResult;
        await _encryptDownloadedFile(fileId);
              
        return downloadResult;
      } else {
        // Fallback to direct download URL method
        final downloadUrl = 'https://drive.google.com/uc?export=download&id=$fileId';
        
        // Apply retry strategy for network issues
        int retryCount = 0;
        const maxRetries = 3;
        String? taskId;
        
        final task = _DownloadTask(
          id: fileId,
          name: fileName,
          mimeType: mimeType,
          basePath: basePath,
          relativePath: relativePath,
          isFolder: false,
          onProgress: onProgress,
        );
        
        while (retryCount < maxRetries && taskId == null) {
          try {
            // Start the download task
            taskId = await FlutterDownloader.enqueue(
              url: downloadUrl,
              savedDir: downloadDir,
              fileName: fileName,
              showNotification: true,
              openFileFromNotification: false,
              saveInPublicStorage: false,
              headers: {'User-Agent': 'Mozilla/5.0'},
              timeout: 60000, // 60 seconds timeout
            );
            
            // Also notify background service to monitor this download
            _backgroundService?.invoke(
              DOWNLOAD_TASK_EVENT,
              {
                'action': 'start_download',
                'url': downloadUrl,
                'savedDir': downloadDir,
                'fileName': fileName,
              },
            );
          } catch (e) {
            retryCount++;
            if (retryCount >= maxRetries) rethrow;
            await Future.delayed(Duration(seconds: 2 * retryCount)); // Exponential backoff
          }
        }
        
        // Store task ID to file path mapping for encryption later
        if (taskId != null) {
          _taskIdToFilePath[taskId] = filePath;
          
          // Add to active downloads
          await _addActiveDownload(task, taskId);
          
          // Set up subscription to track progress if needed
          if (onProgress != null) {
            _progressStreamController.stream
                .where((event) => event.id == taskId)
                .listen((event) {
              if (event.status == DownloadTaskStatus.running) {
                onProgress(event.progress / 100);
              } else if (event.status == DownloadTaskStatus.complete) {
                onProgress(1.0);
              } else if (event.status == DownloadTaskStatus.failed) {
                onProgress(-1.0);
              }
            });
          }
        }
        
        return filePath;
      }
    } catch (e) {
      debugPrint('Error downloading file: $e');
      onProgress?.call(-1.0); // Signal error
      return null;
    }
  }
  
  // Add a folder download task to the queue
  static Future<String?> downloadFolder(
    BuildContext context,
    String folderId,
    String folderName, {
    Function(double)? onProgress,
  }) async {
    // Initialize if not already done
    if (!await initialize()) {
      return null;
    }
    
    // Request storage permission
    final hasPermission = await PermissionManager.requestStoragePermission(context);
    if (!hasPermission) {
      return null;
    }
    
    try {
      // Get the base download path
      final basePath = await PermissionManager.getAppropriateDownloadPath();
      final folderPath = path.join(basePath, folderName);
      
      // Create folder directory
      await Directory(folderPath).create(recursive: true);
      
      // Register the progress callback with the UI component
      if (onProgress != null) {
        registerUICallback(context, onProgress);
      }
      
      // Create folder task
      final folderTask = _DownloadTask(
        id: folderId,
        name: folderName,
        basePath: basePath,
        relativePath: '',
        isFolder: true,
        onProgress: onProgress,
      );
      
      // Add to download queue
      _downloadQueue.add(folderTask);
      await _persistQueue(); // Persist queue immediately
      
      // Start processing queue if not already running
      if (!_isProcessingQueue) {
        _processNextInQueue();
      }
      
      // Ensure background service is running
      await _startBackgroundService();
      
      return folderPath;
    } catch (e) {
      debugPrint('Error queueing folder download: $e');
      onProgress?.call(-1.0); // Signal error
      return null;
    }
  }
  
  // Internal method to actually download a folder
  static Future<String?> _downloadFolderInternal(
    String folderId,
    String folderName,
    String basePath,
    String relativePath,
    Function(double)? onProgress,
  ) async {
    try {
      // Determine the full path with proper folder structure
      final currentRelativePath = path.join(relativePath, folderName);
      final folderPath = path.join(basePath, currentRelativePath);
      
      // Create folder directory
      await Directory(folderPath).create(recursive: true);
      
      // Check if we should use Google Drive API
      if (_driveService != null && await _driveService!.isSignedIn()) {
        // Get folder contents
        final List<drive.File> folderContents = await _driveService!.listFolderContents(folderId);
        if (folderContents.isEmpty) {
          onProgress?.call(1.0); // Empty folder - complete
          return folderPath;
        }
        
        double totalItems = folderContents.length.toDouble();
        double itemsProcessed = 0;
        
        // Use a completion counter to track overall progress
        int completedItems = 0;
        final completer = Completer<void>();
        
        // Track errors
        List<String> errors = [];
        
        // Process each item while maintaining folder structure
        for (final item in folderContents) {
          final itemId = item.id;
          final itemName = item.name;
          final itemMimeType = item.mimeType;
          
          if (itemId == null || itemName == null || itemMimeType == null) {
            completedItems++;
            if (completedItems >= folderContents.length) {
              completer.complete();
            }
            continue;
          }
          
          void updateProgress(double subProgress) {
            if (onProgress != null && !completer.isCompleted) {
              if (subProgress < 0) {
                // Error in subitem
                errors.add(itemName);
              } else {
                double combinedProgress = (itemsProcessed + subProgress) / totalItems;
                onProgress(combinedProgress);
              }
            }
          }
          
          void markCompleted() {
            completedItems++;
            itemsProcessed++;
            if (onProgress != null) {
              onProgress(itemsProcessed / totalItems);
            }
            
            if (completedItems >= folderContents.length) {
              completer.complete();
            }
          }
          
          try {
            if (itemMimeType == 'application/vnd.google-apps.folder') {
              // Create subfolder task
              // final subfolderTask = _DownloadTask(
              //   id: itemId,
              //   name: itemName,
              //   basePath: basePath,
              //   relativePath: currentRelativePath,
              //   isFolder: true,
              //   onProgress: updateProgress,
              // );
              
              // Download subfolder with proper relative path
              await _downloadFolderInternal(
                itemId,
                itemName,
                basePath,
                currentRelativePath,
                updateProgress
              );
              markCompleted();
            } else {
              // Create file task
              // final fileTask = _DownloadTask(
              //   id: itemId,
              //   name: itemName,
              //   mimeType: itemMimeType,
              //   basePath: basePath,
              //   relativePath: currentRelativePath,
              //   isFolder: false,
              //   onProgress: updateProgress,
              // );
              
              // Download file with proper relative path
              await _downloadFileInternal(
                itemId,
                itemName,
                itemMimeType,
                basePath,
                currentRelativePath,
                updateProgress
              );
              markCompleted();
            }
          } catch (e) {
            debugPrint('Error downloading item $itemName: $e');
            errors.add(itemName);
            markCompleted();
          }
        }
        
        // Wait for all processes to complete
        await completer.future;
        
        // Log errors if any
        if (errors.isNotEmpty) {
          debugPrint('Errors downloading ${errors.length} items in folder $folderName: ${errors.join(", ")}');
        }
        
        return folderPath;
      } else {
        // Fallback to basic implementation 
        onProgress?.call(-1.0); // Signal error
        throw Exception('Not authenticated. Cannot download folder without authentication.');
      }
    } catch (e) {
      debugPrint('Error downloading folder: $e');
      onProgress?.call(-1.0); // Signal error
      return null;
    }
  }
  
  // Encrypt the downloaded file
  static Future<void> _encryptDownloadedFile(String taskId) async {
    final filePath = _taskIdToFilePath[taskId];
    if (filePath == null) return;
    
    try {
      // Get info about the task
      final tasks = await FlutterDownloader.loadTasks();
      final task = tasks?.firstWhere((t) => t.taskId == taskId, orElse: () => throw Exception('Task not found'));
      
      if (task != null && task.status == DownloadTaskStatus.complete) {
        // The actual file path from FlutterDownloader
        final downloadedFilePath = task.savedDir + Platform.pathSeparator + (task.filename ?? '');
        
        // Check if file exists before encryption
        if (!await File(downloadedFilePath).exists()) {
          debugPrint('File does not exist: $downloadedFilePath');
          return;
        }
        
        // Encrypt the file
        if (PDFEncryptionUtils.shouldEncrypt(downloadedFilePath)) {
          final encryptedPath = '$downloadedFilePath.enc';
          
          // Don't overwrite existing encrypted file
          if (await File(encryptedPath).exists()) {
            await File(encryptedPath).delete();
          }
          
          await PDFEncryptionUtils.encryptFile(downloadedFilePath, encryptedPath);
          
          // Replace original with encrypted
          final encryptedFile = File(encryptedPath);
          if (await encryptedFile.exists()) {
            await File(downloadedFilePath).delete();
            await encryptedFile.rename(downloadedFilePath);
          }
        }
      }
    } catch (e) {
      debugPrint('Error encrypting downloaded file: $e');
    } finally {
      // Remove from the tracking map regardless of success/failure
      _taskIdToFilePath.remove(taskId);
    }
  }
  
  // Clean up resources when no longer needed
  static void dispose() {
    IsolateNameServer.removePortNameMapping(_portName);
    _progressStreamController.close();
    _isInitialized = false;
  }
  
  // Open a downloaded file (with decryption)
  static Future<Uint8List?> openFile(String filePath) async {
    if (!await File(filePath).exists()) {
      return null;
    }
    
    try {
      // Check if the file is encrypted
      if (await DownloadedFolderEncryptionService.isFileEncrypted(filePath)) {
        // Decrypt and return the file content
        return await PDFEncryptionUtils.decryptFile(filePath);
      } else {
        // Return the raw file content if not encrypted
        return await File(filePath).readAsBytes();
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      return null;
    }
  }
  
  // Get all downloaded files
  static Future<List<FileSystemEntity>> getDownloadedFiles() async {
    final basePath = await PermissionManager.getAppropriateDownloadPath();
    
    try {
      final directory = Directory(basePath);
      if (!await directory.exists()) {
        return [];
      }
      
      return directory.listSync(recursive: true);
    } catch (e) {
      debugPrint('Error getting downloaded files: $e');
      return [];
    }
  }

  static Future<String> getDownloadDirectory() async {
    // Get the app's documents directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final downloadDir = '${appDocDir.path}/FUTApedia';
    
    // Create the directory if it doesn't exist
    final directory = Directory(downloadDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    return downloadDir;
  }
  
  // Cancel all active downloads
  static Future<bool> cancelAllDownloads() async {
    if (!_isInitialized) return false;
    
    try {
      // Clear the queue
      _downloadQueue.clear();
      await _persistQueue();
      _isProcessingQueue = false;
      
      // Cancel all active download tasks
      final tasks = await FlutterDownloader.loadTasks();
      if (tasks != null) {
        for (final task in tasks) {
          if (task.status == DownloadTaskStatus.running || 
              task.status == DownloadTaskStatus.enqueued) {
            await FlutterDownloader.cancel(taskId: task.taskId);
          }
        }
      }
      
      // Stop background service instead of Workmanager
      if (_backgroundService != null) {
        _backgroundService!.invoke('stopService');
      }
      
      // Clear active downloads
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyActiveDownloads, []);
      
      return true;
    } catch (e) {
      debugPrint('Error canceling downloads: $e');
      return false;
    }
  }

  
  // Get a stream of download progress events
  static Stream<DownloadProgress>? getDownloadProgressStream() {
    return _progressStreamController.stream;
  }
  
  // Get current download status
  static Future<Map<String, dynamic>> getDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingDownloadsJson = prefs.getStringList(_keyPendingDownloads) ?? [];
    final activeDownloadsJson = prefs.getStringList(_keyActiveDownloads) ?? [];
    
    return {
      'pendingCount': pendingDownloadsJson.length,
      'activeCount': activeDownloadsJson.length,
      'isProcessingQueue': _isProcessingQueue,
    };
  }

  // Register a UI callback
  static void registerUICallback(dynamic uiComponent, Function callback) {
    if (!_uiCallbacks.containsKey(uiComponent)) {
      _uiCallbacks[uiComponent] = [];
    }
    _uiCallbacks[uiComponent]?.add(callback);
  }

  // Detach UI references but keep downloads running
  static void detachFromUI(dynamic uiComponent) {
    if (_uiCallbacks.containsKey(uiComponent)) {
      _uiCallbacks.remove(uiComponent);
    }
  }
}

// Class to represent a download task in the queue
class _DownloadTask {
  final String id;
  final String name;
  final String? mimeType;
  final String basePath;
  final String relativePath;
  final bool isFolder;
  final Function(double)? onProgress;
  int progressValue = 0;
  int status = DownloadTaskStatus.undefined.index;
  String? flutterTaskId;
  
  _DownloadTask({
    required this.id,
    required this.name,
    this.mimeType,
    required this.basePath,
    required this.relativePath,
    required this.isFolder,
    this.onProgress,
    this.flutterTaskId,
  });

  // Convert to map for JSON serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mimeType': mimeType,
      'basePath': basePath,
      'relativePath': relativePath,
      'isFolder': isFolder,
      'progressValue': progressValue,
      'status': status,
      'flutterTaskId': flutterTaskId,
    };
  }
  
  // Convert to JSON string
  String toJson() {
    return mapToJson(toMap());
  }
  
  // Static helper to convert map to JSON string
  static String mapToJson(Map<String, dynamic> map) {
    return map.entries
        .map((e) => '"${e.key}":"${e.value}"')
        .join(',');
  }
  
  // Static helper to convert JSON string to map
  static Map<String, dynamic> jsonToMap(String json) {
    final map = <String, dynamic>{};
    
    // Simple JSON parser for our needs
    final entries = json.substring(1, json.length - 1).split(',');
    for (final entry in entries) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        final key = parts[0].replaceAll('"', '');
        final value = parts[1].replaceAll('"', '');
        
        // Convert values based on key
        if (key == 'isFolder') {
          map[key] = value == 'true';
        } else if (key == 'progressValue' || key == 'status') {
          map[key] = int.tryParse(value) ?? 0;
        } else {
          map[key] = value;
        }
      }
    }
    
    return map;
  }
  
  // Create from JSON string  
  factory _DownloadTask.fromJson(String json) {
    final map = jsonToMap(json);
    
    return _DownloadTask(
      id: map['id'],
      name: map['name'],
      mimeType: map['mimeType'],
      basePath: map['basePath'],
      relativePath: map['relativePath'],
      isFolder: map['isFolder'] ?? false,
      flutterTaskId: map['flutterTaskId'],
    )
      ..progressValue = map['progressValue'] ?? 0
      ..status = map['status'] ?? DownloadTaskStatus.undefined.index;
  }
}

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
        await PDFEncryptionUtils.encryptFile(tempFilePath, finalFilePath);
        
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