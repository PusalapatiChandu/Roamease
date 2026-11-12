package com.example.roamease

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.*
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

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
                    fetchNearbyCellTowersAsync { towers ->
                        result.success(towers)
                    }
                }
                "is5gCapable" -> {
                    result.success(check5gCapable())
                }
                "hasValidGoogleMapsKey" -> {
                    result.success(hasValidGoogleMapsKey())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasValidGoogleMapsKey(): Boolean {
        return try {
            val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong())
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            }
            val apiKey = appInfo.metaData?.getString("com.google.android.geo.API_KEY") ?: ""
            apiKey.isNotBlank() && !apiKey.startsWith("AIzaSyDummy", ignoreCase = true)
        } catch (_: Exception) {
            false
        }
    }

    private fun isValidInt(value: Int): Boolean {
        return value != Integer.MAX_VALUE && value != Int.MIN_VALUE
    }

    private fun isValidLong(value: Long): Boolean {
        return value != Long.MAX_VALUE && value != Long.MIN_VALUE
    }

    private fun isValidDbm(dbm: Int): Boolean {
        return isValidInt(dbm) && dbm in -156..-25
    }

    private fun normalizeLteSinr(raw: Int): Int? {
        if (!isValidInt(raw)) return null
        if (raw in -25..35) return raw
        if (raw in -250..350) return raw / 10
        return null
    }

    @SuppressLint("MissingPermission")
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
            data["signalAsu"] = -1
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

        // Network operator MCC/MNC if exposed
        val netOp = telephonyManager.networkOperator
        if (!netOp.isNullOrBlank() && netOp.length >= 5) {
            data["mcc"] = netOp.substring(0, 3)
            data["mnc"] = netOp.substring(3)
        }

        // Roaming status
        data["isRoaming"] = telephonyManager.isNetworkRoaming
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
        val hasPhoneState = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
        var rawNetworkType = TelephonyManager.NETWORK_TYPE_UNKNOWN

        if (hasPhoneState || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            try {
                rawNetworkType = telephonyManager.dataNetworkType
                if (rawNetworkType == TelephonyManager.NETWORK_TYPE_UNKNOWN) {
                    @Suppress("DEPRECATION")
                    rawNetworkType = telephonyManager.networkType
                }
            } catch (_: Exception) {}
        }

        // Signal Strength in dBm, Level (0-4), plus RSRP / RSRQ / SINR / CQI / Timing Advance
        var dbm = -1
        var level = 0
        var asu = -1
        var rsrp: Int? = null
        var rsrq: Int? = null
        var sinr: Int? = null
        var cqi: Int? = null
        var timingAdvance: Int? = null
        var hasNrSignal = false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val signalStrength = telephonyManager.signalStrength
                if (signalStrength != null) {
                    level = signalStrength.level
                    val cellSignalStrengths = signalStrength.cellSignalStrengths

                    val nrStrengths = signalStrength.getCellSignalStrengths(CellSignalStrengthNr::class.java)
                    val lteStrengths = signalStrength.getCellSignalStrengths(CellSignalStrengthLte::class.java)

                    if (nrStrengths.isNotEmpty()) {
                        hasNrSignal = true
                        val nr = nrStrengths[0]
                        if (isValidDbm(nr.dbm)) dbm = nr.dbm
                        if (isValidInt(nr.asuLevel) && nr.asuLevel in 0..99) asu = nr.asuLevel

                        val ssRsrp = nr.ssRsrp
                        val csiRsrp = nr.csiRsrp
                        rsrp = when {
                            isValidDbm(ssRsrp) -> ssRsrp
                            isValidDbm(csiRsrp) -> csiRsrp
                            else -> null
                        }

                        val ssRsrq = nr.ssRsrq
                        val csiRsrq = nr.csiRsrq
                        rsrq = when {
                            isValidInt(ssRsrq) && ssRsrq in -43..20 -> ssRsrq
                            isValidInt(csiRsrq) && csiRsrq in -43..20 -> csiRsrq
                            else -> null
                        }

                        val ssSinr = nr.ssSinr
                        val csiSinr = nr.csiSinr
                        sinr = when {
                            isValidInt(ssSinr) && ssSinr in -25..45 -> ssSinr
                            isValidInt(csiSinr) && csiSinr in -25..45 -> csiSinr
                            else -> null
                        }
                    } else if (lteStrengths.isNotEmpty()) {
                        val lte = lteStrengths[0]
                        if (isValidDbm(lte.dbm)) dbm = lte.dbm
                        if (isValidInt(lte.asuLevel) && lte.asuLevel in 0..99) asu = lte.asuLevel
                        if (isValidDbm(lte.rsrp)) rsrp = lte.rsrp
                        if (isValidInt(lte.rsrq) && lte.rsrq in -35..5) rsrq = lte.rsrq
                        sinr = normalizeLteSinr(lte.rssnr)
                        if (isValidInt(lte.cqi) && lte.cqi in 0..15) cqi = lte.cqi
                        if (isValidInt(lte.timingAdvance) && lte.timingAdvance in 0..1282) {
                            timingAdvance = lte.timingAdvance
                        }
                    } else if (cellSignalStrengths.isNotEmpty()) {
                        val primary = cellSignalStrengths[0]
                        if (isValidDbm(primary.dbm)) dbm = primary.dbm
                        if (isValidInt(primary.asuLevel) && primary.asuLevel in 0..99) asu = primary.asuLevel
                    }
                }
            } catch (_: Exception) {}
        }

        // Enrich with serving CellInfo details if Fine Location granted
        val hasFineLocation = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        if (hasFineLocation) {
            try {
                val cellInfoList = telephonyManager.allCellInfo ?: emptyList()
                val registeredCells = cellInfoList.filter { it.isRegistered }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && registeredCells.any { it is CellInfoNr }) {
                    hasNrSignal = true
                }

                // Prefer NR serving cell if present, otherwise first registered cell
                val servingCell = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    registeredCells.firstOrNull { it is CellInfoNr } ?: registeredCells.firstOrNull()
                } else {
                    registeredCells.firstOrNull()
                }

                if (servingCell != null) {
                    val cellMap = cellInfoToMap(servingCell, telephonyManager)
                    data["servingCellId"] = cellMap["cellId"]
                    data["servingTac"] = cellMap["tac"] ?: cellMap["lac"]
                    data["servingPci"] = cellMap["pci"]
                    data["arfcn"] = cellMap["arfcn"]
                    data["bandwidthKhz"] = cellMap["bandwidthKhz"]
                    if (cellMap["mcc"] != null) data["mcc"] = cellMap["mcc"]
                    if (cellMap["mnc"] != null) data["mnc"] = cellMap["mnc"]

                    if (rsrp == null && cellMap["rsrp"] is Int) rsrp = cellMap["rsrp"] as Int
                    if (rsrq == null && cellMap["rsrq"] is Int) rsrq = cellMap["rsrq"] as Int
                    if (sinr == null && cellMap["sinr"] is Int) sinr = cellMap["sinr"] as Int
                    if (cqi == null && cellMap["cqi"] is Int) cqi = cellMap["cqi"] as Int
                    if (timingAdvance == null && cellMap["timingAdvance"] is Int) {
                        timingAdvance = cellMap["timingAdvance"] as Int
                    }
                    if (dbm == -1 && cellMap["dbm"] is Int && isValidDbm(cellMap["dbm"] as Int)) {
                        dbm = cellMap["dbm"] as Int
                    }
                }
            } catch (_: Exception) {}
        }

        val networkTypeStr = mapNetworkType(rawNetworkType, isWifi, isConnected, hasNrSignal)
        data["networkType"] = networkTypeStr
        data["rawNetworkType"] = rawNetworkType
        data["signalStrengthDbm"] = dbm
        data["signalLevel"] = level
        data["signalAsu"] = asu
        data["rsrp"] = rsrp
        data["rsrq"] = rsrq
        data["sinr"] = sinr
        data["cqi"] = cqi
        data["timingAdvance"] = timingAdvance
        data["is5gSupported"] = check5gCapable()

        return data
    }

    private fun mapNetworkType(
        type: Int,
        isWifi: Boolean,
        isConnected: Boolean,
        hasNrSignal: Boolean
    ): String {
        if (type == 20) return "5G NR" // TelephonyManager.NETWORK_TYPE_NR
        if (hasNrSignal && (type == TelephonyManager.NETWORK_TYPE_LTE || type == 19)) {
            return "5G NSA"
        }

        return when (type) {
            TelephonyManager.NETWORK_TYPE_LTE,
            19 -> "4G LTE" // LTE_CA

            TelephonyManager.NETWORK_TYPE_UMTS,
            TelephonyManager.NETWORK_TYPE_EVDO_0,
            TelephonyManager.NETWORK_TYPE_EVDO_A,
            TelephonyManager.NETWORK_TYPE_HSDPA,
            TelephonyManager.NETWORK_TYPE_HSUPA,
            TelephonyManager.NETWORK_TYPE_HSPA,
            TelephonyManager.NETWORK_TYPE_EVDO_B,
            TelephonyManager.NETWORK_TYPE_EHRPD,
            TelephonyManager.NETWORK_TYPE_HSPAP -> "3G"

            TelephonyManager.NETWORK_TYPE_GPRS,
            TelephonyManager.NETWORK_TYPE_EDGE,
            TelephonyManager.NETWORK_TYPE_CDMA,
            TelephonyManager.NETWORK_TYPE_1xRTT,
            TelephonyManager.NETWORK_TYPE_IDEN,
            TelephonyManager.NETWORK_TYPE_GSM -> "2G"

            else -> {
                if (isWifi) "Wi-Fi"
                else if (hasNrSignal) "5G NSA"
                else if (isConnected) "Mobile Data"
                else "No Service"
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun fetchNearbyCellTowersAsync(callback: (List<Map<String, Any?>>) -> Unit) {
        val hasFineLocation = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasFineLocation) {
            callback(emptyList())
            return
        }

        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        if (telephonyManager == null) {
            callback(emptyList())
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val replied = AtomicBoolean(false)
            val handler = Handler(Looper.getMainLooper())

            val fallbackRunnable = Runnable {
                if (replied.compareAndSet(false, true)) {
                    val cached = try {
                        telephonyManager.allCellInfo
                    } catch (_: Exception) {
                        null
                    }
                    callback(parseCellInfoList(cached, telephonyManager))
                }
            }
            handler.postDelayed(fallbackRunnable, 2200L)

            try {
                telephonyManager.requestCellInfoUpdate(
                    ContextCompat.getMainExecutor(this),
                    object : TelephonyManager.CellInfoCallback() {
                        override fun onCellInfo(cellInfo: MutableList<CellInfo>) {
                            handler.removeCallbacks(fallbackRunnable)
                            if (replied.compareAndSet(false, true)) {
                                val listToParse = if (cellInfo.isNotEmpty()) {
                                    cellInfo
                                } else {
                                    try {
                                        telephonyManager.allCellInfo
                                    } catch (_: Exception) {
                                        cellInfo
                                    }
                                }
                                callback(parseCellInfoList(listToParse, telephonyManager))
                            }
                        }

                        override fun onError(errorCode: Int, detail: Throwable?) {
                            handler.removeCallbacks(fallbackRunnable)
                            if (replied.compareAndSet(false, true)) {
                                val cached = try {
                                    telephonyManager.allCellInfo
                                } catch (_: Exception) {
                                    null
                                }
                                callback(parseCellInfoList(cached, telephonyManager))
                            }
                        }
                    }
                )
            } catch (_: Exception) {
                handler.removeCallbacks(fallbackRunnable)
                if (replied.compareAndSet(false, true)) {
                    val cached = try {
                        telephonyManager.allCellInfo
                    } catch (_: Exception) {
                        null
                    }
                    callback(parseCellInfoList(cached, telephonyManager))
                }
            }
        } else {
            val cached = try {
                telephonyManager.allCellInfo
            } catch (_: Exception) {
                null
            }
            callback(parseCellInfoList(cached, telephonyManager))
        }
    }

    private fun parseCellInfoList(
        cellInfoList: List<CellInfo>?,
        telephonyManager: TelephonyManager
    ): List<Map<String, Any?>> {
        if (cellInfoList.isNullOrEmpty()) return emptyList()
        val towers = mutableListOf<Map<String, Any?>>()
        for (info in cellInfoList) {
            val map = cellInfoToMap(info, telephonyManager)
            if (map.isNotEmpty()) {
                towers.add(map)
            }
        }
        // Sort so Serving Cells (isRegistered == true) appear first, then strongest dBm
        towers.sortWith(
            compareByDescending<Map<String, Any?>> { it["isRegistered"] == true }
                .thenByDescending { (it["dbm"] as? Int) ?: -999 }
        )
        return towers
    }

    private fun cellInfoToMap(
        info: CellInfo,
        telephonyManager: TelephonyManager
    ): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        map["isRegistered"] = info.isRegistered

        val fallbackOperator = telephonyManager.networkOperatorName.takeIf { !it.isNullOrBlank() }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && info is CellInfoNr) {
            map["type"] = "5G NR"
            val identity = info.cellIdentity as? CellIdentityNr
            val signal = info.cellSignalStrength as? CellSignalStrengthNr
            if (identity != null) {
                val nci = identity.nci
                if (isValidLong(nci) && nci > 0) {
                    map["cellId"] = nci.toString()
                }
                if (isValidInt(identity.tac) && identity.tac >= 0) {
                    map["tac"] = identity.tac
                }
                if (isValidInt(identity.pci) && identity.pci >= 0) {
                    map["pci"] = identity.pci
                }
                if (isValidInt(identity.nrarfcn) && identity.nrarfcn >= 0) {
                    map["arfcn"] = identity.nrarfcn
                }
                if (!identity.mccString.isNullOrBlank()) map["mcc"] = identity.mccString
                if (!identity.mncString.isNullOrBlank()) map["mnc"] = identity.mncString

                val opAlpha = identity.operatorAlphaLong?.toString()?.takeIf { it.isNotBlank() }
                    ?: identity.operatorAlphaShort?.toString()?.takeIf { it.isNotBlank() }
                if (opAlpha != null) {
                    map["operatorName"] = opAlpha
                } else if (info.isRegistered && fallbackOperator != null) {
                    map["operatorName"] = fallbackOperator
                }
            }
            if (signal != null) {
                map["dbm"] = if (isValidDbm(signal.dbm)) signal.dbm else -1
                map["level"] = signal.level
                if (isValidInt(signal.asuLevel) && signal.asuLevel in 0..99) {
                    map["asu"] = signal.asuLevel
                }

                val ssRsrp = signal.ssRsrp
                val csiRsrp = signal.csiRsrp
                when {
                    isValidDbm(ssRsrp) -> map["rsrp"] = ssRsrp
                    isValidDbm(csiRsrp) -> map["rsrp"] = csiRsrp
                }

                val ssRsrq = signal.ssRsrq
                val csiRsrq = signal.csiRsrq
                when {
                    isValidInt(ssRsrq) && ssRsrq in -43..20 -> map["rsrq"] = ssRsrq
                    isValidInt(csiRsrq) && csiRsrq in -43..20 -> map["rsrq"] = csiRsrq
                }

                val ssSinr = signal.ssSinr
                val csiSinr = signal.csiSinr
                when {
                    isValidInt(ssSinr) && ssSinr in -25..45 -> map["sinr"] = ssSinr
                    isValidInt(csiSinr) && csiSinr in -25..45 -> map["sinr"] = csiSinr
                }
            }
            return map
        } else if (info is CellInfoLte) {
            map["type"] = "4G LTE"
            val identity = info.cellIdentity
            val signal = info.cellSignalStrength

            if (isValidInt(identity.ci) && identity.ci >= 0) {
                map["cellId"] = identity.ci.toString()
            }
            if (isValidInt(identity.tac) && identity.tac >= 0) {
                map["tac"] = identity.tac
            }
            if (isValidInt(identity.pci) && identity.pci >= 0) {
                map["pci"] = identity.pci
            }
            if (isValidInt(identity.earfcn) && identity.earfcn >= 0) {
                map["arfcn"] = identity.earfcn
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                if (!identity.mccString.isNullOrBlank()) map["mcc"] = identity.mccString
                if (!identity.mncString.isNullOrBlank()) map["mnc"] = identity.mncString
                if (isValidInt(identity.bandwidth) && identity.bandwidth > 0) {
                    map["bandwidthKhz"] = identity.bandwidth
                }
                val opAlpha = identity.operatorAlphaLong?.toString()?.takeIf { it.isNotBlank() }
                    ?: identity.operatorAlphaShort?.toString()?.takeIf { it.isNotBlank() }
                if (opAlpha != null) {
                    map["operatorName"] = opAlpha
                } else if (info.isRegistered && fallbackOperator != null) {
                    map["operatorName"] = fallbackOperator
                }
            } else {
                @Suppress("DEPRECATION")
                val legacyMcc = identity.mcc
                @Suppress("DEPRECATION")
                val legacyMnc = identity.mnc
                if (isValidInt(legacyMcc) && legacyMcc > 0) map["mcc"] = legacyMcc.toString()
                if (isValidInt(legacyMnc) && legacyMnc >= 0) map["mnc"] = legacyMnc.toString()
                if (info.isRegistered && fallbackOperator != null) {
                    map["operatorName"] = fallbackOperator
                }
            }

            map["dbm"] = if (isValidDbm(signal.dbm)) signal.dbm else -1
            map["level"] = signal.level
            if (isValidInt(signal.asuLevel) && signal.asuLevel in 0..99) {
                map["asu"] = signal.asuLevel
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (isValidDbm(signal.rsrp)) map["rsrp"] = signal.rsrp
                if (isValidInt(signal.rsrq) && signal.rsrq in -35..5) map["rsrq"] = signal.rsrq
                val sinrVal = normalizeLteSinr(signal.rssnr)
                if (sinrVal != null) map["sinr"] = sinrVal
                if (isValidInt(signal.cqi) && signal.cqi in 0..15) map["cqi"] = signal.cqi
            }
            if (isValidInt(signal.timingAdvance) && signal.timingAdvance in 0..1282) {
                map["timingAdvance"] = signal.timingAdvance
            }
            return map
        } else if (info is CellInfoWcdma) {
            map["type"] = "3G WCDMA"
            val identity = info.cellIdentity
            val signal = info.cellSignalStrength
            if (isValidInt(identity.cid) && identity.cid >= 0) map["cellId"] = identity.cid.toString()
            if (isValidInt(identity.lac) && identity.lac >= 0) map["lac"] = identity.lac
            if (isValidInt(identity.psc) && identity.psc >= 0) map["pci"] = identity.psc
            if (isValidInt(identity.uarfcn) && identity.uarfcn >= 0) map["arfcn"] = identity.uarfcn
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                if (!identity.mccString.isNullOrBlank()) map["mcc"] = identity.mccString
                if (!identity.mncString.isNullOrBlank()) map["mnc"] = identity.mncString
                val opAlpha = identity.operatorAlphaLong?.toString()?.takeIf { it.isNotBlank() }
                if (opAlpha != null) map["operatorName"] = opAlpha
            }
            if (info.isRegistered && map["operatorName"] == null && fallbackOperator != null) {
                map["operatorName"] = fallbackOperator
            }
            map["dbm"] = if (isValidDbm(signal.dbm)) signal.dbm else -1
            map["level"] = signal.level
            if (isValidInt(signal.asuLevel) && signal.asuLevel in 0..99) map["asu"] = signal.asuLevel
            return map
        } else if (info is CellInfoGsm) {
            map["type"] = "2G GSM"
            val identity = info.cellIdentity
            val signal = info.cellSignalStrength
            if (isValidInt(identity.cid) && identity.cid >= 0) map["cellId"] = identity.cid.toString()
            if (isValidInt(identity.lac) && identity.lac >= 0) map["lac"] = identity.lac
            if (isValidInt(identity.arfcn) && identity.arfcn >= 0) map["arfcn"] = identity.arfcn
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                if (!identity.mccString.isNullOrBlank()) map["mcc"] = identity.mccString
                if (!identity.mncString.isNullOrBlank()) map["mnc"] = identity.mncString
                val opAlpha = identity.operatorAlphaLong?.toString()?.takeIf { it.isNotBlank() }
                if (opAlpha != null) map["operatorName"] = opAlpha
            }
            if (info.isRegistered && map["operatorName"] == null && fallbackOperator != null) {
                map["operatorName"] = fallbackOperator
            }
            map["dbm"] = if (isValidDbm(signal.dbm)) signal.dbm else -1
            map["level"] = signal.level
            if (isValidInt(signal.asuLevel) && signal.asuLevel in 0..99) map["asu"] = signal.asuLevel
            return map
        }

        return emptyMap()
    }

    private fun check5gCapable(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
    }
}
