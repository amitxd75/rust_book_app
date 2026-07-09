package com.rustbook.app

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.view.WindowManager
import android.os.Build

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Request high refresh rate (120Hz/90Hz) display modes if supported by the display
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val window = window
            val layoutParams = window.attributes
            layoutParams.preferredRefreshRate = 120.0f
            window.attributes = layoutParams
        }
    }
}
