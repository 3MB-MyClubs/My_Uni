package com.threemb.clupup

import android.content.Intent
import com.google.android.gms.pay.Pay
import com.google.android.gms.pay.PayApiAvailabilityStatus
import com.google.android.gms.pay.PayClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "ku_app/native_weather"
    private var previousBrightness: Float? = null
    private val walletRequestCode = 7421
    private val walletClient by lazy { Pay.getClient(this) }
    private var pendingWalletResult: MethodChannel.Result? = null
    private val pkpassHandler by lazy { PkpassTicketHandler(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ku_app/pkpass_ticket")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "addPass" -> pkpassHandler.addPass(call.arguments as? ByteArray, result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "openWeatherApp" -> result.success(openWeatherApp())
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ku_app/ticket_brightness")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "maximize" -> {
                        if (previousBrightness == null) {
                            previousBrightness = window.attributes.screenBrightness
                        }
                        window.attributes = window.attributes.apply { screenBrightness = 1f }
                        result.success(null)
                    }
                    "restore" -> {
                        previousBrightness?.let { brightness ->
                            window.attributes = window.attributes.apply { screenBrightness = brightness }
                            previousBrightness = null
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ku_app/google_wallet_ticket")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canAddPasses" -> walletClient
                        .getPayApiAvailabilityStatus(PayClient.RequestType.SAVE_PASSES)
                        .addOnSuccessListener { status ->
                            result.success(status == PayApiAvailabilityStatus.AVAILABLE)
                        }
                        .addOnFailureListener { result.success(false) }
                    "addPass" -> {
                        val jwt = call.arguments as? String
                        when {
                            jwt.isNullOrBlank() -> result.error("invalid_pass", "Empty Google Wallet pass", null)
                            pendingWalletResult != null -> result.error("wallet_busy", "Wallet sheet is already open", null)
                            else -> {
                                pendingWalletResult = result
                                try {
                                    walletClient.savePassesJwt(jwt, this, walletRequestCode)
                                } catch (error: Exception) {
                                    pendingWalletResult = null
                                    result.error("wallet_unavailable", error.message, null)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (pkpassHandler.onActivityResult(requestCode, resultCode, data)) return
        if (requestCode != walletRequestCode) return
        val result = pendingWalletResult ?: return
        pendingWalletResult = null
        when (resultCode) {
            RESULT_OK, RESULT_CANCELED -> result.success(null)
            PayClient.SavePassesResult.SAVE_ERROR -> result.error(
                "wallet_save_failed",
                data?.getStringExtra(PayClient.EXTRA_API_ERROR_MESSAGE) ?: "Google Wallet could not save this pass",
                null,
            )
            else -> result.error("wallet_save_failed", "Google Wallet did not save this pass", null)
        }
    }

    override fun onDestroy() {
        pkpassHandler.dispose()
        super.onDestroy()
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
