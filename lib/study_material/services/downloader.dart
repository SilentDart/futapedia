import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:futapedia/study_material/pdf/pdf_drive.dart';
import 'package:futapedia/study_material/services/encrypt_utils.dart';
import 'package:futapedia/study_material/services/permission_manager.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String BACKGROUND_SERVICE_ID = "com.futapedia.backgroundDownloadService";
const String DOWNLOAD_TASK_EVENT = "download_task_even";
const String NOTIFICATION_CHANNEL_ID = "download_service_channel";
const String NOTIFICATION_CHANNEL_NAME = "Download Service";

// Constants for optimization
const int MAX_CONCURRENT_DOWNLOADS = 3;  // Optimal number of concurrent downloads
const int DOWNLOAD_TIMEOUT = 120000;     // 2 minutes timeout for downloads
const int RETRY_COUNT = 3;               // Number of retries for failed downloads
const int ENCRYPTION_BATCH_SIZE = 5;     // Number of files to encrypt in a batch
bool _isProcessingQueue = false;

class GoogleDriveDownloader {
  static const String _portName = 'downloader_send_port';
  static final Map<String, String> _taskIdToFilePath = {};
  static bool _isInitialized = false;
  static late ReceivePort _port;
  static GoogleDriveServicePDF? _driveService;
  static final Map<dynamic, List<Function>> _uiCallbacks = {};
  
  // Download queue and concurrent processing
  static final Queue<_DownloadTask> _downloadQueue = Queue<_DownloadTask>();
  static int _activeDownloads = 0;
  static final Set<String> _tasksInProgress = <String>{};
  static late StreamController<DownloadProgress> _progressStreamController;
  
  // Cache and memory optimization
  static final Map<String, _DownloadTaskStatus> _taskStatus = {};
  static final Map<String, Completer<String?>> _downloadCompleters = {};
  
  // Keys for shared preferences
  static const String _keyPendingDownloads = 'pending_downloads';
  static const String _keyActiveDownloads = 'active_downloads';

  // Background service instance
  static FlutterBackgroundService? _backgroundService;
  
  // Initialize the downloader
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Initialize FlutterDownloader first for faster startup
      await FlutterDownloader.initialize(
        debug: false, // Set to false in production
      );
      
      // Set up port for communication with isolate
      _port = ReceivePort();
      IsolateNameServer.registerPortWithName(_port.sendPort, _portName);
      
      // Initialize stream controller for progress updates
      _progressStreamController = StreamController<DownloadProgress>.broadcast();
      
      // Register callback for download progress
      await FlutterDownloader.registerCallback(downloadCallback);
      
      // Initialize background service in parallel with other setup
      final backgroundServiceFuture = _initializeBackgroundService();
      
      // Initialize Google Drive service in parallel
      final driveServiceFuture = _initializeDriveService();
      
      // Listen for download status updates
      _port.listen(_handleDownloadStatusUpdate);
      
      // Wait for parallel initialization to complete
      await Future.wait([backgroundServiceFuture, driveServiceFuture]);
      
