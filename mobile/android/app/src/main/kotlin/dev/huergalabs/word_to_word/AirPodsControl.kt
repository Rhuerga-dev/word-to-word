package dev.huergalabs.word_to_word

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Apaga y vuelve a encender la "detección de conversación" (Conversation Awareness) de unos AirPods
 * mientras practicas, para que la cancelación de ruido no se quite cada vez que hablas.
 *
 * Habla con los AirPods por el protocolo de accesorios de Apple (AAP) sobre L2CAP, como hacen las apps
 * de ingeniería inversa (implementación propia; el protocolo está documentado por tyalie/AAP-Protocol-Definition).
 * Muchos teléfonos todavía no lo permiten (fallo del Bluetooth de Android corregido en Android 16 QPR3 / 17):
 * ahí todo falla en silencio y la app sigue igual.
 */
object AirPodsControl {
    private const val PSM = 0x1001
    private val AAP_UUID: ParcelUuid = ParcelUuid.fromString("74ec2172-0bad-4d01-8f77-997b2be0722a")

    private val HANDSHAKE = bytes(0x00, 0x00, 0x04, 0x00, 0x01, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
    private val FEATURES = bytes(0x04, 0x00, 0x04, 0x00, 0x4d, 0x00, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
    private val NOTIFICATIONS = bytes(0x04, 0x00, 0x04, 0x00, 0x0f, 0x00, 0xff, 0xff, 0xff, 0xff)
    private const val CONVERSATION_AWARENESS = 0x28
    private const val ON = 0x01
    private const val OFF = 0x02

    /** Cómo estaba antes de apagarla (para dejarla igual al terminar). null = no se sabe. */
    @Volatile private var before: Int? = null

    private fun bytes(vararg v: Int) = ByteArray(v.size) { v[it].toByte() }
    private fun control(id: Int, value: Int) = bytes(0x04, 0x00, 0x04, 0x00, 0x09, 0x00, id, value, 0x00, 0x00, 0x00)

    fun hasPermission(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ctx.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    /** Los AirPods conectados ahora mismo (por audio), o null. */
    @SuppressLint("MissingPermission")
    fun connectedAirPods(ctx: Context): BluetoothDevice? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || !hasPermission(ctx)) return null
        val adapter = (ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter ?: return null
        if (!adapter.isEnabled) return null
        val latch = CountDownLatch(1)
        var found: BluetoothDevice? = null
        val ok = adapter.getProfileProxy(ctx, object : BluetoothProfile.ServiceListener {
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                found = proxy.connectedDevices.firstOrNull { isAirPods(it) }
                adapter.closeProfileProxy(profile, proxy)
                latch.countDown()
            }
            override fun onServiceDisconnected(profile: Int) { latch.countDown() }
        }, BluetoothProfile.A2DP)
        if (!ok) return null
        latch.await(2, TimeUnit.SECONDS)
        return found
    }

    @SuppressLint("MissingPermission")
    private fun isAirPods(d: BluetoothDevice): Boolean =
        d.uuids?.contains(AAP_UUID) == true || (d.name ?: "").contains("AirPods", ignoreCase = true)

    /**
     * Apaga (quiet = true) o vuelve a dejar como estaba (quiet = false) la detección de conversación.
     * Devuelve true si los AirPods aceptaron la orden.
     */
    @SuppressLint("MissingPermission")
    fun setQuiet(ctx: Context, quiet: Boolean): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val device = connectedAirPods(ctx) ?: return false
        if (quiet == false && before == null) return false // nunca la cambiamos: no tocar nada
        var socket: BluetoothSocket? = null
        return try {
            socket = device.createInsecureL2capChannel(PSM)
            socket.connect()
            val out = socket.outputStream
            out.write(HANDSHAKE); out.flush()
            Thread.sleep(150)
            out.write(FEATURES); out.flush()
            out.write(NOTIFICATIONS); out.flush()
            if (quiet) {
                before = readCurrent(socket) ?: ON
                if (before == ON) out.write(control(CONVERSATION_AWARENESS, OFF))
            } else {
                if (before == ON) out.write(control(CONVERSATION_AWARENESS, ON))
                before = null
            }
            out.flush()
            Thread.sleep(200)
            true
        } catch (e: IOException) {
            false
        } catch (e: SecurityException) {
            false
        } catch (e: RuntimeException) {
            false
        } finally {
            try { socket?.close() } catch (_: IOException) {}
        }
    }

    /** Tras pedir notificaciones, los AirPods mandan sus ajustes: se busca el de la detección de conversación. */
    private fun readCurrent(socket: BluetoothSocket): Int? {
        val input = socket.inputStream
        val buf = ByteArray(512)
        val deadline = System.currentTimeMillis() + 1200
        while (System.currentTimeMillis() < deadline) {
            if (input.available() <= 0) { Thread.sleep(40); continue }
            val n = input.read(buf)
            var i = 0
            while (i + 7 < n) {
                if (buf[i] == 0x04.toByte() && buf[i + 4] == 0x09.toByte() && buf[i + 6] == CONVERSATION_AWARENESS.toByte()) {
                    val v = buf[i + 7].toInt() and 0xff
                    if (v == ON || v == OFF) return v
                }
                i++
            }
        }
        return null
    }
}
