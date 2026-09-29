package com.example.safestep

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.safestep.FakeCallUtils

class ShakeDetectionService : Service(), SensorEventListener {
    private var userMaxGestureValue: Float = Float.POSITIVE_INFINITY
    private lateinit var sensorManager: SensorManager
    private var accelLast = 0f

    // Multi-shake detection parameters
    private val MIN_SHAKE_THRESHOLD = 14.5f             // Minimum delta acceleration (m/s²) to qualify as a strong shake
    private val REQUIRED_SHAKE_COUNT = 3               // Requires 3 distinct strong shakes
    private val SHAKE_WINDOW_MS = 1800L                // All shakes must occur within 1.8 seconds
    private val MIN_INTERVAL_BETWEEN_SHAKES_MS = 220L  // Minimum 220ms between separate shake peaks (prevents double-counting 1 movement)
    private val SOS_COOLDOWN_MS = 3000L                // 3.0 second cooldown after SOS trigger to prevent repeat triggers

    private var shakeCount = 0
    private var firstShakeTime = 0L
    private var lastShakeTime = 0L
    private var lastSosTriggerTime = 0L

    private val CHANNEL_ID = "shake_detection_service"
    private val NOTIFICATION_ID = 2001
    private var lastNotificationTime = 0L
    private val NOTIFICATION_INTERVAL_MS = 2000L

    companion object {
    // Static method to record shake gesture for 10 seconds and return max value
        fun recordShakeGesture(context: Context, callback: (Float?, String?) -> Unit) {
            try {
                val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
                val accelSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                if (accelSensor == null) {
                    Log.e("ShakeDetectionService", "No accelerometer sensor available")
                    callback(null, "No accelerometer sensor available")
                    return
                }
                var accelLast = SensorManager.GRAVITY_EARTH
                var maxDelta = 0f
                val listener = object : SensorEventListener {
                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                    override fun onSensorChanged(event: SensorEvent?) {
                        if (event?.sensor?.type == Sensor.TYPE_ACCELEROMETER) {
                            val x = event.values[0]
                            val y = event.values[1]
                            val z = event.values[2]
                            val accelCurrent = Math.sqrt((x * x + y * y + z * z).toDouble()).toFloat()
                            val delta = Math.abs(accelCurrent - accelLast)
                            accelLast = accelCurrent
                            if (delta > maxDelta) maxDelta = delta
                        }
                    }
                }
                sensorManager.registerListener(listener, accelSensor, SensorManager.SENSOR_DELAY_UI)
                android.os.Handler(context.mainLooper).postDelayed({
                    sensorManager.unregisterListener(listener)
                    Log.d("ShakeDetectionService", "Gesture recording finished, maxDelta=$maxDelta")
                    callback(maxDelta, null)
                }, 7000)
            } catch (e: Exception) {
                Log.e("ShakeDetectionService", "Error recording gesture: ${e.message}")
                callback(null, "Error recording gesture: ${e.message}")
            }
        }
    }

    override fun onCreate() {
        Log.d("ShakeDetectionService", "Service onCreate() called")
        // Load user's recorded max gesture value from SharedPreferences
        val prefs = getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
        if (prefs.contains("user_max_gesture_value")) {
            userMaxGestureValue = prefs.getFloat("user_max_gesture_value", Float.POSITIVE_INFINITY)
            Log.d("ShakeDetectionService", "Loaded user max gesture value: $userMaxGestureValue")
        } else {
            userMaxGestureValue = Float.POSITIVE_INFINITY
            Log.w("ShakeDetectionService", "No user max gesture value found, using default")
        }
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val accelSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (accelSensor != null) {
            sensorManager.registerListener(this, accelSensor, SensorManager.SENSOR_DELAY_UI)
            Log.d("ShakeDetectionService", "Accelerometer sensor registered")
        } else {
            Log.e("ShakeDetectionService", "No accelerometer sensor available")
        }
        accelLast = SensorManager.GRAVITY_EARTH
        createNotificationChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                buildNotification("Shake detection active"),
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(NOTIFICATION_ID, buildNotification("Shake detection active"))
        }
        Log.d("ShakeDetectionService", "Service started in foreground")
        val filter = android.content.IntentFilter().apply {
            addAction("com.example.safestep.FAKE_CALL_ACCEPTED")
            addAction("com.example.safestep.FAKE_CALL_REJECTED")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(fakeCallActionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(fakeCallActionReceiver, filter)
        }
    }

