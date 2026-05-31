package com.example.flutter_application_1

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "ku_app/native_weather"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "openWeatherApp" -> result.success(openWeatherApp())
                else -> result.notImplemented()
            }
        }
    }

    private fun openWeatherApp(): Boolean {
        val packageManager = packageManager
        val knownWeatherPackages = listOf(
            "com.google.android.apps.weather",
            "com.sec.android.daemonapp",
            "com.samsung.android.weather",
            "com.huawei.android.totemweather",
            "com.miui.weather2",
            "com.coloros.weather2",
            "com.vivo.weather",
            "com.htc.Weather",
        )

        for (packageName in knownWeatherPackages) {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            }
        }

        val fallbackIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory("android.intent.category.APP_WEATHER")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        return if (fallbackIntent.resolveActivity(packageManager) != null) {
            startActivity(fallbackIntent)
            true
        } else {
            false
        }
    }
}
