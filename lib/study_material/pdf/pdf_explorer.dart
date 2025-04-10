import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:futapedia/study_material/pdf/pdf_drive.dart';
import 'package:futapedia/study_material/services/notification_manager.dart';
import 'package:futapedia/study_material/services/encrypted_pdfviewer.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:loading_animation_widget/loading_animation_widget.dart';
// import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:routemaster/routemaster.dart';


class GoogleDriveManagerScreen extends StatefulWidget {
  const GoogleDriveManagerScreen({super.key});

  @override
  _GoogleDriveManagerScreenState createState() => _GoogleDriveManagerScreenState();
}

class _GoogleDriveManagerScreenState extends State<GoogleDriveManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeDownloader();
  }

  Future<void> _initializeDownloader() async {
    await GoogleDriveDownloader.initialize();
    await NotificationDownloadManager().initialize();

    if (Platform.isAndroid) {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return PopScope(
        canPop: true,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Updated loading screen with better visuals
                LoadingAnimationWidget.staggeredDotsWave(
                  color: Colors.brown,
                  size: 50,
                ),
                const SizedBox(height: 24),
                Text(
                  'Connecting to server...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your study materials will appear shortly',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false, // Prevent default system back behavior
      onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (!didPop) {
            // Manually pop for system back gestures
            Navigator.of(context).pop();
          }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.chevron_left, size: 35,),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Premium Notes',style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(120),
            child: Column(
              children: [
                // TabBar
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.cloud),
                      text: 'Drive Files',
                    ),
                    Tab(
                      icon: Icon(Icons.download),
                      text: 'Downloaded',
                    ),
                  ],
                ),
                // Breadcrumb navigation will be handled by each tab
                SizedBox(height: 48),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            EnhancedDriveExplorerTab(),
            EnhancedDownloadedFilesTab(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    GoogleDriveDownloader.detachFromUI(this);
    _tabController.dispose();
    NotificationDownloadManager.detachFromUI(this);
    super.dispose();
  }
}

// Enhanced Tab for browsing Google Drive content
class EnhancedDriveExplorerTab extends StatefulWidget {
  const EnhancedDriveExplorerTab({Key? key}) : super(key: key);

  @override
  _EnhancedDriveExplorerTabState createState() => _EnhancedDriveExplorerTabState();
}

class _EnhancedDriveExplorerTabState extends State<EnhancedDriveExplorerTab> {
  List<drive.File> _currentFolderContents = [];
  bool _isLoading = true;
  String _currentFolderId = 'root'; // Start with root folder
  List<drive.File> _breadcrumbs = [];
  Map<String, bool> _isDownloading = {};
  Map<String, double?> _downloadProgress = {};
  late GoogleDriveServicePDF _driveService;

  @override
  void initState() {
    super.initState();
    _driveService = GoogleDriveServicePDF();
    _loadDriveContents();
  }

