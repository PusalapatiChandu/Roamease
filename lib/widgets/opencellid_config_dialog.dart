import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/network_provider.dart';

void showOpenCellIdConfigDialog(BuildContext context) {
  final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
  final keyController = TextEditingController(text: networkProvider.openCellIdApiKey);
  double selectedRadius = networkProvider.towerSearchRadiusMeters;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.cell_tower_rounded, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Base Station Dataset Settings',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RoamEase queries beaconDB & OpenStreetMap automatically without any key. Adding a free OpenCelliD API key enables direct 4G/5G Cell-ID & operator area lookups.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: keyController,
                    decoration: const InputDecoration(
                      labelText: 'OpenCelliD API Key (Optional)',
                      hintText: 'pk.xxxxxxxxxxxxxxxxxxxx',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'OSM Tower Search Radius: ${(selectedRadius / 1000).toStringAsFixed(1)} km',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: selectedRadius,
                    min: 2000,
                    max: 9000,
                    divisions: 7,
                    label: '${(selectedRadius / 1000).toStringAsFixed(1)} km',
                    onChanged: (val) => setState(() => selectedRadius = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await networkProvider.setOpenCellIdApiKey(keyController.text);
                  await networkProvider.setTowerSearchRadius(selectedRadius);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save & Rescan'),
              ),
            ],
          );
        },
      );
    },
  );
}

