// ...existing code...
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

Future<void> openMapToLocation({
  double? latitude,
  double? longitude,
  String? placeId,
  String? name,
  double? long,
  double? lat,
}) async {
  final double? finalLat = latitude ?? lat;
  final double? finalLong = longitude ?? long;

  Uri? httpsUri;
  Uri? geoUri;
  Uri? navUri;

  if (finalLat != null && finalLong != null) {
    final label = name != null && name.isNotEmpty ? '(${Uri.encodeComponent(name)})' : '';
    geoUri = Uri.parse('geo:$finalLat,$finalLong?q=$finalLat,$finalLong$label');
    navUri = Uri.parse('google.navigation:q=$finalLat,$finalLong');
    httpsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$finalLat,$finalLong${placeId != null ? '&query_place_id=$placeId' : ''}');
  } else if (placeId != null && placeId.isNotEmpty) {
    // include name in query so Maps shows readable label rather than only the encoded id
    final encodedName = (name != null && name.isNotEmpty) ? Uri.encodeComponent(name) : null;
    // geo query with label: geo:0,0?q=place_id:PLACE_ID(NAME)
    geoUri = Uri.parse(encodedName != null
        ? 'geo:0,0?q=place_id:$placeId($encodedName)'
        : 'geo:0,0?q=place_id:$placeId');
    // https: include both query (name) and query_place_id so Google Maps shows the place with readable name
    httpsUri = Uri.parse(encodedName != null
        ? 'https://www.google.com/maps/search/?api=1&query=$encodedName&query_place_id=$placeId'
        : 'https://www.google.com/maps/search/?api=1&query_place_id=$placeId');
    // navigation using name fallback
    if (encodedName != null) navUri = Uri.parse('google.navigation:q=$encodedName');
  } else if (name != null && name.isNotEmpty) {
    final encoded = Uri.encodeComponent(name);
    httpsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    geoUri = Uri.parse('geo:0,0?q=$encoded');
  } else {
    throw Exception('No location info provided to openMapToLocation');
  }

  // debug
  // ignore: avoid_print
  print('openMapToLocation -> geo: $geoUri, nav: $navUri, https: $httpsUri, coords: ($finalLat,$finalLong), placeId: $placeId, name: $name');

  Future<bool> tryLaunch(Uri? u, LaunchMode mode) async {
    if (u == null) return false;
    try {
      // attempt launch even if canLaunchUrl returns false on some devices
      // ignore: avoid_print
      print('attempting launch: $u mode=$mode');
      final launched = await launchUrl(u, mode: mode);
      // ignore: avoid_print
      print('launchUrl($u) returned $launched');
      return launched;
    } catch (e) {
      // ignore: avoid_print
      print('launch error for $u -> $e');
      return false;
    }
  }

  if (Platform.isAndroid) {
    if (navUri != null && await tryLaunch(navUri, LaunchMode.externalApplication)) return;
    if (await tryLaunch(geoUri, LaunchMode.externalApplication)) return;
    if (await tryLaunch(httpsUri, LaunchMode.externalApplication)) return;
    if (await tryLaunch(httpsUri, LaunchMode.inAppWebView)) return;
  } else {
    if (await tryLaunch(httpsUri, LaunchMode.externalApplication)) return;
    if (await tryLaunch(httpsUri, LaunchMode.inAppWebView)) return;
    if (await tryLaunch(geoUri, LaunchMode.externalApplication)) return;
    if (await tryLaunch(geoUri, LaunchMode.inAppWebView)) return;
  }

  throw Exception('Could not launch maps URL. Last tried https: $httpsUri, geo: $geoUri, nav: $navUri');
}
// ...existing code...