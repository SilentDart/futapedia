package com.coldcode.futapedia

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.TextView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import com.coldcode.futapedia.R // Ensure this import is correct

class NativeAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: Map<String, Any>?
    ): NativeAdView {
        val layoutInflater = LayoutInflater.from(context)
        val adView = layoutInflater.inflate(R.layout.native_ad_layout, null) as NativeAdView

        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        adView.setNativeAd(nativeAd)
        return adView
    }
}