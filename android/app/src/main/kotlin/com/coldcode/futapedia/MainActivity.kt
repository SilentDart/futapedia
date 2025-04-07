package com.coldcode.futapedia

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "listTile", // Factory ID
            NativeAdFactory(context)
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine!!, "listTile")
    }
}
