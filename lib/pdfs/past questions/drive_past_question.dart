import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:futapedia/pdfs/past%20questions/encrypt_util_past_question.dart';
import 'package:futapedia/pdfs/past%20questions/google_drive_past_question.dart';
import 'package:futapedia/study_material/services/permission_manager.dart';
import 'package:futapedia/pdfs/services/downloader.dart';
// import 'package:futapedia/study_material/services/downloader.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:routemaster/routemaster.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class PastQuestionDriveScreen extends StatefulWidget {
  const PastQuestionDriveScreen({Key? key}) : super(key: key);

  @override
  State<PastQuestionDriveScreen> createState() => _PastQuestionDriveScreenState();
}

class _PastQuestionDriveScreenState extends State<PastQuestionDriveScreen> with TickerProviderStateMixin {
  final PastQuestionsDriveService _driveService = PastQuestionsDriveService();
  final EnhancedBackgroundDownloadService _downloadService = EnhancedBackgroundDownloadService();

  List<drive.File> _currentFolderContents = [];
  String _currentFolderId = '';
  String _currentFolderName = 'Past Questions';
  List<FolderBreadcrumb> _breadcrumbs = [];
  bool _isLoading = false;
  
  // Downloaded files tracking
  List<FileSystemEntity> _downloadedFiles = [];
  bool _isLoadingDownloads = false;
  String _basePathToHide = '';
  
  // Download tracking
  Map<String, double> _downloadProgress = {};
  Map<String, bool> _isDownloading = {};
  
  // TabController for managing tabs
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initBasePathToHide();
    _loadRootFolder();
    
    // Add listener to load downloaded files when switching to downloads tab
    _tabController.addListener(() {
      if (_tabController.index == 1 && _downloadedFiles.isEmpty) {
        _loadDownloadedFiles();
      }
    });

