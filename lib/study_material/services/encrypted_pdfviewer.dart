import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:futapedia/study_material/services/encrypt_utils.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:routemaster/routemaster.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart' as syncfusion;
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';

class EncryptedFileViewer extends StatefulWidget {
  final String fileName;
  final Uint8List fileData;
  
  const EncryptedFileViewer({
    super.key,
    required this.fileName,
    required this.fileData,
  });
  
  @override
  _EncryptedFileViewerState createState() => _EncryptedFileViewerState();
}

class _EncryptedFileViewerState extends State<EncryptedFileViewer> {
  // final TabNavigationService _tabService = TabNavigationService();
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  String _tempFilePath = '';
  int _initialPage = 1; // Default to first page
  int _currentPage = 1; // Track current page
  final syncfusion.PdfViewerController _pdfViewerController = syncfusion.PdfViewerController();
  bool _documentLoaded = false; // Flag to track document load status
  bool _showCalculator = false; // Track calculator visibility
  
  @override
  void initState() {
    super.initState();
    _prepareFile();
  }
  
  @override
  void dispose() {
    // Save the current page before closing
    if (_isPdfFile()) {
      _saveCurrentPage();
    }
    
    // Clean up temporary files when viewer is closed
    _cleanupTempFile();
    _pdfViewerController.dispose();
    super.dispose();
  }
  
  // Generate a unique key for this PDF file based on its name and content hash
  Future<String> _getPdfKey() async {
    final fileNameHash = crypto.md5.convert(utf8.encode(widget.fileName)).toString();
    return 'pdf_page_$fileNameHash';
  }
  
  // Save the current page position to SharedPreferences
  Future<void> _saveCurrentPage() async {
    try {
      // Use the tracked current page value
      final prefs = await SharedPreferences.getInstance();
      final key = await _getPdfKey();
      await prefs.setInt(key, _currentPage);
      debugPrint('Saved page position: $_currentPage for PDF: ${widget.fileName}');
    } catch (e) {
      debugPrint('Error saving page position: $e');
    }
  }
  
  // Load the last viewed page from SharedPreferences
  Future<void> _loadSavedPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getPdfKey();
      final savedPage = prefs.getInt(key);
      
      if (savedPage != null && savedPage > 0) {
        setState(() {
          _initialPage = savedPage;
          _currentPage = savedPage;
        });
        debugPrint('Loaded saved page position: $savedPage for PDF: ${widget.fileName}');
      }
    } catch (e) {
      debugPrint('Error loading saved page position: $e');
    }
  }
  
  Future<void> _prepareFile() async {
    setState(() {
      _isLoading = true;
      _isError = false;
      _documentLoaded = false; // Reset document loaded state
    });
    
    try {
      // For PDF files we need to save to a temp file for the viewer
      if (_isPdfFile()) {
        await _createTempFileForViewing(widget.fileData);
        await _loadSavedPage(); // Load the saved page position
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if(mounted){
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'Failed to prepare file: ${e.toString()}';
        });
      }
      
    }
  }
  
  bool _isPdfFile() {
    return widget.fileName.toLowerCase().endsWith('.pdf');
  }
  
  Future<void> _createTempFileForViewing(Uint8List data) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(data);
      
      setState(() {
        _tempFilePath = tempPath;
      });
    } catch (e) {
      throw Exception('Failed to create temporary file: $e');
    }
  }
  
  Future<void> _cleanupTempFile() async {
    if (_tempFilePath.isNotEmpty) {
      try {
        final tempFile = File(_tempFilePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting temporary file: $e');
      }
    }
  }
  
  // Navigate to initial page after document is fully loaded
  void _navigateToInitialPage() {
    // Only navigate if we have a non-default initial page and the document is loaded
    if (_initialPage > 1 && _documentLoaded) {
      // Add a slight delay to ensure the controller is ready
      Future.delayed(const Duration(milliseconds: 200), () {
        try {
          _pdfViewerController.jumpToPage(_initialPage);
          debugPrint('Navigated to initial page: $_initialPage');
        } catch (e) {
          debugPrint('Error navigating to initial page: $e');
        }
      });
    }
  }
  
  Widget _buildFileViewer() {        
    final extension = widget.fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'pdf':
        return syncfusion.SfPdfViewer.file(
          File(_tempFilePath),
          controller: _pdfViewerController,
          onPageChanged: (syncfusion.PdfPageChangedDetails details) {
            // Update the current page tracker
            setState(() {
              _currentPage = details.newPageNumber;
            });
          },
          onDocumentLoaded: (syncfusion.PdfDocumentLoadedDetails details) {
            debugPrint('PDF document loaded with ${details.document.pages.count} pages');
            setState(() {
              _documentLoaded = true;
            });
            // Navigate to initial page after document is fully loaded
            _navigateToInitialPage();
          },
          onDocumentLoadFailed: (details) {
            setState(() {
              _isError = true;
              _errorMessage = 'Failed to load PDF: ${details.error}';
            });
          },
        );
      case 'jpg':
      case 'jpeg':
      case 'png':
        return PhotoView(
          imageProvider: MemoryImage(widget.fileData),
          backgroundDecoration: BoxDecoration(color: Colors.transparent),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        );
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getFileIcon(widget.fileName), size: 100, color: Colors.blue),
              const SizedBox(height: 16),
              Text(widget.fileName, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text('${widget.fileData.length} bytes'),
              const SizedBox(height: 24),
              const Text('No preview available for this file type'),
            ],
          ),
        );
    }
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

  // Toggle calculator visibility
  void _toggleCalculator() {
    setState(() {
      _showCalculator = !_showCalculator;
    });
  }
  
    
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 35,),
          onPressed:  () => Routemaster.of(context).pop(),
        ),
        title: Text(widget.fileName),
        actions: [
          // Add calculator icon
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: _toggleCalculator,
            tooltip: 'Scientific Calculator',
          ),
          // IconButton(
          //   icon: const Icon(Icons.refresh),
          //   onPressed: _prepareFile,
          //   tooltip: 'Reload',
          // ),
          if (_isPdfFile())
            IconButton(
              icon: const Icon(Icons.bookmark),
              onPressed: () {
                // Manually save current page
                _saveCurrentPage();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Bookmark saved at page $_currentPage'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Save current position',
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Implement file sharing functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature will be added soon')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main file viewer - gestures will pass through to this when calculator is shown
          GestureDetector(
            onTap: () {
              // Hide calculator when tapping outside of it
              if (_showCalculator) {
                setState(() {
                  _showCalculator = false;
                });
              }
            },
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                'Error',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _prepareFile,
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildFileViewer(),
          ),
          
          // Calculator overlay - shown from bottom when toggled
          if (_showCalculator)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).size.height * 2/3, // Takes 2/3 of screen height
              child: const ScientificCalculatorPanel(),
            ),
        ],
      ),
    );
  }
}

