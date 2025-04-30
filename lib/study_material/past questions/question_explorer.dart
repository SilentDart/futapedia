import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:futapedia/study_material/services/downloader.dart';
import 'package:futapedia/templates/snackbar.dart';
import 'package:futapedia/study_material/past%20questions/question_drive.dart';
// import 'package:futapedia/study_material/pdf/pdf_drive.dart';
import 'package:futapedia/study_material/services/encrypted_pdfviewer.dart';
import 'package:futapedia/study_material/services/notification_manager.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:loading_animation_widget/loading_animation_widget.dart';
// import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:routemaster/routemaster.dart';


class PastQuestionGoogleDriveManager extends StatefulWidget {
  const PastQuestionGoogleDriveManager({super.key});

  @override
  _PastQuestionGoogleDriveManagerState createState() => _PastQuestionGoogleDriveManagerState();
}

class _PastQuestionGoogleDriveManagerState extends State<PastQuestionGoogleDriveManager> with SingleTickerProviderStateMixin {
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
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
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
                  size: 40.sp,
                ),
                SizedBox(height: 20.h),
                Text(
                  'Connecting to server...',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                'Past Question materials will appear shortly',
                  style: TextStyle(
                    fontSize: 14.sp,
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
        appBar: PreferredSize(
        preferredSize: Size.fromHeight(110.h), // You can adjust this value as needed
          child: AppBar(
            leading: IconButton(
              icon: Icon(Icons.chevron_left, size: 30.sp,),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Past Questions',style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25.sp)),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(50.h),
              child: Column(
                children: [
                  // TabBar
                  TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.cloud, size: 25.sp),
                      text: 'Drive Files',
                      height: 50.h, // Set a fixed height
                    ),
                    Tab(
                      icon: Icon(Icons.download, size: 25.sp),
                      text: 'Downloaded',
                      height: 50.h, // Set a fixed height
                    ),
                  ],
                  labelPadding: EdgeInsets.symmetric(horizontal: 10.w), // Added .w for responsive width
                  indicatorWeight: 3.h, // Added .h for responsive thickness
                  labelStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold), 
                  // unselectedLabelStyle: TextStyle(fontSize: 14.sp), // Optional: style for unselected tabs
                ),
                  // Breadcrumb navigation will be handled by each tab
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            PastQuestionExplorer(),
            PastQuestionDownloadedFilesTab(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    GoogleDriveDownloader.detachFromUI(this);
    NotificationDownloadManager.detachFromUI(this);
    super.dispose();
  }
}

// Enhanced Tab for browsing Google Drive content
class PastQuestionExplorer extends StatefulWidget {
  const PastQuestionExplorer({super.key});

  @override
  _PastQuestionExplorerState createState() => _PastQuestionExplorerState();
}

class _PastQuestionExplorerState extends State<PastQuestionExplorer> {
  List<drive.File> _currentFolderContents = [];
  bool _isLoading = true;
  String _currentFolderId = 'root'; // Start with root folder
  List<drive.File> _breadcrumbs = [];
  Map<String, bool> _isDownloading = {};
  Map<String, double?> _downloadProgress = {};
  late GoogleDriveServicePQ _driveService;

  @override
  void initState() {
    super.initState();
    _driveService = GoogleDriveServicePQ();
    _loadDriveContents();
  }

  void showError(text){
    CustomSnackbar.show(context, text, backgroundColor: Colors.red);
  }

  void showSuccess(text){
    CustomSnackbar.show(context, text, backgroundColor: Colors.green);
  }

  void showNotify(text){
    CustomSnackbar.show(context, text);
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

      showSuccess('Another download is in progress. This file will be queued.');
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
        
        showSuccess('File downloaded: ${file.name}');
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
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                child: Text(
                  _breadcrumbs[i].name ?? 'Unnamed',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).primaryColor,
                    fontWeight: i == _breadcrumbs.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
            if (i < _breadcrumbs.length - 1)
              Icon(Icons.chevron_right, size: 18.sp),
          ],
        ),
      );
    }
    
    return breadcrumbWidgets;
  }

  Widget _buildDriveFilesView() {
    if (_currentFolderContents.isEmpty) {
      return  Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48.sp, color: Colors.grey),
            SizedBox(height: 8.h),
            Text(
              'This folder is empty',
              style: TextStyle(fontSize: 14.sp),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _currentFolderContents.length,
      padding: EdgeInsets.symmetric(vertical: 2.h),
      itemBuilder: (context, index) {
        final item = _currentFolderContents[index];
        final isItemFolder = _driveService.isFolder(item);
        final iconColor = isItemFolder ? Colors.amber.shade600 : Colors.red.shade400;
        
        return Card(
          elevation: 0.5,
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
          child: ListTile(
            dense: true,            
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 0),
            visualDensity: VisualDensity(horizontal: 0, vertical: -4),
            leading: Container(
              width: 40.w,
              height: 35.h,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Center(
                child: Icon(
                  isItemFolder ? Icons.folder : Icons.picture_as_pdf,
                  color: iconColor,
                  size: 20.sp,
                ),
              ),
            ),
            title: Text(
              item.name ?? 'Unnamed',
              style: TextStyle(
                fontSize: 14.sp, 
                fontWeight: FontWeight.w500, 
                color: Colors.black87
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 2.h),
                if (!isItemFolder && item.size != null)
                  Text(
                    _formatFileSize(int.parse(item.size!)),
                    style: TextStyle(
                      fontSize: 11.sp, 
                      color: Colors.black54
                    ),
                  )
                else if (isItemFolder)
                  Text(
                    'Folder',
                    style: TextStyle(
                      fontSize: 11.sp, 
                      color: Colors.black54
                    ),
                  ),
              ],
            ),
            onTap: isItemFolder
                ? () => _navigateToFolder(item)
                : () => _downloadFile(item),
            trailing: _isDownloading[item.id] == true
              ? SizedBox(
                  width: 40.w,
                  height: 30.h,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _downloadProgress[item.id],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                        strokeWidth: 3.w,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                      ),
                      Text(
                        '${((_downloadProgress[item.id] ?? 0) * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 10.sp, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.green
                        ),
                      ),
                    ],
                  ),
                )
                : SizedBox(
                    width: 36.w,
                    height: 36.h,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          isItemFolder 
                            ? _downloadFolder(item) 
                            : _downloadFile(item);
                        },
                        child: Icon(
                          Icons.download_rounded,
                          size: 20.sp,
                          color: Colors.blue.shade700,
                        ),
                      ),
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
            height: 48.h,
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: 20.w),
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
                size: 40.sp,
              )
              : _buildDriveFilesView(),
          ),
        ],
      ),
    );
  }
}

