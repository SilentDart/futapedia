import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PermissionManager {
  // Flag to track if we're using external storage or app-specific storage
  static bool _useExternalStorage = true;
  
  // Getter for the storage flag
  static bool get useExternalStorage => _useExternalStorage;
  
  // Add a lock to prevent concurrent permission requests
  static bool _isRequestingPermission = false;
  static Future<void>? _ongoingRequest;
  
  // Request storage permission only
  static Future<bool> requestStoragePermission(BuildContext context) async {
    // If there's already a request in progress, wait for it to complete
    if (_isRequestingPermission) {
      if (_ongoingRequest != null) {
        try {
          // Wait for the ongoing request to complete
          await _ongoingRequest;
          // Return the result of whether external storage is usable
          return _useExternalStorage || true;
        } catch (e) {
          // If the ongoing request failed, we'll try again
          return _requestStoragePermissionInternal(context);
        }
      }
      return false;
    }
    
    return _requestStoragePermissionInternal(context);
  }
  
  // Internal implementation that does the actual permission request
  static Future<bool> _requestStoragePermissionInternal(BuildContext context) async {
    if (_isRequestingPermission) {
      return false;
    }
    
    _isRequestingPermission = true;
    
    // Create a completer for the ongoing request
    final completer = Completer<bool>();
    _ongoingRequest = completer.future;
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        
        // For Android 11+ (API 30+)
        if (androidInfo.version.sdkInt >= 30) {
          // First try MANAGE_EXTERNAL_STORAGE for full access
          final status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            // Show explanation if denied
            if (!context.mounted) {
              _isRequestingPermission = false;
              completer.complete(false);
              return false;
            }
            
            final shouldContinue = await _showManageStorageExplanationDialog(context);
            if (shouldContinue) {
              // Try regular storage as fallback
              final storageStatus = await Permission.storage.request();
              if (!storageStatus.isGranted) {
                _useExternalStorage = false;
                _isRequestingPermission = false;
                completer.complete(true); // Continue with app storage
                return true;
              }
            } else {
              _useExternalStorage = false;
              _isRequestingPermission = false;
              completer.complete(false); // User canceled
              return false;
            }
          }
          _isRequestingPermission = false;
          completer.complete(true);
          return true;
        } 
        // For Android 10 and below (API 29-)
        else {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            // Show explanation dialog
            if (!context.mounted) {
              _isRequestingPermission = false;
              completer.complete(false);
              return false;
            }
            
            final shouldTryAgain = await _showStorageExplanationDialog(context);
            if (shouldTryAgain) {
              // Try again
              final retriedStatus = await Permission.storage.request();
              if (!retriedStatus.isGranted) {
                _useExternalStorage = false;
                _isRequestingPermission = false;
                completer.complete(true); // Continue with app storage
                return true;
              }
            } else {
              _useExternalStorage = false;
              _isRequestingPermission = false;
              completer.complete(false); // User canceled
              return false;
            }
          }
          _isRequestingPermission = false;
          completer.complete(true);
          return true;
        }
      }
      
      _isRequestingPermission = false;
      completer.complete(true); // For non-Android platforms
      return true;
    } catch (e) {
      _isRequestingPermission = false;
      completer.completeError(e);
      return false;
    }
  }
  
  // Get the appropriate path based on permissions
  static Future<String> getAppropriateDownloadPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      // Get the current stack trace to identify caller
      String caller = StackTrace.current.toString();
      
      // Choose path based on the calling class
      String path;
      if (caller.contains('GoogleDriveServicePQ')) {
        path = '${directory.path}/PastQuestion';
      } else {
        path = '${directory.path}/FUTApedia';
      }
      
      await Directory(path).create(recursive: true);
      return path;
    } catch (err) {
      // Log the error (use proper logging in production)
      // print('Error creating download path: $err');
      throw Exception('Failed to create download directory');
    }
  }
  
  // Dialog for manage storage explanation
  static Future<bool> _showManageStorageExplanationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Storage Access Required'),
        content: const Text(
          'FUTApedia needs permission to manage storage to save files in the exact '
          'location requested. Without this permission, files will be saved in the '
          'app\'s private storage area instead.\n\n'
          'Would you like to try granting basic storage permission instead?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('CONTINUE'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              openAppSettings();
            },
            child: const Text('OPEN SETTINGS'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  // Dialog for basic storage explanation
  static Future<bool> _showStorageExplanationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
          'FUTApedia needs storage permission to download and save files to your device. '
          'Without this permission, you can still use the app, but files will be saved '
          'only in the app\'s private storage area.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('TRY AGAIN'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              openAppSettings();
            },
            child: const Text('OPEN SETTINGS'),
          ),
        ],
      ),
    ) ?? false;
  }
}