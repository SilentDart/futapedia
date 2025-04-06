import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:futapedia/pdfs/past%20questions/encrypt_util_past_question.dart';
import 'package:futapedia/study_material/services/permission_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:routemaster/routemaster.dart';

class StudentDownloadsView extends StatefulWidget {
  const StudentDownloadsView({Key? key}) : super(key: key);

  @override
  _StudentDownloadsViewState createState() => _StudentDownloadsViewState();
}

class _StudentDownloadsViewState extends State<StudentDownloadsView> {
  List<FileSystemEntity> _downloadedFiles = [];
  bool _isLoading = false;
  List<String> _downloadPaths = [];
  List<FolderBreadcrumb> _breadcrumbs = [];

  @override
  void initState() {
    super.initState();
    _initDownloadPathsAndLoadFiles();
  }

  Future<void> _initDownloadPathsAndLoadFiles() async {
    await _initDownloadPaths();
    await _loadDownloadedFiles();
  }

  Future<void> _initDownloadPaths() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      // Define multiple paths
      final paths = [
        '${directory.path}/PastQuestion',
        '${directory.path}FUTApedia'
      ];
      
      // Create directories if they don't exist
      for (var path in paths) {
        await Directory(path).create(recursive: true);
      }
      
      setState(() {
        _downloadPaths = paths;
        _breadcrumbs = [FolderBreadcrumb(name: 'Downloads', id: 'root')];
      });
    } catch (err) {
      _showError('Failed to create download directories');
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

  Future<void> _loadDownloadedFiles() async {
    if (!await _checkPermissions()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Collect files from all paths
      List<FileSystemEntity> allFiles = [];
      
      for (var basePath in _downloadPaths) {
        // Construct the current directory path based on breadcrumbs
        String currentPath = basePath;
        for (int i = 1; i < _breadcrumbs.length; i++) {
          currentPath += '/${_breadcrumbs[i].name}';
        }
        
        final directory = Directory(currentPath);
        
        if (await directory.exists()) {
          final files = await directory.list().toList();
          allFiles.addAll(files);
        }
      }
      
      // Sort directories first, then files
      allFiles.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        
        return a.path.split('/').last.compareTo(b.path.split('/').last);
      });
      
      setState(() {
        _downloadedFiles = allFiles;
      });
    } catch (e) {
      _showError('Failed to load downloaded files');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToLocalDirectory(String path) {
    setState(() => _isLoading = true);
    
    try {
      // Extract the directory name
      final dirName = path.split('/').last;
      
      // Update breadcrumbs
      _breadcrumbs.add(FolderBreadcrumb(
        name: dirName,
        id: path
      ));
      
      // Reload files with updated breadcrumbs
      _loadDownloadedFiles();
    } catch (e) {
      _showError('Failed to navigate to directory');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToBreadcrumb(int index) async {
    setState(() {
      _breadcrumbs = _breadcrumbs.sublist(0, index + 1);
    });
    await _loadDownloadedFiles();
  }

  Future<bool> _onWillPop() {
    // If we have more than one breadcrumb, navigate back
    if (_breadcrumbs.length > 1) {
      _breadcrumbs.removeLast();
      _navigateToBreadcrumb(_breadcrumbs.length - 1);
      return Future.value(false); // Prevent default back button behavior
    }
    
    // If only one breadcrumb, allow default back navigation
    return Future.value(true);
  }

  
  // Helper method to format file size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unsupported file type')),
      );
    }
  }

  

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(child: Text(message)),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  


   @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Downloads'),
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
            preferredSize: const Size.fromHeight(48),
            child: Container(
              height: 48,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < _breadcrumbs.length; i++)
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
                  ],
                ),
              ),
            ),
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _buildDownloadedFilesGrid(),
      ),
    );
  }

  Widget _buildDownloadedFilesGrid() {
    if (_downloadedFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download_done, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No downloaded files',
              style: Theme.of(context).textTheme.titleLarge,
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
        
        // Get relative path by removing any of the base paths
        String displayPath = entity.path;
        for (var basePath in _downloadPaths) {
          if (displayPath.startsWith(basePath)) {
            displayPath = displayPath.substring(basePath.length);
            break;
          }
        }
        
        // Remove leading slash if present
        if (displayPath.startsWith('/')) {
          displayPath = displayPath.substring(1);
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
                    // Icon and file details remain the same as in previous implementation
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
                    // Text details remain the same
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
}

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
   return WillPopScope(
    onWillPop: () async {
      // Optional: Perform any cleanup here
      // For example, you might want to clear decrypted image data
      // or perform some logging
      
      // Return true to allow normal back navigation
      return true;
    },
    child:Scaffold(
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
   ));
  }
}