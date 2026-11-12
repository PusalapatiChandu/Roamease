import 'dart:math' as math;

class TelecomUtils {
  /// Classifies measured signal into 'Strong', 'Moderate', 'Weak', or 'Unavailable'
  /// per 3GPP LTE / 5G NR RSRP and RSSI thresholds.
  static String classifySignalQuality({
    int? rsrp,
    int? dbm,
    int? level,
    bool isConnected = true,
  }) {
    if (!isConnected) return 'Unavailable';

    final int? effectiveDbm = (rsrp != null && rsrp <= -30 && rsrp >= -156)
        ? rsrp
        : ((dbm != null && dbm != -1 && dbm <= -25 && dbm >= -156) ? dbm : null);

    if (effectiveDbm != null) {
      if (effectiveDbm >= -90) return 'Strong';
      if (effectiveDbm >= -105) return 'Moderate';
      return 'Weak';
    }

    if (level != null && level > 0) {
      if (level >= 4) return 'Strong';
      if (level >= 2) return 'Moderate';
      return 'Weak';
    }

    return 'Unavailable';
  }

  /// Resolves official operator name from ITU E.212 MCC + MNC codes.
  static String? resolveOperatorFromMccMnc(String? mcc, String? mnc) {
    if (mcc == null || mnc == null || mcc.isEmpty || mnc.isEmpty) return null;
    final cleanMcc = mcc.trim().padLeft(3, '0');
    final cleanMnc = mnc.trim();
    final normMnc = cleanMnc.length == 1 ? cleanMnc.padLeft(2, '0') : cleanMnc;
    final key = '$cleanMcc-$normMnc';
    final rawKey = '$cleanMcc-$cleanMnc';

    if (_mccMncMap.containsKey(key)) return _mccMncMap[key];
    if (_mccMncMap.containsKey(rawKey)) return _mccMncMap[rawKey];

    // Broad India prefixes by MCC 404/405 ranges when circle-specific MNC varies
    if (cleanMcc == '405') {
      final int? mncNum = int.tryParse(cleanMnc);
      if (mncNum != null && mncNum >= 840 && mncNum <= 874) {
        return 'Reliance Jio';
      }
      if (mncNum != null && mncNum >= 51 && mncNum <= 56) {
        return 'Bharti Airtel';
      }
      if (mncNum != null && (mncNum == 800 || (mncNum >= 801 && mncNum <= 812))) {
        return 'Reliance Jio';
      }
    }
    return null;
  }

  /// Maps 3GPP EARFCN (4G LTE) or NR-ARFCN (5G NR) to readable band name & MHz center frequency.
  static String? resolveBandFromArfcn(int? arfcn, String? generation) {
    if (arfcn == null || arfcn < 0) return null;
    final gen = (generation ?? '').toUpperCase();

    if (gen.contains('5G') || gen.contains('NR')) {
      if (arfcn >= 620000 && arfcn <= 653333) return '5G NR n78 (3500 MHz C-Band)';
      if (arfcn >= 600000 && arfcn < 620000) return '5G NR n77 (3700 MHz)';
      if (arfcn >= 499200 && arfcn <= 537999) return '5G NR n41 / n38 (2500 MHz)';
      if (arfcn >= 460000 && arfcn <= 480000) return '5G NR n40 (2300 MHz TDD)';
      if (arfcn >= 422000 && arfcn <= 434000) return '5G NR n1 (2100 MHz)';
      if (arfcn >= 361000 && arfcn <= 376000) return '5G NR n3 (1800 MHz)';
      if (arfcn >= 151600 && arfcn <= 160600) return '5G NR n28 (700 MHz Low-Band)';
      if (arfcn >= 123400 && arfcn <= 130400) return '5G NR n71 (600 MHz)';
      if (arfcn >= 2054166) return '5G NR mmWave n258/n257 (26-28 GHz)';
      return 'NR-ARFCN $arfcn';
    }

    // 4G LTE EARFCN
    if (arfcn >= 0 && arfcn <= 599) return 'LTE Band 1 (2100 MHz)';
    if (arfcn >= 1200 && arfcn <= 1949) return 'LTE Band 3 (1800 MHz)';
    if (arfcn >= 2400 && arfcn <= 2649) return 'LTE Band 5 (850 MHz)';
    if (arfcn >= 2750 && arfcn <= 3449) return 'LTE Band 7 (2600 MHz)';
    if (arfcn >= 3450 && arfcn <= 3799) return 'LTE Band 8 (900 MHz)';
    if (arfcn >= 9210 && arfcn <= 9659) return 'LTE Band 28 (700 MHz)';
    if (arfcn >= 38650 && arfcn <= 39649) return 'LTE Band 40 (2300 MHz TDD)';
    if (arfcn >= 39650 && arfcn <= 41589) return 'LTE Band 41 (2500 MHz TDD)';
    return 'ARFCN $arfcn';
  }

