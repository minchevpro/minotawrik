import 'dart:async';

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  CameraDescription? firstCamera;
  try {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      firstCamera = cameras.first;
    }
  } catch (e) {
    debugPrint('Error getting cameras: $e');
  }

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription? camera;

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: camera == null
          ? const Scaffold(body: Center(child: Text('No camera available')))
          : CameraScreen(camera: camera!),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final file = await _controller.stopVideoRecording();
        if (!mounted) return;
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video saved to ${file.path}')),
        );

        // Example of using FFmpeg (just logging version for now to prove dependency works)
        FFmpegKit.execute('-version').then((session) async {
          final returnCode = await session.getReturnCode();
          debugPrint("FFmpeg process exited with rc $returnCode");
        });
      } else {
        await _controller.prepareForVideoRecording();
        await _controller.startVideoRecording();
        if (!mounted) return;
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Error toggling recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Center(child: Text('Camera initialization failed: ${snapshot.error}'));
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: FloatingActionButton(
                      onPressed: () async {
                        await _toggleRecording();
                      },
                      backgroundColor: _isRecording ? Colors.red : Colors.white,
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.videocam,
                        color: _isRecording ? Colors.white : Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
