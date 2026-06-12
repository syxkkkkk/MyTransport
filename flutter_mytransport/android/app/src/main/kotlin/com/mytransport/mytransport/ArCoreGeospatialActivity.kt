package com.mytransport.mytransport

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Typeface
import android.location.Location
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.ar.core.*
import com.google.ar.core.ArCoreApk
import com.google.ar.core.exceptions.*
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Full-screen native Activity that runs an ARCore Geospatial session.
 *
 * Launched from Flutter via MethodChannel with:
 *   - "latitude"    : Double  — destination latitude
 *   - "longitude"   : Double  — destination longitude
 *   - "stationName" : String  — display name
 */
class ArCoreGeospatialActivity : Activity(), GLSurfaceView.Renderer {

    // ── Intent extras ────────────────────────────────────────────────────────
    companion object {
        const val EXTRA_LAT  = "latitude"
        const val EXTRA_LNG  = "longitude"
        const val EXTRA_NAME = "stationName"
        private const val CAMERA_PERM_CODE = 1001
    }

    // ── Destination ──────────────────────────────────────────────────────────
    private var destLat  = 3.1478
    private var destLng  = 101.6953
    private var destName = "LRT Station"

    // ── ARCore ───────────────────────────────────────────────────────────────
    private var session: Session? = null
    private var installRequested = false
    private val cameraRenderer = CameraBackgroundRenderer()

    // ── GL surface ───────────────────────────────────────────────────────────
    private lateinit var glSurfaceView: GLSurfaceView
    private var viewportWidth  = 0
    private var viewportHeight = 0
    private var viewportDirty  = false

    // ── Overlay UI ───────────────────────────────────────────────────────────
    private lateinit var arrowView:  ArrowOverlayView
    private lateinit var tvStation:  TextView
    private lateinit var tvDistance: TextView
    private lateinit var tvAccuracy: TextView
    private lateinit var tvStatus:   TextView

    // ── Navigation state (written on GL thread, read on UI thread) ───────────
    @Volatile private var relativeBearing = 0f   // degrees, 0 = straight ahead
    @Volatile private var distanceMeters  = 0f
    @Volatile private var accuracyMeters  = 999f
    @Volatile private var isTracking      = false

    private val mainHandler = Handler(Looper.getMainLooper())
    private val uiTick = object : Runnable {
        override fun run() {
            refreshHud()
            mainHandler.postDelayed(this, 200)
        }
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        destLat  = intent.getDoubleExtra(EXTRA_LAT,  3.1478)
        destLng  = intent.getDoubleExtra(EXTRA_LNG,  101.6953)
        destName = intent.getStringExtra(EXTRA_NAME) ?: "LRT Station"

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        @Suppress("DEPRECATION")
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)

