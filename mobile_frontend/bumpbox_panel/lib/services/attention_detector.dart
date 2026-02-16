import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/attention_state.dart';

class AttentionDetector {
  final FaceDetector _faceDetector;
  bool _isProcessing = false;
  DateTime? _lastProcessTime;

  // Process frames every 200ms (5 FPS) for efficiency
  static const _processingInterval = Duration(milliseconds: 200);

  AttentionDetector()
    : _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          enableClassification: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

  Future<AttentionState> processImage(CameraImage image) async {
    // Throttle processing
    final now = DateTime.now();
    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!) < _processingInterval) {
      return AttentionState(
        status: AttentionStatus.unknown,
        confidence: 0.0,
        details: 'Throttled',
      );
    }

    if (_isProcessing) {
      return AttentionState(
        status: AttentionStatus.unknown,
        confidence: 0.0,
        details: 'Processing',
      );
    }

    _isProcessing = true;
    _lastProcessTime = now;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        return AttentionState(
          status: AttentionStatus.unknown,
          confidence: 0.0,
          details: 'Failed to convert image',
        );
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return AttentionState(
          status: AttentionStatus.noFaceDetected,
          confidence: 0.0,
          details: 'No face detected',
        );
      }

      // Use the first detected face (or largest if multiple)
      final face = faces.first;
      final metrics = _extractFaceMetrics(face);

      return _determineAttentionState(metrics);
    } catch (e) {
      debugPrint('Error processing image: $e');
      return AttentionState(
        status: AttentionStatus.unknown,
        confidence: 0.0,
        details: 'Error: $e',
      );
    } finally {
      _isProcessing = false;
    }
  }

  FaceMetrics _extractFaceMetrics(Face face) {
    return FaceMetrics(
      faceDetected: true,
      leftEyeOpenProbability: face.leftEyeOpenProbability,
      rightEyeOpenProbability: face.rightEyeOpenProbability,
      headPitch: face.headEulerAngleX,
      headYaw: face.headEulerAngleY,
      headRoll: face.headEulerAngleZ,
      faceSize: face.boundingBox.width * face.boundingBox.height,
    );
  }

  AttentionState _determineAttentionState(FaceMetrics metrics) {
    if (!metrics.faceDetected) {
      return AttentionState(
        status: AttentionStatus.noFaceDetected,
        confidence: 0.0,
        details: 'No face detected',
      );
    }

    // Check multiple criteria
    final eyesOpen = metrics.eyesOpen;
    final headFacing = metrics.headFacingScreen;

    // Calculate confidence score
    double confidence = 0.0;
    final details = <String>[];

    if (eyesOpen) {
      confidence += 0.6;
      details.add('Eyes open ✓');
    } else {
      details.add('Eyes closed ✗');
    }

    if (headFacing) {
      confidence += 0.4;
      details.add('Head facing screen ✓');
    } else {
      details.add('Head not facing screen ✗');
    }

    // Determine status
    AttentionStatus status;
    if (confidence >= 0.8) {
      status = AttentionStatus.payingAttention;
    } else {
      status = AttentionStatus.notPayingAttention;
    }

    return AttentionState(
      status: status,
      confidence: confidence,
      details: details.join(', '),
    );
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      // Concatenate all plane bytes
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      // Platform-specific rotation
      // Android front camera: 270 degrees (portrait mode)
      // iOS front camera: 0 degrees (native orientation)
      final InputImageRotation imageRotation = Platform.isAndroid
          ? InputImageRotation.rotation270deg
          : InputImageRotation.rotation0deg;

      final inputImageFormat = InputImageFormatValue.fromRawValue(
        image.format.raw,
      );
      if (inputImageFormat == null) {
        debugPrint('Unknown image format: ${image.format.raw}');
        return null;
      }

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await _faceDetector.close();
  }
}
