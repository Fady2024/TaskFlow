package com.example.new_app

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.view.View
import android.widget.TextView

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Detect dark mode
        val isDarkMode = (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES

        // Find views in the splash screen layout (defined in res/layout/splash_screen.xml)
        val backgroundLight: View? = window.decorView.findViewById(R.id.background_light)
        val backgroundDark: View? = window.decorView.findViewById(R.id.background_dark)
        val splashText: TextView? = window.decorView.findViewById(R.id.splash_text)

        // Toggle visibility and text color based on dark mode
        if (isDarkMode) {
            backgroundLight?.visibility = View.GONE
            backgroundDark?.visibility = View.VISIBLE
            splashText?.setTextColor(android.graphics.Color.WHITE) // White text for dark mode
        } else {
            backgroundLight?.visibility = View.VISIBLE
            backgroundDark?.visibility = View.GONE
            splashText?.setTextColor(android.graphics.Color.parseColor("#2D3748")) // Light mode text color
        }
    }
}