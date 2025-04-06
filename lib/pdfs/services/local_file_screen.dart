// ignore_for_file: unused_field

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:routemaster/routemaster.dart';

class LocalFilesScreen extends StatefulWidget {
  final String? initialPath;
  
  const LocalFilesScreen({Key? key, this.initialPath}) : super(key: key);

  @override
  _LocalFilesScreenState createState() => _LocalFilesScreenState();
}

class _LocalFilesScreenState extends State<LocalFilesScreen> {
  List<FileSystemEntity> _files = [];
  String _currentPath = '';
  List<PathBreadcrumb> _breadcrumbs = [];
  bool _isLoading = false;
  String _basePathToHide = ''; // Path prefix to hide from display
  
  @override
  void initState() {
    super.initState();
    _initializeLocalFiles();
  }
  
  Future<void> _initializeLocalFiles() async {
    setState(() => _isLoading = true);
    
    try {
      String basePath;
      if (widget.initialPath != null) {
        basePath = widget.initialPath!;
      } else {
        final externalDir = await getExternalStorageDirectory();
        basePath = '${externalDir?.path}/FUTApedia';
        _basePathToHide = basePath; // We'll hide this part of the path
      }
      
      final baseDir = Directory(basePath);
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }
      
      await _navigateToDirectory(basePath);
    } catch (e) {
      _showError('Failed to load local files');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _navigateToDirectory(String path) async {
    setState(() => _isLoading = true);
    
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
      
      // Update breadcrumbs
      _updateBreadcrumbs(path);
      
      setState(() {
        _files = entities;
        _currentPath = path;
      });
    } catch (e) {
      _showError('Failed to navigate to directory');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _updateBreadcrumbs(String path) {
    // Don't show the base FUTApedia path in breadcrumbs
    String displayPath = path;
    if (path.startsWith(_basePathToHide)) {
      displayPath = path.substring(_basePathToHide.length);
      if (displayPath.isEmpty) displayPath = '/';
    }
    
    final parts = displayPath.split('/');
    final List<PathBreadcrumb> crumbs = [];
    
    // Add root/home breadcrumb
    crumbs.add(PathBreadcrumb(
      name: 'Home',
      path: _basePathToHide,
    ));
    
    // Add other breadcrumbs
    String currentPath = _basePathToHide;
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      
      currentPath += '/${parts[i]}';
      
      crumbs.add(PathBreadcrumb(
        name: parts[i],
        path: currentPath,
      ));
    }
    
    setState(() {
      _breadcrumbs = crumbs;
    });
  }
  
  Future<void> _navigateToBreadcrumb(int index) async {
    await _navigateToDirectory(_breadcrumbs[index].path);
  }
  
  void _openFile(File file) {
    final path = file.path;
    if (path.toLowerCase().endsWith('.pdf')) {
      Routemaster.of(context).push('/encrypted_pdfviewer?filePath=${Uri.encodeComponent(path)}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only PDF files can be viewed in the app')),
      );
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloaded Files'),
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
          : _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'This folder is empty',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final entity = _files[index];
                    final name = entity.path.split('/').last;
                    final isDirectory = entity is Directory;
                    final isPdf = name.toLowerCase().endsWith('.pdf');
                    
                    return ListTile(
                      leading: Icon(
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
                      ),
                      title: Text(name),
                      onTap: isDirectory
                          ? () => _navigateToDirectory(entity.path)
                          : () => _openFile(entity as File),
                      trailing: !isDirectory
                          ? IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () => _openFile(entity as File),
                              tooltip: 'View in app',
                            )
                          : null,
                    );
                  },
                ),
    );
  }
}

class PathBreadcrumb {
  final String name;
  final String path;
  
  PathBreadcrumb({required this.name, required this.path});
}
