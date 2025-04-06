// ignore_for_file: unused_field
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' show min, max;

class YouTubePlayerWidget extends StatefulWidget {
  final String youtubeLink;
  final String title;
  
  const YouTubePlayerWidget({
    Key? key,
    required this.youtubeLink,
    this.title = '',
  }) : super(key: key);

  @override
  State<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends State<YouTubePlayerWidget> with WidgetsBindingObserver {
  late YoutubePlayerController _controller;
  late TextEditingController _idController;
  late YoutubeMetaData _videoMetaData;
  
  double _currentVideoTime = 0;
  bool _isPlayerReady = false;
  bool _isResumeNotificationShown = false;
  bool _muted = false;
  bool _isFullScreen = true; // Set default to true for landscape
  bool _showControls = false; // Controls visibility state
  double _playbackSpeed = 1.0;
  String _videoId = '';
  
  final List<double> _playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  Timer? _controlsTimer;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _videoId = _extractVideoIdFromUrl(widget.youtubeLink);
    _loadSavedPosition();
    _controller = YoutubePlayerController(
      initialVideoId: _videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        enableCaption: true,
        captionLanguage: 'en',
        hideControls: true, // Hide YouTube's default controls
      ),
    )..addListener(_controllerListener);
    _idController = TextEditingController();
    _videoMetaData = const YoutubeMetaData();
    