  /// Calculates estimated 3GPP/ITU macro-cell reference footprint radius (meters)
  /// strictly for coverage visualization when external DB lacks an explicit range.
  static double estimateReferenceCoverageRadiusMeters({
    required String generation,
    int? arfcn,
  }) {
    final g = generation.toUpperCase();
    if (g.contains('5G')) {
      if (arfcn != null && arfcn >= 2054166) return 280.0; // mmWave small cell
      if (arfcn != null && arfcn <= 200000) return 2400.0; // n28/n71 700MHz wide coverage
      return 850.0; // 5G C-Band / Mid-band typical urban macro cell
    }
    if (g.contains('4G') || g.contains('LTE')) {
      if (arfcn != null && ((arfcn >= 2400 && arfcn <= 2649) || (arfcn >= 3450 && arfcn <= 3799) || (arfcn >= 9210 && arfcn <= 9659))) {
        return 2600.0; // Sub-1GHz LTE long range
      }
      return 1500.0; // 1800-2300 MHz urban/suburban LTE
    }
    if (g.contains('3G')) return 2200.0;
    return 1400.0; // Unspecified mobile macro mast baseline
  }

  /// Computes estimated received reference power (dBm) at a given distance using
  /// simplified 3GPP TR 38.901 Urban Macro (UMa) path-loss model.
  /// Strictly for ESTIMATED COVERAGE COMPARISON — NEVER represents measured signal.
  static int estimatePathLossDbm({
    required double distanceMeters,
    required String generation,
  }) {
    final d = math.max(distanceMeters, 25.0);
    final is5gMid = generation.toUpperCase().contains('5G');
    // Standard carrier frequency reference: 3.5 GHz for 5G, 1.8 GHz for 4G
    final double freqGhz = is5gMid ? 3.5 : 1.8;
    // Reference EIRP macro sector: ~58 dBm minus ~15 dB building/body loss allowance
    const double effectiveEirpDbm = 43.0;
    final double pathLossDb = 28.0 + 22.0 * (math.log(d) / math.ln10) + 20.0 * (math.log(freqGhz) / math.ln10);
    final int est = (effectiveEirpDbm - pathLossDb).round().clamp(-135, -55);
    return est;
  }

