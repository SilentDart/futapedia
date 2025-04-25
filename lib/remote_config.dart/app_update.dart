import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// Constants for remote config
const String KEY_UPDATED_VERSION = 'updated_app_version';
const String KEY_UPDATED_MESSAGE = 'updated_message';
const int DEFAULT_GRACE_PERIOD = 14; // 14 days grace period as default

class AppUpdateChecker {
  final FirebaseRemoteConfig _remoteConfig;
  static const String _defaultVersion = '1.0.0';
  static const String _defaultMessage = 'Please update the app to have access to new features.';

  // Private constructor
  AppUpdateChecker._({required FirebaseRemoteConfig remoteConfig}) 
      : _remoteConfig = remoteConfig;

  // Singleton instance
  static AppUpdateChecker? _instance;

  // Factory method to get the singleton instance
  static Future<AppUpdateChecker> getInstance() async {
    if (_instance == null) {
      try {
        // debugPrint('🔄 Initializing Firebase Remote Config...');
        
        // Initialize Firebase Remote Config
        final remoteConfig = FirebaseRemoteConfig.instance;
        
        // Log the current state of Remote Config
        // debugPrint('📊 Remote Config initial state: ${remoteConfig.toString()}');
        
        // debugPrint('⚙️ Setting Remote Config settings...');
        await remoteConfig.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 10),
        ));
        // debugPrint('✅ Remote Config settings applied successfully');

        // Set default values
        // debugPrint('📝 Setting default values for Remote Config...');
        await remoteConfig.setDefaults({
          KEY_UPDATED_VERSION: _defaultVersion,
          KEY_UPDATED_MESSAGE: _defaultMessage,
        });
        // debugPrint('✅ Default values set successfully');

        // Fetch the latest values
        // debugPrint('🔄 Fetching and activating Remote Config values...');
        await remoteConfig.fetchAndActivate();
        // debugPrint('📥 Fetch and activate result: ${fetchSuccess ? "New values applied" : "No new values found"}');
        
        // Log the values we got from Remote Config
        // debugPrint('📋 Remote Config values retrieved:');
        // debugPrint('   - $KEY_UPDATED_VERSION: ${remoteConfig.getString(KEY_UPDATED_VERSION)}');
        // debugPrint('   - $KEY_UPDATED_MESSAGE: ${remoteConfig.getString(KEY_UPDATED_MESSAGE)}');

