package com.example.academia_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "academia_android_video",
                AcademiaAndroidVideoViewFactory(flutterEngine.dartExecutor.binaryMessenger)
            )
    }
}
