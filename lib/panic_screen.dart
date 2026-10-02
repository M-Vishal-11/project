import 'dart:async';
import 'package:flutter/material.dart';
import 'package:awesome_ripple_animation/awesome_ripple_animation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safestep/services/safety_share_service.dart';
import 'package:safestep/services/native_background_location_service.dart';

class TenSecondPanicScreen extends StatefulWidget {
  const TenSecondPanicScreen({super.key});

  @override
  State<TenSecondPanicScreen> createState() => _TenSecondPanicScreenState();
}

class _TenSecondPanicScreenState extends State<TenSecondPanicScreen> {
  late Timer _timer;
  int _countdown = 10;
  bool _isAlerting = false;
  bool _alertSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        _timer.cancel();
        _sendEmergencyAlert();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _sendEmergencyAlert() async {
    try {
      setState(() {
        _isAlerting = true;
        _error = null;
      });

      print('🚨 [EMERGENCY] Starting emergency alert process');

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await SafetyShareService.startSos(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      try {
        final trackingStarted = await NativeBackgroundLocationService.startSafetyTracking();
        await SafetyShareService.setTrackingEnabled(trackingStarted);
      } catch (trackingError) {
        debugPrint('[SAFETY SHARE] Background tracking did not start: $trackingError');
      }

      print('📍 [EMERGENCY] Current location: ${position.latitude}, ${position.longitude}');

      setState(() {
        _alertSent = true;
        _isAlerting = false;
      });
    } catch (e) {
      print('❌ [EMERGENCY] Error sending alert: $e');
      setState(() {
        _error = e.toString();
        _isAlerting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 140),
            // Show different UI based on state
            if (!_isAlerting && !_alertSent && _error == null) ...[
              // Countdown state
              RippleAnimation(
                key: UniqueKey(),
                repeat: true,
                duration: const Duration(milliseconds: 900),
                ripplesCount: 3,
                color: const Color(0xFF8F5FE8),
                minRadius: 100,
                size: const Size(170, 170),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF8F5FE8),
                  child: Text(
                    '$_countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 80,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 100),
              const Text(
                'KEEP CALM!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: Color(0xFF8F5FE8),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'After the countdown, your SafeStep close contacts will see an SOS alert and your live location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    color: Colors.black,
                  ),
                ),
              ),
            ] else if (_isAlerting) ...[
              // Alerting state
              RippleAnimation(
                key: UniqueKey(),
                repeat: true,
                duration: const Duration(milliseconds: 600),
                ripplesCount: 5,
                color: Colors.red,
                minRadius: 100,
                size: const Size(170, 170),
                child: const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.red,
                  child: Icon(
                    Icons.warning,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: 100),
              const Text(
                'ALERTING CLOSE CONTACTS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Sharing your SOS alert and live location with your SafeStep contacts...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    color: Colors.black,
                  ),
                ),
              ),
            ] else if (_alertSent) ...[
              // Success state
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green,
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 100),
              const Text(
                'ALERT SENT SUCCESSFULLY!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Your SafeStep contacts can see that you are in danger and follow your live location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    color: Colors.black,
                  ),
                ),
              ),
            ] else if (_error != null) ...[
              // Error state
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.orange,
                child: Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 100),
              const Text(
                'ALERT FAILED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Failed to send alert: $_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    color: Colors.black,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 60),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Press the button below to stop SOS alert.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: ElevatedButton(
                onPressed: () async {
                  _timer.cancel();
                  try {
                    await SafetyShareService.stopSos();
                    await NativeBackgroundLocationService.stopSafetyTracking();
                  } finally {
                    if (mounted) Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF8F5FE8),
                  minimumSize: const Size(200, 70),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text(
                  'STOP SENDING SOS ALERT',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}