    override fun onDestroy() {
        Log.d("ShakeDetectionService", "Service onDestroy() called")
        super.onDestroy()
        sensorManager.unregisterListener(this)
        unregisterReceiver(fakeCallActionReceiver)
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_ACCELEROMETER) {
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]
            val accelCurrent = Math.sqrt((x * x + y * y + z * z).toDouble()).toFloat()
            val delta = Math.abs(accelCurrent - accelLast)
            accelLast = accelCurrent
            val now = System.currentTimeMillis()

            // In cooldown period after triggering SOS?
            if (now - lastSosTriggerTime < SOS_COOLDOWN_MS) {
                return
            }

            // Determine effective threshold (use calibrated value if sensible, or robust default)
            val threshold = if (userMaxGestureValue > 0f && userMaxGestureValue != Float.POSITIVE_INFINITY) {
                Math.max(MIN_SHAKE_THRESHOLD, userMaxGestureValue * 0.75f)
            } else {
                MIN_SHAKE_THRESHOLD
            }

            // Check if this acceleration delta qualifies as a strong shake
            if (delta > threshold) {
                // Reset window if too much time passed since first shake
                if (firstShakeTime == 0L || (now - firstShakeTime > SHAKE_WINDOW_MS)) {
                    shakeCount = 1
                    firstShakeTime = now
                    lastShakeTime = now
                    Log.d("ShakeDetectionService", "Shake 1/$REQUIRED_SHAKE_COUNT detected (delta=%.2f, threshold=%.2f)".format(delta, threshold))
                } else if (now - lastShakeTime >= MIN_INTERVAL_BETWEEN_SHAKES_MS) {
                    // Valid separate shake peak within the active window
                    shakeCount++
                    lastShakeTime = now
                    Log.d("ShakeDetectionService", "Shake $shakeCount/$REQUIRED_SHAKE_COUNT detected (delta=%.2f)".format(delta))

                    if (shakeCount >= REQUIRED_SHAKE_COUNT) {
                        Log.d("ShakeDetectionService", "Genuine shake gesture confirmed ($shakeCount shakes). Triggering SOS.")
                        lastSosTriggerTime = now
                        shakeCount = 0
                        firstShakeTime = 0L
                        lastShakeTime = 0L
                        openSosScreen()
                    }
                }
            }
        }
    }

    private fun onShakeDetected() {
        // Open SOS screen for every qualifying shake; SHAKE_DEBOUNCE_MS already prevents spam
        openSosScreen()
    }

    private fun openSosScreen() {
        try {
            // Persist flag; Flutter will open SOS once engine is ready (cold start safety)
            val prefs = getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("open_sos_screen", true).apply()

            // Create intent to open/bring app to foreground with SOS screen
            val intent = Intent(applicationContext, MainActivity::class.java).apply {
                action = "com.example.safestep.OPEN_SOS_SCREEN"
                addCategory(Intent.CATEGORY_LAUNCHER)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                putExtra("open_sos_screen", true)
                setPackage(packageName)
            }

            // Start the activity
            startActivity(intent)

            // Show notification that SOS screen was opened
            showEventNotification(
                "SOS Screen Opened",
                "Gesture detected - SOS screen opened"
            )
            
            Log.d("ShakeDetectionService", "SOS screen intent sent from background service")
        } catch (e: Exception) {
            Log.e("ShakeDetectionService", "Error opening SOS screen: ${e.message}")
            // Fallback: show notification
            showEventNotification(
                "Gesture Detected",
                "SOS screen could not be opened"
            )
        }
    }

    private val fakeCallActionReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            // No-op for multiple shake behavior
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Shake Detection",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(content: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SafeStep Background Detection")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .build()
    }

    private fun showEventNotification(title: String, content: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)
            .build()
        manager.notify((System.currentTimeMillis() % 10000).toInt(), notification)
    }
}
