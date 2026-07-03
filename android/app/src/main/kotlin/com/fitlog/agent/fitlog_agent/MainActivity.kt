package com.fitlog.agent.fitlog_agent

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var notificationChannel: MethodChannel? = null
    private var pendingWorkoutDraftNotificationTap = false
    private var notificationPermissionRequested = false
    private var pendingNotificationTitle: String? = null
    private var pendingNotificationBody: String? = null
    private var pendingNotificationImageAsset: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WORKOUT_DRAFT_NOTIFICATION_CHANNEL,
        )
        notificationChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "showWorkoutDraftNotification" -> {
                    val title = call.argument<String>("title")?.trim().orEmpty()
                    val body = call.argument<String>("body")?.trim().orEmpty()
                    val imageAsset = call.argument<String>("imageAsset")?.trim()
                    if (title.isEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    result.success(showWorkoutDraftNotification(title, body, imageAsset))
                }
                "cancelWorkoutDraftNotification" -> {
                    cancelWorkoutDraftNotification()
                    result.success(null)
                }
                "consumeInitialWorkoutDraftNotificationTap" -> {
                    val consumed = pendingWorkoutDraftNotificationTap
                    pendingWorkoutDraftNotificationTap = false
                    result.success(consumed)
                }
                else -> result.notImplemented()
            }
        }
        rememberWorkoutDraftNotificationTap(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        notificationChannel?.setMethodCallHandler(null)
        notificationChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isWorkoutDraftNotificationTap(intent)) {
            notificationChannel?.invokeMethod("workoutDraftNotificationTapped", null)
                ?: run { pendingWorkoutDraftNotificationTap = true }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_POST_NOTIFICATIONS) {
            return
        }
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        val title = pendingNotificationTitle
        val body = pendingNotificationBody
        val imageAsset = pendingNotificationImageAsset
        pendingNotificationTitle = null
        pendingNotificationBody = null
        pendingNotificationImageAsset = null
        if (granted && title != null && body != null) {
            showWorkoutDraftNotification(title, body, imageAsset)
        }
    }

    private fun rememberWorkoutDraftNotificationTap(intent: Intent?) {
        if (isWorkoutDraftNotificationTap(intent)) {
            pendingWorkoutDraftNotificationTap = true
        }
    }

    private fun isWorkoutDraftNotificationTap(intent: Intent?): Boolean {
        return intent?.action == ACTION_WORKOUT_DRAFT_NOTIFICATION
    }

    private fun showWorkoutDraftNotification(
        title: String,
        body: String,
        imageAsset: String?,
    ): Boolean {
        if (!canPostNotifications()) {
            requestNotificationPermissionIfNeeded(title, body, imageAsset)
            return false
        }
        val manager = notificationManager()
        ensureWorkoutDraftNotificationChannel(manager)

        val tapIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_WORKOUT_DRAFT_NOTIFICATION
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val tapPendingIntent = PendingIntent.getActivity(
            this,
            WORKOUT_DRAFT_NOTIFICATION_REQUEST_CODE,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutablePendingIntentFlag(),
        )

        val exerciseImage = loadFlutterAssetBitmap(imageAsset)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, WORKOUT_DRAFT_NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setSmallIcon(R.drawable.ic_fitlog_notification_small)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(tapPendingIntent)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setOngoing(false)
            .setCategory(Notification.CATEGORY_STATUS)
            .setPriority(Notification.PRIORITY_DEFAULT)

        exerciseImage?.let { builder.setLargeIcon(it) }
        exerciseImage?.let {
            val style = Notification.BigPictureStyle().bigPicture(it)
            style.bigLargeIcon(it)
            builder.setStyle(style)
        }

        return try {
            manager.notify(WORKOUT_DRAFT_NOTIFICATION_ID, builder.build())
            true
        } catch (_: SecurityException) {
            false
        }
    }

    private fun cancelWorkoutDraftNotification() {
        notificationManager().cancel(WORKOUT_DRAFT_NOTIFICATION_ID)
    }

    private fun notificationManager(): NotificationManager {
        return getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }

    private fun ensureWorkoutDraftNotificationChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val existing = manager.getNotificationChannel(WORKOUT_DRAFT_NOTIFICATION_CHANNEL_ID)
        if (existing != null) {
            return
        }
        val channel = NotificationChannel(
            WORKOUT_DRAFT_NOTIFICATION_CHANNEL_ID,
            "Workout draft",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Current workout draft progress"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun canPostNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestNotificationPermissionIfNeeded(
        title: String,
        body: String,
        imageAsset: String?,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return
        }
        pendingNotificationTitle = title
        pendingNotificationBody = body
        pendingNotificationImageAsset = imageAsset
        if (notificationPermissionRequested) {
            return
        }
        notificationPermissionRequested = true
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_POST_NOTIFICATIONS,
        )
    }

    private fun immutablePendingIntentFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }

    private fun loadFlutterAssetBitmap(assetPath: String?): Bitmap? {
        val path = assetPath?.takeIf { it.isNotBlank() } ?: return null
        return try {
            val assetKey = FlutterInjector.instance()
                .flutterLoader()
                .getLookupKeyForAsset(path)
            assets.open(assetKey).use { input ->
                BitmapFactory.decodeStream(input)
            }
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        private const val WORKOUT_DRAFT_NOTIFICATION_CHANNEL =
            "fitlog/workout_draft_notification"
        private const val WORKOUT_DRAFT_NOTIFICATION_CHANNEL_ID =
            "workout_draft_progress"
        private const val WORKOUT_DRAFT_NOTIFICATION_ID = 4027
        private const val WORKOUT_DRAFT_NOTIFICATION_REQUEST_CODE = 4027
        private const val REQUEST_POST_NOTIFICATIONS = 4028
        private const val ACTION_WORKOUT_DRAFT_NOTIFICATION =
            "com.fitlog.agent.fitlog_agent.WORKOUT_DRAFT_NOTIFICATION"
    }
}
