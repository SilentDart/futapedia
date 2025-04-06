import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:futapedia/study_material/pdf/pdf_drive.dart';
import 'package:futapedia/study_material/services/notification_manager.dart';
import 'package:futapedia/study_material/services/encrypted_pdfviewer.dart';
// import 'package:futapedia/pdfs/lecture%20notes/google_drive_pdf.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:open_file/open_file.dart';
import 'dart:io';

import 'package:path/path.dart' as path;

void main() {
  runApp(MaterialApp(
    theme: ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
    ),
    home: GoogleDriveManagerScreen(),
  ));
}

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
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
          FlutterLocalNotificationsPlugin();
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
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Futapedia Drive'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Drive', icon: Icon(Icons.cloud)),
            Tab(text: 'Downloads', icon: Icon(Icons.download)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DriveExplorerTab(),
          DownloadedFilesTab(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    GoogleDriveDownloader.dispose();
    NotificationDownloadManager().dispose();
    super.dispose();
  }
}

// Tab for browsing Google Drive content
class DriveExplorerTab extends StatefulWidget {
  const DriveExplorerTab({Key? key}) : super(key: key);

  @override
  _DriveExplorerTabState createState() => _DriveExplorerTabState();
}

class _DriveExplorerTabState extends State<DriveExplorerTab> {
  List<Map<String, dynamic>> _driveItems = [];
  bool _isLoading = true;
  String _currentFolderId = 'root'; // Start with root folder
  List<Map<String, String>> _folderBreadcrumbs = [{'id': 'root', 'name': 'My Drive'}];

  @override
  void initState() {
    super.initState();
    _loadDriveContents();
  }

  Future<void> _loadDriveContents() async {
  setState(() {
    _isLoading = true;
  });

  try {
    // Create instance of GoogleDriveServicePDF
    final driveService = GoogleDriveServicePDF();
    
    // Get the drive API instance
    final driveApi = await driveService.driveApi;
    if (driveApi == null) {
      throw Exception('Failed to initialize Google Drive API');
    }
    
    // Query to find files in the current folder
    final query = _currentFolderId == 'root' 
      ? "'${driveService.getRootFolderId()}' in parents and trashed = false"
      : "'$_currentFolderId' in parents and trashed = false";
    
    // Request files with necessary fields
    final fileList = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name, mimeType, size)',
    );
    
