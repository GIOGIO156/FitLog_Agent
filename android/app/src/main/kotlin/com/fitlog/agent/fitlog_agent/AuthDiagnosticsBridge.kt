package com.fitlog.agent.fitlog_agent

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Local, user-exported diagnostics. No network identifiers or credentials. */
class AuthDiagnosticsBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "fitlog/auth_diagnostics")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "snapshot" -> {
                    try { result.success(snapshot()) }
                    catch (_: Exception) { result.success(mapOf("snapshot_status" to "unavailable")) }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun snapshot(): Map<String, Any?> {
        val connectivity = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivity.activeNetwork
        val caps = connectivity.getNetworkCapabilities(network)
        val power = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
        val manager = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val pkg = activity.packageManager.getPackageInfo(activity.packageName, 0)
        return mapOf(
            "snapshot_status" to "available",
            "app_version" to pkg.versionName,
            "build_number" to if (Build.VERSION.SDK_INT >= 28) pkg.longVersionCode else pkg.versionCode.toLong(),
            "android_sdk" to Build.VERSION.SDK_INT,
            "android_release" to Build.VERSION.RELEASE,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "network" to when {
                caps == null -> "none"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "vpn"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                else -> "other"
            },
            "network_validated" to (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) ?: false),
            "network_internet" to (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ?: false),
            "vpn_active" to (caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ?: false),
            "proxy_configured" to (connectivity.defaultProxy != null),
            "auto_time" to (Settings.Global.getInt(activity.contentResolver, Settings.Global.AUTO_TIME, 0) == 1),
            "power_save" to power.isPowerSaveMode,
            "battery_optimization_exempt" to power.isIgnoringBatteryOptimizations(activity.packageName),
            "background_restricted" to if (Build.VERSION.SDK_INT >= 28) manager.isBackgroundRestricted else null,
            "first_install_ms" to pkg.firstInstallTime,
            "last_update_ms" to pkg.lastUpdateTime,
        )
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
