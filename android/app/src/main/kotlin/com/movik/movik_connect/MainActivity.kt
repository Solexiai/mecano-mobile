package com.movik.movik_connect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
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

    // Offre « qui sonne » (2026-11-09, « comme Uber ») :
    // - canal de notification dédié aux offres (importance haute, son Movi-K,
    //   vibration longue, visible sur l'écran verrouillé) — utilisé par le
    //   push serveur (`channelId: movik_delivery_offers`) quand l'app est
    //   fermée ou en arrière-plan ;
    // - canal Flutter `movik/offer_alert` : sonnerie en boucle + vibration
    //   répétée pendant que l'écran d'offre plein écran est affiché, arrêtées
    //   dès que le chauffeur répond ou que l'offre expire. Le son suit le
    //   volume « sonnerie » du téléphone (mode silencieux respecté).
    private val offerAlertChannel = "movik/offer_alert"
    private val offerNotificationChannelId = "movik_delivery_offers"
    private val offerVibrationPattern = longArrayOf(0, 600, 300, 600, 300, 900)
    private var offerPlayer: MediaPlayer? = null
    private var offerVibrator: Vibrator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createOfferNotificationChannel()
    }

    override fun onDestroy() {
        stopOfferAlert()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "signingCertSha1" -> result.success(signingCertSha1())
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, offerAlertChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startOfferAlert()
                    result.success(null)
                }
                "stop" -> {
                    stopOfferAlert()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun offerSoundUri(): Uri = Uri.parse("android.resource://$packageName/${R.raw.movik_offer}")

    private fun ringtoneAttributes(): AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private fun createOfferNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val manager = getSystemService(NotificationManager::class.java) ?: return
            if (manager.getNotificationChannel(offerNotificationChannelId) != null) return
            val channel = NotificationChannel(
                offerNotificationChannelId,
                "Nouvelles demandes de livraison",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Sonne quand une livraison vous est proposée pendant que vous êtes en service."
                setSound(offerSoundUri(), ringtoneAttributes())
                enableVibration(true)
                vibrationPattern = offerVibrationPattern
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(channel)
        } catch (_: Exception) {
            // Sans canal dédié, Android utilise le canal par défaut : l'offre
            // arrive quand même, avec le son standard.
        }
    }

    private fun startOfferAlert() {
        stopOfferAlert()
        try {
            val player = MediaPlayer()
            player.setAudioAttributes(ringtoneAttributes())
            val fd = resources.openRawResourceFd(R.raw.movik_offer)
            player.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
            fd.close()
            player.isLooping = true
            player.prepare()
            player.start()
            offerPlayer = player
        } catch (_: Exception) {
            offerPlayer = null
        }
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            if (vibrator != null && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createWaveform(offerVibrationPattern, 0))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(offerVibrationPattern, 0)
                }
                offerVibrator = vibrator
            }
        } catch (_: Exception) {
            offerVibrator = null
        }
    }

    private fun stopOfferAlert() {
        try {
            offerPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {
        }
        offerPlayer = null
        try {
            offerVibrator?.cancel()
        } catch (_: Exception) {
        }
        offerVibrator = null
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
