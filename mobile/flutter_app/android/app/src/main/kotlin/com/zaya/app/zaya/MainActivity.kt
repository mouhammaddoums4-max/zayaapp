package com.zaya.app.zaya

import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity : exigée par le verrouillage par empreinte ou visage (local_auth).
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Protection anti-capture (CDC V6.4 §7 et V2.3 §1.2) : profils, photos et conversations sont présents sur
        // presque tous les écrans, elle couvre donc toute l'application. Captures et enregistrements d'écran donnent
        // une image noire, et l'aperçu des applications récentes est masqué. Elle ne peut pas empêcher un autre
        // téléphone de photographier l'écran. Les versions de développement restent capturables pour les tests.
        val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!debuggable) {
            window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