    // Convert to the format your app expects
    _driveItems = (fileList.files ?? []).map((file) {
      final isFolder = file.mimeType == 'application/vnd.google-apps.folder';
      return {
        'id': file.id!,
        'name': file.name ?? 'Unnamed',
        'type': isFolder ? 'folder' : 'file',
        'mimeType': file.mimeType ?? 'application/octet-stream',
        'size': file.size,
      };
    }).toList();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading drive contents: $e')),
    );
    _driveItems = [];
  }

  if (mounted) {
    setState(() {
      _isLoading = false;
    });
  }
}

  void _navigateToFolder(String folderId, String folderName) {
    setState(() {
      _currentFolderId = folderId;
      _folderBreadcrumbs.add({'id': folderId, 'name': folderName});
    });
    _loadDriveContents();
  }

  void _navigateUp() {
    if (_folderBreadcrumbs.length > 1) {
      setState(() {
        _folderBreadcrumbs.removeLast(); // Remove current folder
        _currentFolderId = _folderBreadcrumbs.last['id']!;
      });
      _loadDriveContents();
    }
  }

  Future<void> _downloadItem(Map<String, dynamic> item) async {
    try {
      final driveService = GoogleDriveServicePDF();
      final notificationManager = NotificationDownloadManager();
      
      // Create a directory for downloads if it doesn't exist
      final String downloadDirPath = await GoogleDriveDownloader.getDownloadDirectory();
      
      // Convert the String path to a Directory object
      final downloadDir = Directory(downloadDirPath);
      
      if (item['type'] == 'folder') {
        // For folders, we need to create a drive.File object
        final folderFile = drive.File()
          ..id = item['id']
          ..name = item['name']
          ..mimeType = 'application/vnd.google-apps.folder';
        
        // Use notification download manager
        await notificationManager.downloadFolderWithNotification(
          folderFile,
          downloadDir,  // Now passing a Directory object
          driveService,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder download complete: ${item['name']}')),
          );
        }
      } else {
        // For files, create a drive.File object
        final driveFile = drive.File()
          ..id = item['id']
          ..name = item['name']
          ..mimeType = item['mimeType']
          ..size = item['size'];
        
        // Use notification download manager
        final filePath = await notificationManager.downloadFileWithNotification(
          driveFile,
          downloadDir,  // Now passing a Directory object
          driveService,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File downloaded: ${item['name']}'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  OpenFile.open(filePath);
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Breadcrumb navigation
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                if (_folderBreadcrumbs.length > 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _navigateUp,
                    tooltip: 'Go back',
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _folderBreadcrumbs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final breadcrumb = entry.value;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: index < _folderBreadcrumbs.length - 1
                                  ? () {
                                      setState(() {
                                        _currentFolderId = breadcrumb['id']!;
                                        _folderBreadcrumbs = _folderBreadcrumbs.sublist(0, index + 1);
                                      });
                                      _loadDriveContents();
                                    }
                                  : null,
                              child: Text(
                                breadcrumb['name']!,
                                style: TextStyle(
                                  color: index < _folderBreadcrumbs.length - 1 ? Colors.blue : Colors.black,
                                ),
                              ),
                            ),
                            if (index < _folderBreadcrumbs.length - 1) 
                              const Text(' > ', style: TextStyle(color: Colors.grey)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Drive items list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _driveItems.isEmpty
                    ? const Center(child: Text('This folder is empty'))
                    : RefreshIndicator(
                        onRefresh: _loadDriveContents,
                        child: ListView.builder(
                          itemCount: _driveItems.length,
                          itemBuilder: (context, index) {
                            final item = _driveItems[index];
                            final isFolder = item['type'] == 'folder';
                            
                            return ListTile(
                              leading: Icon(
                                isFolder ? Icons.folder : _getFileIcon(item['name']),
                                color: isFolder ? Colors.amber : Colors.blue,
                              ),
                              title: Text(item['name']),
                              subtitle: Text(isFolder ? 'Folder' : _getFileType(item['name'])),
                              onTap: isFolder
                                  ? () => _navigateToFolder(item['id'], item['name'])
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () => _downloadItem(item),
                                tooltip: 'Download',
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'PDF Document';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'Image';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'xls':
      case 'xlsx':
        return 'Excel Spreadsheet';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint Presentation';
      default:
        return 'File';
    }
  }
}

// Tab for viewing downloaded files
class DownloadedFilesTab extends StatefulWidget {
  const DownloadedFilesTab({Key? key}) : super(key: key);

  @override
  _DownloadedFilesTabState createState() => _DownloadedFilesTabState();
}

class _DownloadedFilesTabState extends State<DownloadedFilesTab> {
  List<FileSystemEntity> _allFiles = [];
  List<FileSystemEntity> _displayedFiles = [];
  String _currentPath = '';
  bool _isLoading = true;
  List<String> _folderBreadcrumbs = [];

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  Future<void> _loadDownloadedFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await GoogleDriveDownloader.getDownloadedFiles();
      
      // Sort files: directories first, then files
      files.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });
      
      setState(() {
        _allFiles = files;
        
        if (_currentPath.isEmpty) {
          // Initial load, get the base path
          if (files.isNotEmpty) {
            final basePath = path.dirname(files[0].path);
            _currentPath = basePath;
            _folderBreadcrumbs = [basePath];
          }
        }
        
        // Filter files by current directory
        _updateDisplayedFiles();
        
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _allFiles = [];
          _displayedFiles = [];
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: $e')),
        );
      }
    }
  }

  void _updateDisplayedFiles() {
    _displayedFiles = _allFiles.where((file) {
      final parent = path.dirname(file.path);
      return parent == _currentPath;
    }).toList();
  }

  void _navigateToFolder(String folderPath) {
    setState(() {
      _currentPath = folderPath;
      _folderBreadcrumbs.add(folderPath);
      _updateDisplayedFiles();
    });
  }

  void _navigateUp() {
    if (_folderBreadcrumbs.length > 1) {
      setState(() {
        _folderBreadcrumbs.removeLast();
        _currentPath = _folderBreadcrumbs.last;
        _updateDisplayedFiles();
      });
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      final decryptedContent = await GoogleDriveDownloader.openFile(filePath);
      
      if(!mounted) return;

      if (decryptedContent != null) {
        // Navigate to file viewer
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EncryptedFileViewer(
              fileName: path.basename(filePath),
              fileData: decryptedContent,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    } catch (e) {
      if(!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Breadcrumb navigation
          if (_folderBreadcrumbs.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  if (_folderBreadcrumbs.length > 1)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _navigateUp,
                      tooltip: 'Go back',
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _folderBreadcrumbs.asMap().entries.map((entry) {
                          final index = entry.key;
                          final breadcrumb = entry.value;
                          final displayName = breadcrumb == _folderBreadcrumbs.first
                              ? 'Downloads'
                              : path.basename(breadcrumb);
                          
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: index < _folderBreadcrumbs.length - 1
                                    ? () {
                                        setState(() {
                                          _currentPath = breadcrumb;
                                          _folderBreadcrumbs = _folderBreadcrumbs.sublist(0, index + 1);
                                          _updateDisplayedFiles();
                                        });
                                      }
                                    : null,
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    color: index < _folderBreadcrumbs.length - 1 ? Colors.blue : Colors.black,
                                  ),
                                ),
                              ),
                              if (index < _folderBreadcrumbs.length - 1) 
                                const Text(' > ', style: TextStyle(color: Colors.grey)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // File list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _displayedFiles.isEmpty
                    ? const Center(child: Text('No files in this directory'))
                    : RefreshIndicator(
                        onRefresh: _loadDownloadedFiles,
                        child: ListView.builder(
                          itemCount: _displayedFiles.length,
                          itemBuilder: (context, index) {
                            final file = _displayedFiles[index];
                            final fileName = path.basename(file.path);
                            
                            if (file is Directory) {
                              return ListTile(
                                leading: const Icon(Icons.folder, color: Colors.amber),
                                title: Text(fileName),
                                subtitle: const Text('Folder'),
                                onTap: () => _navigateToFolder(file.path),
                              );
                            } else if (file is File) {
                              return ListTile(
                                leading: Icon(_getFileIcon(fileName), color: Colors.blue),
                                title: Text(fileName),
                                subtitle: Text(_getFileType(fileName)),
                                onTap: () => _openFile(file.path),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadDownloadedFiles,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'PDF Document';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'Image';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'xls':
      case 'xlsx':
        return 'Excel Spreadsheet';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint Presentation';
      default:
        return 'File';
    }
  }
}




class DownloadProgressDialog extends StatefulWidget {
  final String title;
  final VoidCallback onCancel;

  const DownloadProgressDialog({
    Key? key,
    required this.title,
    required this.onCancel,
  }) : super(key: key);

  @override
  DownloadProgressDialogState createState() => DownloadProgressDialogState();

  static DownloadProgressDialogState? of(BuildContext context) {
    return context.findAncestorStateOfType<DownloadProgressDialogState>();
  }
}

class DownloadProgressDialogState extends State<DownloadProgressDialog> {
  double _progress = 0.0;

  void updateProgress(double progress) {
    setState(() {
      _progress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 16),
          Text('${(_progress * 100).toInt()}%'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}