// Enhanced Tab for viewing downloaded files
class PastQuestionDownloadedFilesTab extends StatefulWidget {
  const PastQuestionDownloadedFilesTab({super.key});

  @override
  _PastQuestionDownloadedFilesTabState createState() => _PastQuestionDownloadedFilesTabState();
}

class _PastQuestionDownloadedFilesTabState extends State<PastQuestionDownloadedFilesTab> {
  List<FileSystemEntity> _downloadedFiles = [];
  bool _isLoadingDownloads = true;
  String _currentPath = '';
  String _basePathToHide = '';
  List<DirectoryInfo> _breadcrumbs = [];

// Create secure storage instance for cache checking (if not already there)
  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  void showError(text){
    CustomSnackbar.show(context, text, backgroundColor: Colors.red);
  }

  void showSuccess(text){
    CustomSnackbar.show(context, text, backgroundColor: Colors.green);
  }

  void showNotify(text){
    CustomSnackbar.show(context, text);
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
      
      setState(() {
        _downloadedFiles = files.where((file) {
          // Only show files in the current directory
          final fileDir = path.dirname(file.path);
          return fileDir == _currentPath;
        }).toList();
        _isLoadingDownloads = false;
        // _isVideoAvailable = isVideoAvailable; // Set the flag based on availability
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
    
    final lowerPath = file.path.toLowerCase();
    
    try {
      final decryptedContent = await GoogleDriveDownloader.openFile(file.path);
      
      if (!mounted) return;

      if (decryptedContent != null) {

        if(lowerPath.endsWith('.pdf')){
          PQFileViewerState.fileData = decryptedContent;
          PQFileViewerState.fileName = path.basename(file.path);

          Routemaster.of(context).push('/encryptedpqpdfviewer');
        }else if (['.jpg', '.jpeg', '.png', '.gif', '.bmp'].any((ext) => lowerPath.endsWith(ext))) {
          // Open image with photo viewer
          _openImage(file);
        }
        // Navigate to file viewer
        
      } else {
        if (!mounted) return;
        showError('File Corrupted! Re-download file');
      }
    } catch (e) {
      if (!mounted) return;

      showError('Error opening file: $e');
    }
  }

  void _openImage(File imageFile) {
    // Create a list of image files from downloaded files
    final imageFiles = _downloadedFiles
        .where((file) => 
          file is File && 
          ['.jpg', '.jpeg', '.png', '.gif', '.bmp']
            .any((ext) => file.path.toLowerCase().endsWith(ext))
        )
        .cast<File>()
        .toList();
    
    // Find the index of the current image
    final initialIndex = imageFiles.indexWhere((file) => file.path == imageFile.path);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecureImageGalleryScreen(
          images: imageFiles,
          initialIndex: initialIndex,
        ),
      ),
    );
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
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
                child: Text(
                  _breadcrumbs[i].name,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(context).primaryColor,
                    fontWeight: i == _breadcrumbs.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
            if (i < _breadcrumbs.length - 1)
              Icon(Icons.chevron_right, size: 18.sp),
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
      padding: EdgeInsets.all(16.r),
      gridDelegate:  SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110.w,
        childAspectRatio: .8,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 16.h,
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
            elevation: 5,
            child: Padding(
              padding:  EdgeInsets.all(10.r),
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
                            : Icons.image,
                        color: isDirectory
                          ? Colors.amber
                          : isPdf
                            ? Colors.red
                            : Colors.blue,
                        size: 35.sp,
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
                            style: TextStyle(fontSize: 12.sp),
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
            height: 48.h,
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
                
              ],
            ),
          ),
          
          // File grid
          Expanded(
            child: _isLoadingDownloads
              ? LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.brown,
                size: 40.sp,
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




class PQFileViewerState {
  static String fileName = "";
  static Uint8List? fileData;
}