        setContentView(buildLayout())
        mainHandler.post(uiTick)
    }

    override fun onResume() {
        super.onResume()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this, arrayOf(Manifest.permission.CAMERA), CAMERA_PERM_CODE
            )
            return
        }

        try {
            if (ArCoreApk.getInstance().requestInstall(this, !installRequested)
                == ArCoreApk.InstallStatus.INSTALL_REQUESTED) {
                installRequested = true
                return
            }
            installRequested = false

            if (session == null) {
                val s = Session(this)
                val cfg = Config(s)
                cfg.geospatialMode = Config.GeospatialMode.ENABLED
                cfg.updateMode     = Config.UpdateMode.LATEST_CAMERA_IMAGE
                s.configure(cfg)
                session = s
            }

            session!!.resume()
            glSurfaceView.onResume()

        } catch (e: UnavailableArcoreNotInstalledException) {
            showStatus("ARCore not installed")
        } catch (e: UnavailableDeviceNotCompatibleException) {
            showStatus("Device not compatible with ARCore")
        } catch (e: UnavailableSdkTooOldException) {
            showStatus("Update this app for ARCore support")
        } catch (e: UnavailableApkTooOldException) {
            showStatus("Update ARCore (Google Play Services for AR)")
        } catch (e: Exception) {
            showStatus("AR error: ${e.message}")
        }
    }

    override fun onPause() {
        super.onPause()
        glSurfaceView.onPause()
        session?.pause()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(uiTick)
        session?.close()
        session = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CAMERA_PERM_CODE &&
            (grantResults.isEmpty() || grantResults[0] != PackageManager.PERMISSION_GRANTED)) {
            showStatus("Camera permission required for AR")
        }
    }

    // ── GLSurfaceView.Renderer ───────────────────────────────────────────────

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        cameraRenderer.createOnGlThread()
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        viewportWidth  = width
        viewportHeight = height
        viewportDirty  = true
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val s = session ?: return

        try {
            s.setCameraTextureName(cameraRenderer.textureId)

            if (viewportDirty) {
                val rot = getDisplayRotation()
                s.setDisplayGeometry(rot, viewportWidth, viewportHeight)
                viewportDirty = false
            }

            val frame = s.update()
            cameraRenderer.draw(frame)

            val earth = s.earth ?: return
            if (earth.trackingState == TrackingState.TRACKING) {
                val pose    = earth.cameraGeospatialPose
                val results = FloatArray(2)
                Location.distanceBetween(
                    pose.latitude, pose.longitude,
                    destLat, destLng,
                    results
                )
                distanceMeters  = results[0]
                val bearing     = results[1].toDouble()
                relativeBearing = ((bearing - pose.heading + 360.0) % 360.0).toFloat()
                accuracyMeters  = pose.horizontalAccuracy.toFloat()
                isTracking      = true
            } else {
                isTracking = false
            }

        } catch (_: Exception) {
            // Skip bad frames silently
        }
    }

    @Suppress("DEPRECATION")
    private fun getDisplayRotation(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
            display?.rotation ?: 0
        else
            windowManager.defaultDisplay.rotation

    // ── UI helpers ───────────────────────────────────────────────────────────

    private fun refreshHud() {
        if (isTracking) {
            arrowView.setAngle(relativeBearing)
            tvDistance.text = if (distanceMeters < 1000)
                "%.0f m".format(distanceMeters)
            else
                "%.1f km".format(distanceMeters / 1000f)
            tvAccuracy.text = "GPS ±%.1fm".format(accuracyMeters)
            tvStatus.visibility  = View.GONE
            arrowView.visibility = View.VISIBLE
        } else {
            tvStatus.visibility  = View.VISIBLE
            arrowView.visibility = View.GONE
        }
    }

    private fun showStatus(msg: String) {
        mainHandler.post {
            tvStatus.text       = msg
            tvStatus.visibility = View.VISIBLE
        }
    }

    // ── Layout ───────────────────────────────────────────────────────────────

    private fun buildLayout(): View {
        val root = FrameLayout(this)

        // 1 — ARCore GL surface (camera feed)
        glSurfaceView = GLSurfaceView(this).apply {
            preserveEGLContextOnPause = true
            setEGLContextClientVersion(2)
            setEGLConfigChooser(8, 8, 8, 8, 16, 0)
            setRenderer(this@ArCoreGeospatialActivity)
            renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        }
        root.addView(glSurfaceView, matchParent())

        // 2 — Directional arrow overlay
        arrowView = ArrowOverlayView(this)
        root.addView(arrowView, matchParent())

        // 3 — Top bar
        val topBar = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#CC000000"))
            val dp = resources.displayMetrics.density
            val pad = (16 * dp).toInt()
            val topPad = (36 * dp).toInt()
            setPadding(pad, topPad, pad, pad)
        }
        tvStation = makeTextView(destName, 18f, Color.WHITE, bold = true)
        topBar.addView(tvStation, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).also { it.gravity = Gravity.CENTER })

        val closeBtn = makeTextView("✕", 20f, Color.WHITE).apply {
            setOnClickListener { finish() }
            val dp = resources.displayMetrics.density
            setPadding((12 * dp).toInt(), (8 * dp).toInt(), (12 * dp).toInt(), (8 * dp).toInt())
        }
        topBar.addView(closeBtn, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).also { it.gravity = Gravity.END or Gravity.CENTER_VERTICAL })

        root.addView(topBar, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).also { it.gravity = Gravity.TOP })

        // 4 — Status label (shown while acquiring position)
        tvStatus = makeTextView("Acquiring geospatial position…", 15f, Color.WHITE).apply {
            setBackgroundColor(Color.parseColor("#AA000000"))
            val dp = resources.displayMetrics.density
            setPadding((20 * dp).toInt(), (10 * dp).toInt(), (20 * dp).toInt(), (10 * dp).toInt())
        }
        root.addView(tvStatus, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).also { it.gravity = Gravity.CENTER })

        // 5 — Bottom HUD
        val bottomBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#CC000000"))
            val dp = resources.displayMetrics.density
            setPadding((20 * dp).toInt(), (14 * dp).toInt(), (20 * dp).toInt(), (32 * dp).toInt())
            gravity = Gravity.CENTER_VERTICAL
        }
        tvDistance = makeTextView("--", 34f, Color.parseColor("#4285F4"), bold = true)
        tvAccuracy = makeTextView("  GPS --", 13f, Color.parseColor("#AAAAAA"))

        bottomBar.addView(tvDistance)
        bottomBar.addView(tvAccuracy)

        root.addView(bottomBar, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).also { it.gravity = Gravity.BOTTOM })

        return root
    }

    private fun matchParent() = FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT,
        FrameLayout.LayoutParams.MATCH_PARENT
    )

    private fun makeTextView(text: String, sp: Float, color: Int, bold: Boolean = false) =
        TextView(this).apply {
            this.text = text
            textSize  = sp
            setTextColor(color)
            if (bold) setTypeface(null, Typeface.BOLD)
        }
}

// ── Directional arrow overlay ─────────────────────────────────────────────────

/**
 * Transparent View drawn on top of the camera feed.
 * [setAngle] accepts degrees where 0° = straight ahead, 90° = turn right.
 */
class ArrowOverlayView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : View(context, attrs) {

    private var angleDeg = 0f

    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#4285F4")
        style = Paint.Style.FILL
        alpha = 210
    }
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 6f
        alpha = 190
    }
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#4285F4")
        style = Paint.Style.FILL
        alpha = 55
        maskFilter = android.graphics.BlurMaskFilter(
            32f, android.graphics.BlurMaskFilter.Blur.NORMAL
        )
    }

    fun setAngle(degrees: Float) {
        angleDeg = degrees
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx   = width  / 2f
        val cy   = height / 2f
        val size = minOf(width, height) * 0.18f

        canvas.save()
        canvas.translate(cx, cy)
        canvas.rotate(angleDeg)

        val arrow = Path().apply {
            moveTo(0f,             -size)
            lineTo( size * 0.55f,  size * 0.25f)
            lineTo( size * 0.22f,  size * 0.05f)
            lineTo( size * 0.22f,  size * 0.65f)
            lineTo(-size * 0.22f,  size * 0.65f)
            lineTo(-size * 0.22f,  size * 0.05f)
            lineTo(-size * 0.55f,  size * 0.25f)
            close()
        }

        canvas.drawPath(arrow, glowPaint)
        canvas.drawPath(arrow, fillPaint)
        canvas.drawPath(arrow, strokePaint)
        canvas.restore()
    }
}
