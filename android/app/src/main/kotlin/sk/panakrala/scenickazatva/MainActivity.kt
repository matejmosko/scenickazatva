package sk.panakrala.scenickazatva

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sk.panakrala.scenickazatva/settings").setMethodCallHandler { call, result ->
            if (call.method == "setInterceptLinks") {
                val enabled = call.argument<Boolean>("enabled") ?: true
                toggleDeepLinkAlias(enabled)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun toggleDeepLinkAlias(enabled: Boolean) {
        val componentName = ComponentName(this, "sk.panakrala.scenickazatva.DeepLinkAlias")
        val state = if (enabled) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }
        packageManager.setComponentEnabledSetting(
            componentName,
            state,
            PackageManager.DONT_KILL_APP
        )
    }
}
