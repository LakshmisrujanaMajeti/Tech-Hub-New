import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme.dart';
import '../core/api_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  late final MobileScannerController _cameraController;
  final _tokenInputController = TextEditingController();

  bool _isSubmitting = false;
  bool _hasScanned = false;
  bool _isTorchOn = false;
  CameraFacing _currentFacing = CameraFacing.back;
  String? _errorMessage;
  Map<String, dynamic>? _attendanceResult;

  late AnimationController _laserAnimController;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _tokenInputController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isSubmitting || _hasScanned) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();
      if (rawValue != null && rawValue.isNotEmpty) {
        HapticFeedback.mediumImpact();
        setState(() => _hasScanned = true);
        _submitAttendance(rawValue);
        break;
      }
    }
  }

  Future<void> _submitAttendance(String token) async {
    String clean = token.trim();
    if (clean.startsWith('{') && clean.contains('attendance_token')) {
      try {
        final parsed = jsonDecode(clean);
        if (parsed['attendance_token'] != null) {
          clean = parsed['attendance_token'].toString().trim();
        }
      } catch (_) {}
    }
    clean = clean.toUpperCase();

    if (clean.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter or scan a valid attendance token.';
        _hasScanned = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.markAttendance(clean, deviceInfo: 'Cognito Mobile App (Camera Scan)');
      if (mounted) {
        setState(() {
          _attendanceResult = res['attendance'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          // Allow re-scanning after error
          _hasScanned = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _toggleTorch() async {
    try {
      await _cameraController.toggleTorch();
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (e) {
      debugPrint('Error toggling torch: $e');
    }
  }

  void _switchCamera() async {
    try {
      await _cameraController.switchCamera();
      setState(() {
        _currentFacing = _currentFacing == CameraFacing.back ? CameraFacing.front : CameraFacing.back;
      });
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }

  void _retryCamera() {
    setState(() {
      _errorMessage = null;
    });
    _cameraController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Scan Attendance QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: _isTorchOn ? Colors.amber : Colors.white70),
            tooltip: 'Toggle Flashlight',
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded, color: Colors.white70),
            tooltip: 'Switch Camera',
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: SafeArea(
        child: _attendanceResult != null ? _buildSuccessView() : _buildScannerView(),
      ),
    );
  }

  Widget _buildScannerView() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded, size: 16, color: Colors.lightBlueAccent),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Point camera at the live classroom QR projector',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: Colors.cyanAccent),
                  SizedBox(width: 6),
                  Text(
                    'Daily Attendance Hours: 09:00 AM – 04:00 PM',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Camera Viewport & Viewfinder
            SizedBox(
              height: 330,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: CognitoColors.primary.withValues(alpha: 0.6), width: 2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Real Hardware Camera Feed
                      MobileScanner(
                        controller: _cameraController,
                        onDetect: _onBarcodeDetected,
                        errorBuilder: (context, error) {
                          return _buildCameraErrorWidget(error);
                        },
                      ),

                      // 2. Viewfinder Target Corners
                      Positioned(top: 24, left: 24, child: _cornerIcon()),
                      Positioned(top: 24, right: 24, child: _cornerIcon(rotation: 1)),
                      Positioned(bottom: 24, left: 24, child: _cornerIcon(rotation: 3)),
                      Positioned(bottom: 24, right: 24, child: _cornerIcon(rotation: 2)),

                      // 3. Animated Scanning Laser Bar
                      if (!_isSubmitting)
                        AnimatedBuilder(
                          animation: _laserAnimController,
                          builder: (context, child) {
                            return Align(
                              alignment: Alignment(0, (_laserAnimController.value * 2) - 1),
                              child: Container(
                                height: 3,
                                margin: const EdgeInsets.symmetric(horizontal: 40),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyanAccent.withValues(alpha: 0.9),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                      // 4. In-Flight Processing Indicator
                      if (_isSubmitting)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                SizedBox(height: 12),
                                Text(
                                  'Verifying & Syncing Attendance...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Controls shortcut strip
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                InkWell(
                  onTap: _toggleTorch,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isTorchOn ? Colors.amber.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _isTorchOn ? Colors.amber : Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          size: 18,
                          color: _isTorchOn ? Colors.amber : Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isTorchOn ? 'Flashlight ON' : 'Flashlight OFF',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isTorchOn ? Colors.amber : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: _switchCamera,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flip_camera_ios_rounded, size: 18, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text(
                          _currentFacing == CameraFacing.back ? 'Back Camera' : 'Front Camera',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Error Alert Banner
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: CognitoColors.danger.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CognitoColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // Alternative Manual Token Entry Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.keyboard_outlined, size: 16, color: Colors.white60),
                      SizedBox(width: 8),
                      Text(
                        'Alternative Manual Token Entry',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'If camera has trouble focusing on the projector, enter the code shown under the QR:',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tokenInputController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
                          decoration: InputDecoration(
                            hintText: 'Enter session token code',
                            hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 1),
                            fillColor: Colors.black26,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : () => _submitAttendance(_tokenInputController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CognitoColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('SUBMIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraErrorWidget(MobileScannerException error) {
    final isPermDenied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isPermDenied ? Icons.no_photography_rounded : Icons.videocam_off_rounded, size: 44, color: Colors.orangeAccent),
            const SizedBox(height: 12),
            Text(
              isPermDenied ? 'Camera Permission Required' : 'Camera Hardware Notice',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              isPermDenied
                  ? 'Please grant camera access to scan attendance QR codes directly from your device.'
                  : 'Unable to start camera sensor. You can enter the session token manually below.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _retryCamera,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(isPermDenied ? 'ALLOW CAMERA ACCESS' : 'RETRY CAMERA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CognitoColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final isOffline = _attendanceResult?['status'] == 'QUEUED_OFFLINE';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isOffline ? Colors.orange : CognitoColors.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isOffline ? Colors.orange : CognitoColors.success).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(isOffline ? Icons.cloud_queue_rounded : Icons.check, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              isOffline ? 'OFFLINE RECORD QUEUED' : 'ATTENDANCE RECORDED',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            Text(
              isOffline
                  ? 'Attendance saved on device. Automatic cloud sync active.'
                  : (_attendanceResult!['sessionTitle'] ?? 'Classroom Session'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            if (!isOffline && _attendanceResult!['collegeName'] != null)
              Text(
                '${_attendanceResult!['collegeName']} • ${_attendanceResult!['batchName'] ?? ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Token ID: ', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _attendanceResult!['token'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sync Status: ', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            isOffline ? 'QUEUED FOR AUTO-SYNC' : 'VERIFIED & AUDITED',
                            style: TextStyle(
                              color: isOffline ? Colors.amberAccent : Colors.greenAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: CognitoColors.primary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('BACK TO DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cornerIcon({int rotation = 0}) {
    return RotatedBox(
      quarterTurns: rotation,
      child: Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.cyanAccent, width: 3.5),
            left: BorderSide(color: Colors.cyanAccent, width: 3.5),
          ),
        ),
      ),
    );
  }
}
