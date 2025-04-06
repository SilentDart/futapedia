import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:futapedia/study_material/services/notification_manager.dart';
import 'package:futapedia/study_material/services/encrypted_pdfviewer.dart';
import 'package:futapedia/study_material/pdf/pdf_drive.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

// Main Screen - Keep the same structure but update the UI
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

  // Keep initialization method the same
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
            children: [
              // Updated loading screen with better visuals
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                strokeWidth: 4.0,
              ),
              const SizedBox(height: 24),
              Text(
                'Connecting to your drive...',
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
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.school, color: Colors.amber[600]),
            const SizedBox(width: 10),
            const Text('Futapedia Learning Drive'),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.blue,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.cloud_outlined), 
              text: 'Study Materials',
            ),
            Tab(
              icon: Icon(Icons.book_outlined), 
              text: 'My Library',
            ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Show help dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('How to use Futapedia Drive'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(Icons.cloud_outlined, color: Colors.blue),
                    title: const Text('Study Materials Tab'),
                    subtitle: const Text('Browse and download files from your Google Drive'),
                  ),
                  ListTile(
                    leading: Icon(Icons.book_outlined, color: Colors.green),
                    title: const Text('My Library Tab'),
                    subtitle: const Text('Access your downloaded files for offline study'),
                  ),
                  ListTile(
                    leading: Icon(Icons.download, color: Colors.amber),
                    title: const Text('Download Files'),
                    subtitle: const Text('Tap the download icon to save files for offline use'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it!'),
                ),
              ],
            ),
          );
        },
        label: const Text('Help'),
        icon: const Icon(Icons.help_outline),
        backgroundColor: Colors.blue,
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

// Drive Explorer Tab - Update the UI while maintaining core functionality
class DriveExplorerTab extends StatefulWidget {
  const DriveExplorerTab({Key? key}) : super(key: key);

  @override
  _DriveExplorerTabState createState() => _DriveExplorerTabState();
}

class _DriveExplorerTabState extends State<DriveExplorerTab> {
  List<Map<String, dynamic>> _driveItems = [];
  bool _isLoading = true;
  String _currentFolderId = 'root';
  List<Map<String, String>> _folderBreadcrumbs = [{'id': 'root', 'name': 'My Drive'}];
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredItems = [];
  
  @override
  void initState() {
    super.initState();
    _loadDriveContents();
  }

  // Keep the same loading method
  Future<void> _loadDriveContents() async {
    // Implementation remains the same
    setState(() {
      _isLoading = true;
    });

    try {
      final driveService = GoogleDriveServicePDF();
      final driveApi = await driveService.driveApi;
      if (driveApi == null) {
        throw Exception('Failed to initialize Google Drive API');
      }
      
      final query = _currentFolderId == 'root' 
        ? "'${driveService.getRootFolderId()}' in parents and trashed = false"
        : "'$_currentFolderId' in parents and trashed = false";
      
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, size)',
      );
      
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
      
      // Apply search filter if there's a query
      _filterItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading drive contents: $e'),
          backgroundColor: Colors.red,
        ),
      );
      _driveItems = [];
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // New method to filter items based on search
  void _filterItems() {
    if (_searchQuery.isEmpty) {
      _filteredItems = List.from(_driveItems);
    } else {
      _filteredItems = _driveItems.where(
        (item) => item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
  }

  // Keep navigation methods the same
  void _navigateToFolder(String folderId, String folderName) {
    setState(() {
      _currentFolderId = folderId;
      _folderBreadcrumbs.add({'id': folderId, 'name': folderName});
      _searchQuery = ''; // Clear search when navigating
    });
    _loadDriveContents();
  }

  void _navigateUp() {
    if (_folderBreadcrumbs.length > 1) {
      setState(() {
        _folderBreadcrumbs.removeLast();
        _currentFolderId = _folderBreadcrumbs.last['id']!;
        _searchQuery = ''; // Clear search when navigating up
      });
      _loadDriveContents();
    }
  }

  // Keep download method the same
  Future<void> _downloadItem(Map<String, dynamic> item) async {
    // Implementation remains the same
    try {
      final driveService = GoogleDriveServicePDF();
      final notificationManager = NotificationDownloadManager();
      
      final String downloadDirPath = await GoogleDriveDownloader.getDownloadDirectory();
      final downloadDir = Directory(downloadDirPath);
      
      // Show progress indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                ),
                const SizedBox(width: 12),
                Text('Downloading ${item['name']}...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      if (item['type'] == 'folder') {
        final folderFile = drive.File()
          ..id = item['id']
          ..name = item['name']
          ..mimeType = 'application/vnd.google-apps.folder';
        
        await notificationManager.downloadFolderWithNotification(
          folderFile,
          downloadDir,
          driveService,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📚 Folder saved: ${item['name']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final driveFile = drive.File()
          ..id = item['id']
          ..name = item['name']
          ..mimeType = item['mimeType']
          ..size = item['size'];
        
        final filePath = await notificationManager.downloadFileWithNotification(
          driveFile,
          downloadDir,
          driveService,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📄 Downloaded: ${item['name']}'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
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
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search in current folder...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _filterItems();
                        });
                      },
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterItems();
                });
              },
            ),
          ),
          
          // Breadcrumb navigation
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(
                bottom: BorderSide(color: Colors.blue[200]!),
                top: BorderSide(color: Colors.blue[200]!),
              ),
            ),
            child: Row(
              children: [
                if (_folderBreadcrumbs.length > 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: _navigateUp,
                    tooltip: 'Go back',
                    color: Colors.blue[700],
                  ),
                const Icon(Icons.folder_open, color: Colors.amber),
                const SizedBox(width: 8),
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
                                  color: index < _folderBreadcrumbs.length - 1 
                                      ? Colors.blue[700] 
                                      : Colors.black,
                                  fontWeight: index == _folderBreadcrumbs.length - 1
                                      ? FontWeight.bold
                                      : FontWeight.normal,
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
          
          // Drive items grid or list
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading materials...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : _filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'This folder is empty'
                                  : 'No results found for "$_searchQuery"',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              TextButton.icon(
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear search'),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _filterItems();
                                  });
                                },
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDriveContents,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final isFolder = item['type'] == 'folder';
                            
                            return InkWell(
                              onTap: isFolder
                                  ? () => _navigateToFolder(item['id'], item['name'])
                                  : () => _downloadItem(item),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isFolder ? Colors.amber[100] : Colors.blue[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isFolder 
                                            ? Icons.folder 
                                            : _getFileIcon(item['name']),
                                        size: 36,
                                        color: isFolder ? Colors.amber[800] : Colors.blue[700],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        item['name'],
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isFolder ? 'Folder' : _getFileType(item['name']),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (!isFolder)
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.download, size: 16),
                                        label: const Text('Download'),
                                        onPressed: () => _downloadItem(item),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          minimumSize: const Size(100, 30),
                                        ),
                                      ),
                                  ],
                                ),
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
    // Keep this method the same
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
    // Keep this method the same
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