  /// Formats distance meters nicely (e.g., '345 m', '1.42 km').
  static String formatDistance(double? meters) {
    if (meters == null || meters.isNaN || meters < 0) return 'Unavailable';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000.0).toStringAsFixed(2)} km';
  }

  /// Curated ITU E.212 MCC-MNC operator map (India + major global networks).
  static const Map<String, String> _mccMncMap = {
    // India - Reliance Jio (405-840, 854..874)
    '405-840': 'Reliance Jio',
    '405-854': 'Reliance Jio',
    '405-855': 'Reliance Jio',
    '405-856': 'Reliance Jio',
    '405-857': 'Reliance Jio',
    '405-858': 'Reliance Jio',
    '405-859': 'Reliance Jio',
    '405-860': 'Reliance Jio',
    '405-861': 'Reliance Jio',
    '405-862': 'Reliance Jio',
    '405-863': 'Reliance Jio',
    '405-864': 'Reliance Jio',
    '405-865': 'Reliance Jio',
    '405-866': 'Reliance Jio',
    '405-867': 'Reliance Jio',
    '405-868': 'Reliance Jio',
    '405-869': 'Reliance Jio',
    '405-870': 'Reliance Jio',
    '405-871': 'Reliance Jio',
    '405-872': 'Reliance Jio',
    '405-873': 'Reliance Jio',
    '405-874': 'Reliance Jio',

    // India - Bharti Airtel (404/405)
    '404-02': 'Bharti Airtel',
    '404-03': 'Bharti Airtel',
    '404-10': 'Bharti Airtel',
    '404-16': 'Bharti Airtel',
    '404-31': 'Bharti Airtel',
    '404-40': 'Bharti Airtel',
    '404-45': 'Bharti Airtel',
    '404-49': 'Bharti Airtel',
    '404-70': 'Bharti Airtel',
    '404-90': 'Bharti Airtel',
    '404-92': 'Bharti Airtel',
    '404-93': 'Bharti Airtel',
    '404-94': 'Bharti Airtel',
    '404-95': 'Bharti Airtel',
    '404-96': 'Bharti Airtel',
    '404-97': 'Bharti Airtel',
    '404-98': 'Bharti Airtel',

    // India - Vodafone Idea (Vi)
    '404-01': 'Vodafone Idea (Vi)',
    '404-04': 'Vodafone Idea (Vi)',
    '404-05': 'Vodafone Idea (Vi)',
    '404-07': 'Vodafone Idea (Vi)',
    '404-11': 'Vodafone Idea (Vi)',
    '404-12': 'Vodafone Idea (Vi)',
    '404-13': 'Vodafone Idea (Vi)',
    '404-14': 'Vodafone Idea (Vi)',
    '404-15': 'Vodafone Idea (Vi)',
    '404-19': 'Vodafone Idea (Vi)',
    '404-20': 'Vodafone Idea (Vi)',
    '404-21': 'Vodafone Idea (Vi)',
    '404-22': 'Vodafone Idea (Vi)',
    '404-24': 'Vodafone Idea (Vi)',
    '404-27': 'Vodafone Idea (Vi)',
    '404-30': 'Vodafone Idea (Vi)',
    '404-43': 'Vodafone Idea (Vi)',
    '404-44': 'Vodafone Idea (Vi)',
    '404-46': 'Vodafone Idea (Vi)',
    '404-56': 'Vodafone Idea (Vi)',
    '404-60': 'Vodafone Idea (Vi)',
    '404-78': 'Vodafone Idea (Vi)',
    '404-82': 'Vodafone Idea (Vi)',
    '404-84': 'Vodafone Idea (Vi)',
    '404-86': 'Vodafone Idea (Vi)',
    '404-87': 'Vodafone Idea (Vi)',
    '404-88': 'Vodafone Idea (Vi)',
    '404-89': 'Vodafone Idea (Vi)',

    // India - BSNL
    '404-34': 'BSNL',
    '404-38': 'BSNL',
    '404-51': 'BSNL',
    '404-53': 'BSNL',
    '404-54': 'BSNL',
    '404-55': 'BSNL',
    '404-57': 'BSNL',
    '404-58': 'BSNL',
    '404-59': 'BSNL',
    '404-62': 'BSNL',
    '404-64': 'BSNL',
    '404-66': 'BSNL',
    '404-71': 'BSNL',
    '404-72': 'BSNL',
    '404-73': 'BSNL',
    '404-74': 'BSNL',
    '404-75': 'BSNL',
    '404-76': 'BSNL',
    '404-77': 'BSNL',
    '404-79': 'BSNL',
    '404-80': 'BSNL',
    '404-81': 'BSNL',

    // Global Major Carriers
    '310-260': 'T-Mobile US',
    '310-410': 'AT&T Mobility',
    '311-480': 'Verizon Wireless',
    '234-10': 'O2 UK',
    '234-15': 'Vodafone UK',
    '234-20': 'Three UK',
    '234-30': 'EE UK',
    '262-01': 'Deutsche Telekom',
    '262-02': 'Vodafone DE',
    '262-03': 'O2 DE',
    '208-01': 'Orange France',
    '505-01': 'Telstra AU',
    '505-02': 'Optus AU',
    '525-01': 'Singtel',
  };
}

