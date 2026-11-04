class CellTowerModel {
  final String cellId;
  final String type; // '5G NR', '4G LTE', '3G WCDMA', '2G GSM'
  final int dbm;
  final int level;
  final int? asu;
  final int? tac;
  final int? pci;
  final bool isRegistered;

  CellTowerModel({
    required this.cellId,
    required this.type,
    required this.dbm,
    required this.level,
    this.asu,
    this.tac,
    this.pci,
    this.isRegistered = false,
  });

  factory CellTowerModel.fromMap(Map<dynamic, dynamic> map) {
    return CellTowerModel(
      cellId: map['cellId']?.toString() ?? 'ID N/A',
      type: map['type']?.toString() ?? 'Cell Tower',
      dbm: (map['dbm'] as num?)?.toInt() ?? -1,
      level: (map['level'] as num?)?.toInt() ?? 0,
      asu: (map['asu'] as num?)?.toInt(),
      tac: (map['tac'] as num?)?.toInt(),
      pci: (map['pci'] as num?)?.toInt(),
      isRegistered: map['isRegistered'] == true,
    );
  }
}