// Downloaded Files Tab - Update the UI while keeping core functionality
class DownloadedFilesTab extends StatefulWidget {
  const DownloadedFilesTab({Key? key}) : super(key: key);

  @override
  _DownloadedFilesTabState createState() => _DownloadedFilesTabState();
}

class _DownloadedFilesTabState extends State<DownloadedFilesTab> {
  List<FileSystemEntity> _allFiles = [];
  List<FileSystemEntity> _displayedFiles = [];
  List<FileSystemEntity> _filteredFiles = [];
  String _currentPath = '';
  bool _isLoading = true;
  List<String> _folderBreadcrumbs = [];
  String _searchQuery = '';
  Map<String, int> _categoryCounts = {};

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  Future<void> _loadDownloadedFiles() async {
    // Implementation largely the same with added category counting
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
        
        // Update displayed files
        _updateDisplayedFiles();
        
        // Count file types
        _updateCategoryCounts();
        
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _allFiles = [];
          _displayedFiles = [];
          _filteredFiles = [];
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateDisplayedFiles() {
    // Filter by current directory
    _displayedFiles = _allFiles.where((file) {
      final parent = path.dirname(file.path);
      return parent == _currentPath;
    }).toList();
    
    // Apply search filter
    _filterFiles();
  }

  void _filterFiles() {
    if (_searchQuery.isEmpty) {
      _filteredFiles = List.from(_displayedFiles);
    } else {
      _filteredFiles = _displayedFiles.where(
        (file) => path.basename(file.path).toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
  }

  void _updateCategoryCounts() {
    _categoryCounts = {
      'PDF': 0,
      'Images': 0,
      'Documents': 0,
      'Presentations': 0,
      'Spreadsheets': 0,
      'Other': 0,
    };
    
    for (var file in _allFiles) {
      if (file is File) {
        final extension = path.extension(file.path).toLowerCase();
        switch (extension) {
          case '.pdf':
            _categoryCounts['PDF'] = (_categoryCounts['PDF'] ?? 0) + 1;
            break;
          case '.jpg':
          case '.jpeg':
          case '.png':
          case '.gif':
            _categoryCounts['Images'] = (_categoryCounts['Images'] ?? 0) + 1;
            break;
          case '.doc':
          case '.docx':
            _categoryCounts['Documents'] = (_categoryCounts['Documents'] ?? 0) + 1;
            break;
          case '.ppt':
          case '.pptx':
            _categoryCounts['Presentations'] = (_categoryCounts['Presentations'] ?? 0) + 1;
            break;
          case '.xls':
          case '.xlsx':
            _categoryCounts['Spreadsheets'] = (_categoryCounts['Spreadsheets'] ?? 0) + 1;
            break;
          default:
            _categoryCounts['Other'] = (_categoryCounts['Other'] ?? 0) + 1;
        }
      }
    }
  }

  // Keep navigation methods the same
  void _navigateToFolder(String folderPath) {
    setState(() {
      _currentPath = folderPath;
      _folderBreadcrumbs.add(folderPath);
      _searchQuery = '';
      _updateDisplayedFiles();
    });
  }

  void _navigateUp() {
    if (_folderBreadcrumbs.length > 1) {
      setState(() {
        _folderBreadcrumbs.removeLast();
        _currentPath = _folderBreadcrumbs.last;
        _searchQuery = '';
        _updateDisplayedFiles();
      });
    }
  }

  // Keep open file method the same
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
          // Search bar and category chips
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search in my library...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _filterFiles();
                            });
                          },
                        )
                      : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _filterFiles();
                    });
                  },
                ),
                
                // Category chips
                if (_allFiles.isNotEmpty)
                  Container(
                    height: 50,
                    margin: const EdgeInsets.only(top: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // _buildCategoryChip('PDF', Icons.picture_as_pdf, Colors.red[700]!),
                        // _buildCategoryChip('Documents', Icons.description, Colors.blue[700]!),
                        // _buildCategoryChip('Presentations', Icons.slideshow, Colors.orange[700]!),
                        // _buildCategoryChip('Spreadsheets', Icons.table_chart, Colors.green[700]!),
                        // _buildCategoryChip('Images', Icons.image, Colors.purple[700]!),
                        // _buildCategoryChip('Other', Icons.more_horiz, Colors.grey[700]!),
                      ],
                    ),
                  ),
              ],
            ),
          ),
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