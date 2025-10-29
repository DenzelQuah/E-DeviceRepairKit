import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Opens an external maps app or browser to show the provided location.
///
/// Prefer coordinates (latitude & longitude). If those are missing, fall back
/// to `placeId` (if available) or a free-text `name` search.
Future<void> openMapToLocation({
  double? latitude,
  double? longitude,
  String? placeId,
  String? name,
}) async {
  Uri? uri;

  if (latitude != null && longitude != null) {
    uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude${placeId != null ? '&query_place_id=$placeId' : ''}',
    );
  } else if (placeId != null && placeId.isNotEmpty) {
    uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query_place_id=$placeId',
    );
  } else if (name != null && name.isNotEmpty) {
    uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}',
    );
  } else {
    throw ArgumentError(
      'At least one of latitude/longitude, placeId or name must be provided',
    );
  }

  // On Android prefer the google.navigation intent for direct navigation if available
  if (Platform.isAndroid && latitude != null && longitude != null) {
    final navUri = Uri.parse('google.navigation:q=$latitude,$longitude');
    if (await canLaunchUrl(navUri)) {
      await launchUrl(navUri);
      return;
    }
  }

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  throw Exception('Could not launch maps for $uri');
}
