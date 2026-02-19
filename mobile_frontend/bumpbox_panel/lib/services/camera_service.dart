import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;
  bool _isInitialized = false;
  CameraDescription? _frontCamera;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> initialize() async {
    try {
      // Request permission
      final hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        debugPrint('Camera permission denied');
        return false;
      }

      // Get available cameras
      final cameras = await availableCameras();

      // Find front camera
      _frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Initialize controller with lower resolution for better performance
      // Use NV21 on Android for better ML Kit compatibility
      _controller = CameraController(
        _frontCamera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      _isInitialized = true;

      debugPrint('Camera initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      return false;
    }
  }

  Future<void> startImageStream(Function(CameraImage) onImage) async {
    if (!_isInitialized || _controller == null) {
      throw Exception('Camera not initialized');
    }

    await _controller!.startImageStream(onImage);
  }

  Future<void> stopImageStream() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }

  Future<void> dispose() async {
    await stopImageStream();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  Future<void> pausePreview() async {
    if (_controller != null && _isInitialized) {
      await _controller!.pausePreview();
    }
  }

  Future<void> resumePreview() async {
    if (_controller != null && _isInitialized) {
      await _controller!.resumePreview();
    }
  }
}