        _instance = AppUpdateChecker._(remoteConfig: remoteConfig);
        // debugPrint('✅ AppUpdateChecker instance created successfully');
      } catch (e) {
        // debugPrint('❌ Error initializing Firebase Remote Config: $e');
        // debugPrint('📚 Stack trace: $stackTrace');
        
        // // Create instance with default Remote Config anyway to avoid crashes
        // debugPrint('⚠️ Creating AppUpdateChecker with default Remote Config instance');
        _instance = AppUpdateChecker._(remoteConfig: FirebaseRemoteConfig.instance);
      }
    }

    return _instance!;
  }

  // Check if update is required
  Future<UpdateStatus> checkForUpdate() async {
    try {
      debugPrint('🔄 Starting update check process...');
      
      // // Get current app version
      // debugPrint('📱 Retrieving current app version...');
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      // debugPrint('📦 Current app version: $currentVersion');

      // Get required version from remote config
      // debugPrint('🔍 Reading values from Remote Config...');
      final updatedVersion = _remoteConfig.getString(KEY_UPDATED_VERSION);
      final updatedMessage = _remoteConfig.getString(KEY_UPDATED_MESSAGE);
      
      debugPrint('📋 Remote Config values:');
      debugPrint('   - Updated version: $updatedVersion');
      debugPrint('   - Update message: $updatedMessage');
      debugPrint('   - Grace period: $DEFAULT_GRACE_PERIOD days (fixed)');

      // Compare versions
      final bool isNewer = _isVersionNewer(updatedVersion, currentVersion);
      // debugPrint('🔄 Version comparison: ${isNewer ? "Update required" : "App is up to date"}');
      
      if (isNewer) {
        // We're always using a soft update with the default grace period
        // debugPrint('ℹ️ Update is optional for now with fixed grace period');
        return UpdateStatus(
          updateAvailable: true, 
          forceUpdate: false,
          currentVersion: currentVersion,
          requiredVersion: updatedVersion,
          message: updatedMessage,
          daysRemaining: DEFAULT_GRACE_PERIOD,
        );
      }

      // No update required
      // debugPrint('✅ No update required');
      return UpdateStatus(updateAvailable: false);
    } catch (e) {
      // In case of error, don't force update
      // debugPrint('❌ Error checking for app update: $e');
      // debugPrint('📚 Stack trace: $stackTrace');
      return UpdateStatus(updateAvailable: false);
    }
  }

  // Utility method to compare version strings
  bool _isVersionNewer(String requiredVersion, String currentVersion) {
    // debugPrint('🔄 Comparing versions: required=$requiredVersion vs current=$currentVersion');
    
    List<int> required = _parseVersion(requiredVersion);
    List<int> current = _parseVersion(currentVersion);
    
    // debugPrint('📊 Parsed versions: required=$required, current=$current');

    for (int i = 0; i < 3; i++) {
      if (required[i] > current[i]) {
        // debugPrint('📈 Required version is newer at position $i: ${required[i]} > ${current[i]}');
        return true;
      }
      if (required[i] < current[i]) {
        // debugPrint('📉 Current version is newer at position $i: ${required[i]} < ${current[i]}');
        return false;
      }
    }
    debugPrint("$required");
    debugPrint('🔄 Versions are equal');
    return false; // Versions are equal
  }

  // Parse a version string into its components
  List<int> _parseVersion(String version) {
    List<String> parts = version.split('.');
    List<int> parsed = [0, 0, 0]; // Default to [0,0,0]
    
    for (int i = 0; i < parts.length && i < 3; i++) {
      parsed[i] = int.tryParse(parts[i]) ?? 0;
    }
    
    return parsed;
  }

  // Method to check Remote Config connection and values
  Future<Map<String, dynamic>> checkRemoteConfigStatus() async {
    try {
      debugPrint('🔄 Performing Remote Config diagnostic check...');
      
      // Try to fetch latest values
      // debugPrint('🔄 Attempting to fetch new values...');
      bool fetchResult = await _remoteConfig.fetchAndActivate();
      // debugPrint('📥 Fetch result: $fetchResult');
      
      // Get all parameter keys
      // debugPrint('🔑 Getting all Remote Config keys...');
      final allKeys = _remoteConfig.getAll().keys;
      // debugPrint('📋 Found ${allKeys.length} keys: $allKeys');
      
      // Get all values
      final Map<String, dynamic> values = {};
      for (final key in allKeys) {
        final value = _remoteConfig.getValue(key);
        values[key] = value.asString();
        debugPrint('🔑 $key: ${value.asString()}');
      }
      
      // Get last fetch status
      final lastFetchStatus = _remoteConfig.lastFetchStatus;
      final lastFetchTime = _remoteConfig.lastFetchTime;
      // debugPrint('📊 Last fetch status: $lastFetchStatus');
      // debugPrint('⏱️ Last fetch time: $lastFetchTime');
      
      return {
        'fetchSuccessful': fetchResult,
        'lastFetchStatus': lastFetchStatus.toString(),
        'lastFetchTime': lastFetchTime.toString(),
        'configValues': values,
      };
    } catch (e, stackTrace) {
      // debugPrint('❌ Error checking Remote Config status: $e');
      // debugPrint('📚 Stack trace: $stackTrace');
      return {
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      };
    }
  }
}

// Class to represent update status
class UpdateStatus {
  final bool updateAvailable;
  final bool forceUpdate;
  final String? currentVersion;
  final String? requiredVersion;
  final String? message;
  final int? daysRemaining;

  UpdateStatus({
    required this.updateAvailable,
    this.forceUpdate = false,
    this.currentVersion,
    this.requiredVersion,
    this.message,
    this.daysRemaining,
  });

  @override
  String toString() {
    return 'UpdateStatus{updateAvailable: $updateAvailable, forceUpdate: $forceUpdate, '
           'currentVersion: $currentVersion, requiredVersion: $requiredVersion, '
           'message: $message, daysRemaining: $daysRemaining}';
  }
}

// Dialog to show when update is required
class UpdateDialog extends StatelessWidget {
  final UpdateStatus updateStatus;
  final VoidCallback? onLaterPressed;

  const UpdateDialog({
    Key? key,
    required this.updateStatus,
    this.onLaterPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String title = updateStatus.forceUpdate 
        ? 'Update Required' 
        : 'Update Available';
    
    String message = updateStatus.message ?? 'Please update the app to have access to new features.';
    
    if (!updateStatus.forceUpdate && updateStatus.daysRemaining != null) {
      message += '\n\n ${updateStatus.daysRemaining} days till mandatory update.';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30.r),
      ),
      titlePadding: EdgeInsets.fromLTRB(40.w, 20.h, 20.w, 10.h),
      contentPadding: EdgeInsets.fromLTRB(40.w, 0, 20.w, 10.h),
      actionsPadding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 10.h),
      title: Row(
        children: [
          Icon(
            Icons.school,
            color: Theme.of(context).primaryColor,
            size: 28.sp,
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 16.sp),
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 30.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    "Updating gives you access to new features and improvements!",
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 15.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (!updateStatus.forceUpdate)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onLaterPressed != null) onLaterPressed!();
            },
            child: Text(
              'Remind Me Later',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12.sp,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              // Open Play Store
              final url = Uri.parse('https://play.google.com/store/apps/details?id=${await _getPackageName()}');
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
            icon: Icon(Icons.download, size: 18.sp,color: Colors.white),
            label: Text('Update Now', style: TextStyle(fontSize: 12.sp,)),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Theme.of(context).primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4),
              minimumSize: Size(0, 36.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
          ),
      ],
    );
  }

  static Future<String> _getPackageName() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.packageName;
  }
}