// Enhanced Scientific Calculator Panel Implementation
class ScientificCalculatorPanel extends StatefulWidget {
  const ScientificCalculatorPanel({Key? key}) : super(key: key);

  @override
  _ScientificCalculatorPanelState createState() => _ScientificCalculatorPanelState();
}

class _ScientificCalculatorPanelState extends State<ScientificCalculatorPanel> with SingleTickerProviderStateMixin {
  String _expression = '';
  String _result = '0';
  bool _showHistory = false;
  List<String> _history = [];
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // Modern color scheme
  final Color _backgroundColor = Colors.grey.shade900;
  final Color _displayColor = Colors.grey.shade800;
  final Color _numberColor = Colors.grey.shade800;
  final Color _operatorColor = Colors.blue.shade700;
  final Color _functionColor = Colors.deepPurple.shade400;
  final Color _actionColor = Colors.orange.shade600;
  final Color _equalColor = Colors.green.shade600;
  final Color _textColor = Colors.white;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuad,
    );
    _animationController.forward();
    
    // Load history from shared preferences
    _loadHistory();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // Load calculation history
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = prefs.getStringList('calculator_history');
      if (historyList != null) {
        setState(() {
          _history = historyList;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }
  
  // Save calculation history
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('calculator_history', _history);
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }
  
  void _addToExpression(String value) {
    setState(() {
      _expression += value;
    });
  }
  
  void _clear() {
    setState(() {
      _expression = '';
      _result = '0';
    });
  }
  
  void _backspace() {
    setState(() {
      if (_expression.isNotEmpty) {
        _expression = _expression.substring(0, _expression.length - 1);
      }
    });
  }
  
  void _toggleHistory() {
    setState(() {
      _showHistory = !_showHistory;
    });
  }
  
  void _calculate() {
    if (_expression.isEmpty) return;
    
    try {
      // Create a parser and define the expression
      Parser p = Parser();
      
      // Replace scientific notations
      String tempExpression = _expression
          .replaceAll('sin', 'sin(')
          .replaceAll('cos', 'cos(')
          .replaceAll('tan', 'tan(')
          .replaceAll('log', 'log(')
          .replaceAll('ln', 'ln(')
          .replaceAll('√', 'sqrt(')
          .replaceAll('π', '3.1415926535897932')
          .replaceAll('e', '2.718281828459045');
      
      // Add missing parentheses
      RegExp regExp = RegExp(r'(sin|cos|tan|log|ln|sqrt)\([^)]*$');
      if (regExp.hasMatch(tempExpression)) {
        tempExpression += ')';
      }
      
      // Balance remaining parentheses
      int openCount = '('.allMatches(tempExpression).length;
      int closeCount = ')'.allMatches(tempExpression).length;
      
      for (int i = 0; i < openCount - closeCount; i++) {
        tempExpression += ')';
      }
      
      // Parse and evaluate the expression
      Expression exp = p.parse(tempExpression);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      
      // Format the result
      String resultStr;
      if (eval == eval.toInt()) {
        resultStr = eval.toInt().toString();
      } else {
        resultStr = eval.toStringAsFixed(8).replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }
      
      setState(() {
        _result = resultStr;
        // Add calculation to history
        _history.add('$_expression = $_result');
        if (_history.length > 20) {
          _history.removeAt(0); // Keep only latest 20 entries
        }
        // Save history to shared preferences
        _saveHistory();
      });
    } catch (e) {
      setState(() {
        _result = 'Error';
      });
    }
  }
  
  Widget _buildButton(String text, {
    Color? backgroundColor, 
    Color? textColor,
    Function()? onTap, 
    int flex = 1, 
    IconData? icon,
    bool isOperator = false,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(isOperator ? 25 : 10),
          color: backgroundColor ?? _numberColor,
          child: InkWell(
            borderRadius: BorderRadius.circular(isOperator ? 25 : 10),
            onTap: onTap ?? () => _addToExpression(text),
            child: Container(
              height: 60,
              alignment: Alignment.center,
              child: icon != null 
                  ? Icon(icon, color: textColor ?? _textColor, size: 24) 
                  : Text(
                      text, 
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: isOperator ? FontWeight.bold : FontWeight.normal,
                        color: textColor ?? _textColor
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_animation),
      child: Container(
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle indicator
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade500,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            // Calculator content
            Expanded(
              child: _showHistory 
                  ? _buildHistoryView() 
                  : _buildCalculatorView(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHistoryView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calculation History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor),
              ),
              IconButton(
                icon: Icon(Icons.arrow_back, color: _textColor),
                onPressed: _toggleHistory,
              ),
            ],
          ),
        ),
        const Divider(thickness: 1, height: 1, color: Colors.grey),
        Expanded(
          child: _history.isEmpty 
              ? Center(
                  child: Text(
                    'No history yet',
                    style: TextStyle(color: _textColor.withOpacity(0.6)),
                  ),
                )
              : ListView.builder(
                  itemCount: _history.length,
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final calculation = _history[_history.length - 1 - index];
                    return Card(
                      color: Colors.grey.shade800,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(
                          calculation, 
                          style: TextStyle(fontSize: 16, color: _textColor),
                        ),
                        onTap: () {
                          final parts = calculation.split(' = ');
                          if (parts.length > 1) {
                            setState(() {
                              _expression = parts[0];
                              _result = parts[1];
                              _showHistory = false;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _history.clear();
                _saveHistory();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_forever),
                SizedBox(width: 8),
                Text('Clear History', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCalculatorView() {
    return Column(
      children: [
        // Display area
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _displayColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.history, color: _textColor.withOpacity(0.8), size: 20),
                    onPressed: _toggleHistory,
                    tooltip: 'History',
                  ),
                  Expanded(
                    child: Text(
                      _expression.isEmpty ? '' : _expression,
                      style: TextStyle(fontSize: 18, color: _textColor.withOpacity(0.9)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _result,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        
        // Buttons area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              children: [
                // Scientific functions
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('sin', backgroundColor: _functionColor),
                      _buildButton('cos', backgroundColor: _functionColor),
                      _buildButton('tan', backgroundColor: _functionColor),
                      _buildButton('log', backgroundColor: _functionColor),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('ln', backgroundColor: _functionColor),
                      _buildButton('√', backgroundColor: _functionColor),
                      _buildButton('π', backgroundColor: _functionColor),
                      _buildButton('e', backgroundColor: _functionColor),
                    ],
                  ),
                ),
                // Standard calculator buttons
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('(', backgroundColor: _functionColor),
                      _buildButton(')', backgroundColor: _functionColor),
                      _buildButton('%', backgroundColor: _functionColor),
                      _buildButton('/', backgroundColor: _operatorColor, isOperator: true),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('7'),
                      _buildButton('8'),
                      _buildButton('9'),
                      _buildButton('*', backgroundColor: _operatorColor, isOperator: true),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('4'),
                      _buildButton('5'),
                      _buildButton('6'),
                      _buildButton('-', backgroundColor: _operatorColor, isOperator: true),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('1'),
                      _buildButton('2'),
                      _buildButton('3'),
                      _buildButton('+', backgroundColor: _operatorColor, isOperator: true),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('0', flex: 2),
                      _buildButton('.'),
                      _buildButton('', onTap: _backspace, icon: Icons.backspace_outlined, backgroundColor: _actionColor),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('C', onTap: _clear, backgroundColor: _actionColor, flex: 2),
                      _buildButton('=', onTap: _calculate, backgroundColor: _equalColor, flex: 2, isOperator: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
        return await PDFEncryptionUtils.instance.decryptFile(image.path);
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
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 35,),
          onPressed: () => Navigator.pop(context),
        ),
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


