// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_downloader/flutter_downloader.dart';
// import 'package:futapedia/pdfs/lecture%20notes/downloader.dart';
// // import 'package:futapedia/pdfs/encrypt_utils.dart';
// // import 'package:futapedia/pdfs/lecture%20notes/google_drive_pdf.dart';
// import 'package:futapedia/study_material/pdf/pdf_drive.dart';
// import 'package:futapedia/study_material/services/permission_manager.dart';
// // ignore: unused_import
// import 'package:googleapis/drive/v3.dart' as drive;
// // import 'package:open_file/open_file.dart';
// import 'package:routemaster/routemaster.dart';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// import 'dart:async'; // This will import Completer

// class DriveExplorerScreen extends StatefulWidget {
//   const DriveExplorerScreen({Key? key}) : super(key: key);

//   @override
//   _DriveExplorerScreenState createState() => _DriveExplorerScreenState();
// }

// class _DriveExplorerScreenState extends State<DriveExplorerScreen> with TickerProviderStateMixin {
//   final GoogleDriveServicePDF _driveService = GoogleDriveServicePDF();
//   final BackgroundDownloaderService _downloaderService = BackgroundDownloaderService();
//   List<drive.File> _currentFolderContents = [];
//   String _currentFolderId = '';
//   String _currentFolderName = 'FUTApedia';
//   List<FolderBreadcrumb> _breadcrumbs = [];
//   bool _isLoading = false;
  
//   // Added for downloaded files
//   List<FileSystemEntity> _downloadedFiles = [];
//   bool _isLoadingDownloads = false;
//   String _basePathToHide = ''; // Path to hide from display
  
//   // Track download progress and status
//   Map<String, double> _downloadProgress = {};
//   Map<String, bool> _isDownloading = {};
//   // Map<String, String> _downloadTaskIds = {}; // Track task IDs
  
//   // TabController for managing tabs
//   late TabController _tabController;
  
//   // Subscriptions for download events
//   late StreamSubscription<DownloadProgress> _progressSubscription;
//   late StreamSubscription<DownloadStatus> _statusSubscription;
  
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _initDownloader();
//     _initBasePathToHide();
//     _loadRootFolder();
    
//     // Add listener to load downloaded files when switching to downloads tab
//     _tabController.addListener(() {
//       if (_tabController.index == 1 && _downloadedFiles.isEmpty) {
//         _loadDownloadedFiles();
//       }
//     });
//   }
  
//   Future<void> _initDownloader() async {
//     // Initialize downloader service
//     // await _downloaderService.initializeFlutterDownloader();
    
//     // Listen for download progress updates
//     _progressSubscription = _downloaderService.downloadProgressStream.listen((event) {
//       setState(() {
//         _downloadProgress[event.driveFileId] = event.progress;
//       });
//     });
    
//     // Listen for download status updates
//     _statusSubscription = _downloaderService.downloadStatusStream.listen((event) {
//       if (event.status == DownloadTaskStatus.complete) {
//         setState(() {
//           _isDownloading[event.driveFileId] = false;
//         });
        
//         // Reload downloads list if we're on the downloads tab
//         if (_tabController.index == 1) {
//           _loadDownloadedFiles();
//         }
        
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Downloaded ${event.fileName}'),
//               duration: const Duration(seconds: 2),
//             ),
//           );
//         }
//       } else if (event.status == DownloadTaskStatus.failed) {
//         setState(() {
//           _isDownloading[event.driveFileId] = false;
//         });
        
//         if (mounted) {
//           _showError('Failed to download ${event.fileName}');
//         }
//       }
//     });
//   }

//   Future<void> _initBasePathToHide() async {
//     final basePath = await _getDownloadPath();
//     _basePathToHide = basePath;
//   }
  
//   @override
//   void dispose() {
//     _progressSubscription.cancel();
//     _statusSubscription.cancel();
//     _downloaderService.dispose();
//     _tabController.dispose();
//     super.dispose();