    // Listen to download stream for real-time updates
    _downloadService.downloadStream.listen((task) {
      setState(() {
        _downloadProgress[task.file.id!] = task.progress;
        _isDownloading[task.file.id!] = task.status != DownloadStatus.completed;

        if (task.status == DownloadStatus.completed && _tabController.index == 1) {
          _loadDownloadedFiles();
        }
      });
    });
  }
  
  Future<void> _initBasePathToHide() async {
    final basePath = await _getDownloadPath();
    setState(() {
      _basePathToHide = basePath;
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadRootFolder() async {
    setState(() => _isLoading = true);
    try {
      final rootId = _driveService.getRootFolderId();
      _currentFolderId = rootId;
      _breadcrumbs = [FolderBreadcrumb(name: 'Past Questions', id: rootId)];
      await _loadFolderContents(rootId);
    } catch (e) {
      _showError('Failed to load root folder');
    } finally {
      // // if(!mounted) return;
      // setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadFolderContents(String folderId) async {
    setState(() => _isLoading = true);
    try {
      final contents = await _driveService.listFolderContents(folderId);
      setState(() {
        _currentFolderContents = contents;
        _currentFolderId = folderId;
      });
    } catch (e) {
      _showError('No Internet Connection. Click FUTApedia above to refresh');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _navigateToFolder(drive.File folder) async {
    setState(() {
      _currentFolderName = folder.name ?? 'Unnamed Folder';
      _breadcrumbs.add(FolderBreadcrumb(name: _currentFolderName, id: folder.id!));
    });
    await _loadFolderContents(folder.id!);
  }
  
  Future<void> _navigateToBreadcrumb(int index) async {
    setState(() {
      _breadcrumbs = _breadcrumbs.sublist(0, index + 1);
      _currentFolderId = _breadcrumbs.last.id;
      _currentFolderName = _breadcrumbs.last.name;
    });
    
    // If we're in the Downloaded tab, reload downloaded files
    if (_tabController.index == 1) {
      await _loadDownloadedFilesForBreadcrumb();
    } else {
      // If in Drive Files tab, load folder contents
      await _loadFolderContents(_currentFolderId);
    }
  }
  
  Future<bool> _checkPermissions() async {
    final hasPermission = await PermissionManager.requestStoragePermission(context);
    
    if (!hasPermission) {
      if (!mounted) return false;
      
      _showError('Cannot proceed without storage access. You can try again later.');
      return false;
    }
    
    return true;
  }
  
  Future<String> _getDownloadPath() async {
    return await PermissionManager.getAppropriateDownloadPath();
  }
  
  Future<void> _loadDownloadedFiles() async {
  if (!await _checkPermissions()) return;
  
  setState(() => _isLoadingDownloads = true);
  
  try {
    final basePath = await _getDownloadPath();
    String relativePath = _generateRelativePathFromBreadcrumbs();
    
    // Ensure the path is correctly formatted
    final directoryPath = relativePath.isEmpty 
        ? basePath 
        : '$basePath/$relativePath';
        
    print('Loading downloaded files from: $directoryPath');
    
    final directory = Directory(directoryPath);
    
    if (await directory.exists()) {
      List<FileSystemEntity> files = [];
      
      try {
        // Use recursive listing to ensure we get all files
        files = await directory.list(recursive: false).toList();
        print('Found ${files.length} files/folders in $directoryPath');
        
        // Debug: Print found files
        for (var file in files) {
          print('Found: ${file.path}');
        }
      } catch (e) {
        print('Error listing directory: $e');
        
        // Fallback approach if directory listing fails
        try {
          files = [];
          await for (final entity in directory.list(recursive: false)) {
            files.add(entity);
          }
        } catch (e) {
          print('Fallback directory listing also failed: $e');
        }
      }
      
      // Sort directories first, then files alphabetically
      files.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        
        final aName = a.path.split('/').last.toLowerCase();
        final bName = b.path.split('/').last.toLowerCase();
        return aName.compareTo(bName);
      });
      
      setState(() {
        _downloadedFiles = files;
        _basePathToHide = basePath;
      });
    } else {
      // Directory doesn't exist, create it
      try {
        await directory.create(recursive: true);
        print('Created directory: $directoryPath');
      } catch (e) {
        print('Failed to create directory: $e');
      }
      
      setState(() {
        _downloadedFiles = [];
      });
    }
  } catch (e, stack) {
    print('Failed to load downloaded files: $e');
    print('Stack trace: $stack');
    _showError('Failed to load downloaded files');
  } finally {
    setState(() => _isLoadingDownloads = false);
  }
}
  
  Future<void> _loadDownloadedFilesForBreadcrumb() async {
    if (!await _checkPermissions()) return;
    
    setState(() => _isLoadingDownloads = true);
    
    try {
      final basePath = await _getDownloadPath();
      String relativePath = _generateRelativePathFromBreadcrumbs();
      
      final directoryPath = '$basePath$relativePath';
      final directory = Directory(directoryPath);
      
      if (await directory.exists()) {
        final files = await directory.list().toList();
        
        // Sort directories first, then files
        files.sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          
          return a.path.split('/').last.compareTo(b.path.split('/').last);
        });
        
        setState(() {
          _downloadedFiles = files;
        });
      } else {
        setState(() {
          _downloadedFiles = [];
        });
      }
    } catch (e) {
      _showError('Failed to load downloaded files');
    } finally {
      setState(() => _isLoadingDownloads = false);
    }
  }
  
  String _generateRelativePathFromBreadcrumbs() {
    return _breadcrumbs
      .skip(1)  // Skip the root 'FUTApedia'
      .map((crumb) => crumb.name)
      .join('/');
  }
  
  // Helper method to format file size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  Future<void> _downloadFile(drive.File file) async {
    if (!await _checkPermissions()) return;
    
    try {
      // Use enhanced background download service with visual feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Starting download: ${file.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Set the progress indicator for this file
      setState(() {
        _isDownloading[file.id!] = true;
        _downloadProgress[file.id!] = 0.0;
      });
      
      // Important: Listen to download progress before starting the download
      final subscription = _downloadService.downloadStream.listen((task) {
        if (task.file.id == file.id) {
          setState(() {
            _downloadProgress[file.id!] = task.progress;
            
            // Update downloading state based on task status
            if (task.status == DownloadStatus.completed || 
                task.status == DownloadStatus.failed) {
              _isDownloading[file.id!] = false;
              
              // If download completed and we're in the downloads tab, refresh the list
              if (task.status == DownloadStatus.completed && _tabController.index == 1) {
                _loadDownloadedFiles();
              }
            }
          });
        }
      });
      
      // Start the download with progress tracking
      _downloadService.downloadWithConnectivityCheck(
        file: file, 
        breadcrumbs: _breadcrumbs,
        isFolder: false,
      );
      
      // Switch to Downloads tab after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _tabController.animateTo(1);
          // Reload downloaded files list after switching to Downloads tab
          _loadDownloadedFiles();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading[file.id!] = false;
        });
        _showError('Failed to download file: ${e.toString()}');
      }
    }
  }
  
  Future<void> _downloadAndOpenFile(drive.File file) async {
    if (!await _checkPermissions()) return;
    
    try {
      
      // Enqueue download
      _downloadService.downloadWithConnectivityCheck(
        file: file, 
        breadcrumbs: _breadcrumbs,
      );
      
      // Navigate to encrypted PDF viewer once download is complete
      // You might want to implement a mechanism to track download completion
      // Routemaster.of(context).push('/encrypted_pdfviewer?filePath=${Uri.encodeComponent(downloadPath)}');
    } catch (e) {
      _showError('Failed to download and open file');
    }
  }
  
  Future<void> _downloadFolder(drive.File folder) async {
  if (!await _checkPermissions()) return;
  
  try {
    // Create a loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading folder: ${folder.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    // Set the progress indicator for this folder
    setState(() {
      _isDownloading[folder.id!] = true;
      _downloadProgress[folder.id!] = 0.0;
    });
    
    // Important: Listen to download progress before starting the download
    final subscription = _downloadService.downloadStream.listen((task) {
      if (task.file.id == folder.id) {
        setState(() {
          _downloadProgress[folder.id!] = task.progress;
          
          // Update downloading state based on task status
          if (task.status == DownloadStatus.completed || 
              task.status == DownloadStatus.failed) {
            _isDownloading[folder.id!] = false;
            
            // If download completed and we're in the downloads tab, refresh the list
            if (task.status == DownloadStatus.completed && _tabController.index == 1) {
              _loadDownloadedFiles();
            }
          }
        });
      }
    });
    
    // Use enhanced background download service for folder
    _downloadService.downloadWithConnectivityCheck(
      file: folder, 
      breadcrumbs: _breadcrumbs,
      isFolder: true,
    );
    
    // Switch to Downloads tab after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _tabController.animateTo(1);
        // Reload downloaded files list after switching to Downloads tab
        _loadDownloadedFiles();
      }
    });
  } catch (e) {
    if (mounted) {
      setState(() {
        _isDownloading[folder.id!] = false;
      });
      _showError('Failed to download folder: ${e.toString()}');
    }
  }
}
  
  // Method to handle file opening
  void _openFile(File file) {
    final path = file.path;
    final lowerPath = path.toLowerCase();
    
    if (lowerPath.endsWith('.pdf')) {
      // Use encrypted PDF viewer 
      Routemaster.of(context).push('/encrypted_pdfviewer?filePath=${Uri.encodeComponent(path)}');
    } else if (['.jpg', '.jpeg', '.png', '.gif', '.bmp'].any((ext) => lowerPath.endsWith(ext))) {
      // Open image with photo viewer
      _openImage(file);
    } else {
      // For unsupported file types
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unsupported file type')),
      );
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

  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(child: Text(message)), 
        backgroundColor: Colors.red, 
        duration: const Duration(seconds: 2)
      ),
    );
  }
  
  // Phone back navigation handler
  Future<bool> _handlePhoneBackNavigation() async {
    if (_breadcrumbs.length > 1) {
      // Remove last breadcrumb
      _breadcrumbs.removeLast();
      await _navigateToBreadcrumb(_breadcrumbs.length - 1);
      return false; // Prevent default back navigation
    }
    return true; // Allow default back navigation
  }
  
  @override
  Widget build(BuildContext context) {
    // Wrap with WillPopScope for custom back navigation
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return;
        }
        await _handlePhoneBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Past Questions'),
          leading: (_breadcrumbs.length > 1) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_breadcrumbs.length > 1) {
                    _breadcrumbs.removeLast();
                    _navigateToBreadcrumb(_breadcrumbs.length - 1);
                  }
                },
              )
            : null,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(96),
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
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Drive Files Tab
            _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildDriveFilesView(),
            
            // Downloaded Files Tab
            _isLoadingDownloads
              ? const Center(child: CircularProgressIndicator())
              : _buildDownloadedFilesGrid(),
          ],
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
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  _breadcrumbs[i].name,
                  style: TextStyle(
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
                        PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: const [
                              Icon(Icons.visibility),
                              SizedBox(width: 8),
                              Text('View'),
                            ],
                          ),
                        ),
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
        childAspectRatio: 1,
        crossAxisSpacing: 16,
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
        
        // Get file size for display
        String? fileSize;
        if (!isDirectory && entity is File) {
          try {
            final sizeInBytes = entity.lengthSync();
            fileSize = _formatFileSize(sizeInBytes);
          } catch (e) {
            // Ignore file size errors
          }
        }
        
        return GestureDetector(
          onTap: isDirectory
            ? () => _navigateToLocalDirectory(entity.path)
            : () => _openFile(entity as File),
          child: Card(
            elevation: 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Fixed-size area for icon (about 60% of card height)
                    SizedBox(
                      height: constraints.maxHeight * 0.6,
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
                          size: 48,
                        ),
                      ),
                    ),
                    // Fixed-size area for text (about 40% of card height)
                    SizedBox(
                      height: constraints.maxHeight * 0.4,
                      width: constraints.maxWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (fileSize != null)
                              Text(
                                fileSize,
                                style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _navigateToLocalDirectory(String path) async {
    setState(() => _isLoadingDownloads = true);
    
    try {
      final dir = Directory(path);
      final List<FileSystemEntity> entities = await dir.list().toList();
      
      // Sort: directories first, then files
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        
        return a.path.split('/').last.compareTo(b.path.split('/').last);
      });
      
      // Get the relative path from base path
      String relativePath = path;
      if (relativePath.startsWith(_basePathToHide)) {
        relativePath = relativePath.substring(_basePathToHide.length);
        if (relativePath.startsWith('/')) {
          relativePath = relativePath.substring(1);
        }
      }
      
      // Create breadcrumbs based on the relative path
      final pathParts = relativePath.split('/');
      
      // Update UI
      setState(() {
        _downloadedFiles = entities;
        
        // Keep just the first breadcrumb (FUTApedia)
        if (_breadcrumbs.isNotEmpty) {
          _breadcrumbs = [_breadcrumbs[0]];
        }
        
        // Add breadcrumbs for each part of the path
        String currentPath = _basePathToHide;
        for (int i = 0; i < pathParts.length; i++) {
          if (pathParts[i].isEmpty) continue;
          currentPath = '$currentPath/${pathParts[i]}';
          _breadcrumbs.add(FolderBreadcrumb(
            name: pathParts[i],
            id: currentPath,
          ));
        }
      });
    } catch (e) {
      _showError('Failed to navigate to local directory');
    } finally {
      setState(() => _isLoadingDownloads = false);
    }
  }
}