      // Resume any pending downloads from previous sessions
      _resumePendingDownloads();
      
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing GoogleDriveDownloader: $e');
      return false;
    }
  }
  
  // Handle download status updates more efficiently
  static void _handleDownloadStatusUpdate(dynamic data) {
    try {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];
      
      // Update task status in memory cache first
      _taskStatus[id] = _DownloadTaskStatus(status: status, progress: progress);
      
      // Emit progress event to all listeners
      _progressStreamController.add(DownloadProgress(id, status, progress));
      
      // When download completes, handle efficiently
      if (status == DownloadTaskStatus.complete) {
        _handleDownloadComplete(id);
      } else if (status == DownloadTaskStatus.failed) {
        _handleDownloadFailed(id);
      }
      
      // Persist status update in background
      _updateTaskStatusAsync(id, status, progress);
    } catch (e) {
      debugPrint('Error handling download status update: $e');
    }
  }
  
  // Handle download completion efficiently
  static Future<void> _handleDownloadComplete(String id) async {
    try {
      // Encrypt file in background
      _encryptDownloadedFile(id);
      
      // Remove task from active list
      _tasksInProgress.remove(id);
      _activeDownloads--;
      
      // Complete any waiting future
      final completer = _downloadCompleters[id];
      if (completer != null && !completer.isCompleted) {
        completer.complete(_taskIdToFilePath[id]);
        _downloadCompleters.remove(id);
      }
      
      // Process next files immediately
      _processNextBatch();
    } catch (e) {
      debugPrint('Error handling download completion: $e');
    }
  }
  
  // Handle download failure efficiently
  static Future<void> _handleDownloadFailed(String id) async {
    try {
      _tasksInProgress.remove(id);
      _activeDownloads--;
      _taskIdToFilePath.remove(id);
      
      // Complete any waiting future with error
      final completer = _downloadCompleters[id];
      if (completer != null && !completer.isCompleted) {
        completer.complete(null);
        _downloadCompleters.remove(id);
      }
      
      // Process next files immediately
      _processNextBatch();
    } catch (e) {
      debugPrint('Error handling download failure: $e');
    }
  }
  
  // Initialize background service
  static Future<void> _initializeBackgroundService() async {
    _backgroundService = FlutterBackgroundService();
    
    // Configure service for Android with optimized settings
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
    _backgroundService!.on(DOWNLOAD_TASK_EVENT).listen(_handleBackgroundServiceEvent);
  }
  
  // Handle background service events more efficiently
  static void _handleBackgroundServiceEvent(event) async {
    if (event == null) return;
    
    final action = event['action'];
    
    switch (action) {
      case 'process_queue':
        _resumePendingDownloads();
        break;
      case 'download_progress':
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
        final taskId = event['taskId'];
        if (taskId != null) {
          _encryptDownloadedFile(taskId);
          _removeActiveTask(taskId);
          _processNextBatch();
        }
        break;
    }
  }
  
  // Initialize Drive API service
  static Future<void> _initializeDriveService() async {
    _driveService = GoogleDriveServicePDF();
    await _driveService!.initialize();
  }
  
  // Update task status asynchronously
  static Future<void> _updateTaskStatusAsync(
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
        }
      }
      
      await prefs.setStringList(_keyActiveDownloads, updatedList);
    } catch (e) {
      // Non-critical error, just log
      debugPrint('Error updating task status: $e');
    }
  }
  
  // Resume downloads from previous sessions
  static Future<void> _resumePendingDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingDownloadsJson = prefs.getStringList(_keyPendingDownloads) ?? [];
      
      if (pendingDownloadsJson.isEmpty) return;
      
      debugPrint('Resuming ${pendingDownloadsJson.length} pending downloads');
      
      // Restore download queue in a single batch
      for (final taskJson in pendingDownloadsJson) {
        try {
          final task = _DownloadTask.fromJson(taskJson);
          _downloadQueue.add(task);
        } catch (e) {
          debugPrint('Error parsing task: $e');
        }
      }
      
      // Process the queue efficiently
      _processNextBatch();
    } catch (e) {
      debugPrint('Error resuming pending downloads: $e');
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
      // Non-critical error, just log
      debugPrint('Error removing active task: $e');
    }
  }
  
  // Save the download queue to persistent storage efficiently
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
  
  // Background service entry point for Android - optimized
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
    
    // Check downloads less frequently to save battery
    Timer.periodic(Duration(minutes: 30), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          final prefs = await SharedPreferences.getInstance();
          final pendingDownloadsJson = prefs.getStringList(_keyPendingDownloads) ?? [];
          final activeDownloadsJson = prefs.getStringList(_keyActiveDownloads) ?? [];
          
          // Only update notification if there are active downloads
          if (activeDownloadsJson.isNotEmpty || pendingDownloadsJson.isNotEmpty) {
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
        
        // Only update notification for significant progress changes (saves CPU)
        if (service is AndroidServiceInstance) {
          if (status == DownloadTaskStatus.running && progress % 10 == 0) {
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
              timeout: DOWNLOAD_TIMEOUT,
              headers: {'User-Agent': 'Mozilla/5.0'}, // Prevent throttling
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
  
  // Process multiple downloads concurrently
  static Future<void> _processNextBatch() async {
    if (_downloadQueue.isEmpty || _activeDownloads >= MAX_CONCURRENT_DOWNLOADS) {
      await _persistQueue(); // Save updated queue
      
      // If queue is empty and no active downloads, check if we should stop the background service
      if (_downloadQueue.isEmpty && _activeDownloads == 0) {
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
    
    // Start multiple downloads concurrently up to the maximum limit
    final downloadsToStart = MAX_CONCURRENT_DOWNLOADS - _activeDownloads;
    final List<Future<void>> downloadFutures = [];
    
    for (int i = 0; i < downloadsToStart; i++) {
      if (_downloadQueue.isEmpty) break;
      
      final task = _downloadQueue.removeFirst();
      _activeDownloads++;
      
      if (task.isFolder) {
        downloadFutures.add(_downloadFolderInternal(
          task.id,
          task.name,
          task.basePath,
          task.relativePath,
          task.onProgress,
        ));
      } else {
        downloadFutures.add(_downloadFileInternal(
          task.id,
          task.name,
          task.mimeType!,
          task.basePath,
          task.relativePath,
          task.onProgress,
        ));
      }
    }
    
    await _persistQueue(); // Save updated queue
    
    // Process downloads in parallel
    await Future.wait(downloadFutures).then((_) {
      // Check for more downloads after batch completes
      _processNextBatch();
    });
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
      
      // Check if file already exists - return immediately if it does
      if (await File(filePath).exists()) {
        debugPrint('File already exists: $filePath');
        onProgress?.call(1.0); // Signal complete
        return filePath;
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
      if (_activeDownloads < MAX_CONCURRENT_DOWNLOADS) {
        _processNextBatch();
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
  
  // Internal method to actually download a file - optimized
  static Future<String?> _downloadFileInternal(
    String fileId,
    String fileName,
    String mimeType,
    String basePath,
    String relativePath,
    Function(double)? onProgress,
  ) async {
    try {
      // Check if task is already in progress
      if (_tasksInProgress.contains(fileId)) {
        // Wait for existing download to complete
        final completer = _downloadCompleters[fileId];
        if (completer != null) {
          return await completer.future;
        }
      }
      
      // Add task to in-progress set
      _tasksInProgress.add(fileId);
      
      // Create completer for this download
      final downloadCompleter = Completer<String?>();
      _downloadCompleters[fileId] = downloadCompleter;
      
      // Determine the full path with proper folder structure
      final downloadDir = path.join(basePath, relativePath);
      
      // Create directory if it doesn't exist
      await Directory(downloadDir).create(recursive: true);
      
      // Determine the file path
      final filePath = path.join(downloadDir, fileName);
      
      // Check if file already exists
      if (await File(filePath).exists()) {
        _tasksInProgress.remove(fileId);
        _downloadCompleters.remove(fileId);
        onProgress?.call(1.0); // Signal complete
        return filePath;
      }
      
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
        _tasksInProgress.remove(fileId);
        
        // Stream encryption for better performance
        _encryptDownloadedFile(fileId);
        
        // Complete the future
        downloadCompleter.complete(downloadResult);
        _downloadCompleters.remove(fileId);
              
        return downloadResult;
      } else {
        // Fallback to direct download URL method
        final downloadUrl = 'https://drive.google.com/uc?export=download&id=$fileId';
        
        // Apply retry strategy for network issues
        int retryCount = 0;
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
        
        while (retryCount < RETRY_COUNT && taskId == null) {
          try {
            // Start the download task with optimized settings
            taskId = await FlutterDownloader.enqueue(
              url: downloadUrl,
              savedDir: downloadDir,
              fileName: fileName,
              showNotification: true,
              openFileFromNotification: false,
              saveInPublicStorage: false,
              headers: {
                'User-Agent': 'Mozilla/5.0',
                'Connection': 'keep-alive'
              },
              timeout: DOWNLOAD_TIMEOUT,
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
            if (retryCount >= RETRY_COUNT) {
              _tasksInProgress.remove(fileId);
              downloadCompleter.complete(null);
              _downloadCompleters.remove(fileId);
              rethrow;
            }
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
                _tasksInProgress.remove(fileId);
                if (!downloadCompleter.isCompleted) {
                  downloadCompleter.complete(null);
                  _downloadCompleters.remove(fileId);
                }
              }
            });
          }
        } else {
          _tasksInProgress.remove(fileId);
          downloadCompleter.complete(null);
          _downloadCompleters.remove(fileId);
        }
        
        return filePath;
      }
    } catch (e) {
      debugPrint('Error downloading file: $e');
      _tasksInProgress.remove(fileId);
      onProgress?.call(-1.0); // Signal error
      return null;
    }
  }
  
  // Add a folder download task to the queue
  static Future<String?> downloadFolder(
    BuildContext context,
    String folderId,
    String folderName, {
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
      final folderPath = path.join(downloadDir, folderName);
      
      // Create folder directory
      await Directory(folderPath).create(recursive: true);
      
      // Calculate relative path
      final relativePath = parentFolderPath != null ? 
        parentFolderPath.replaceFirst(basePath + path.separator, '') : '';
      
      // Register the progress callback with the UI component
      if (onProgress != null) {
        registerUICallback(context, onProgress);
      }
      
      // Create folder task
      final folderTask = _DownloadTask(
        id: folderId,
        name: folderName,
        basePath: basePath,
        relativePath: relativePath,
        isFolder: true,
        onProgress: onProgress,
      );
      
      // Add to download queue
      _downloadQueue.add(folderTask);
      await _persistQueue(); // Persist queue immediately
      
      // Start processing queue if not already running
      if (_activeDownloads < MAX_CONCURRENT_DOWNLOADS) {
        _processNextBatch();
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
  
  // Internal method to actually download a folder - optimized for concurrency
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
      final folder = Directory(folderPath);
      await folder.create(recursive: true);
      
      // Check if we should use Google Drive API
      if (_driveService != null && await _driveService!.isSignedIn()) {
        // Get folder contents in parallel with directory creation
        final folderContentsFuture = _driveService!.listFolderContents(folderId);
        
        // Check for cached folder structure
        final prefs = await SharedPreferences.getInstance();
        final cachedFolderKey = 'folder_structure_$folderId';
        List<drive.File>? folderContents;
        
        // Try to get from cache first for faster startup
        final cachedData = prefs.getString(cachedFolderKey);
        if (cachedData != null) {
          try {
            // Use cached data while waiting for fresh data
            // Implementation details omitted - you would need to define a serialization format
            debugPrint('Using cached folder structure while loading');
            // Process initial items from cache
          } catch (e) {
            debugPrint('Error parsing cached folder structure: $e');
          }
        }
        
        // Get actual folder contents (or wait for future if already started)
        folderContents = await folderContentsFuture;
        
        // Cache folder structure for next time
        if (folderContents.isNotEmpty) {
          // Cache the folder structure (implementation details omitted)
          // This would serialize the basic structure to JSON
        }
        
        // Handle empty folders
        if (folderContents.isEmpty) {
          onProgress?.call(1.0); // Empty folder - complete
          return folderPath;
        }
        
        // Prepare for batch processing
        double totalItems = folderContents.length.toDouble();
        double itemsProcessed = 0;
        int completedItems = 0;
        final List<String> errors = [];

        // Group by type for batch processing
        final files = <drive.File>[];
        final folders = <drive.File>[];
        
        // Split into files and folders for optimized processing
        for (final item in folderContents) {
          if (item.mimeType == 'application/vnd.google-apps.folder') {
            folders.add(item);
          } else {
            files.add(item);
          }
        }
        
        // Create a pool of workers for parallel processing
        // final completers = <Completer<void>>[];
        final maxParallelOps = MAX_CONCURRENT_DOWNLOADS;
        int activeOps = 0;
        final processLock = Mutex(); // You'd need to implement or import a Mutex class
        
        void updateProgress(double subProgress) {
          if (onProgress != null) {
            if (subProgress < 0) {
              // Error in subitem - count as processed but record error
              errors.add('Item failed');
            } else {
              // Calculate combined progress
              double combinedProgress = (itemsProcessed + subProgress) / totalItems;
              onProgress(combinedProgress);
            }
          }
        }

        // Function to process the next item
        Future<void> processNext() async {
          await processLock.acquire();
          try {
            // Process files first for quick wins
            if (files.isNotEmpty) {
              final item = files.removeAt(0);
              processLock.release();
              await _processItem(item, currentRelativePath, basePath, updateProgress);
              itemsProcessed++;
              completedItems++;
              if (onProgress != null) {
                onProgress(itemsProcessed / totalItems);
              }
              
              activeOps--;
              if ((files.isNotEmpty || folders.isNotEmpty) && activeOps < maxParallelOps) {
                // Process next item immediately
                activeOps++;
                processNext();
              }
            } 
            // Then process folders
            else if (folders.isNotEmpty) {
              final folder = folders.removeAt(0);
              processLock.release();
              await _processItem(folder, currentRelativePath, basePath, updateProgress);
              itemsProcessed++;
              completedItems++;
              if (onProgress != null) {
                onProgress(itemsProcessed / totalItems);
              }
              
              activeOps--;
              if ((files.isNotEmpty || folders.isNotEmpty) && activeOps < maxParallelOps) {
                // Process next item immediately
                activeOps++;
                processNext();
              }
            } else {
              processLock.release();
            }
          } catch (e) {
            processLock.release();
            activeOps--;
          }
        }
        
        
        
        // Initial batch of workers
        final initialCount = math.min(maxParallelOps, folderContents.length);
        for (int i = 0; i < initialCount; i++) {
          activeOps++;
          processNext();
        }
        
        // Wait for all items to complete processing
        while (completedItems < folderContents.length) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        
        // Log errors if any
        if (errors.isNotEmpty) {
          debugPrint('Errors downloading ${errors.length} items in folder $folderName');
        }
        
        // Complete download
        onProgress?.call(1.0);
        return folderPath;
      } else {
        // Fallback to basic implementation if not authenticated
        onProgress?.call(-1.0); // Signal error
        throw Exception('Not authenticated. Cannot download folder without authentication.');
      }
    } catch (e) {
      debugPrint('Error downloading folder: $e');
      onProgress?.call(-1.0); // Signal error
      return null;
    }
  }

  // Process an individual item (file or folder)
  static Future<void> _processItem(
    drive.File item,
    String currentRelativePath,
    String basePath,
    Function(double) updateProgress
  ) async {
    final itemId = item.id;
    final itemName = item.name;
    final itemMimeType = item.mimeType;
    
    if (itemId == null || itemName == null || itemMimeType == null) {
      updateProgress(-1.0);
      return;
    }
    
    try {
      if (itemMimeType == 'application/vnd.google-apps.folder') {
        // Process subfolder recursively
        await _downloadFolderInternal(
          itemId,
          itemName,
          basePath,
          currentRelativePath,
          updateProgress
        );
      } else {
        // Download file with proper path
        await _downloadFileInternal(
          itemId,
          itemName,
          itemMimeType,
          basePath,
          currentRelativePath,
          updateProgress
        );
      }
    } catch (e) {
      debugPrint('Error processing item $itemName: $e');
      updateProgress(-1.0);
    }
  }
  
  // Process queue items
  // static Future<void> _processNextInQueue() async {
  //   if (_isProcessingQueue) return;
    
  //   _isProcessingQueue = true;
  //   try {
  //     while (_downloadQueue.isNotEmpty && _activeDownloads < MAX_CONCURRENT_DOWNLOADS) {
  //       await _processNextBatch();
  //     }
  //   } finally {
  //     _isProcessingQueue = false;
  //   }
  // }
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
          
          await PDFEncryptionUtils.instance.encryptFile(downloadedFilePath, encryptedPath);
          
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
        return await PDFEncryptionUtils.instance.decryptFile(filePath);
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



// / lass to represent a download task in the queue
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

class Mutex {
    Completer<void>? _completer;

    bool get isLocked => _completer != null;

    Future<void> acquire() async {
      while (isLocked) {
        await _completer!.future;
      }
      _completer = Completer<void>();
    }

    void release() {
      if (isLocked) {
        final completer = _completer!;
        _completer = null;
        completer.complete();
      }
    }
}

  // Clean up implementation
  Future<void> cleanupOldTemporaryFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      
      final DateTime now = DateTime.now();
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          final fileAge = now.difference(stat.modified);
          
          // Delete temp files older than 1 day
          if (fileAge.inDays > 1) {
            try {
              await file.delete();
            } catch (e) {
              // Ignore errors deleting temp files
            }
          }
        }
      }
    } catch (e) {
      // Non-critical operation, just log
      debugPrint('Error cleaning temp files: $e');
    }
  }

  // Download progress tracking class
   class _DownloadTaskStatus {
    final DownloadTaskStatus status;
    final int progress;
    
    _DownloadTaskStatus({required this.status, required this.progress});
  }


// Helper class for Download Progress
class DownloadProgress {
  final String id;
  final DownloadTaskStatus status;
  final int progress;
  
  DownloadProgress(this.id, this.status, this.progress);
}