    // Set landscape orientation on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setLandscapeOrientation();
    });
  }

  @override
  void dispose() {
    _saveCurrentPosition();
    _controller.dispose();
    _idController.dispose();
    _controlsTimer?.cancel();
    // Reset orientation to normal when widget is disposed
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    
    // Auto-hide controls after 3 seconds
    if (_showControls) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }
  
  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save position when app goes to background
    if (state == AppLifecycleState.paused) {
      _saveCurrentPosition();
      _controlsTimer?.cancel();
    }
    // Ensure landscape mode is maintained when app is resumed
    if (state == AppLifecycleState.resumed && _isFullScreen) {
      _setLandscapeOrientation();
    }
  }

  void _controllerListener() {
    if (_isPlayerReady && mounted) {
      setState(() {
        _videoMetaData = _controller.metadata;
        _currentVideoTime = _controller.value.position.inSeconds.toDouble();
      });
      
      // Save position every 5 seconds
      if (_controller.value.position.inSeconds % 5 == 0 && 
          _controller.value.isPlaying &&
          _currentVideoTime > 0) {
        _saveCurrentPosition();
      }
    }
  }

  String _extractVideoIdFromUrl(String url) {
    // First, try using the YouTube package's method
    String? videoId = YoutubePlayer.convertUrlToId(url);
    
    // If that doesn't work, try manual extraction
    if (videoId == null) {
      // Handle youtu.be format
      if (url.contains('youtu.be')) {
        var uri = Uri.parse(url);
        videoId = uri.pathSegments.last;
      } 
      // Handle watch?v= format
      else if (url.contains('youtube.com/watch')) {
        var uri = Uri.parse(url);
        videoId = uri.queryParameters['v'];
      }
      // Handle embed format
      else if (url.contains('youtube.com/embed/')) {
        var uri = Uri.parse(url);
        videoId = uri.pathSegments.last;
      }
      // Handle short format
      else if (url.contains('youtube.com/shorts/')) {
        var uri = Uri.parse(url);
        videoId = uri.pathSegments.last;
      }
    }
    
    return videoId ?? '';
  }

  Future<void> _loadSavedPosition() async {
    if (_videoId.isEmpty) return;
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double savedPosition = prefs.getDouble('${_videoId}_position') ?? 0;
    double savedSpeed = prefs.getDouble('${_videoId}_speed') ?? 1.0;
    
    if (savedPosition > 0) {
      setState(() {
        _currentVideoTime = savedPosition;
        _playbackSpeed = savedSpeed;
      });
    }
  }

  Future<void> _saveCurrentPosition() async {
    if (_videoId.isEmpty || _currentVideoTime <= 0) return;
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_videoId}_position', _currentVideoTime);
    await prefs.setDouble('${_videoId}_speed', _playbackSpeed);
  }

  void _seekRelative(double seconds) {
    final currentPosition = _controller.value.position.inSeconds;
    final targetPosition = currentPosition + seconds.toInt();
    _controller.seekTo(Duration(seconds: targetPosition));
    
    // Show visual feedback
    _showSeekIndicator(seconds > 0 ? "⏩ ${seconds.toInt()}s" : "⏪ ${seconds.abs().toInt()}s");
    
    // Reset the timer for auto-hiding controls
    if (_showControls) {
      _startControlsTimer();
    }
  }

  void _setPlaybackSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    _controller.setPlaybackRate(speed);
    _saveCurrentPosition();  // Save speed preference
    
    _showToast("Speed: ${speed}x");
    
    // Reset the timer for auto-hiding controls
    if (_showControls) {
      _startControlsTimer();
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    
    if (_isFullScreen) {
      _setLandscapeOrientation();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    
    // Reset the timer for auto-hiding controls
    if (_showControls) {
      _startControlsTimer();
    }
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    
    // Reset the timer for auto-hiding controls
    if (_showControls) {
      _startControlsTimer();
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // Visual indicator for seeking
  void _showSeekIndicator(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 500),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Video Player (full screen)
          GestureDetector(
            onTap: _toggleControls,
            onDoubleTapDown: (details) {
              final width = MediaQuery.of(context).size.width;
              final tapPosition = details.globalPosition.dx;
              
              // Left side - seek backward
              if (tapPosition < width * 0.2) {
                _seekRelative(-10);
              } 
              // Right side - seek forward
              else if (tapPosition > width * 0.8) {
                _seekRelative(10);
              } else {
                // Center - toggle play/pause
                _togglePlayPause();
              }
            },
            child: YoutubePlayerBuilder(
              player: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.red,
                progressColors: const ProgressBarColors(
                  playedColor: Colors.red,
                  handleColor: Colors.redAccent,
                ),
                onReady: () {
                  setState(() {
                    _isPlayerReady = true;
                    
                    // Apply saved position and speed after player is ready
                    if (_currentVideoTime > 0) {
                      // Only show resume notification if there's a significant saved position
                      if (_currentVideoTime > 10) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _showToast("Resuming from ${_formatDuration(_currentVideoTime)}");
                        });
                        _isResumeNotificationShown = true;
                      }
                      
                      _controller.seekTo(Duration(seconds: _currentVideoTime.toInt()));
                    }
                    
                    if (_playbackSpeed != 1.0) {
                      _controller.setPlaybackRate(_playbackSpeed);
                    }
                  });
                },
                onEnded: (metaData) {
                  // Reset saved position when video ends
                  _currentVideoTime = 0;
                  _saveCurrentPosition();
                  // Show controls when video ends
                  setState(() {
                    _showControls = true;
                  });
                },
              ),
              builder: (context, player) {
                return player;
              },
            ),
          ),
          
          // Controls overlay - only shown when _showControls is true
          if (_showControls)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  // Semi-transparent black background for controls
                  color: Colors.black.withOpacity(0.4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top section with title and exit fullscreen button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.title.isNotEmpty)
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.fullscreen_exit,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: _toggleFullScreen,
                          ),
                        ],
                      ),
                    ),
                    
                    // Center play/pause button
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    
                    // Bottom controls
                    Column(
                      children: [
                        // Progress bar with current time
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                _formatDuration(_controller.value.position.inSeconds.toDouble()),
                                style: const TextStyle(color: Colors.white),
                              ),
                              Expanded(
                                child: Slider(
                                  value: min(_controller.value.position.inSeconds.toDouble(), 
                                            _controller.metadata.duration.inSeconds.toDouble()),
                                  min: 0,
                                  max: max(1.0, _controller.metadata.duration.inSeconds.toDouble()), // Ensure max is at least 1.0
                                  activeColor: Colors.red,
                                  inactiveColor: Colors.grey,
                                  onChanged: (value) {
                                    _controller.seekTo(Duration(seconds: value.toInt()));
                                    _startControlsTimer();
                                  },
                                ),
                              ),
                              Text(
                                _formatDuration(_controller.metadata.duration.inSeconds.toDouble()),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        
                        // Main controls row
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.replay_10, color: Colors.white, size: 30),
                                onPressed: _isPlayerReady ? () => _seekRelative(-10) : null,
                              ),
                              const Spacer(),
                              // Playback speed dropdown
                              PopupMenuButton<double>(
                                onSelected: _setPlaybackSpeed,
                                itemBuilder: (context) => _playbackSpeeds
                                    .map((speed) => PopupMenuItem<double>(
                                          value: speed,
                                          child: Row(
                                            children: [
                                              if (_playbackSpeed == speed)
                                                const Icon(Icons.check, color: Colors.red),
                                              const SizedBox(width: 8),
                                              Text("${speed}x"),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                                child: Chip(
                                  label: Text("${_playbackSpeed}x"),
                                  backgroundColor: Colors.blue,
                                  labelStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.forward_10, color: Colors.white, size: 30),
                                onPressed: _isPlayerReady ? () => _seekRelative(10) : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds - minutes * 60;
    
    return "$minutes:${remainingSeconds.toString().padLeft(2, '0')}";
  }
}