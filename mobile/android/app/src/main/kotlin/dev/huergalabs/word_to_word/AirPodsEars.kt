package dev.huergalabs.word_to_word

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel

/**
 * ¿Llevas los AirPods puestos? Los AirPods emiten sin parar un aviso Bluetooth (BLE) de Apple, el de
 * "proximity pairing" (fabricante 0x004C, tipo 0x07), con su estado: batería, estuche y si cada auricular
 * está en la oreja. Lo leemos como hacen OpenPods o LibrePods (formato no oficial, por ingeniería inversa).
 *
 * Byte de estado (posición 5 de los datos del fabricante): 0x02 = el auricular principal está en la oreja,
 * 0x08 = el otro está en la oreja, 0x20 = el principal es el izquierdo. Si hay varios AirPods cerca se usa
 * el que llega con más señal (los tuyos, puestos, están a centímetros).
 *
 * Solo escanea mientras Flutter escucha (durante la sesión o en la tarjeta de Progreso).
 */
object AirPodsEars : EventChannel.StreamHandler {
    private const val APPLE = 0x004C
    private const val MIN_RSSI = -72          // más lejos que esto: no son los tuyos
    private var ctx: Context? = null
    private var sink: EventChannel.EventSink? = null
    private var scanner: BluetoothLeScanner? = null
    private var lastKey = ""
    private var lastSent = 0L

    fun attach(context: Context) { ctx = context.applicationContext }

    fun hasPermission(c: Context): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            c.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        else c.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private val callback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            if (result.rssi < MIN_RSSI) return
            val d = result.scanRecord?.getManufacturerSpecificData(APPLE) ?: return
            if (d.size < 9 || d[0].toInt() != 0x07) return
            val status = d[5].toInt() and 0xFF
            val primaryIn = status and 0x02 != 0
            val otherIn = status and 0x08 != 0
            val primaryLeft = status and 0x20 != 0
            val left = if (primaryLeft) primaryIn else otherIn
            val right = if (primaryLeft) otherIn else primaryIn
            val key = "$left$right"
            val now = SystemClock.elapsedRealtime()
            // Solo cuando cambia algo (o cada 4 s, para el estado en directo).
            if (key == lastKey && now - lastSent < 4000) return
            lastKey = key; lastSent = now
            sink?.success(mapOf(
                "left" to left, "right" to right, "status" to status, "rssi" to result.rssi,
                "model" to (((d[3].toInt() and 0xFF) shl 8) or (d[4].toInt() and 0xFF)),
            ))
        }

        override fun onScanFailed(errorCode: Int) {
            sink?.error("scan", "BLE scan failed: $errorCode", null)
        }
    }

    @SuppressLint("MissingPermission")
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val c = ctx ?: return
        if (!hasPermission(c)) { events?.error("permission", "Falta el permiso de dispositivos cercanos", null); return }
        val adapter = (c.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        if (adapter == null || !adapter.isEnabled) { events?.error("off", "Bluetooth apagado", null); return }
        val filter = ScanFilter.Builder()
            .setManufacturerData(APPLE, byteArrayOf(0x07), byteArrayOf(0xFF.toByte()))
            .build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        lastKey = ""; lastSent = 0
        try {
            scanner = adapter.bluetoothLeScanner
            scanner?.startScan(listOf(filter), settings, callback)
        } catch (e: Exception) {
            events?.error("scan", e.message, null)
        }
    }

    @SuppressLint("MissingPermission")
    override fun onCancel(arguments: Any?) {
        try { scanner?.stopScan(callback) } catch (_: Exception) {}
        scanner = null
        sink = null
    }
}
