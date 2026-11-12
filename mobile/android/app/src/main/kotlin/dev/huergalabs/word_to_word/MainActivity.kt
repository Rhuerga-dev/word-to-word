package dev.huergalabs.word_to_word

import android.Manifest
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // AirPods: ¿los llevas puestos? (aviso BLE de Apple; ver AirPodsEars).
        AirPodsEars.attach(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "w2w/airpods/ears").setStreamHandler(AirPodsEars)
        // AirPods: apagar la detección de conversación mientras practicas (ver AirPodsControl).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "w2w/airpods").setMethodCallHandler { call, result ->
            when (call.method) {
                "permission" -> {
                    if (AirPodsControl.hasPermission(this)) result.success(true)
                    else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        pendingPermission = result
                        requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), 4711)
                    } else result.success(true)
                }
                // Para saber si los llevas puestos: escanear avisos BLE (mismo grupo "Dispositivos cercanos").
                "earsPermission" -> {
                    if (AirPodsEars.hasPermission(this)) result.success(true)
                    else {
                        pendingPermission = result
                        val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.ACCESS_FINE_LOCATION)
                        else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
                        requestPermissions(perms, 4711)
                    }
                }
                // Ajustes de la app (para dar el permiso a mano si se negó antes).
                "settings" -> {
                    startActivity(android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        android.net.Uri.fromParts("package", packageName, null)))
                    result.success(true)
                }
                // Ajustes de Bluetooth del teléfono, para conectar los auriculares sin salir a buscarlos.
                "bluetooth" -> {
                    try {
                        startActivity(android.content.Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "connected" -> worker.execute {
                    val d = AirPodsControl.connectedAirPods(this)
                    main.post { result.success(d != null) }
                }
                "quiet" -> {
                    val on = call.argument<Boolean>("on") ?: true
                    worker.execute {
                        val ok = AirPodsControl.setQuiet(this, on)
                        main.post { result.success(ok) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4711) {
            pendingPermission?.success(grantResults.isNotEmpty() && grantResults.all { it == android.content.pm.PackageManager.PERMISSION_GRANTED })
            pendingPermission = null
        }
    }
}
