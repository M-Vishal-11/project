import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_session.dart';

class AgentDataService {
  static StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  static StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  static StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  static const int _dataRetentionMinutes = 10;
  static const int _maxBufferSize = 100;

  // In-memory ring buffers to avoid 100Hz SQLite disk writes and database locking
  static final List<Map<String, dynamic>> _accelerometerBuffer = [];
  static final List<Map<String, dynamic>> _gyroscopeBuffer = [];
  static final List<Map<String, dynamic>> _magnetometerBuffer = [];

  // Start collecting all sensor data
  static Future<void> startDataCollection() async {
    print('🚀 [AGENT DATA] Starting comprehensive in-memory data collection');

    // Start accelerometer data collection
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _saveSensorData('accelerometer', {
        'x': event.x,
        'y': event.y,
        'z': event.z,
        'magnitude': sqrt(event.x * event.x + event.y * event.y + event.z * event.z),
      });
    });

    // Start gyroscope data collection
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      _saveSensorData('gyroscope', {
        'x': event.x,
        'y': event.y,
        'z': event.z,
        'magnitude': sqrt(event.x * event.x + event.y * event.y + event.z * event.z),
      });
    });

    // Start magnetometer data collection
    _magnetometerSubscription = magnetometerEvents.listen((MagnetometerEvent event) {
      _saveSensorData('magnetometer', {
        'x': event.x,
        'y': event.y,
        'z': event.z,
        'magnitude': sqrt(event.x * event.x + event.y * event.y + event.z * event.z),
      });
    });

    print('✅ [AGENT DATA] Sensor data collection started');
  }

  // Stop collecting sensor data
  static Future<void> stopDataCollection() async {
    print('🛑 [AGENT DATA] Stopping data collection');

    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    await _magnetometerSubscription?.cancel();

    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _magnetometerSubscription = null;

    print('✅ [AGENT DATA] Data collection stopped');
  }

  // Save sensor data to in-memory ring buffer
  static void _saveSensorData(String dataType, Map<String, dynamic> data) {
    final entry = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data_type': dataType,
      'data': data,
    };

    switch (dataType) {
      case 'accelerometer':
        _accelerometerBuffer.add(entry);
        if (_accelerometerBuffer.length > _maxBufferSize) {
          _accelerometerBuffer.removeAt(0);
        }
        break;
      case 'gyroscope':
        _gyroscopeBuffer.add(entry);
        if (_gyroscopeBuffer.length > _maxBufferSize) {
          _gyroscopeBuffer.removeAt(0);
        }
        break;
      case 'magnetometer':
        _magnetometerBuffer.add(entry);
        if (_magnetometerBuffer.length > _maxBufferSize) {
          _magnetometerBuffer.removeAt(0);
        }
        break;
    }
  }

  // Get comprehensive data for AI agent (optimized for smaller payload)
  static Future<Map<String, dynamic>> getComprehensiveData() async {
    try {
      print('📊 [AGENT DATA] Collecting essential data for AI agent');

      // Get current location
      final locationData = await _getCurrentLocationData();

      // Get nearby safe places (limited to 3 closest)
      final safePlacesData = await _getNearbySafePlaces(locationData);

      // Get essential sensor data (summary only)
      final sensorData = await _getEssentialSensorData();

      // Get user context (essential info only)
      final userContext = await _getEssentialUserContext();

      final essentialData = {
        'location': locationData,
        'nearby_safe_places': safePlacesData.take(3).toList(),
        'sensor_data': sensorData,
        'user_context': userContext,
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('✅ [AGENT DATA] Essential data collected successfully');
      return essentialData;
    } catch (e) {
      print('❌ [AGENT DATA] Error collecting essential data: $e');
      return {
        'error': 'Failed to collect essential data: ${e.toString()}',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Get current location data
  static Future<Map<String, dynamic>> _getCurrentLocationData() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
      };
    } catch (e) {
      return {
        'error': 'Failed to get location: ${e.toString()}',
        'location_permission_status': (await Geolocator.checkPermission()).toString(),
      };
    }
  }

  // Get nearby safe places
  static Future<List<Map<String, dynamic>>> _getNearbySafePlaces(Map<String, dynamic> locationData) async {
    try {
      if (locationData.containsKey('error')) {
        return [];
      }

      // Query Firestore for nearby safe places
      final db = FirebaseFirestore.instance;
      final safePlaces = <Map<String, dynamic>>[];

      // Get police stations within 5km
      final policeQuery = await db.collection('safe_places')
          .where('type', isEqualTo: 'police_station')
          .limit(10)
          .get();

      for (final doc in policeQuery.docs) {
        final data = doc.data();
        final distance = _calculateDistance(
          locationData['latitude'],
          locationData['longitude'],
          data['latitude'],
          data['longitude'],
        );

        if (distance <= 5.0) {
          safePlaces.add({
            'type': 'police_station',
            'name': data['name'],
            'distance_km': distance,
          });
        }
      }

      // Get hospitals within 10km
      final hospitalQuery = await db.collection('safe_places')
          .where('type', isEqualTo: 'hospital')
          .limit(10)
          .get();

      for (final doc in hospitalQuery.docs) {
        final data = doc.data();
        final distance = _calculateDistance(
          locationData['latitude'],
          locationData['longitude'],
          data['latitude'],
          data['longitude'],
        );

        if (distance <= 10.0) {
          safePlaces.add({
            'type': 'hospital',
            'name': data['name'],
            'distance_km': distance,
          });
        }
      }

      // Sort by distance
      safePlaces.sort((a, b) => (a['distance_km'] as double).compareTo(b['distance_km'] as double));
      return safePlaces.take(5).toList();
    } catch (e) {
      print('❌ [AGENT DATA] Error getting nearby safe places: $e');
      return [];
    }
  }

  // Calculate distance between two points
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  // Get essential sensor data (summary only from in-memory buffer)
  static Future<Map<String, dynamic>> _getEssentialSensorData() async {
    try {
      if (_accelerometerBuffer.isEmpty) {
        return {'status': 'no_data'};
      }

      final recentReadings = _accelerometerBuffer.reversed.take(50).toList();
      final magnitudes = recentReadings.map((e) {
        final sensorData = e['data'] as Map<String, dynamic>;
        return (sensorData['magnitude'] as num).toDouble();
      }).toList();

      if (magnitudes.isEmpty) {
        return {'status': 'no_data'};
      }

      final avgMagnitude = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
      final maxMagnitude = magnitudes.reduce((a, b) => a > b ? a : b);

      final highMovementCount = magnitudes.where((m) => m > 15.0).length;
      final lowMovementCount = magnitudes.where((m) => m < 5.0).length;

      String movementPattern = 'normal';
      Map<String, bool> indicators = {};

      if (highMovementCount > 10) {
        movementPattern = 'high_activity';
        indicators['possible_running'] = avgMagnitude > 12.0;
      } else if (lowMovementCount > 50) {
        movementPattern = 'low_activity';
        indicators['possible_stationary'] = avgMagnitude < 6.0;
      }

      indicators['possible_fall'] = maxMagnitude > 25.0;

      return {
        'accelerometer': {
          'movement_pattern': movementPattern,
          'average_magnitude': avgMagnitude,
          'max_magnitude': maxMagnitude,
          'potential_indicators': indicators,
        },
      };
    } catch (e) {
      print('❌ [AGENT DATA] Error getting essential sensor data: $e');
      return {'error': 'Failed to get sensor data: ${e.toString()}'};
    }
  }

  // Get essential user context
  static Future<Map<String, dynamic>> _getEssentialUserContext() async {
    try {
      final localUserId = await LocalSession.getCurrentUserId();
      if (localUserId == null) {
        return {'status': 'not_authenticated'};
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(localUserId)
          .get();

      if (!userDoc.exists) {
        return {'status': 'user_not_found'};
      }

      final userData = userDoc.data()!;

      return {
        'name': userData['name'],
        'is_sharing_location': userData['sharingLocation'] ?? false,
        'emergency_contacts_count': (userData['emergencyContacts'] as List?)?.length ?? 0,
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  // Get sensor data from in-memory buffer
  static Future<Map<String, dynamic>> _getSensorData(int cutoffTime) async {
    try {
      final accelList = _accelerometerBuffer.where((e) => (e['timestamp'] as int) >= cutoffTime).take(100).toList();
      final gyroList = _gyroscopeBuffer.where((e) => (e['timestamp'] as int) >= cutoffTime).take(100).toList();
      final magList = _magnetometerBuffer.where((e) => (e['timestamp'] as int) >= cutoffTime).take(100).toList();

      final accelerometerAnalysis = _analyzeAccelerometerData(accelList);
      final gyroscopeAnalysis = _analyzeGyroscopeData(gyroList);
      final magnetometerAnalysis = _analyzeMagnetometerData(magList);

      return {
        'accelerometer': {
          'raw_data_count': accelList.length,
          'analysis': accelerometerAnalysis,
          'recent_readings': accelList.take(10).map((e) => e['data']).toList(),
        },
        'gyroscope': {
          'raw_data_count': gyroList.length,
          'analysis': gyroscopeAnalysis,
          'recent_readings': gyroList.take(10).map((e) => e['data']).toList(),
        },
        'magnetometer': {
          'raw_data_count': magList.length,
          'analysis': magnetometerAnalysis,
          'recent_readings': magList.take(10).map((e) => e['data']).toList(),
        },
        'data_period_minutes': _dataRetentionMinutes,
      };
    } catch (e) {
      print('❌ [AGENT DATA] Error getting sensor data: $e');
      return {
        'error': 'Failed to get sensor data: ${e.toString()}',
      };
    }
  }

  // Analyze accelerometer data
  static Map<String, dynamic> _analyzeAccelerometerData(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return {'status': 'no_data'};
    }

    final magnitudes = data.map((e) {
      final sensorData = e['data'] as Map<String, dynamic>;
      return (sensorData['magnitude'] as num).toDouble();
    }).toList();

    final avgMagnitude = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
    final maxMagnitude = magnitudes.reduce((a, b) => a > b ? a : b);
    final minMagnitude = magnitudes.reduce((a, b) => a < b ? a : b);

    final highMovementCount = magnitudes.where((m) => m > 15.0).length;
    final lowMovementCount = magnitudes.where((m) => m < 5.0).length;

    return {
      'average_magnitude': avgMagnitude,
      'max_magnitude': maxMagnitude,
      'min_magnitude': minMagnitude,
      'high_movement_readings': highMovementCount,
      'low_movement_readings': lowMovementCount,
      'movement_pattern': highMovementCount > 10 ? 'high_activity' :
                         lowMovementCount > 50 ? 'low_activity' : 'normal',
      'potential_indicators': {
        'possible_fall': maxMagnitude > 25.0,
        'possible_running': avgMagnitude > 12.0 && highMovementCount > 20,
        'possible_stationary': avgMagnitude < 6.0 && lowMovementCount > 30,
      },
    };
  }

  // Analyze gyroscope data
  static Map<String, dynamic> _analyzeGyroscopeData(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return {'status': 'no_data'};
    }

    final rotations = data.map((e) {
      final sensorData = e['data'] as Map<String, dynamic>;
      return (sensorData['magnitude'] as num).toDouble();
    }).toList();

    final avgRotation = rotations.reduce((a, b) => a + b) / rotations.length;
    final maxRotation = rotations.reduce((a, b) => a > b ? a : b);

    return {
      'average_rotation': avgRotation,
      'max_rotation': maxRotation,
      'rotation_pattern': avgRotation > 2.0 ? 'high_rotation' : 'low_rotation',
      'potential_indicators': {
        'possible_spinning': maxRotation > 5.0,
        'possible_turning': avgRotation > 1.0,
      },
    };
  }

  // Analyze magnetometer data
  static Map<String, dynamic> _analyzeMagnetometerData(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return {'status': 'no_data'};
    }

    final magneticFields = data.map((e) {
      final sensorData = e['data'] as Map<String, dynamic>;
      return (sensorData['magnitude'] as num).toDouble();
    }).toList();

    final avgField = magneticFields.reduce((a, b) => a + b) / magneticFields.length;
    final maxField = magneticFields.reduce((a, b) => a > b ? a : b);

    return {
      'average_magnetic_field': avgField,
      'max_magnetic_field': maxField,
      'field_stability': maxField - avgField < 10.0 ? 'stable' : 'variable',
    };
  }

  // Clean up old data
  static Future<void> cleanupOldData() async {
    final cutoffTime = DateTime.now()
        .subtract(const Duration(minutes: _dataRetentionMinutes))
        .millisecondsSinceEpoch;
    _accelerometerBuffer.removeWhere((e) => (e['timestamp'] as int) < cutoffTime);
    _gyroscopeBuffer.removeWhere((e) => (e['timestamp'] as int) < cutoffTime);
    _magnetometerBuffer.removeWhere((e) => (e['timestamp'] as int) < cutoffTime);
  }

  // Close service
  static Future<void> close() async {
    await stopDataCollection();
    _accelerometerBuffer.clear();
    _gyroscopeBuffer.clear();
    _magnetometerBuffer.clear();
  }
}