//   }
  
//   Future<void> _loadRootFolder() async {
//     setState(() => _isLoading = true);
//     try {
//       final rootId = _driveService.getRootFolderId();
//       _currentFolderId = rootId;
//       _breadcrumbs = [FolderBreadcrumb(name: 'FUTApedia', id: rootId)];
//       await _loadFolderContents(rootId);
//     } catch (e) {
//     } finally {
//       setState(() => _isLoading = false);
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
//       _currentFolderId = _breadcrumbs.last.id;
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
//     return await PermissionManager.getAppropriateDownloadPath();
//   }
  
//   Future<void> _loadDownloadedFiles() async {
//      if (!await _checkPermissions()) return;
    
//     setState(() => _isLoadingDownloads = true);
    
//     try {
//       final basePath = await _getDownloadPath();
//       String relativePath = '';
//       for (int i = 1; i < _breadcrumbs.length; i++) {
//         relativePath += '/${_breadcrumbs[i].name}';
//       }
      
//       final directoryPath = '$basePath$relativePath';
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
//       setState(() => _isLoadingDownloads = false);
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
    
//     // Set initial download progress
//     setState(() {
//       _isDownloading[file.id!] = true;
//       _downloadProgress[file.id!] = 0.0;
//     });
    
//     try {
//       final basePath = await _getDownloadPath();
      
//       // Create path that mirrors the Google Drive structure
//       String relativePath = '';
//       for (int i = 1; i < _breadcrumbs.length; i++) {
//         relativePath += '/${_breadcrumbs[i].name}';
//       }
      
//       final filePath = '$basePath$relativePath';
//       final downloadDir = Directory(filePath);
//       if (!await downloadDir.exists()) {
//         await downloadDir.create(recursive: true);
//       }
      
//       // Use background downloader service
//       final downloadedPath = await _downloaderService.downloadFile(file, filePath);
      
//       // No need to manually reload downloads - this will happen via the status subscription
//       await _downloadFile(downloadedPath as drive.File);
//       // Switch to Downloads tab after successful download
//       _tabController.animateTo(1);
//     } catch (e) {
//       setState(() {
//         _isDownloading[file.id!] = false;
//       });
//       _showError('Failed to download file');
//     }
//   }

//   Future<void> _downloadAndOpenFile(drive.File file) async {
//     if (!await _checkPermissions()) return;

//     // Set initial download progress
//     setState(() {
//       _isDownloading[file.id!] = true;
//       _downloadProgress[file.id!] = 0.0;
//     });
    
//     try {
//       final basePath = await _getDownloadPath();
      
//       // Create path that mirrors the Google Drive structure
//       String relativePath = '';
//       for (int i = 1; i < _breadcrumbs.length; i++) {
//         relativePath += '/${_breadcrumbs[i].name}';
//       }
      
//       final filePath = '$basePath$relativePath';
//       final fileName = file.name ?? 'untitled';
//       final fullFilePath = '$filePath/$fileName';
      
//       // Check if file already exists
//       if (await File(fullFilePath).exists()) {
//         if (!mounted) return;
        
//         // Open existing file
//         Routemaster.of(context).push('/encrypted_pdfviewer?filePath=${Uri.encodeComponent(fullFilePath)}');
        
//         setState(() {
//           _isDownloading[file.id!] = false;
//         });
//         return;
//       }
      
//       // Use background downloader
//       final downloadedPath = await _downloaderService.downloadFile(file, filePath);
      
//       // Wait for download to complete via a Stream
//       final completer = Completer<void>();
//       late StreamSubscription<DownloadStatus> subscription;
      
//       subscription = _downloaderService.downloadStatusStream.listen((status) {
//         if (status.driveFileId == file.id && status.status == DownloadTaskStatus.complete) {
//           subscription.cancel();
//           completer.complete();
//         } else if (status.driveFileId == file.id && status.status == DownloadTaskStatus.failed) {
//           subscription.cancel();
//           completer.completeError('Download failed');
//         }
//       });
      