// Example usage in your main.dart or app startup
Future<void> checkAppUpdate(BuildContext context) async {
  try {
    debugPrint('🔄 Starting app update check process...');
    
    final updateChecker = await AppUpdateChecker.getInstance();
    debugPrint('✅ Got AppUpdateChecker instance');
    
    // Check Remote Config status
    debugPrint('🔄 Checking Remote Config status...');
    final configStatus = await updateChecker.checkRemoteConfigStatus();
    debugPrint('📊 Remote Config status: $configStatus');
    
    final updateStatus = await updateChecker.checkForUpdate();
    debugPrint('📋 Update status: $updateStatus');

    if (updateStatus.updateAvailable) {
      debugPrint('⚠️ Update available, showing dialog');
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        barrierDismissible: !updateStatus.forceUpdate,
        builder: (context) => UpdateDialog(
          updateStatus: updateStatus,
          onLaterPressed: () {
            // debugPrint('👆 User pressed "Later"');
            // Handle 'Later' button press if needed
          },
        ),
      );
    } else {
      // debugPrint('✅ No update required');
    }
  } catch (e) {
    // debugPrint('❌ Error in checkAppUpdate: $e');
    // debugPrint('📚 Stack trace: $stackTrace');
  }
}

// Diagnostic method to help debug Firebase Remote Config issues
Future<void> diagnoseRemoteConfigIssues(BuildContext context) async {
  try {
    // debugPrint('🔍 Starting Remote Config diagnostic...');
    
    // Try to get Remote Config instance and perform diagnostics
    final updateChecker = await AppUpdateChecker.getInstance();
    final configStatus = await updateChecker.checkRemoteConfigStatus();
    
    // Display diagnostic results to user
    // ignore: use_build_context_synchronously
    // Helper function to convert API keys to readable names
  String _getReadableName(String apiKey) {
    // Convert camelCase or snake_case to spaces and capitalize first letter of each word
    final words = apiKey.replaceAllMapped(
      RegExp(r'([A-Z])'), 
      (match) => ' ${match.group(0)}'
    ).split(RegExp(r'[_\s]'));
    
    return words.map((word) => 
      word.isNotEmpty 
        ? '${word[0].toUpperCase()}${word.substring(1)}' 
        : ''
    ).join(' ').trim();
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.school),  // Changed to school icon for student context
          SizedBox(width: 8),
          Text('Learning Settings'),  // More intuitive title for students
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status section with more friendly messaging
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: configStatus['lastFetchStatus'] == 'SUCCESS' 
                  ? Colors.green.withOpacity(0.1) 
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  configStatus['lastFetchStatus'] == 'SUCCESS' 
                      ? Icons.check_circle 
                      : Icons.info_outline,
                  color: configStatus['lastFetchStatus'] == 'SUCCESS' 
                      ? Colors.green 
                      : Colors.orange,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    configStatus['lastFetchStatus'] == 'SUCCESS'
                        ? 'Your settings are up to date!'
                        : 'Tap "Update Now" to get the latest settings',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 20),
          
          // Config values with more descriptive headings
          Text('Your Learning Settings:', 
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            )
          ),
          SizedBox(height: 12),
          
          if (configStatus.containsKey('configValues') && 
              (configStatus['configValues'] as Map<String, dynamic>).isNotEmpty)
            Container(
              height: 200,  // Fixed height for scrollable area
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView(
                padding: EdgeInsets.all(8),
                children: (configStatus['configValues'] as Map<String, dynamic>).entries.map((e) => 
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.settings, size: 16, color: Colors.blue),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getReadableName(e.key),
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${e.value}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ).toList(),
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 28),
                    SizedBox(height: 8),
                    Text(
                      'No settings available yet',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    Text(
                      'Tap "Update Now" to get started',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            
          // Error message with helper text
          if (configStatus.containsKey('error'))
            Container(
              margin: EdgeInsets.only(top: 16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Something went wrong',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${configStatus['error']}',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try updating again or contact support if this continues',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: Icon(Icons.refresh),
          label: Text('Update Now'),  // More action-oriented button text
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue,  // Fixed 'primary' to 'foregroundColor'
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () {
            // Add refresh logic here
          },
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade700,  // Fixed 'primary' to 'foregroundColor'
          ),
          child: Text('Close'),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  );
      
  } catch (e) {
    // debugPrint('❌ Error in diagnoseRemoteConfigIssues: $e');
    // debugPrint('📚 Stack trace: $stackTrace');
    
    // Show error to user
    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diagnostic Error'),
        content: Text('Error connecting to Remote Config: $e'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}