import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomSnackbar {
  static late final GlobalKey<NavigatorState> navigatorKey;
  
  // Add initialization method
  static void init(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }
  static final List<_SnackbarItem> _snackbarQueue = [];
  static bool _isShowingSnackbar = false;

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 1),
    double top = 50, 
    double horizontalMargin = 20, 
    Color backgroundColor = Colors.blueAccent, 
    Color textColor = Colors.white, 
  }) {
    // Check if the context is still mounted
    if (!_isContextMounted(context)) {
      return;
    }

    // Convert values to be responsive
    final responsiveTop = top.h;
    final responsiveMargin = horizontalMargin.w;

    final overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedSnackbar(
        message: message,
        top: responsiveTop,
        horizontalMargin: responsiveMargin,
        backgroundColor: backgroundColor,
        textColor: textColor,
        duration: duration,
        onComplete: () {
          _removeCurrentSnackbar();
        },
      ),
    );

    // Add to queue with context
    _snackbarQueue.add(_SnackbarItem(overlayEntry, context));
    
    // If not currently showing a snackbar, show this one
    if (!_isShowingSnackbar) {
      _showNextSnackbar();
    }
  }

  // Check if the context is still mounted/valid
  static bool _isContextMounted(BuildContext context) {
    try {
      return context.mounted;
    } catch (e) {
      return false;
    }
  }

  static void _showNextSnackbar() {
    if (_snackbarQueue.isEmpty) {
      _isShowingSnackbar = false;
      return;
    }

    _isShowingSnackbar = true;
    final item = _snackbarQueue.first;
    
    // Make sure the context is still valid
    if (_isContextMounted(item.context)) {
      final overlay = Overlay.of(item.context);
      overlay.insert(item.entry);
      return;
    }
    
    // If we get here, the context is invalid, so remove this item and try the next
    _snackbarQueue.removeAt(0);
    _showNextSnackbar();
  }

  static void _removeCurrentSnackbar() {
    if (_snackbarQueue.isNotEmpty) {
      final item = _snackbarQueue.removeAt(0);
      item.entry.remove();
    }
    
    // Show the next one if available
    _showNextSnackbar();
  }
}

// Helper class to store both overlay entry and its context
class _SnackbarItem {
  final OverlayEntry entry;
  final BuildContext context;
  
  _SnackbarItem(this.entry, this.context);
}

class _AnimatedSnackbar extends StatefulWidget {
  final String message;
  final double top;
  final double horizontalMargin;
  final Color backgroundColor;
  final Color textColor;
  final Duration duration;
  final VoidCallback onComplete;

  const _AnimatedSnackbar({
    required this.message,
    required this.top,
    required this.horizontalMargin,
    required this.backgroundColor,
    required this.textColor,
    required this.duration,
    required this.onComplete,
  });

  @override
  State<_AnimatedSnackbar> createState() => _AnimatedSnackbarState();
}

class _AnimatedSnackbarState extends State<_AnimatedSnackbar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuint),
    );

    // Start the animation
    _controller.forward();

    // Schedule auto-dismiss
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: widget.top,
      left: widget.horizontalMargin,
      right: widget.horizontalMargin,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 14.h,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10.r,
                    offset: Offset(0, 4.h),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}