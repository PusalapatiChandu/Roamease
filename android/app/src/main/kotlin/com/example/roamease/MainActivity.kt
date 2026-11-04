package com.example.roamease

import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.telephony.*
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.roamease/telephony"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNetworkDetails" -> {
                    try {
                        val details = getNetworkDetails()
                        result.success(details)
                    } catch (e: Exception) {
                        result.error("TELEPHONY_ERROR", e.localizedMessage, null)
                    }
                }
                "getNearbyCellTowers" -> {
                    try {
                        val towers = getNearbyCellTowers()
                        result.success(towers)
                    } catch (e: Exception) {
                        result.error("CELL_TOWER_ERROR", e.localizedMessage, null)
                    }
                }
                "is5gCapable" -> {
                    result.success(check5gCapable())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getNetworkDetails(): Map<String, Any?> {
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

        val data = mutableMapOf<String, Any?>()

        // Connection check
        var isConnected = false
        var isWifi = false
        var isCellular = false

        if (connectivityManager != null) {
            val activeNetwork = connectivityManager.activeNetwork
            val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
            if (capabilities != null) {
                isConnected = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                isWifi = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
                isCellular = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
            }
        }

        data["isConnected"] = isConnected
        data["isWifi"] = isWifi
        data["isCellular"] = isCellular

        if (telephonyManager == null) {
            data["operatorName"] = "Unknown"
            data["networkType"] = if (isWifi) "Wi-Fi" else if (isConnected) "Active Network" else "No Connection"
            data["signalStrengthDbm"] = -1
            data["signalLevel"] = 0
            data["isRoaming"] = false
            return data
        }

        // Operator name
        var operator = telephonyManager.networkOperatorName
        if (operator.isNullOrBlank()) {
            operator = telephonyManager.simOperatorName
        }
        if (operator.isNullOrBlank()) {
            operator = if (isWifi) "Wi-Fi Network" else "No Carrier"
        }
        data["operatorName"] = operator

        // Roaming status
        val isRoaming = telephonyManager.isNetworkRoaming
        data["isRoaming"] = isRoaming
        data["simCountryIso"] = telephonyManager.simCountryIso?.uppercase() ?: ""
        data["networkCountryIso"] = telephonyManager.networkCountryIso?.uppercase() ?: ""

        // SIM State
        data["simState"] = when (telephonyManager.simState) {
            TelephonyManager.SIM_STATE_READY -> "Ready"
            TelephonyManager.SIM_STATE_ABSENT -> "No SIM Card"
            TelephonyManager.SIM_STATE_PIN_REQUIRED -> "PIN Required"
            TelephonyManager.SIM_STATE_PUK_REQUIRED -> "PUK Required"
            TelephonyManager.SIM_STATE_NETWORK_LOCKED -> "Network Locked"
            else -> "Unknown"
        }

        // Determine Network Generation (2G/3G/4G/5G)
        val hasPhoneState = ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
        var rawNetworkType = TelephonyManager.NETWORK_TYPE_UNKNOWN

        if (hasPhoneState || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            try {
                rawNetworkType = telephonyManager.dataNetworkType
                if (rawNetworkType == TelephonyManager.NETWORK_TYPE_UNKNOWN) {
                    rawNetworkType = telephonyManager.networkType
                }
            } catch (ignored: Exception) {}
        }

        val networkTypeStr = mapNetworkType(rawNetworkType, isWifi, isConnected)
        data["networkType"] = networkTypeStr
        data["rawNetworkType"] = rawNetworkType

        // Signal Strength in dBm and Level (0-4)
        var dbm = -1
        var level = 0
        var asu = -1

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val signalStrength = telephonyManager.signalStrength
                if (signalStrength != null) {
                    level = signalStrength.level
                    val cellSignalStrengths = signalStrength.cellSignalStrengths
                    if (cellSignalStrengths.isNotEmpty()) {
                        val primary = cellSignalStrengths[0]
                        dbm = primary.dbm
                        asu = primary.asuLevel
                    }
                }
            } catch (ignored: Exception) {}
        }

        data["signalStrengthDbm"] = dbm
        data["signalLevel"] = level
        data["signalAsu"] = asu
        data["is5gSupported"] = check5gCapable()

        return data
    }

    private fun mapNetworkType(type: Int, isWifi: Boolean, isConnected: Boolean): String {
        return when (type) {
            // 5G NR
            20 -> "5G" // TelephonyManager.NETWORK_TYPE_NR

            // 4G LTE
            TelephonyManager.NETWORK_TYPE_LTE,
            19 -> "4G LTE" // TelephonyManager.NETWORK_TYPE_LTE_CA

            // 3G
            TelephonyManager.NETWORK_TYPE_UMTS,
            TelephonyManager.NETWORK_TYPE_EVDO_0,
            TelephonyManager.NETWORK_TYPE_EVDO_A,
            TelephonyManager.NETWORK_TYPE_HSDPA,
            TelephonyManager.NETWORK_TYPE_HSUPA,
            TelephonyManager.NETWORK_TYPE_HSPA,
            TelephonyManager.NETWORK_TYPE_EVDO_B,
            TelephonyManager.NETWORK_TYPE_EHRPD,
            TelephonyManager.NETWORK_TYPE_HSPAP -> "3G"

            // 2G
            TelephonyManager.NETWORK_TYPE_GPRS,
            TelephonyManager.NETWORK_TYPE_EDGE,
            TelephonyManager.NETWORK_TYPE_CDMA,
            TelephonyManager.NETWORK_TYPE_1xRTT,
            TelephonyManager.NETWORK_TYPE_IDEN,
            TelephonyManager.NETWORK_TYPE_GSM -> "2G"

            else -> {
                if (isWifi) "Wi-Fi"
                else if (isConnected) "Mobile Data"
                else "No Service"
            }
        }
    }

    private fun getNearbyCellTowers(): List<Map<String, Any?>> {
        val towers = mutableListOf<Map<String, Any?>>()
        val hasFineLocation = ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!hasFineLocation) {
            return towers
        }

        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return towers

        try {
            val cellInfoList = telephonyManager.allCellInfo ?: return towers

            for (info in cellInfoList) {
                val map = mutableMapOf<String, Any?>()
                map["isRegistered"] = info.isRegistered

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && info is CellInfoNr) {
                    map["type"] = "5G NR"
                    val identity = info.cellIdentity as? CellIdentityNr
                    val signal = info.cellSignalStrength as? CellSignalStrengthNr
                    if (identity != null) {
                        val nci = identity.nci
                        if (nci != Long.MAX_VALUE && nci != CellInfo.UNAVAILABLE_LONG) {
                            map["cellId"] = nci.toString()
                        }
                        val tac = identity.tac
                        if (tac != Integer.MAX_VALUE && tac != CellInfo.UNAVAILABLE) {
                            map["tac"] = tac
                        }
                        val pci = identity.pci
                        if (pci != Integer.MAX_VALUE && pci != CellInfo.UNAVAILABLE) {
                            map["pci"] = pci
                        }
                    }
                    if (signal != null) {
                        map["dbm"] = signal.dbm
                        map["level"] = signal.level
                        map["asu"] = signal.asuLevel
                    }
                    towers.add(map)
                } else if (info is CellInfoLte) {
                    map["type"] = "4G LTE"
                    val identity = info.cellIdentity
                    val signal = info.cellSignalStrength
                    val ci = identity.ci
                    if (ci != Integer.MAX_VALUE && ci != CellInfo.UNAVAILABLE) {
                        map["cellId"] = ci.toString()
                    }
                    val tac = identity.tac
                    if (tac != Integer.MAX_VALUE && tac != CellInfo.UNAVAILABLE) {
                        map["tac"] = tac
                    }
                    val pci = identity.pci
                    if (pci != Integer.MAX_VALUE && pci != CellInfo.UNAVAILABLE) {
                        map["pci"] = pci
                    }
                    map["dbm"] = signal.dbm
                    map["level"] = signal.level
                    map["asu"] = signal.asuLevel
                    towers.add(map)
                } else if (info is CellInfoWcdma) {
                    map["type"] = "3G WCDMA"
                    val identity = info.cellIdentity
                    val signal = info.cellSignalStrength
                    val cid = identity.cid
                    if (cid != Integer.MAX_VALUE && cid != CellInfo.UNAVAILABLE) {
                        map["cellId"] = cid.toString()
                    }
                    val lac = identity.lac
                    if (lac != Integer.MAX_VALUE && lac != CellInfo.UNAVAILABLE) {
                        map["lac"] = lac
                    }
                    map["dbm"] = signal.dbm
                    map["level"] = signal.level
                    towers.add(map)
                } else if (info is CellInfoGsm) {
                    map["type"] = "2G GSM"
                    val identity = info.cellIdentity
                    val signal = info.cellSignalStrength
                    val cid = identity.cid
                    if (cid != Integer.MAX_VALUE && cid != CellInfo.UNAVAILABLE) {
                        map["cellId"] = cid.toString()
                    }
                    val lac = identity.lac
                    if (lac != Integer.MAX_VALUE && lac != CellInfo.UNAVAILABLE) {
                        map["lac"] = lac
                    }
                    map["dbm"] = signal.dbm
                    map["level"] = signal.level
                    towers.add(map)
                }
            }
        } catch (ignored: Exception) {}

        return towers
    }

    private fun check5gCapable(): Boolean {
        // Android 10 (API 29) introduced 5G NR support
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
    }
}