  void showError(text){
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Center(child: Text(text,  style: TextStyle(color: Colors.white),)), backgroundColor: Colors.red, duration: Duration(milliseconds: 900)),
      );
  }

  void showSuccess(text){
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Center(child: Text(text, style: TextStyle(color: Colors.white),)), backgroundColor: Colors.green, duration: Duration(milliseconds: 900)),
      );
  }

  void showNotify(text){
     if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Center(child: Text(text,  style: TextStyle(color: Colors.white),)), backgroundColor: Colors.grey, duration: Duration(milliseconds: 900)),
      );
  }

  Future<bool> _handlePhoneBackNavigation() async {
    if (_breadcrumbs.length > 1) {
      _breadcrumbs.removeLast();
      _navigateToBreadcrumb(_breadcrumbs.length - 1);
      return false;
    }
    return true; // Allow app to exit if not navigating
  }

  Future<void> _loadDriveContents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the drive API instance
      final driveApi = await _driveService.driveApi;
      if (driveApi == null) {
        throw Exception('Failed to initialize Google Drive API');
      }
      
      // If breadcrumbs are empty, initialize with root folder
      if (_breadcrumbs.isEmpty) {
        final rootFolderId = _driveService.getRootFolderId();
        final rootFolder = drive.File()
          ..id = rootFolderId
          ..name = 'My Drive'
          ..mimeType = 'application/vnd.google-apps.folder';
        _breadcrumbs = [rootFolder];
      }

      // Query to find files in the current folder
      final query = _currentFolderId == 'root' 
        ? "'${_driveService.getRootFolderId()}' in parents and trashed = false"
        : "'$_currentFolderId' in parents and trashed = false";
      
      // Request files with necessary fields
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, size)',
      );
      
      // Convert to drive.File objects
      _currentFolderContents = fileList.files ?? [];
    } catch (e) {
      showError("Internet Connection Error!");
      _currentFolderContents = [];
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToFolder(drive.File folder) {
    setState(() {
      _currentFolderId = folder.id!;
      _breadcrumbs.add(folder);
    });
    _loadDriveContents();
  }

  void _navigateToBreadcrumb(int index) {
    setState(() {
      _currentFolderId = _breadcrumbs[index].id!;
      _breadcrumbs = _breadcrumbs.sublist(0, index + 1);
    });
    _loadDriveContents();
  }

  Future<void> _downloadFile(drive.File file) async {
    // Check if any file is currently downloading
    if (_isDownloading.values.contains(true)) {

      showNotify('Another download is in progress. This file will be queued');

    }

    setState(() {
      _isDownloading[file.id!] = true;
      _downloadProgress[file.id!] = 0.0;
    });

    try {
      final NotificationDownloadManager notificationManager = NotificationDownloadManager();
      
      // Create a directory for downloads
      final String downloadDirPath = await GoogleDriveDownloader.getDownloadDirectory();
      final downloadDir = Directory(downloadDirPath);
      
      // Build relative path from breadcrumbs (excluding root and current folder)
      String relativePath = '';
      if (_breadcrumbs.length > 1) {
        relativePath = _breadcrumbs.sublist(1, _breadcrumbs.length).map((f) => f.name ?? 'unnamed').join('/');
      }
      
      // Start download with progress tracking
      final filePath = await notificationManager.downloadFileWithNotification(
        file,
        downloadDir,
        _driveService,
        relativePath: relativePath,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress[file.id!] = progress;
            });
          }
        },
      );
      
      if (mounted && filePath != null) {
        showSuccess('File Downloaded:${file.name}');
      }
    } catch (e) {
      if (mounted) {
        showError('Error downloading file: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading[file.id!] = false;
        });
      }
    }
  }

  Future<void> _downloadAndOpenFile(drive.File file) async {
    // Check if any file is currently downloading
    if (_isDownloading.values.contains(true)) {
      
      showNotify('Another download is in progress. This file will be queued');

    }

    setState(() {
      _isDownloading[file.id!] = true;
      _downloadProgress[file.id!] = 0.0;
    });

    try {
      final notificationManager = NotificationDownloadManager();
      
      // Create a directory for downloads
      final String downloadDirPath = await GoogleDriveDownloader.getDownloadDirectory();
      final downloadDir = Directory(downloadDirPath);
      
      // Build relative path from breadcrumbs (excluding root and current folder)
      String relativePath = '';
      if (_breadcrumbs.length > 1) {
        relativePath = _breadcrumbs.sublist(1, _breadcrumbs.length).map((f) => f.name ?? 'unnamed').join('/');
      }
      
      // Start download with progress tracking
      final filePath = await notificationManager.downloadFileWithNotification(
        file,
        downloadDir,
        _driveService,
        relativePath: relativePath,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress[file.id!] = progress;
            });
          }
        },
      );
      
      // Open file after download
      if (mounted && filePath != null) {
        final decryptedContent = await GoogleDriveDownloader.openFile(filePath);
        
        if (decryptedContent != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EncryptedFileViewer(
                fileName: path.basename(filePath),
                fileData: decryptedContent,
              ),
            ),
          );
        } else {
          if (!mounted) return;
         
          showError('Could not open file');
        }
      }
    } catch (e) {
      if (mounted) {
        
        showError('Error downloading and opening file: $e');

      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading[file.id!] = false;
        });
      }
    }
  }

  Future<void> _downloadFolder(drive.File folder) async {
    // Check if any file is currently downloading
    if (_isDownloading.values.contains(true)) {

      showNotify('Another download is in progress. This folder will be queued.');

    }

    setState(() {
      _isDownloading[folder.id!] = true;
      _downloadProgress[folder.id!] = 0.0;
    });

    try {
      final notificationManager = NotificationDownloadManager();
      
      // Create a directory for downloads
      final String downloadDirPath = await GoogleDriveDownloader.getDownloadDirectory();
      final downloadDir = Directory(downloadDirPath);
      
      // Build relative path from breadcrumbs (excluding root and current folder)
      String relativePath = '';
      if (_breadcrumbs.length > 1) {
        relativePath = _breadcrumbs.sublist(1, _breadcrumbs.length-1).map((f) => f.name ?? 'unnamed').join('/');
      }
      
      // Start folder download
      await notificationManager.downloadFolderWithNotification(
        folder,
        downloadDir,
        _driveService,
        relativePath: relativePath,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress[folder.id!] = progress;
            });
          }
        },
      );
      
      if (mounted) {
        
        showSuccess('Folder downloaded: ${folder.name}');

      }
    } catch (e) {
      if (mounted) {
        
        showError('Error downloading folder: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading[folder.id!] = false;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  List<Widget> _buildBreadcrumbs() {
    List<Widget> breadcrumbWidgets = [];
    
    for (int i = 0; i < _breadcrumbs.length; i++) {
      breadcrumbWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _navigateToBreadcrumb(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  _breadcrumbs[i].name ?? 'Unnamed',
                  style: TextStyle(
                    fontSize: 17,
                    color: Theme.of(context).primaryColor,
                    fontWeight: i == _breadcrumbs.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
            if (i < _breadcrumbs.length - 1)
              const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      );
    }
    
    return breadcrumbWidgets;
  }

  Widget _buildDriveFilesView() {
    if (_currentFolderContents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'This folder is empty',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _currentFolderContents.length,
      itemBuilder: (context, index) {
        final item = _currentFolderContents[index];
        final isItemFolder = _driveService.isFolder(item);
        
        return ListTile(
          leading: Icon(
            isItemFolder ? Icons.folder : Icons.picture_as_pdf,
            color: isItemFolder ? Colors.amber : Colors.red,
          ),
          title: Text(item.name ?? 'Unnamed'),
          subtitle: !isItemFolder && item.size != null
              ? Text(_formatFileSize(int.parse(item.size!)))
              : null,
          onTap: isItemFolder
              ? () => _navigateToFolder(item)
              : () => _downloadFile(item),
          trailing: _isDownloading[item.id] == true
            ? SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _downloadProgress[item.id],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      strokeWidth: 4.0,
                    ),
                    Text(
                      '${((_downloadProgress[item.id] ?? 0) * 100).toInt()}%',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
              : isItemFolder
                  ? PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: const [
                              Icon(Icons.download),
                              SizedBox(width: 8),
                              Text('Download'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'download') {
                          _downloadFolder(item);
                        }
                      },
                    )
                  : PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: const [
                              Icon(Icons.download),
                              SizedBox(width: 8),
                              Text('Download'),
                            ],
                          ),
                        ),
                        // PopupMenuItem(
                        //   value: 'view',
                        //   child: Row(
                        //     children: const [
                        //       Icon(Icons.visibility),
                        //       SizedBox(width: 8),
                        //       Text('View'),
                        //     ],
                        //   ),
                        // ),
                      ],
                      onSelected: (value) {
                        if (value == 'download') {
                          _downloadFile(item);
                        } else if (value == 'view') {
                          _downloadAndOpenFile(item);
                        }
                      },
                    ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return;
        }
        await _handlePhoneBackNavigation();
      },
      child: Column(
        children: [
          // Breadcrumb navigation
          Container(
            height: 48,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildBreadcrumbs(),
              ),
            ),
          ),
          
          // File list
          Expanded(
            child: _isLoading 
              ? LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.brown,
                size: 50,
              )
              : _buildDriveFilesView(),
          ),
        ],
      ),
    );
  }
}

