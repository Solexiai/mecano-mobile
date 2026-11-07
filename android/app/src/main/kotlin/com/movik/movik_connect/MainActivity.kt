package com.movik.movik_connect

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    // Identité de l'app pour les clés Google restreintes « Applications
    // Android » (2026-11-07) : l'API Places (New) exige les en-têtes
    // X-Android-Package et X-Android-Cert (SHA-1 du certificat de signature)
    // quand la clé est restreinte à l'app. Le SHA-1 est calculé à l'exécution
    // pour que la même app marche signée par Google Play (clé de signature)
    // ou par la clé de téléversement (APK de test).
    private val channelName = "movik/app_identity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "signingCertSha1" -> result.success(signingCertSha1())
                else -> result.notImplemented()
            }
        }
    }

    private fun signingCertSha1(): String? {
        return try {
            val pm = packageManager
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                val signingInfo = info.signingInfo ?: return null
                if (signingInfo.hasMultipleSigners()) signingInfo.apkContentsSigners else signingInfo.signingCertificateHistory
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
            }
            val first = signatures?.firstOrNull() ?: return null
            val digest = MessageDigest.getInstance("SHA-1").digest(first.toByteArray())
            digest.joinToString("") { "%02X".format(it) }
        } catch (_: Exception) {
            null
        }
    }
}
