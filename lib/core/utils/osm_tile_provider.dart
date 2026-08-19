import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OsmTileProvider implements TileProvider {
  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    final url = 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      request.headers.add('User-Agent', 'com.shieldai.app');
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        return Tile(256, 256, bytes);
      }
    } catch (e) {
      // Ignore errors and return noTile
    }
    return TileProvider.noTile;
  }
}