//       // Timeout after 5 minutes
//       Timer(const Duration(minutes: 5), () {
//         if (!completer.isCompleted) {
//           subscription.cancel();
//           completer.completeError('Download timeout');
//         }
//       });
      
//       await completer.future;
      
//       if (!mounted) return;
      
//       // Open the encrypted file directly in our viewer
//       Routemaster.of(context).push('/encrypted_pdfviewer?filePath=${Uri.encodeComponent(fullFilePath)}');
//     } catch (e) {
//       _showError('Failed to open file');
//     } finally {
//       setState(() {
//         _isDownloading[file.id!] = false;
//       });
//     }
//   }

//   Future<void> _downloadFolder(drive.File folder) async {
//     if (!await _checkPermissions()) return;
    
//     // Set initial download progress
//     setState(() {
//       _isDownloading[folder.id!] = true;
//       _downloadProgress[folder.id!] = 0.0;
//     });
    
//     try {
//       final basePath = await _getDownloadPath();
      
//       // Create path that mirrors the Google Drive structure
//       String relativePath = '';
//       for (int i = 1; i < _breadcrumbs.length; i++) {
//         relativePath += '/${_breadcrumbs[i].name}';
//       }
      
//       final downloadPath = '$basePath$relativePath';
      
//       // Use background downloader for folders
//       await _downloaderService.downloadFolder(
//         folder, 
//         downloadPath, 
//         _driveService, 
//         (progress) {
//           setState(() {
//             _downloadProgress[folder.id!] = progress;
//           });
//         }
//       );
      
//       // Load downloaded files after download completes
//       await _loadDownloadedFiles();
      
//       if (!mounted) return;
      
//       ScaffoldMessenger.of(context).showSnackBar(         
//         SnackBar(
//           content: Text('Downloaded folder ${folder.name}'),
//           duration: const Duration(seconds: 1),
//         ),
//       );
      
//       // Switch to Downloads tab after successful download
//       _tabController.animateTo(1);
//     } catch (e) {
//       _showError('An error has occured. Click the FUTApedia above to refresh');
//     } finally {
//       setState(() {
//         _isDownloading[folder.id!] = false;
//       });
//     }
//   }
  
//   // First, let's modify _openFile method in DriveExplorerScreen
//   void _openFile(File file) {
//     final path = file.path;
//     if (path.toLowerCase().endsWith('.pdf')) {
//       // Use encrypted PDF viewer instead of standard PDF viewer or external app
//       Routemaster.of(context).push('/encrypted_pdfviewer?filePath=${Uri.encodeComponent(path)}');
//     } else {
//       // For non-PDF files, you might want to prevent opening or implement similar encryption
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Only PDF files can be viewed in the app')),
//       );
//     }
//   }
  