// Enhanced Tab for viewing downloaded files
class EnhancedDownloadedFilesTab extends StatefulWidget {
  const EnhancedDownloadedFilesTab({super.key});

  @override
  _EnhancedDownloadedFilesTabState createState() => _EnhancedDownloadedFilesTabState();
}

class _EnhancedDownloadedFilesTabState extends State<EnhancedDownloadedFilesTab> {
  List<FileSystemEntity> _downloadedFiles = [];
  bool _isLoadingDownloads = true;
  String _currentPath = '';
  String _basePathToHide = '';
  List<DirectoryInfo> _breadcrumbs = [];

  // Add this near the top of _EnhancedDownloadedFilesTabState class
  bool _isVideoAvailable = false; // Flag to track video availability
    
  // Create secure storage instance for cache checking (if not already there)
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  void showError(text){
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Center(child: Text(text)), backgroundColor: Colors.red, duration: Duration(milliseconds: 900)),
      );
  }

  void showSuccess(text){
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Center(child: Text(text)), backgroundColor: Colors.green, duration: Duration(milliseconds: 900)),
      );
  }

  void showNotify(text){
     if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Center(child: Text(text)), backgroundColor: Colors.grey, duration: Duration(milliseconds: 900)),
      );
  }

  Future<bool> _handlePhoneBackNavigation() async {
    if (_breadcrumbs.length > 1) {
      _breadcrumbs.removeLast();
      _navigateToBreadcrumb(_breadcrumbs.length - 1);
      return false;
    }
    return true; // Allow app to exit if not navigating
  }

  Future<void> _loadDownloadedFiles() async {
    setState(() {
      _isLoadingDownloads = true;
    });

    try {
      final List<FileSystemEntity> files = await GoogleDriveDownloader.getDownloadedFiles();
      
      // Sort files: directories first, then files
      files.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return path.basename(a.path).compareTo(path.basename(b.path));
      });
      
      // Set up initial state
      if (_currentPath.isEmpty && files.isNotEmpty) {
        final baseDir = await GoogleDriveDownloader.getDownloadDirectory();
        _basePathToHide = baseDir;
        _currentPath = baseDir;
        
        // Set up initial breadcrumb
        _breadcrumbs = [
          DirectoryInfo(id: baseDir, name: 'Downloads', path: baseDir)
        ];
      }
      
      final bool isVideoAvailable = await _checkVideoAvailability();

      // Then include _isVideoAvailable in the setState call
      setState(() {
        _downloadedFiles = files.where((file) {
          // Only show files in the current directory
          final fileDir = path.dirname(file.path);
          return fileDir == _currentPath;
        }).toList();
        _isLoadingDownloads = false;
        _isVideoAvailable = isVideoAvailable; // Set the flag based on availability
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDownloads = false;
          _downloadedFiles = [];
        });
        
        showError('Error loading file: $e');
      }
    }
  }

  void _navigateToLocalDirectory(String dirPath) {
    final dirName = path.basename(dirPath);
    
    setState(() {
      _currentPath = dirPath;
      _breadcrumbs.add(DirectoryInfo(
        id: dirPath,
        name: dirName,
        path: dirPath,
      ));
    });
    
    _loadDownloadedFiles();
  }

  void _navigateToBreadcrumb(int index) {
    setState(() {
      _currentPath = _breadcrumbs[index].path;
      _breadcrumbs = _breadcrumbs.sublist(0, index + 1);
    });
    
    _loadDownloadedFiles();
  }

  Future<void> _openFile(File file) async {
    try {
      final decryptedContent = await GoogleDriveDownloader.openFile(file.path);
      
      

      if (decryptedContent != null) {
        // Navigate to file viewer
        FileViewerState.fileData = decryptedContent;
        FileViewerState.fileName = path.basename(file.path);
        if (!mounted) return;
        Routemaster.of(context).push('/encryptedpdfviewer');
      } else {
        if (!mounted) return;
        showError('Could not open file');
      }
    } catch (e) {
      if (!mounted) return;

      showError('Error opening file: $e');
    }
  }


  // Check if video is available for the current folder
  // Check if video is available for the current folder