// Utility class for breadcrumb navigation
class FolderBreadcrumb {
  final String name;
  final String id;

  FolderBreadcrumb({required this.name, required this.id});
}


 class SecureImageGalleryScreen extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const SecureImageGalleryScreen({
    Key? key, 
    required this.images, 
    this.initialIndex = 0
  }) : super(key: key);

  @override
  _SecureImageGalleryScreenState createState() => _SecureImageGalleryScreenState();
}

class _SecureImageGalleryScreenState extends State<SecureImageGalleryScreen> {
  late int _currentIndex;
  late PageController _pageController;
  late List<Future<Uint8List>> _decryptedImages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    
    // Pre-decrypt all images
    _decryptedImages = widget.images.map((image) async {
      try {
        return await PastQuestionEncryptionUtils.decryptFile(image.path);
      } catch (e) {
        print('Decryption error: $e');
        // Fallback to original file if decryption fails
        return await image.readAsBytes();
      }
    }).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image ${_currentIndex + 1} of ${widget.images.length}'),
      ),
      body: PhotoViewGallery.builder(
        itemCount: widget.images.length,
        pageController: _pageController,
        builder: (context, index) {
          return PhotoViewGalleryPageOptions.customChild(
            child: FutureBuilder<Uint8List>(
              future: _decryptedImages[index],
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2,
          );
        },
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}


// import 'dart:io';
// import 'dart:typed_data';
// import 'package:crypto/crypto.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_downloader/flutter_downloader.dart';
// import 'package:futapedia/pdfs/past%20questions/encrypt_util_past_question.dart';
// import 'package:futapedia/pdfs/past%20questions/google_drive_past_question.dart';
// import 'package:futapedia/pdfs/permission_manager.dart';
// import 'package:googleapis/drive/v3.dart' as drive;
// import 'package:path_provider/path_provider.dart';
// import 'package:photo_view/photo_view.dart';
// import 'package:photo_view/photo_view_gallery.dart';
// import 'package:routemaster/routemaster.dart';
// import 'dart:async'; // This will import Completer

// class PastQuestionDriveScreen extends StatefulWidget {
//   const PastQuestionDriveScreen({Key? key}) : super(key: key);

//   @override
//   _PastQuestionDriveScreenState createState() => _PastQuestionDriveScreenState();
// }

// class _PastQuestionDriveScreenState extends State<PastQuestionDriveScreen> with TickerProviderStateMixin {
//   final PastQuestionsDriveService _driveService = PastQuestionsDriveService();
//   List<drive.File> _currentFolderContents = [];
//   String _currentFolderId = '';
//   String _currentFolderName = 'Past Questions';
//   List<FolderBreadcrumb> _breadcrumbs = [];
//   bool _isLoading = false;
  
//   // Added for downloaded files
//   List<FileSystemEntity> _downloadedFiles = [];
//   bool _isLoadingDownloads = false;
//   String _basePathToHide = ''; // Path to hide from display
  
//   // final Set<String> _downloadingItems = <String>{};
  
//   // Modify the existing download tracking maps
//   Map<String, double> _downloadProgress = {};
//   Map<String, bool> _isDownloading = {};

  
//   // TabController for managing tabs
//   late TabController _tabController;
  
//   @override
//   void initState() {
//     super.initState();
//     _initializeDownloader();
//     _tabController = TabController(length: 2, vsync: this);
//     _initBasePathToHide();
//     _loadRootFolder();
    
//     _tabController.addListener(() {
//       if (_tabController.index == 1 && _downloadedFiles.isEmpty) {
//         _loadDownloadedFiles();
//       }
//     });
//   }
  
//   Future<void> _initializeDownloader() async {
//     // Only initialize if not already initialized
//     if (!FlutterDownloader.initialized) {
//       await FlutterDownloader.initialize(
//         debug: false, // Set to false in production
//       );
//     }
//   }

//   // Modify _handleDownload and _handleFolderDownload methods

//   Future<void> _handleDownload(drive.File item) async {
//     try {
//       final basePath = await _getDownloadPath();
      
//       // Create path that precisely mirrors the Google Drive structure
//       String relativePath = _breadcrumbs
//           .skip(1)  // Skip the root 'FUTApedia'
//           .map((crumb) => crumb.name)
//           .join('/');
      
//       final downloadPath = '$basePath/$relativePath';
//       final downloadDir = Directory(downloadPath);
//       if (!await downloadDir.exists()) {
//         await downloadDir.create(recursive: true);
//       }

//       // Directly download to the correct path, avoiding nested folder creation
//       await _driveService.downloadFileWithProgress(
//         item, 
//         downloadPath,
//         (progress) {
//           setState(() {
//             _downloadProgress[item.id!] = progress;
//           });
//         }
//       );
//       // Rest of the method remains the same
//     } catch (e) {
//       print('Download error: $e');
//     }
//   }

//   Future<void> _handleFolderDownload(drive.File folder) async {
//     try {
//       final basePath = await _getDownloadPath();
      
//       // Create path that precisely mirrors the Google Drive structure
//       String relativePath = _breadcrumbs
//           .skip(1)  // Skip the root 'FUTApedia'
//           .map((crumb) => crumb.name)
//           .join('/');
      
//       final downloadPath = '$basePath/$relativePath';
//       final downloadDir = Directory(downloadPath);
//       if (!await downloadDir.exists()) {
//         await downloadDir.create(recursive: true);
//       }

//       // Directly download to the correct path, avoiding nested folder creation
//       await _driveService.downloadFolderWithProgress(
//         folder, 
//         downloadPath,
//         (progress) {
//           setState(() {
//             _downloadProgress[folder.id!] = progress;
//           });
//         }
//       );
//       // Rest of the method remains the same
//     } catch (e) {
//       print('Folder download error: $e');
//     }
//   }

//   // NEW: Helper method to clear download state
//   // void _clearDownloadState(String itemId) {
//   //   setState(() {
//   //     _downloadingItems.remove(itemId);
//   //     _isDownloading.remove(itemId);
//   //     _downloadProgress.remove(itemId);
//   //   });
//   // }

//   Future<void> _initBasePathToHide() async {
//     final basePath = await _getDownloadPath();
//     setState(() {
//       _basePathToHide = basePath;
//       _breadcrumbs = [FolderBreadcrumb(name: 'Past Questions', id: basePath)];
//     });
//   }
  
//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }
  
//   Future<void> _loadRootFolder() async {
//     setState(() => _isLoading = true);
//     try {
//       final rootId = _driveService.getRootFolderId();
//       _currentFolderId = rootId;
//       _breadcrumbs = [FolderBreadcrumb(name: 'Past Questions', id: rootId)];
//       await _loadFolderContents(rootId);
//     } catch (e) {
//     // } finally {
//     //   setState(() => _isLoading = false);
//     }
//   }
  
//   Future<void> _loadFolderContents(String folderId) async {
//     setState(() => _isLoading = true);
//     try {
//       final contents = await _driveService.listFolderContents(folderId);
//       setState(() {
//         _currentFolderContents = contents;
//         _currentFolderId = folderId;
//       });
//     } catch (e) {
//       _showError('No Internet Connection. Click FUTApedia above to refresh');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
  
//   Future<void> _navigateToFolder(drive.File folder) async {
//     setState(() {
//       _currentFolderName = folder.name ?? 'Unnamed Folder';
//       _breadcrumbs.add(FolderBreadcrumb(name: _currentFolderName, id: folder.id!));
//     });
//     await _loadFolderContents(folder.id!);
//   }
  
//   Future<void> _navigateToBreadcrumb(int index) async {
//     setState(() {
//       _breadcrumbs = _breadcrumbs.sublist(0, index + 1);
//       // _currentFolderId = _breadcrumbs.last.id;
//       _currentFolderName = _breadcrumbs.last.name;
//     });
//     await _loadFolderContents(_currentFolderId);
//   }
  
//   Future<bool> _checkPermissions() async {
//     final hasPermission = await PermissionManager.requestStoragePermission(context);
    
//     if (!hasPermission) {
//       if (!mounted) return false;
      
//       _showError('Cannot proceed without storage access. You can try again later.');
//       return false;
//     }
    
//     return true;
//   }
  
//   Future<String> _getDownloadPath() async {
//     try {
//       final directory = await getApplicationDocumentsDirectory();
//       final path = '${directory.path}/PastQuestion';
      
//       // Create the directory if it doesn't exist
//       await Directory(path).create(recursive: true);
      
//       return path;
//     } catch (err) {
//       // print('Error creating download path: $err');
//       throw Exception('Failed to create download directory');
//     }
//   }

  
//   Future<void> _loadDownloadedFiles() async {
//     if (!await _checkPermissions()) return;
    
//     setState(() => _isLoading = true);
    
//     try {
//       final basePath = await _getDownloadPath();
//       String relativePath = _breadcrumbs
//           .skip(1)  // Skip the root 'FUTApedia'
//           .map((crumb) => crumb.name)
//           .join('/');
      
//       final directoryPath = '$basePath/$relativePath';
//       final directory = Directory(directoryPath);
      
//       if (await directory.exists()) {
//         final files = await directory.list().toList();
        
//         // Sort directories first, then files
//         files.sort((a, b) {
//           final aIsDir = a is Directory;
//           final bIsDir = b is Directory;
          
//           if (aIsDir && !bIsDir) return -1;
//           if (!aIsDir && bIsDir) return 1;
          
//           return a.path.split('/').last.compareTo(b.path.split('/').last);
//         });
        
//         setState(() {
//           _downloadedFiles = files;
//           _basePathToHide = basePath;
//         });
//       } else {
//         setState(() {
//           _downloadedFiles = [];
//         });
//       }
//     } catch (e) {
//       _showError('Failed to load downloaded files');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
  
//   // Helper method to format file size
//   String _formatFileSize(int bytes) {
//     if (bytes < 1024) return '$bytes B';
//     if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
//     if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
//     return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
//   }
  
//   Future<void> _downloadFile(drive.File file) async {
//     if (!await _checkPermissions()) return;
    
//     try {
//       final basePath = await _getDownloadPath();
      
//       // Create path that mirrors the Google Drive structure
//       String relativePath = '';
//       for (int i = 1; i < _breadcrumbs.length; i++) {
//         relativePath += '/${_breadcrumbs[i].name}';
//       }
      
//       final downloadPath = '$basePath$relativePath';
//       final downloadDir = Directory(downloadPath);
//       if (!await downloadDir.exists()) {
//         await downloadDir.create(recursive: true);
//       }
      
//       // Use existing download method with progress
//       final downloadedPath = await _driveService.downloadFileWithProgress(
//         file, 
//         downloadPath,
//         (progress) {
//           // Optional: You can implement a way to track overall progress if needed
//           print('Download progress: $progress');
//         }
//       );
      
//       // Encrypt the file if required
//       if (PastQuestionEncryptionUtils.shouldEncrypt(downloadedPath)) {
//         final encryptedPath = '${downloadedPath}_encrypted';
//         await PastQuestionEncryptionUtils.encryptFile(downloadedPath, encryptedPath);
        
//         // Replace the original file with the encrypted version
//         await File(downloadedPath).delete();
//         await File(encryptedPath).rename(downloadedPath);
//       }
      
//       // Reload downloaded files
//       await _loadDownloadedFiles();
      
//       // Switch to Downloads tab
//       _tabController.animateTo(1);
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Downloaded ${file.name}'),
//           duration: const Duration(seconds: 2),
//         ),
//       );
//     } catch (e) {
//       _showError('Failed to download file');
//     }
//   }

//   void _openImage(File imageFile) {
//     // Create a list of image files from downloaded files
//     final imageFiles = _downloadedFiles
//         .where((file) => 
//           file is File && 
//           ['.jpg', '.jpeg', '.png', '.gif', '.bmp']
//             .any((ext) => file.path.toLowerCase().endsWith(ext))
//         )
//         .cast<File>()
//         .toList();
    
//     // Find the index of the current image
//     final initialIndex = imageFiles.indexWhere((file) => file.path == imageFile.path);
    
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => SecureImageGalleryScreen(
//           images: imageFiles,
//           initialIndex: initialIndex,
//         ),
//       ),
//     );
//   }
  

//   Future<void> _downloadFolder(drive.File folder) async {
//     if (!await _checkPermissions()) return;
    
//     try {
//       final basePath = await _getDownloadPath();
      
//       // Create path that mirrors the Google Drive structure
//       String relativePath = '';
//       for (int i = 1; i < _breadcrumbs.length; i++) {
//         relativePath += '/${_breadcrumbs[i].name}';
//       }
      
//       final downloadPath = '$basePath$relativePath/${folder.name}';
//       final downloadDir = Directory(downloadPath);
//       if (!await downloadDir.exists()) {
//         await downloadDir.create(recursive: true);
//       }
      
//       // Download folder with progress tracking
//       await _driveService.downloadFolderWithProgress(
//         folder, 
//         downloadPath,
//         (progress) {
//           // Optional: Track overall folder download progress
//           print('Folder download progress: $progress');
//         }
//       );
      
//       // Encrypt the entire downloaded folder
//       // final folderName = folder.name ?? 'unnamed_folder';
//       final fullFolderPath = '$downloadPath';
//       await PastQuestionDownloadedFolderEncryptionService.encryptDownloadedFolder(fullFolderPath);
      
//       // Load downloaded files
//       await _loadDownloadedFiles();
      
//       // Switch to Downloads tab
//       _tabController.animateTo(1);
      
//       ScaffoldMessenger.of(context).showSnackBar(         
//         SnackBar(
//           content: Text('Downloaded and encrypted folder ${folder.name}'),
//           duration: const Duration(seconds: 2),
//         ),
//       );
//     } catch (e) {
//       _showError('Failed to download folder');
//     }
//   }
  
//   // First, let's modify _openFile method in PastQuestionDriveScreen
//   void _openFile(File file) {
//     final path = file.path;
//     final lowerPath = path.toLowerCase();
    
//     if (lowerPath.endsWith('.pdf')) {
//       // Use encrypted PDF viewer 
//       Routemaster.of(context).push('/encrypted_pdfviewer?filePath=${Uri.encodeComponent(path)}');
//     } else if (['.jpg', '.jpeg', '.png', '.gif', '.bmp'].any((ext) => lowerPath.endsWith(ext))) {
//       // Open image with photo viewer
//       _openImage(file);
//     } else {
//       // For unsupported file types
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Unsupported file type')),
//       );
//     }
//   }

//   void _showError(String message) {
//     if(!mounted)return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Center(child: Text(message)), backgroundColor: Colors.red, duration: Duration(microseconds: 300)),
//     );
//   }

//   Future<bool> _onWillPop() {
//     // If we have more than one breadcrumb, navigate back
//     if (_breadcrumbs.length > 1) {
//       _breadcrumbs.removeLast();
//       _navigateToBreadcrumb(_breadcrumbs.length - 1);
//       return Future.value(false); // Prevent default back button behavior
//     }
    
//     // If only one breadcrumb, allow default back navigation
//     return Future.value(true);
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: _onWillPop,
//         child: Scaffold(
//           appBar: AppBar(
//             title: Text('Past Questions'),
//             leading: (_breadcrumbs.length > 1) 
//               ? IconButton(
//                   icon: const Icon(Icons.arrow_back),
//                   onPressed: () {
//                     if (_breadcrumbs.length > 1) {
//                       _breadcrumbs.removeLast();
//                       _navigateToBreadcrumb(_breadcrumbs.length - 1);
//                     }
//                   },
//                 )
//               : null,
//             bottom: PreferredSize(
//               preferredSize: const Size.fromHeight(96), // Increased height for both tabs and breadcrumbs
//               child: Column(
//                 children: [
//                   // TabBar
//                   TabBar(
//                     controller: _tabController,
//                     tabs: const [
//                       Tab(
//                         icon: Icon(Icons.cloud),
//                         text: 'Drive Files',
//                       ),
//                       Tab(
//                         icon: Icon(Icons.download),
//                         text: 'Downloaded',
//                       ),
//                     ],
//                   ),
//                   // Breadcrumb navigation
//                   Container(
//                     height: 48,
//                     alignment: Alignment.centerLeft,
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     child: SingleChildScrollView(
//                       scrollDirection: Axis.horizontal,
//                       child: Row(
//                         children: [
//                           for (int i = 0; i < _breadcrumbs.length; i++)
//                             Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 InkWell(
//                                   onTap: () => _navigateToBreadcrumb(i),
//                                   child: Padding(
//                                     padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
//                                     child: Text(
//                                       _breadcrumbs[i].name,
//                                       style: TextStyle(
//                                         color: Theme.of(context).primaryColor,
//                                         fontWeight: i == _breadcrumbs.length - 1
//                                             ? FontWeight.bold
//                                             : FontWeight.normal,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 if (i < _breadcrumbs.length - 1)
//                                   const Icon(Icons.chevron_right, size: 18),
//                               ],
//                             ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           body: TabBarView(
//             controller: _tabController,
//             children: [
//               // Drive Files Tab
//               _isLoading 
//                 ? const Center(child: CircularProgressIndicator())
//                 : _buildDriveFilesView(),
              
//               // Downloaded Files Tab
//               _isLoadingDownloads
//                 ? const Center(child: CircularProgressIndicator())
//                 : _buildDownloadedFilesGrid(),
//             ],
//           ),
//         ),
//     );
//   }
  
//   Widget _buildDriveFilesView() {
//     if (_currentFolderContents.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.folder_open, size: 48, color: Colors.grey),
//             const SizedBox(height: 16),
//             Text(
//               'This folder is empty',
//               style: Theme.of(context).textTheme.titleLarge,
//             ),
//           ],
//         ),
//       );
//     }
    
//     return ListView.builder(
//       itemCount: _currentFolderContents.length,
//       itemBuilder: (context, index) {
//         final item = _currentFolderContents[index];
//         final isItemFolder = _driveService.isFolder(item);
        
//         return ListTile(
//           leading: Icon(
//             isItemFolder 
//               ? Icons.folder 
//               : _driveService.isImage(item) 
//                 ? Icons.image 
//                 : Icons.insert_drive_file,
//             color: isItemFolder 
//               ? Colors.amber 
//               : _driveService.isImage(item) 
//                 ? Colors.green 
//                 : Colors.grey,
//           ),
//           title: Text(item.name ?? 'Unnamed'),
//           // Add file size as subtitle
//           subtitle: !isItemFolder && item.size != null
//               ? Text(_formatFileSize(int.parse(item.size!)))
//               : null,
//           onTap: isItemFolder
//               ? () => _navigateToFolder(item)
//               : () => _downloadFile(item),
//           trailing: _isDownloading[item.id] == true
//       ? SizedBox(
//           width: 48,
//           height: 48,
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               CircularProgressIndicator(
//                 value: _downloadProgress[item.id],
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//                 strokeWidth: 4.0,
//               ),
//               Text(
//                 '${((_downloadProgress[item.id] ?? 0) * 100).toInt()}%',
//                 style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//         )
//       : isItemFolder
//         ? PopupMenuButton(
//             itemBuilder: (context) => [
//               PopupMenuItem(
//                 value: 'download',
//                 child: Row(
//                   children: const [
//                     Icon(Icons.download),
//                     SizedBox(width: 8),
//                     Text('Download'),
//                   ],
//                 ),
//               ),
//             ],
//             onSelected: (value) {
//               if (value == 'download') {
//                 _handleFolderDownload(item);
//               }
//             },
//           )
//         : PopupMenuButton(
//             itemBuilder: (context) => [
//               PopupMenuItem(
//                 value: 'download',
//                 child: Row(
//                   children: const [
//                     Icon(Icons.download),
//                     SizedBox(width: 8),
//                     Text('Download'),
//                   ],
//                 ),
//               ),
//             ],
//             onSelected: (value) {
//               if (value == 'download') {
//                 _handleDownload(item);
//               }
//             },
//           ),
//          );
//       },
//     );
//   }

  
//   Widget _buildDownloadedFilesGrid() {
//     if (_downloadedFiles.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.download_done, size: 48, color: Colors.grey),
//             const SizedBox(height: 16),
//             Text(
//               'No downloaded files',
//               style: Theme.of(context).textTheme.titleLarge,
//             ),
//           ],
//         ),
//       );
//     }
    
//     return GridView.builder(
//       padding: const EdgeInsets.all(16),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 5,
//         childAspectRatio: 1,
//         crossAxisSpacing: 16,
//         mainAxisSpacing: 16,
//       ),
//       itemCount: _downloadedFiles.length,
//       itemBuilder: (context, index) {
//         final entity = _downloadedFiles[index];
        
//         // Get relative path by removing the base path to hide
//         String displayPath = entity.path;
//         if (displayPath.startsWith(_basePathToHide)) {
//           displayPath = displayPath.substring(_basePathToHide.length);
//           // Remove leading slash if present
//           if (displayPath.startsWith('/')) {
//             displayPath = displayPath.substring(1);
//           }
//         }
        
//         // Get just the name from the path
//         final name = displayPath.split('/').last;
//         final isDirectory = entity is Directory;
//         final isPdf = name.toLowerCase().endsWith('.pdf');
        
//         // Get file size for display
//         String? fileSize;
//         if (!isDirectory && entity is File) {
//           try {
//             final sizeInBytes = entity.lengthSync();
//             fileSize = _formatFileSize(sizeInBytes);
//           } catch (e) {
//             // Ignore file size errors
//           }
//         }
        
//         return GestureDetector(
//           onTap: isDirectory
//             ? () => _navigateToLocalDirectory(entity.path)
//             : () => _openFile(entity as File),
//           child: Card(
//             elevation: 3,
//             child: LayoutBuilder(
//               builder: (context, constraints) {
//                 return Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     // Fixed-size area for icon (about 60% of card height)
//                     SizedBox(
//                       height: constraints.maxHeight * 0.6,
//                       child: Center(
//                         child: Icon(
//                           isDirectory
//                             ? Icons.folder
//                             : isPdf
//                               ? Icons.picture_as_pdf
//                               : Icons.insert_drive_file,
//                           color: isDirectory
//                             ? Colors.amber
//                             : isPdf
//                               ? Colors.red
//                               : Colors.grey,
//                           size: 48,
//                         ),
//                       ),
//                     ),
//                     // Fixed-size area for text (about 40% of card height)
//                     SizedBox(
//                       height: constraints.maxHeight * 0.4,
//                       width: constraints.maxWidth,
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 4),
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Text(
//                               name,
//                               textAlign: TextAlign.center,
//                               maxLines: 2,
//                               overflow: TextOverflow.ellipsis,
//                               style: const TextStyle(fontSize: 12),
//                             ),
//                             if (fileSize != null)
//                               Text(
//                                 fileSize,
//                                 style: const TextStyle(fontSize: 9.5, color: Colors.grey),
//                               ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 );
//               }
//             ),
//           ),
//         );
//       },
//     );
//   }
  
//   Future<void> _navigateToLocalDirectory(String path) async {
//     setState(() => _isLoading = true);
    
//     try {
//       final dir = Directory(path);
//       final List<FileSystemEntity> entities = await dir.list().toList();
      
//       // Sort: directories first, then files
//       entities.sort((a, b) {
//         final aIsDir = a is Directory;
//         final bIsDir = b is Directory;
        
//         if (aIsDir && !bIsDir) return -1;
//         if (!aIsDir && bIsDir) return 1;
        
//         return a.path.split('/').last.compareTo(b.path.split('/').last);
//       });
      
//       // Get the relative path from base path
//       String relativePath = path;
//       if (relativePath.startsWith(_basePathToHide)) {
//         relativePath = relativePath.substring(_basePathToHide.length);
//         if (relativePath.startsWith('/')) {
//           relativePath = relativePath.substring(1);
//         }
//       }
      
//       // Create breadcrumbs based on the relative path
//       final pathParts = relativePath.split('/');
      
//       // Update UI
//       setState(() {
//         _downloadedFiles = entities;
        
//         // Keep the FUTApedia root breadcrumb
//         if (_breadcrumbs.isNotEmpty) {
//           _breadcrumbs = [_breadcrumbs[0]];
//         }
        
//         // Add breadcrumbs for each part of the path
//         String currentPath = _basePathToHide;
//         for (int i = 0; i < pathParts.length; i++) {
//           if (pathParts[i].isEmpty) continue;
//           currentPath = '$currentPath/${pathParts[i]}';
//           _breadcrumbs.add(FolderBreadcrumb(
//             name: pathParts[i],
//             id: currentPath,
//           ));
//         }
//       });
//     } catch (e) {
//       _showError('Failed to navigate to directory');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<bool> _shouldDownload(drive.File item, String downloadPath) async {
//     final itemName = item.name ?? 'unnamed';
//     final fullPath = '$downloadPath/$itemName';

//     // Check if it's a folder
//     if (_driveService.isFolder(item)) {
//       return await _checkFolderNeedsUpdate(item, fullPath);
//     } 
//     // Check if it's a file
//     else {
//       return await _checkFileNeedsUpdate(item, fullPath);
//     }
//   }

//   // Generate a hash for a file to check for changes
//   Future<String> _generateFileHash(File file) async {
//     try {
//       final bytes = await file.readAsBytes();
//       return md5.convert(bytes).toString();
//     } catch (e) {
//       print('Error generating hash for ${file.path}: $e');
//       return '';
//     }
//   }

//   // Compare Google Drive file metadata with local file
//   Future<bool> _checkFileNeedsUpdate(drive.File driveFile, String localPath) async {
//     final localFile = File(localPath);

//     // If file doesn't exist, we need to download
//     if (!await localFile.exists()) {
//       return true;
//     }

//     // Compare file sizes
//     final localFileSize = await localFile.length();
//     final driveFileSize = driveFile.size != null 
//       ? int.tryParse(driveFile.size!) 
//       : null;

//     if (driveFileSize != null && localFileSize != driveFileSize) {
//       return true;
//     }

//     // If size matches, do a content hash check
//     final localFileHash = await _generateFileHash(localFile);
    
//     // You might want to implement a way to get file hash from Google Drive 
//     // This is a placeholder - in reality, you'd need to fetch the file's hash 
//     // or content hash from Google Drive API
//     final driveFileHash = localFileHash; // Replace with actual drive file hash check

//     return localFileHash != driveFileHash;
//   }

//   // Check if folder contents need updating
//   Future<bool> _checkFolderNeedsUpdate(drive.File driveFolder, String localFolderPath) async {
//     final localFolder = Directory(localFolderPath);

//     // If folder doesn't exist, we need to download
//     if (!await localFolder.exists()) {
//       return true;
//     }

//     // Get contents of the drive folder
//     final folderContents = await _driveService.listFolderContents(driveFolder.id!);

//     // Check each file/subfolder
//     for (var item in folderContents) {
//       final itemName = item.name ?? 'unnamed';
//       final localItemPath = '$localFolderPath/$itemName';

//       // Recursively check if each item needs updating
//       if (await _shouldDownload(item, localFolderPath)) {
//         return true;
//       }
//     }

//     // No updates needed
//     return false;
//   }
// }

// class FolderBreadcrumb {
//   final String name;
//   final String id;
  
//   FolderBreadcrumb({required this.name, required this.id});
// }






// class SecureImageGalleryScreen extends StatefulWidget {
//   final List<File> images;
//   final int initialIndex;

//   const SecureImageGalleryScreen({
//     Key? key, 
//     required this.images, 
//     this.initialIndex = 0
//   }) : super(key: key);

//   @override
//   _SecureImageGalleryScreenState createState() => _SecureImageGalleryScreenState();
// }

// class _SecureImageGalleryScreenState extends State<SecureImageGalleryScreen> {
//   late int _currentIndex;
//   late PageController _pageController;
//   late List<Future<Uint8List>> _decryptedImages;

//   @override
//   void initState() {
//     super.initState();
//     _currentIndex = widget.initialIndex;
//     _pageController = PageController(initialPage: _currentIndex);
    
//     // Pre-decrypt all images
//     _decryptedImages = widget.images.map((image) async {
//       try {
//         return await PastQuestionEncryptionUtils.decryptFile(image.path);
//       } catch (e) {
//         print('Decryption error: $e');
//         // Fallback to original file if decryption fails
//         return await image.readAsBytes();
//       }
//     }).toList();
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Image ${_currentIndex + 1} of ${widget.images.length}'),
//       ),
//       body: PhotoViewGallery.builder(
//         itemCount: widget.images.length,
//         pageController: _pageController,
//         builder: (context, index) {
//           return PhotoViewGalleryPageOptions.customChild(
//             child: FutureBuilder<Uint8List>(
//               future: _decryptedImages[index],
//               builder: (context, snapshot) {
//                 if (snapshot.hasData) {
//                   return Image.memory(
//                     snapshot.data!,
//                     fit: BoxFit.contain,
//                   );
//                 }
//                 return const Center(child: CircularProgressIndicator());
//               },
//             ),
//             minScale: PhotoViewComputedScale.contained * 0.8,
//             maxScale: PhotoViewComputedScale.covered * 2,
//           );
//         },
//         onPageChanged: (index) {
//           setState(() {
//             _currentIndex = index;
//           });
//         },
//         loadingBuilder: (context, event) => const Center(
//           child: CircularProgressIndicator(),
//         ),
//       ),
//     );
//   }
// }
