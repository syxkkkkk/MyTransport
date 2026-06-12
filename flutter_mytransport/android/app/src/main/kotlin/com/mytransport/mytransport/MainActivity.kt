package com.mytransport.mytransport

import android.content.Intent
import com.google.ar.core.ArCoreApk
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.mytransport.mytransport/ar_navigation"
    private val arRequestCode = 2001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "isArCoreAvailable" -> {
                        val avail = ArCoreApk.getInstance().checkAvailability(this)
                        result.success(
                            avail == ArCoreApk.Availability.SUPPORTED_INSTALLED ||
                            avail == ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD ||
                            avail == ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED
                        )
                    }

                    "launchARNavigation" -> {
                        val lat  = call.argument<Double>("latitude")    ?: 3.1478
                        val lng  = call.argument<Double>("longitude")   ?: 101.6953
                        val name = call.argument<String>("stationName") ?: "LRT Station"

                        pendingResult = result
                        val intent = Intent(this, ArCoreGeospatialActivity::class.java).apply {
                            putExtra(ArCoreGeospatialActivity.EXTRA_LAT,  lat)
                            putExtra(ArCoreGeospatialActivity.EXTRA_LNG,  lng)
                            putExtra(ArCoreGeospatialActivity.EXTRA_NAME, name)
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, arRequestCode)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == arRequestCode) {
            pendingResult?.success(resultCode == RESULT_OK)
            pendingResult = null
        }
    }
}