//   void _showError(String message) {
//     if(!mounted)return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Center(child: Text(message)), backgroundColor: Colors.red, duration: Duration(seconds: 2)),
//     );
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Study Materials'),
//         leading: (_breadcrumbs.length > 1) 
//           ? IconButton(
//               icon: const Icon(Icons.arrow_back),
//               onPressed: () {
//                 if (_breadcrumbs.length > 1) {
//                   _breadcrumbs.removeLast();
//                   _navigateToBreadcrumb(_breadcrumbs.length - 1);
//                 }
//               },
//             )
//           : null,
//         bottom: PreferredSize(
//           preferredSize: const Size.fromHeight(96), // Increased height for both tabs and breadcrumbs
//           child: Column(
//             children: [
//               // TabBar
//               TabBar(
//                 controller: _tabController,
//                 tabs: const [
//                   Tab(
//                     icon: Icon(Icons.cloud),
//                     text: 'Drive Files',
//                   ),
//                   Tab(
//                     icon: Icon(Icons.download),
//                     text: 'Downloaded',
//                   ),
//                 ],
//               ),
//               // Breadcrumb navigation
//               Container(
//                 height: 48,
//                 alignment: Alignment.centerLeft,
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 child: SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: Row(
//                     children: [
//                       for (int i = 0; i < _breadcrumbs.length; i++)
//                         Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             InkWell(
//                               onTap: () => _navigateToBreadcrumb(i),
//                               child: Padding(
//                                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
//                                 child: Text(
//                                   _breadcrumbs[i].name,
//                                   style: TextStyle(
//                                     color: Theme.of(context).primaryColor,
//                                     fontWeight: i == _breadcrumbs.length - 1
//                                         ? FontWeight.bold
//                                         : FontWeight.normal,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             if (i < _breadcrumbs.length - 1)
//                               const Icon(Icons.chevron_right, size: 18),
//                           ],
//                         ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           // Drive Files Tab
//           _isLoading 
//             ? const Center(child: CircularProgressIndicator())
//             : _buildDriveFilesView(),
          
//           // Downloaded Files Tab
//           _isLoadingDownloads
//             ? const Center(child: CircularProgressIndicator())
//             : _buildDownloadedFilesGrid(),
//         ],
//       ),
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
//             isItemFolder ? Icons.folder : Icons.picture_as_pdf,
//             color: isItemFolder ? Colors.amber : Colors.red,
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
//             ? SizedBox(
//                 width: 48,
//                 height: 48,
//                 child: Stack(
//                   alignment: Alignment.center,
//                   children: [
//                     CircularProgressIndicator(
//                       value: _downloadProgress[item.id],
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//                       strokeWidth: 4.0,
//                     ),
//                     Text(
//                       '${(_downloadProgress[item.id] ?? 0 * 100).toInt()}%',
//                       style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//               )
//               : isItemFolder
//                   ? PopupMenuButton(
//                       itemBuilder: (context) => [
//                         PopupMenuItem(
//                           value: 'download',
//                           child: Row(
//                             children: const [
//                               Icon(Icons.download),
//                               SizedBox(width: 8),
//                               Text('Download'),
//                             ],
//                           ),
//                         ),
//                       ],
//                       onSelected: (value) {
//                         if (value == 'download') {
//                           _downloadFolder(item);
//                         }
//                       },
//                     )
//                   : PopupMenuButton(
//                       itemBuilder: (context) => [
//                         PopupMenuItem(
//                           value: 'download',
//                           child: Row(
//                             children: const [
//                               Icon(Icons.download),
//                               SizedBox(width: 8),
//                               Text('Download'),
//                             ],
//                           ),
//                         ),
//                       ],
//                       onSelected: (value) {
//                         if (value == 'download') {
//                           _downloadFile(item);
//                         } else if (value == 'view') {
//                           _downloadAndOpenFile(item);
//                         }
//                       },
//                     ),
//         );
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
//     setState(() => _isLoadingDownloads = true);
    
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
        
//         // Update breadcrumbs based on relative path
//         // Keep just the first breadcrumb (FUTApedia)
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
//     } finally {
//       setState(() => _isLoadingDownloads = false);
//     }
//   }
// }

// class FolderBreadcrumb {
//   final String name;
//   final String id;
  
//   FolderBreadcrumb({required this.name, required this.id});
// }

// class PdfViewerScreen extends StatelessWidget {
//   final String filePath;
  
//   const PdfViewerScreen({Key? key, required this.filePath}) : super(key: key);
  
//   @override
//   Widget build(BuildContext context) {
//     // Extract just the filename from the path, without any temporary components
//     final fileName = filePath.split('/').last;
//     // Remove any .temp_ prefix if it exists
//     final cleanFileName = fileName.startsWith('.temp_') 
//         ? fileName.substring(6) // Remove '.temp_' prefix
//         : fileName;
        
//     return Scaffold(
//         appBar: AppBar(
//           title: Text(cleanFileName),
//         ),
//         body: SfPdfViewer.file(
//           File(filePath),
//           enableDoubleTapZooming: true,
//       ),
//     );
//   }
// }