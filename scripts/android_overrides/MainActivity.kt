package __PACKAGE__

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "axel_lena/launcher")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Ouvre une appli installée à partir de son identifiant de package.
                    "openApp" -> {
                        val pkg = call.argument<String>("package")
                        val intent = pkg?.let { packageManager.getLaunchIntentForPackage(it) }
                        if (intent == null) {
                            result.success(false)
                        } else {
                            try {
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    // Ouvre une URL en forçant une appli précise (ex. Discord).
                    "openUrlInPackage" -> {
                        val url = call.argument<String>("url")
                        val pkg = call.argument<String>("package")
                        if (url == null || pkg == null) {
                            result.success(false)
                        } else {
                            try {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                intent.setPackage(pkg)
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
