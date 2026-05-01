import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

final RouteObserver<ModalRoute<void>> videoRouteObserver =
    RouteObserver<ModalRoute<void>>();

class VideoPlayerScreen extends StatefulWidget {
  final String? initialVideoPath;

  const VideoPlayerScreen({super.key, this.initialVideoPath});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  String? _currentVideoPath;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialVideoPath != null) {
      _loadVideo(widget.initialVideoPath!);
    }
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final videoPermission = await Permission.videos.request();
      if (videoPermission.isGranted) return true;
      final storagePermission = await Permission.storage.request();
      return storagePermission.isGranted;
    }
    return true;
  }

  Future<void> _pickVideo() async {
    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      setState(() {
        _errorMessage =
            'Storage permission denied. Please allow it from Settings.';
      });
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      _loadVideo(result.files.single.path!);
    }
  }

  Future<void> _loadVideo(String path) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentVideoPath = path;
    });

    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;

    try {
      if (path.startsWith('content://')) {
        _videoPlayerController = VideoPlayerController.contentUri(
          Uri.parse(path),
        );
      } else {
        _videoPlayerController = VideoPlayerController.file(File(path));
      }

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        showOptions: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Colors.white,
          backgroundColor: Colors.grey.shade800,
          bufferedColor: Colors.grey.shade600,
        ),
        subtitleBuilder:
            (context, subtitle) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                subtitle,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
        errorBuilder:
            (context, errorMessage) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
      );

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load video: ${e.toString()}';
      });
    }
  }

  String get _videoTitle {
    if (_currentVideoPath == null) return 'Video Player';
    if (_currentVideoPath!.startsWith('content://')) {
      return Uri.parse(_currentVideoPath!).pathSegments.last;
    }
    return _currentVideoPath!.split('/').last;
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar:
          _chewieController == null
              ? AppBar(
                backgroundColor: Colors.black,
                title: Text(
                  _videoTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    tooltip: 'Open Video',
                    onPressed: _pickVideo,
                  ),
                ],
              )
              : null,
      body: _buildBody(),
      floatingActionButton:
          _chewieController != null
              ? FloatingActionButton(
                backgroundColor: Colors.white,
                mini: true,
                onPressed: _pickVideo,
                child: const Icon(Icons.folder_open, color: Colors.black),
              )
              : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading video...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                onPressed: _pickVideo,
                icon: const Icon(Icons.folder_open, color: Colors.black),
                label: const Text(
                  'Try Again',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_chewieController != null) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _videoTitle,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(child: Chewie(controller: _chewieController!)),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 80,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No video selected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the button below to select a video from your device.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: _pickVideo,
            icon: const Icon(Icons.folder_open, color: Colors.black),
            label: const Text(
              'Open Video',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
