import 'dart:io';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:futapedia/pdfs/lecture%20notes/google_drive_pdf.dart';
import 'package:futapedia/study_material/pdf/pdf_drive.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class NotificationDownloadManager {
  static final NotificationDownloadManager _instance = NotificationDownloadManager._internal();
  factory NotificationDownloadManager() => _instance;
  
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  final Map<String, bool> _activeDownloads = {}; // Track active downloads
  
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
    // } else if (actionId == 'pause') {
    //   pauseDownload(fileId);
    // } else if (actionId == 'resume') {
    //   resumeDownload(fileId);
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
        if (!isComplete && !isError)
          const AndroidNotificationAction(
            'pause_resume',
            'Pause', // This will toggle between Pause/Resume
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
  
  // Handle file download with notification updates
  Future<String> downloadFileWithNotification(
    drive.File driveFile,
    Directory downloadDir, 
    GoogleDriveServicePDF driveService,
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
      final filePath = await driveService.downloadFileWithProgress(
        driveFile,
        downloadPath, // Pass path as String
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
        },
      );
      
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
      
      rethrow;
    }
  }
  
  Future<void> downloadFolderWithNotification(
    drive.File folderFile,
    Directory downloadDir,
    GoogleDriveServicePDF driveService,
  ) async {
    final String folderId = folderFile.id!;
    final String folderName = folderFile.name!;
    
    // Convert Directory to String path
    final String downloadPath = downloadDir.path;
    
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
      await driveService.downloadFolderWithProgress(
        folderFile,
        downloadPath, // Pass path as String
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
        },
      );
      
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
      
      rethrow;
    }
  }
  
  void cancelDownload(String downloadId) {
    _activeDownloads[downloadId] = false;
    _notificationsPlugin.cancel(downloadId.hashCode);
  }
  
  // void pauseDownload(String downloadId) {
  //   // Implement pause functionality
  //   // This would require the download implementation to support pausing
  // }
  
  // void resumeDownload(String downloadId) {
  //   // Implement resume functionality
  //   // This would require the download implementation to support resuming
  // }
  
  void dispose() {
    // Cancel all active downloads
    for (final id in _activeDownloads.keys) {
      _activeDownloads[id] = false;
      _notificationsPlugin.cancel(id.hashCode);
    }
    _activeDownloads.clear();
  }
}