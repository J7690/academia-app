package com.academia.nexiomgroup.app

import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import me.leolin.shortcutbadger.ShortcutBadger
import java.io.File
import java.io.FileOutputStream

/**
 * Global registry of active ExoPlayer instances so the Activity lifecycle
 * can pause them all when the app goes to background.
 */
object ExoPlayerRegistry {
    private val players = mutableSetOf<ExoPlayer>()

    @Synchronized
    fun register(player: ExoPlayer) {
        players.add(player)
    }

    @Synchronized
    fun unregister(player: ExoPlayer) {
        players.remove(player)
    }

    @Synchronized
    fun pauseAll() {
        for (p in players) {
            if (p.isPlaying) {
                p.playWhenReady = false
            }
        }
        Log.d("ExoPlayerRegistry", "Paused ${players.size} players (background)")
    }
}

class MainActivity : FlutterActivity() {

    private val BADGE_CHANNEL = "com.academia.app/badge"
    private val DEEP_LINK_CHANNEL = "com.academia.app/deeplink"
    private val APP_CHANNEL = "com.academia.app/app"
    private val FICHIERS_CHANNEL = "com.academia.app/fichiers"
    private var initialDeepLink: String? = null
    private var deepLinkChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialDeepLink = intent?.dataString
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val deepLink = intent.dataString ?: return
        initialDeepLink = deepLink
        deepLinkChannel?.invokeMethod("onLinkReceived", deepLink)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Pause all ExoPlayer instances when Activity goes to background
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onPause(owner: LifecycleOwner) {
                ExoPlayerRegistry.pauseAll()
            }
        })

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "academia_android_video",
                AcademiaAndroidVideoViewFactory(flutterEngine.dartExecutor.binaryMessenger)
            )

        deepLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEEP_LINK_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> {
                        result.success(initialDeepLink)
                        initialDeepLink = null
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Réduction de l'application, sans la fermer.
        //
        // Indispensable au partage d'écran : sur un téléphone, partager sert
        // précisément à MONTRER autre chose — un document, une application,
        // l'écran d'accueil. Tant que l'application reste au premier plan, elle
        // se partage elle-même et l'exercice n'a aucun intérêt.
        //
        // `moveTaskToBack(true)` renvoie l'utilisateur à son écran d'accueil en
        // laissant l'activité vivante : la capture continue (elle est portée par
        // le service de premier plan) et la séance n'est pas quittée. Revenir se
        // fait par la notification persistante ou l'icône de l'application.
        // `finish()` ou `SystemNavigator.pop()` fermeraient la séance : à éviter.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "moveToBackground" -> {
                        moveTaskToBack(true)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BADGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateBadge" -> {
                        val count = call.argument<Int>("count") ?: 0
                        try {
                            // Update both ShortcutBadger and SharedPreferences
                            val prefs = getSharedPreferences(
                                AcademiaFirebaseMessagingService.PREFS_NAME, MODE_PRIVATE)
                            prefs.edit().putInt(
                                AcademiaFirebaseMessagingService.KEY_BADGE_COUNT, count).apply()
                            if (count > 0) {
                                ShortcutBadger.applyCount(applicationContext, count)
                            } else {
                                ShortcutBadger.removeCount(applicationContext)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "removeBadge" -> {
                        try {
                            val prefs = getSharedPreferences(
                                AcademiaFirebaseMessagingService.PREFS_NAME, MODE_PRIVATE)
                            prefs.edit().putInt(
                                AcademiaFirebaseMessagingService.KEY_BADGE_COUNT, 0).apply()
                            ShortcutBadger.removeCount(applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Enregistrer un document dans le dossier « Téléchargements » de
        // l'appareil — celui que l'étudiant ouvre depuis son gestionnaire de
        // fichiers, pas un dossier privé à l'application.
        //
        // Pourquoi du code natif plutôt qu'un paquet : les deux greffons
        // MediaStore de pub.dev (media_store_plus, flutter_media_store) n'ont
        // rien publié depuis 20 et 23 mois et sont testés jusqu'à l'API 33,
        // alors que cette application cible l'API 36. MediaStore, lui, est
        // stable depuis l'API 29 et tient en quarante lignes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FICHIERS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enregistrerDansTelechargements" -> {
                        val octets = call.argument<ByteArray>("octets")
                        val nom = call.argument<String>("nom")
                        val type = call.argument<String>("type")
                            ?: "application/octet-stream"
                        if (octets == null || nom.isNullOrBlank()) {
                            result.error(
                                "ARGUMENTS",
                                "octets et nom sont obligatoires",
                                null
                            )
                        } else {
                            try {
                                result.success(ecrireDansTelechargements(octets, nom, type))
                            } catch (e: Exception) {
                                // On remonte la cause : un échec muet ferait
                                // croire à l'étudiant que son reçu est enregistré.
                                Log.e("Fichiers", "Enregistrement impossible", e)
                                result.error(
                                    "ECHEC",
                                    e.message ?: e.javaClass.simpleName,
                                    null
                                )
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Écrit [octets] dans le dossier public « Téléchargements » et renvoie le
     * nom réellement retenu par le système.
     *
     * À partir d'Android 10 (API 29) on passe par MediaStore : **aucune
     * permission n'est requise** pour écrire dans Downloads, et le fichier
     * apparaît immédiatement dans le gestionnaire de fichiers. Le drapeau
     * IS_PENDING masque l'entrée tant que l'écriture n'est pas terminée, pour
     * qu'aucune application ne lise un PDF tronqué.
     *
     * En deçà d'Android 10, MediaStore.Downloads n'existe pas : on écrit dans
     * le dossier public et on prévient le scanner de médias, faute de quoi le
     * fichier reste invisible jusqu'au redémarrage. Ce chemin exige
     * WRITE_EXTERNAL_STORAGE, demandée côté Dart avant l'appel.
     */
    private fun ecrireDansTelechargements(
        octets: ByteArray,
        nom: String,
        type: String
    ): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolveur = applicationContext.contentResolver
            val valeurs = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, nom)
                put(MediaStore.Downloads.MIME_TYPE, type)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolveur.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, valeurs)
                ?: throw IllegalStateException(
                    "MediaStore a refusé de créer l'entrée dans Téléchargements"
                )
            try {
                resolveur.openOutputStream(uri)?.use { flux ->
                    flux.write(octets)
                    flux.flush()
                } ?: throw IllegalStateException("Flux de sortie indisponible")
            } catch (e: Exception) {
                // Sans ce nettoyage, une entrée fantôme resterait « en attente »
                // et le nom serait pris pour les tentatives suivantes.
                resolveur.delete(uri, null, null)
                throw e
            }
            valeurs.clear()
            valeurs.put(MediaStore.Downloads.IS_PENDING, 0)
            resolveur.update(uri, valeurs, null, null)

            // MediaStore ajoute lui-même « (1) », « (2) »… en cas d'homonyme :
            // on relit le nom retenu au lieu de le supposer.
            resolveur.query(
                uri,
                arrayOf(MediaStore.Downloads.DISPLAY_NAME),
                null, null, null
            )?.use { curseur ->
                if (curseur.moveToFirst()) {
                    return curseur.getString(0) ?: nom
                }
            }
            return nom
        }

        val dossier = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )
        if (!dossier.exists() && !dossier.mkdirs()) {
            throw IllegalStateException("Dossier Téléchargements introuvable")
        }
        var fichier = File(dossier, nom)
        var suffixe = 1
        val base = nom.substringBeforeLast('.', nom)
        val extension = nom.substringAfterLast('.', "")
        while (fichier.exists()) {
            val candidat = if (extension.isEmpty()) "$base ($suffixe)"
                           else "$base ($suffixe).$extension"
            fichier = File(dossier, candidat)
            suffixe++
        }
        FileOutputStream(fichier).use { flux ->
            flux.write(octets)
            flux.flush()
        }
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(fichier.absolutePath),
            arrayOf(type),
            null
        )
        return fichier.name
    }
}
