import 'dart:io';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:futapedia/study_material/past%20questions/question_drive.dart';
import 'package:futapedia/study_material/pdf/pdf_drive.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class NotificationDownloadManager {
  static final NotificationDownloadManager _instance = NotificationDownloadManager._internal();
  factory NotificationDownloadManager() => _instance;
  
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  final Map<String, bool> _activeDownloads = {}; // Track active downloads
  static final Map<dynamic, Function?> _uiCallbacks = {};
  
  NotificationDownloadManager._internal();
  
  Future<void> initialize() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onSelectNotification,
    );
  }
  
  void _onSelectNotification(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    
    final String actionId = payload.split(':').first;
    final String fileId = payload.split(':').last;
    
    if (actionId == 'cancel') {
      cancelDownload(fileId);
    }
  }
  
  Future<void> showDownloadNotification({
    required String id,
    required String title,
    required int progress,
    required bool isComplete,
    required bool isError,
  }) async {
    // Define notification channels (Android only)
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Shows download progress',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: !isComplete && !isError,
      maxProgress: 100,
      progress: progress,
      ongoing: !isComplete && !isError,
      actions: [
        if (!isComplete && !isError)
          const AndroidNotificationAction(
            'cancel',
            'Cancel',
            showsUserInterface: false,
          ),
      ],
    );
    
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );
    
    String notificationTitle = isError 
        ? 'Download Failed: $title' 
        : isComplete 
            ? 'Download Complete: $title' 
            : 'Downloading: $title';
    
    String notificationBody = isError 
        ? 'An error occurred during download.' 
        : isComplete 
            ? 'Tap to open file' 
            : 'Progress: $progress%';
    
    await _notificationsPlugin.show(
      id.hashCode, // Use hash of ID as notification ID
      notificationTitle,
      notificationBody,
      notificationDetails,
      payload: 'download:$id',
    );
    
    // Auto-remove completed notifications after a delay
    if (isComplete || isError) {
      await Future.delayed(const Duration(seconds: 5));
      await _notificationsPlugin.cancel(id.hashCode);
    }
  }
  
  // Updated method to support your file browser's needs
  Future<String?> downloadFileWithNotification(
    drive.File driveFile,
    Directory downloadDir, 
    dynamic driveService, // Generic type to support different services
    {
      String relativePath = '', // Added parameter
      Function(double)? onProgress, // Added parameter
    }
  ) async {
    final String fileId = driveFile.id!;
    final String fileName = driveFile.name!;
    
    // Mark download as active
    _activeDownloads[fileId] = true;
    
    // Convert Directory to String path
    final String downloadPath = downloadDir.path;
    
    // Show initial notification
    await showDownloadNotification(
      id: fileId,
      title: fileName,
      progress: 0,
      isComplete: false,
      isError: false,
    );
    
    try {
      // Check which type of drive service is being used
      String filePath;
      
      // Create folder structure if relativePath is provided
      final String targetPath = relativePath.isNotEmpty 
          ? '$downloadPath/$relativePath' 
          : downloadPath;
      
      // Create directory if it doesn't exist
      final targetDir = Directory(targetPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      
      // Handle different service types
      if (driveService is GoogleDriveServicePDF) {
        filePath = await driveService.downloadFileWithProgress(
          driveFile,
          targetPath,
          (progress) async {
            // Check if download is still active
            if (_activeDownloads[fileId] != true) {
              throw Exception('Download canceled');
            }
            
            // Update notification with progress
            await showDownloadNotification(
              id: fileId,
              title: fileName,
              progress: (progress * 100).toInt(),
              isComplete: false,
              isError: false,
            );
            
            // Call the onProgress callback if provided
            onProgress?.call(progress);
          },
        );
      } else if (driveService is GoogleDriveServicePQ) {
        filePath = await driveService.downloadFileWithProgress(
          driveFile,
          targetPath,
          (progress) async {
            // Check if download is still active
            if (_activeDownloads[fileId] != true) {
              throw Exception('Download canceled');
            }
            
            // Update notification with progress
            await showDownloadNotification(
              id: fileId,
              title: fileName,
              progress: (progress * 100).toInt(),
              isComplete: false,
              isError: false,
            );
            
            // Call the onProgress callback if provided
            onProgress?.call(progress);
          },
        );
      } else {
        // Generic Google Drive service handling
        // This assumes you have a method with this signature in your service
        filePath = await driveService.downloadFileWithProgress(
          driveFile,
          targetPath,
          (progress) async {
            // Check if download is still active
            if (_activeDownloads[fileId] != true) {
              throw Exception('Download canceled');
            }
            
            // Update notification with progress
            await showDownloadNotification(
              id: fileId,
              title: fileName,
              progress: (progress * 100).toInt(),
              isComplete: false,
              isError: false,
            );
            
            // Call the onProgress callback if provided
            onProgress?.call(progress);
          },
        );
      }
      
      // Show completion notification
      await showDownloadNotification(
        id: fileId,
        title: fileName,
        progress: 100,
        isComplete: true,
        isError: false,
      );
      
      // Remove from active downloads
      _activeDownloads.remove(fileId);
      
      return filePath;
    } catch (e) {
      // Show error notification
      await showDownloadNotification(
        id: fileId,
        title: fileName,
        progress: 0,
        isComplete: false,
        isError: true,
      );
      
      // Remove from active downloads
      _activeDownloads.remove(fileId);
      
      return null;
    }
  }

  Future<bool> downloadFolderWithNotification(
    drive.File folderFile,
    Directory downloadDir,
    dynamic driveService,
    {
      String relativePath = '', // Added parameter
      Function(double)? onProgress, // Added parameter
    }
  ) async {
    final String folderId = folderFile.id!;
    final String folderName = folderFile.name!;
    
    // Convert Directory to String path
    final String downloadPath = downloadDir.path;
    
    // Create folder structure if relativePath is provided
    final String targetPath = relativePath.isNotEmpty 
        ? '$downloadPath/$relativePath' 
        : downloadPath;
    
    // Create directory if it doesn't exist
    final targetDir = Directory(targetPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    
    // Mark download as active
    _activeDownloads[folderId] = true;
    
    // Show initial notification
    await showDownloadNotification(
      id: folderId,
      title: 'Folder: $folderName',
      progress: 0,
      isComplete: false,
      isError: false,
    );
    
    try {
      // Handle different service types
      if (driveService is GoogleDriveServicePDF) {
        await driveService.downloadFolderWithProgress(
          folderFile,
          targetPath,
          (progress) async {
            // Check if download is still active
            if (_activeDownloads[folderId] != true) {
              throw Exception('Download canceled');
            }
            
            // Update notification with progress
            await showDownloadNotification(
              id: folderId,
              title: 'Folder: $folderName',
              progress: (progress * 100).toInt(),
              isComplete: false,
              isError: false,
            );
            
            // Call the onProgress callback if provided
            onProgress?.call(progress);
          },
        );
      } else if (driveService is GoogleDriveServicePQ) {
        await driveService.downloadFolderWithProgress(
          folderFile,
          targetPath,
          (progress) async {
            // Check if download is still active
            if (_activeDownloads[folderId] != true) {
              throw Exception('Download canceled');
            }
            
            // Update notification with progress
            await showDownloadNotification(
              id: folderId,
              title: 'Folder: $folderName',
              progress: (progress * 100).toInt(),
              isComplete: false,
              isError: false,
            );
            
            // Call the onProgress callback if provided
            onProgress?.call(progress);
          },
        );
      } else {
        // Generic Google Drive service handling
        await driveService.downloadFolderWithProgress(
          folderFile,
          targetPath,
          (progress) async {
            // Check if download is still active
            if (_activeDownloads[folderId] != true) {
              throw Exception('Download canceled');
            }
            
            // Update notification with progress
            await showDownloadNotification(
              id: folderId,
              title: 'Folder: $folderName',
              progress: (progress * 100).toInt(),
              isComplete: false,
              isError: false,
            );
            
            // Call the onProgress callback if provided
            onProgress?.call(progress);
          },
        );
      }
      
      // Show completion notification
      await showDownloadNotification(
        id: folderId,
        title: 'Folder: $folderName',
        progress: 100,
        isComplete: true,
        isError: false,
      );
      
      // Remove from active downloads
      _activeDownloads.remove(folderId);
      
      return true;
    } catch (e) {
      // Show error notification
      await showDownloadNotification(
        id: folderId,
        title: 'Folder: $folderName',
        progress: 0,
        isComplete: false,
        isError: true,
      );
      
      // Remove from active downloads
      _activeDownloads.remove(folderId);
      
      return false;
    }
  }
  
  void cancelDownload(String downloadId) {
    _activeDownloads[downloadId] = false;
    _notificationsPlugin.cancel(downloadId.hashCode);
  }
  
  void dispose() {
    // Cancel all active downloads
    for (final id in _activeDownloads.keys) {
      _activeDownloads[id] = false;
      _notificationsPlugin.cancel(id.hashCode);
    }
    _activeDownloads.clear();
  }
  
  static void detachFromUI(dynamic uiComponent) {
    if (_uiCallbacks.containsKey(uiComponent)) {
      _uiCallbacks.remove(uiComponent);
    }
  }
}