Future<bool> _checkVideoAvailability() async {
  if (_breadcrumbs.isEmpty) return false;
  
  // Get the last folder name from breadcrumbs
  final String folderName = _breadcrumbs.last.name;
  final String strippedName = folderName.replaceAll(' ', '');

  // Updated regex pattern: first 3 alphabetic characters followed by 3 digits
  RegExp coursePattern = RegExp(r'^[A-Za-z]{3}\d{3}');
  // Check both original and stripped versions
  if (!coursePattern.hasMatch(folderName) && !coursePattern.hasMatch(strippedName)) return false;
  
  // Try with original name
  String? cachedData = await _secureStorage.read(key: 'course_$folderName');
  
  // If not found, try with whitespace stripped
  cachedData ??= await _secureStorage.read(key: 'course_$strippedName');
  
  return cachedData != null;
}

// Navigate to video route
void _navigateToVideo() {
  if (_breadcrumbs.isEmpty) return;
  
  // Get the last folder name from breadcrumbs
  final String folderName = _breadcrumbs.last.name;
  final String strippedName = folderName.replaceAll(' ', '');

  // Updated regex pattern: first 3 alphabetic characters followed by 3 digits
  RegExp coursePattern = RegExp(r'^[A-Za-z]{3}\d{3}');
  // Check both original and stripped versions
  if (!coursePattern.hasMatch(folderName) && !coursePattern.hasMatch(strippedName)) {
    showError('Invalid course folder format');
    return;
  }
  
      
    // Try with original name first
    _secureStorage.read(key: 'course_$folderName').then((data) {
      if (data != null) {
        if(!mounted) return;
        Routemaster.of(context).push('/course_details/$folderName');
      } else {
        // Try with stripped name if original not found
        _secureStorage.read(key: 'course_$strippedName').then((strippedData) {
          if (strippedData != null) {
            if(!mounted) return;
            Routemaster.of(context).push('/course_details/$strippedName');
          } else {
            showError('Video not available');
          }
        });
      }
    });
  }

  
  List<Widget> _buildBreadcrumbs() {
    List<Widget> breadcrumbWidgets = [];
    
    for (int i = 0; i < _breadcrumbs.length; i++) {
      breadcrumbWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _navigateToBreadcrumb(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  _breadcrumbs[i].name,
                  style: TextStyle(
                    fontSize: 17,
                    color: Theme.of(context).primaryColor,
                    fontWeight: i == _breadcrumbs.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
            if (i < _breadcrumbs.length - 1)
              const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      );
    }
    
    return breadcrumbWidgets;
  }

  Widget _buildDownloadedFilesGrid() {
    if (_downloadedFiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_done, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No downloaded files',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: _downloadedFiles.length,
      itemBuilder: (context, index) {
        final entity = _downloadedFiles[index];
        
        // Get relative path by removing the base path to hide
        String displayPath = entity.path;
        if (displayPath.startsWith(_basePathToHide)) {
          displayPath = displayPath.substring(_basePathToHide.length);
          // Remove leading slash if present
          if (displayPath.startsWith('/')) {
            displayPath = displayPath.substring(1);
          }
        }
        
        // Get just the name from the path
        final name = displayPath.split('/').last;
        final isDirectory = entity is Directory;
        final isPdf = name.toLowerCase().endsWith('.pdf');
        
        
        return GestureDetector(
          onTap: isDirectory
            ? () => _navigateToLocalDirectory(entity.path)
            : () => _openFile(entity as File),
          child: Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // Icon section - flexible but with minimum height
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Icon(
                        isDirectory
                          ? Icons.folder
                          : isPdf
                            ? Icons.picture_as_pdf
                            : Icons.insert_drive_file,
                        color: isDirectory
                          ? Colors.amber
                          : isPdf
                            ? Colors.red
                            : Colors.grey,
                        size: 30,
                      ),
                    ),
                  ),
                  // Text section - flexible with higher priority for long text
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return;
        }
        await _handlePhoneBackNavigation();
      },
      child: Column(
        children: [
          // Breadcrumb navigation
          Container(
            height: 48,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Breadcrumbs section - flexible to take available space
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _buildBreadcrumbs(),
                    ),
                  ),
                ),
                
                // Video available button - only show if available
                if (_isVideoAvailable)
                  TextButton.icon(
                    onPressed: _navigateToVideo,
                    icon: const Icon(Icons.play_circle_fill),
                    label: const Text('Video available'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
              ],
            ),
          ),
          
          // File grid
          Expanded(
            child: _isLoadingDownloads
              ? LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.brown,
                size: 50,
              )
              : _buildDownloadedFilesGrid(),
          ),
        ],
      ),
    );
  }
}
// Helper class for directory breadcrumb navigation
class DirectoryInfo {
  final String id;
  final String name;
  final String path;

  DirectoryInfo({required this.id, required this.name, required this.path});
}




class FileViewerState {
  static String fileName = "";
  static Uint8List? fileData;
}
