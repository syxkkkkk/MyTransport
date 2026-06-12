package com.mytransport.mytransport

import android.opengl.GLES11Ext
import android.opengl.GLES20
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Renders the ARCore camera feed as a full-screen background using OpenGL ES 2.0.
 * Uses an OES external texture (required for ARCore camera images).
 */
class CameraBackgroundRenderer {

    var textureId: Int = -1
        private set

    private var program = -1
    private var posHandle = -1
    private var uvHandle = -1
    private var texHandle = -1

    // NDC quad: two triangles covering the full screen (x, y pairs)
    private val ndcQuad = floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)
    private val ndcBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(ndcQuad.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .also { it.put(ndcQuad); it.rewind() }

    // UV buffer populated each frame by ARCore's transformCoordinates2d
    private val uvBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(8 * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()

    private var geometryDirty = true

    private companion object {
        const val VERTEX_SHADER = """
            attribute vec4 a_Position;
            attribute vec2 a_TexCoord;
            varying vec2 v_TexCoord;
            void main() {
                gl_Position = a_Position;
                v_TexCoord = a_TexCoord;
            }
        """

        const val FRAGMENT_SHADER = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            uniform samplerExternalOES u_Texture;
            varying vec2 v_TexCoord;
            void main() {
                gl_FragColor = texture2D(u_Texture, v_TexCoord);
            }
        """

        fun compileShader(type: Int, src: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader, src)
            GLES20.glCompileShader(shader)
            return shader
        }
    }

    /** Call once from GL thread after surface is created. */
    fun createOnGlThread() {
        val ids = IntArray(1)
        GLES20.glGenTextures(1, ids, 0)
        textureId = ids[0]

        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        val vs = compileShader(GLES20.GL_VERTEX_SHADER, VERTEX_SHADER.trimIndent())
        val fs = compileShader(GLES20.GL_FRAGMENT_SHADER, FRAGMENT_SHADER.trimIndent())
        program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vs)
        GLES20.glAttachShader(program, fs)
        GLES20.glLinkProgram(program)

        posHandle = GLES20.glGetAttribLocation(program, "a_Position")
        uvHandle  = GLES20.glGetAttribLocation(program, "a_TexCoord")
        texHandle = GLES20.glGetUniformLocation(program, "u_Texture")

        geometryDirty = true
    }

    /** Call every frame from GL thread to render the camera background. */
    fun draw(frame: Frame) {
        if (frame.timestamp == 0L) return

        // Recompute UV coords whenever display geometry changes
        if (frame.hasDisplayGeometryChanged() || geometryDirty) {
            ndcBuffer.rewind()
            frame.transformCoordinates2d(
                Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES, ndcBuffer,
                Coordinates2d.TEXTURE_NORMALIZED, uvBuffer
            )
            ndcBuffer.rewind()
            uvBuffer.rewind()
            geometryDirty = false
        }

        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glUseProgram(program)
        GLES20.glUniform1i(texHandle, 0)

        ndcBuffer.rewind()
        GLES20.glVertexAttribPointer(posHandle, 2, GLES20.GL_FLOAT, false, 0, ndcBuffer)
        GLES20.glEnableVertexAttribArray(posHandle)

        uvBuffer.rewind()
        GLES20.glVertexAttribPointer(uvHandle, 2, GLES20.GL_FLOAT, false, 0, uvBuffer)
        GLES20.glEnableVertexAttribArray(uvHandle)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(posHandle)
        GLES20.glDisableVertexAttribArray(uvHandle)
        GLES20.glDepthMask(true)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
    }
}
