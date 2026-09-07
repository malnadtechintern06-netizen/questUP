import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../app/config/app_constants.dart';
import '../../features/quests/data/models/quest_model.dart';
import '../../features/quests/domain/entities/quest.dart';
import '../../features/quests/presentation/utils/quest_image_resolver.dart';
import '../utils/distance_calculator.dart';
import 'google_place_photo_service.dart';

class LocationAddressDetails {
  final String formattedAddress;
  final String? areaName;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final double latitude;
  final double longitude;
  final double? accuracy;

  const LocationAddressDetails({
    required this.formattedAddress,
    this.areaName,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });
}

class DiscoveredPlace {
  final String id;
  final String rawPlaceId; // Exact Google Places place_id (e.g. ChIJf-Z-5gCEuzsRfsP2N31R1pw)
  final String name;
  final String type;
  final List<String> types;
  final String specificCategory; // e.g. college, temple, park, hospital, station, etc.
  final double latitude;
  final double longitude;
  final QuestCategory category;
  final String? description;
  final String? address;
  final String? verifiedTarget; // Optional specific target if verified by admin
  final String? imageUrl;
  final String? photoReference;
  final List<String> photoReferences;
  final String imageSource; // 'google_places' | 'fallback'

  const DiscoveredPlace({
    required this.id,
    required this.rawPlaceId,
    required this.name,
    required this.type,
    this.types = const [],
    required this.specificCategory,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.description,
    this.address,
    this.verifiedTarget,
    this.imageUrl,
    this.photoReference,
    this.photoReferences = const [],
    this.imageSource = 'fallback',
  });
}

abstract class IPlacesDiscoveryService {
  Future<String?> reverseGeocodeArea(double lat, double lon);
  Future<LocationAddressDetails?> getLiveLocationDetails(
    double lat,
    double lon, {
    double? accuracy,
  });
  Future<List<DiscoveredPlace>> findNearbyFamousPlaces(
    double lat,
    double lon, {
    double searchRadiusMeters = 5000.0,
  });
  Future<List<QuestModel>> generateFamousPlaceQuests({
    required double userLat,
    required double userLon,
    double searchRadiusMeters = 5000.0,
    Set<String> completedIds = const {},
  });
}

class PlacesDiscoveryService implements IPlacesDiscoveryService {
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6);

  // Pool of high-speed Overpass API server mirrors for resilience
  static const List<String> _overpassMirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  // Optional registry for Admin-verified specific targets (e.g. Principal's Room, Specific Murals)
  static final Map<String, String> _verifiedInternalTargets = {
    // Allows admin-curated specific internal targets when known
  };

  @override
  Future<LocationAddressDetails?> getLiveLocationDetails(
    double lat,
    double lon, {
    double? accuracy,
  }) async {
    // 1. Google Geocoding API if key configured
    if (AppConstants.googleMapsApiKey.isNotEmpty) {
      try {
        final googleUri = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=${AppConstants.googleMapsApiKey}',
        );
        final request = await _httpClient.getUrl(googleUri);
        final response = await request.close().timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          final results = json['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            final first = results.first as Map<String, dynamic>;
            final formatted = first['formatted_address'] as String? ?? 'Current Location';

            String? area;
            String? city;
            String? state;
            String? country;
            String? postal;

            final components = first['address_components'] as List<dynamic>? ?? [];
            for (final comp in components) {
              final types = (comp['types'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
              final longName = comp['long_name'] as String?;
              if (types.contains('sublocality') ||
                  types.contains('neighborhood') ||
                  types.contains('sublocality_level_1')) {
                area ??= longName;
              } else if (types.contains('locality') || types.contains('administrative_area_level_2')) {
                city ??= longName;
              } else if (types.contains('administrative_area_level_1')) {
                state ??= longName;
              } else if (types.contains('country')) {
                country ??= longName;
              } else if (types.contains('postal_code')) {
                postal ??= longName;
              }
            }

            return LocationAddressDetails(
              formattedAddress: formatted,
              areaName: area ?? city ?? 'Current Location',
              city: city,
              state: state,
              country: country,
              postalCode: postal,
              latitude: lat,
              longitude: lon,
              accuracy: accuracy,
            );
          }
        }
      } catch (e) {
        debugPrint('Google Geocode notice: $e');
      }
    }

    // 2. OpenStreetMap Nominatim Reverse Geocoding fallback
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );

      final request = await _httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'QuestUP-AdventureApp/1.0 (Mobile Exploration)');
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;

        final displayName = json['display_name'] as String? ?? 'Current GPS Location';
        final address = json['address'] as Map<String, dynamic>?;

        final area = address?['neighbourhood'] ??
            address?['suburb'] ??
            address?['residential'] ??
            address?['quarter'] ??
            address?['city_district'] ??
            address?['road'];

        final city = address?['city'] ?? address?['town'] ?? address?['village'] ?? address?['county'];
        final state = address?['state'];
        final country = address?['country'];
        final postal = address?['postcode'];

        return LocationAddressDetails(
          formattedAddress: displayName,
          areaName: area?.toString() ?? city?.toString() ?? 'Current Location',
          city: city?.toString(),
          state: state?.toString(),
          country: country?.toString(),
          postalCode: postal?.toString(),
          latitude: lat,
          longitude: lon,
          accuracy: accuracy,
        );
      }
    } catch (e) {
      debugPrint('Location details geocode notice: $e');
    }

    return LocationAddressDetails(
      formattedAddress: 'GPS: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
      areaName: 'Current Sector',
      latitude: lat,
      longitude: lon,
      accuracy: accuracy,
    );
  }

  @override
  Future<String?> reverseGeocodeArea(double lat, double lon) async {
    final gridKey = '${(lat * 100).round()}_${(lon * 100).round()}';
    if (_areaNameCache.containsKey(gridKey)) {
      return _areaNameCache[gridKey];
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=16&addressdetails=1',
      );

      final request = await _httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'QuestUP-AdventureApp/1.0 (Mobile Exploration)');
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;

        final address = json['address'] as Map<String, dynamic>?;
        if (address != null) {
          final neighbourhood = address['neighbourhood'] ??
              address['suburb'] ??
              address['residential'] ??
              address['quarter'] ??
              address['city_district'] ??
              address['road'] ??
              address['city'] ??
              address['town'] ??
              address['village'];

          if (neighbourhood != null && neighbourhood.toString().isNotEmpty) {
            final areaStr = neighbourhood.toString();
            _areaNameCache[gridKey] = areaStr;
            return areaStr;
          }
        }

        final name = json['name'] as String?;
        if (name != null && name.isNotEmpty) {
          _areaNameCache[gridKey] = name;
          return name;
        }
      }
    } catch (e) {
      debugPrint('[QUESTUP] Reverse geocode notice: $e');
    }
    return null;
  }

  // In-memory cache of discovered places by coordinate grid cell with 3-minute TTL
  static final Map<String, (DateTime, List<DiscoveredPlace>)> _gridPlacesCache = {};
  // In-memory cache of reverse-geocoded area names
  static final Map<String, String> _areaNameCache = {};

  @override
  Future<List<DiscoveredPlace>> findNearbyFamousPlaces(
    double lat,
    double lon, {
    double searchRadiusMeters = 5000.0,
  }) async {
    final sw = Stopwatch()..start();
    final gridKey = '${(lat * 100).round()}_${(lon * 100).round()}';
    final cached = _gridPlacesCache[gridKey];
    if (cached != null && DateTime.now().difference(cached.$1).inMinutes < 10) {
      debugPrint('[QUESTUP] Discovered places loaded from grid cache in ${sw.elapsedMilliseconds}ms: ${cached.$2.length} places');
      return cached.$2;
    }

    final List<DiscoveredPlace> places = [];
    final searchRadius = searchRadiusMeters.clamp(500, 8000).toInt();

    debugPrint('[QUESTUP] Google Places / Overpass discovery started for Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)} (Radius: ${searchRadius}m)...');

    // Run Google Places and Overpass in parallel for high speed
    final discoveryFutures = <Future<List<DiscoveredPlace>>>[];
    if (AppConstants.googleMapsApiKey.isNotEmpty) {
      discoveryFutures.add(_queryGooglePlacesNearby(lat, lon, searchRadius));
    }
    discoveryFutures.add(_queryMultiServerOverpass(lat, lon, searchRadius));

    final results = await Future.wait(discoveryFutures).timeout(
      const Duration(seconds: 3),
      onTimeout: () => [],
    );

    for (final res in results) {
      _addUniquePlaces(places, res);
    }

    // Fast Nominatim fallback only if still empty
    if (places.isEmpty) {
      try {
        final nominatimPlaces = await _queryStructuredNominatim(lat, lon, searchRadius.toDouble())
            .timeout(const Duration(seconds: 2), onTimeout: () => []);
        _addUniquePlaces(places, nominatimPlaces);
      } catch (_) {}
    }

    debugPrint('[QUESTUP] Discovery completed in ${sw.elapsedMilliseconds}ms: ${places.length} places found');

    // Filter places strictly within requested searchRadiusMeters & sort by closest
    final filtered = places.where((p) {
      final dist = DistanceCalculator.calculateDistanceMeters(
        lat1: lat,
        lon1: lon,
        lat2: p.latitude,
        lon2: p.longitude,
      );
      return dist <= searchRadiusMeters;
    }).toList();

    filtered.sort((a, b) {
      final distA = DistanceCalculator.calculateDistanceMeters(
        lat1: lat,
        lon1: lon,
        lat2: a.latitude,
        lon2: a.longitude,
      );
      final distB = DistanceCalculator.calculateDistanceMeters(
        lat1: lat,
        lon1: lon,
        lat2: b.latitude,
        lon2: b.longitude,
      );
      return distA.compareTo(distB);
    });

    // Limit to top 8 closest places for fast loading
    final limited = filtered.take(8).toList();
    _gridPlacesCache[gridKey] = (DateTime.now(), limited);
    return limited;
  }

  void _addUniquePlaces(List<DiscoveredPlace> target, List<DiscoveredPlace> incoming) {
    for (final place in incoming) {
      if (!target.any((existing) =>
          existing.id == place.id ||
          existing.name.toLowerCase() == place.name.toLowerCase() ||
          (DistanceCalculator.calculateDistanceMeters(
                lat1: existing.latitude,
                lon1: existing.longitude,
                lat2: place.latitude,
                lon2: place.longitude,
              ) < 30.0))) {
        target.add(place);
      }
    }
  }

  Future<List<DiscoveredPlace>> _queryGooglePlacesNearby(double lat, double lon, int radius) async {
    final List<DiscoveredPlace> places = [];
    try {
      final googlePlacesUri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lon&radius=$radius&type=school|university|hindu_temple|place_of_worship|park|museum|hospital|local_government_office|transit_station|tourist_attraction|point_of_interest&key=${AppConstants.googleMapsApiKey}',
      );
      final request = await _httpClient.getUrl(googlePlacesUri);
      final response = await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final results = json['results'] as List<dynamic>? ?? [];

        for (final res in results) {
          final name = res['name'] as String?;
          if (name == null || name.trim().isEmpty) continue;

          final geom = res['geometry']?['location'] as Map<String, dynamic>?;
          final pLat = (geom?['lat'] as num?)?.toDouble();
          final pLon = (geom?['lng'] as num?)?.toDouble();
          if (pLat == null || pLon == null) continue;

          final types = (res['types'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
          final typeStr = types.isNotEmpty ? types.first : 'point_of_interest';

          final specificCat = _determineSpecificCategory(typeStr, types, name);
          final questCat = _mapSpecificToQuestCategory(specificCat);
          final rawPlaceId = res['place_id']?.toString() ?? 'gplace_${places.length}';
          final placeId = 'gplace_$rawPlaceId';
          final vicinity = res['vicinity'] as String?;

          final photos = res['photos'] as List<dynamic>? ?? [];
          List<String> photoRefs = photos
              .map((p) => p['photo_reference']?.toString())
              .whereType<String>()
              .toList();

          // If photos array was omitted in basic search, fetch details for this exact place
          if (photoRefs.isEmpty && AppConstants.googleMapsApiKey.isNotEmpty && rawPlaceId.startsWith('ChIJ')) {
            photoRefs = await GooglePlacePhotoService().fetchPlacePhotos(rawPlaceId);
          }

          String? primaryPhotoRef;
          String? photoUrl;
          String imageSource = 'FALLBACK_NO_GOOGLE_PHOTO';

          if (photoRefs.isNotEmpty && AppConstants.googleMapsApiKey.isNotEmpty) {
            primaryPhotoRef = photoRefs.first;
            photoUrl = GooglePlacePhotoService().buildPhotoUrl(primaryPhotoRef);
            if (photoUrl != null) {
              imageSource = 'GOOGLE_PLACES';
            }
          }

          photoUrl ??= QuestImageResolver.resolvePlaceCategoryImageUrl(
            specificCategory: specificCat,
            placeName: name.trim(),
          );

          debugPrint('========== GOOGLE PLACE ==========');
          debugPrint('Name:');
          debugPrint(name.trim());
          debugPrint('Place ID:');
          debugPrint(rawPlaceId);
          debugPrint('Latitude:');
          debugPrint('$pLat');
          debugPrint('Longitude:');
          debugPrint('$pLon');
          debugPrint('Photo count:');
          debugPrint('${photoRefs.length}');
          debugPrint('Photo reference/resource:');
          debugPrint(primaryPhotoRef ?? 'NONE');
          debugPrint('Image source:');
          debugPrint(imageSource);
          debugPrint('=================================');

          places.add(
            DiscoveredPlace(
              id: placeId,
              rawPlaceId: rawPlaceId,
              name: name.trim(),
              type: typeStr,
              types: types,
              specificCategory: specificCat,
              latitude: pLat,
              longitude: pLon,
              category: questCat,
              description: vicinity,
              address: vicinity,
              verifiedTarget: _verifiedInternalTargets[placeId] ??
                  _verifiedInternalTargets[rawPlaceId] ??
                  _verifiedInternalTargets[name.trim()],
              imageUrl: photoUrl,
              photoReference: primaryPhotoRef,
              photoReferences: photoRefs,
              imageSource: imageSource,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Google Places search notice: $e');
    }
    return places;
  }

  Future<List<DiscoveredPlace>> _queryMultiServerOverpass(double lat, double lon, int radius) async {
    // Lean and comprehensive Overpass QL covering Colleges, Schools, Temples, Hospitals, Stations, Offices, Parks, Waterfalls, etc.
    final overpassQuery = '''
[out:json][timeout:5];
(
  nwr["amenity"~"college|university|school|place_of_worship|hospital|townhall|courthouse|library|bus_station|community_centre|marketplace"](around:$radius, $lat, $lon);
  nwr["tourism"~"attraction|museum|monument|viewpoint|artwork|gallery|theme_park"](around:$radius, $lat, $lon);
  nwr["historic"~"monument|memorial|castle|fort|ruins|archaeological_site|heritage"](around:$radius, $lat, $lon);
  nwr["leisure"~"park|garden|nature_reserve|sports_centre|stadium"](around:$radius, $lat, $lon);
  nwr["railway"~"station"](around:$radius, $lat, $lon);
  nwr["natural"~"waterfall|peak"](around:$radius, $lat, $lon);
  nwr["office"~"government"](around:$radius, $lat, $lon);
  nwr["shop"~"mall"](around:$radius, $lat, $lon);
);
out center 30;
''';

    final mirrorFutures = _overpassMirrors.map((mirrorUrl) => _fetchFromOverpassMirror(mirrorUrl, overpassQuery));
    try {
      final results = await Future.wait(mirrorFutures);
      for (final res in results) {
        if (res.isNotEmpty) return res;
      }
    } catch (_) {}
    return [];
  }

  Future<List<DiscoveredPlace>> _fetchFromOverpassMirror(String mirrorUrl, String overpassQuery) async {
    final List<DiscoveredPlace> places = [];
    try {
      final uri = Uri.parse(mirrorUrl);
      final request = await _httpClient.postUrl(uri);
      request.headers.set('User-Agent', 'QuestUP-AdventureApp/1.0 (Mobile Exploration)');
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      request.write('data=${Uri.encodeQueryComponent(overpassQuery)}');

      final response = await request.close().timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];

        for (final el in elements) {
          final tags = el['tags'] as Map<String, dynamic>?;
          if (tags == null) continue;

          final name = tags['name'] as String? ?? tags['name:en'] as String?;
          if (name == null || name.trim().isEmpty) continue;

          final pLat = (el['lat'] as num?)?.toDouble() ?? (el['center']?['lat'] as num?)?.toDouble();
          final pLon = (el['lon'] as num?)?.toDouble() ?? (el['center']?['lon'] as num?)?.toDouble();
          if (pLat == null || pLon == null) continue;

          final typeStr = tags['amenity'] ??
              tags['tourism'] ??
              tags['historic'] ??
              tags['leisure'] ??
              tags['railway'] ??
              tags['natural'] ??
              tags['office'] ??
              'landmark';

          final allTags = tags.entries.map((e) => '${e.key}=${e.value}').toList();
          final specificCat = _determineSpecificCategory(typeStr.toString(), allTags, name);
          final questCat = _mapSpecificToQuestCategory(specificCat);

          final placeId = 'osm_${el['type']}_${el['id']}';
          String? placeImg;
          final imageTag = tags['image'] as String?;
          final commonsTag = tags['wikimedia_commons'] as String?;
          if (imageTag != null && imageTag.startsWith('http')) {
            placeImg = imageTag;
          } else if (commonsTag != null && commonsTag.isNotEmpty) {
            final cleaned = commonsTag.replaceFirst('File:', '').replaceFirst('Image:', '').trim();
            placeImg = 'https://commons.wikimedia.org/wiki/Special:FilePath/${Uri.encodeComponent(cleaned)}?width=800';
          }

          placeImg ??= QuestImageResolver.resolvePlaceCategoryImageUrl(
            specificCategory: specificCat,
            placeName: name.trim(),
          );

          places.add(
            DiscoveredPlace(
              id: placeId,
              rawPlaceId: placeId,
              name: name.trim(),
              type: typeStr.toString(),
              types: [typeStr.toString()],
              specificCategory: specificCat,
              latitude: pLat,
              longitude: pLon,
              category: questCat,
              description: tags['description'] as String? ?? tags['historic'] as String?,
              verifiedTarget: _verifiedInternalTargets[placeId] ?? _verifiedInternalTargets[name.trim()],
              imageUrl: placeImg,
              imageSource: (imageTag != null || commonsTag != null) ? 'GOOGLE_PLACES' : 'FALLBACK_NO_GOOGLE_PHOTO',
            ),
          );
        }
      }
    } catch (_) {}
    return places;
  }

  Future<List<DiscoveredPlace>> _queryStructuredNominatim(double lat, double lon, double radiusMeters) async {
    final List<DiscoveredPlace> places = [];

    // Distinct place categories to query sequentially
    final categoriesToSearch = [
      'college',
      'university',
      'temple',
      'school',
      'hospital',
      'park',
      'station',
      'monument',
      'waterfall',
      'library',
      'government',
    ];

    final boundsDelta = (radiusMeters / 111000.0).clamp(0.01, 0.08);
    final minLon = lon - boundsDelta;
    final maxLon = lon + boundsDelta;
    final minLat = lat - boundsDelta;
    final maxLat = lat + boundsDelta;

    for (final catQuery in categoriesToSearch) {
      if (places.length >= 8) break;

      try {
        final nomUri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=jsonv2&q=$catQuery&bounded=1&viewbox=$minLon,$maxLat,$maxLon,$minLat&limit=5',
        );
        final request = await _httpClient.getUrl(nomUri);
        request.headers.set('User-Agent', 'QuestUP-AdventureApp/1.0 (Mobile Exploration)');
        final response = await request.close().timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as List<dynamic>? ?? [];

          for (final item in data) {
            final name = item['name'] as String? ?? (item['display_name'] as String?)?.split(',').first;
            if (name == null || name.trim().isEmpty) continue;

            final pLat = double.tryParse(item['lat']?.toString() ?? '');
            final pLon = double.tryParse(item['lon']?.toString() ?? '');
            if (pLat == null || pLon == null) continue;

            final typeStr = item['type']?.toString() ?? item['category']?.toString() ?? catQuery;
            final specificCat = _determineSpecificCategory(typeStr, [typeStr, catQuery], name);
            final questCat = _mapSpecificToQuestCategory(specificCat);

            final placeId = 'nom_${item['place_id']}';
            final placeImg = QuestImageResolver.resolvePlaceCategoryImageUrl(
              specificCategory: specificCat,
              placeName: name.trim(),
            );

            places.add(
              DiscoveredPlace(
                id: placeId,
                rawPlaceId: placeId,
                name: name.trim(),
                type: typeStr,
                types: [typeStr, catQuery],
                specificCategory: specificCat,
                latitude: pLat,
                longitude: pLon,
                category: questCat,
                verifiedTarget: _verifiedInternalTargets[placeId] ?? _verifiedInternalTargets[name.trim()],
                imageUrl: placeImg,
                imageSource: 'fallback',
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Nominatim query ($catQuery) notice: $e');
      }
    }

    return places;
  }

  String _determineSpecificCategory(String primaryType, List<String> tags, String name) {
    final lower = '$primaryType ${tags.join(' ')} $name'.toLowerCase();

    if (lower.contains('college') || lower.contains('university') || lower.contains('campus') || lower.contains('institute')) {
      return 'college';
    }
    if (lower.contains('school') || lower.contains('vidyalaya') || lower.contains('academy')) {
      return 'school';
    }
    if (lower.contains('temple') || lower.contains('mandir') || lower.contains('devasthana') || lower.contains('kovil') || lower.contains('gudi')) {
      return 'temple';
    }
    if (lower.contains('church') || lower.contains('cathedral') || lower.contains('chapel')) {
      return 'church';
    }
    if (lower.contains('mosque') || lower.contains('masjid') || lower.contains('dargah')) {
      return 'mosque';
    }
    if (lower.contains('worship') || lower.contains('shrine') || lower.contains('gurdwara')) {
      return 'worship';
    }
    if (lower.contains('waterfall') || lower.contains('falls') || lower.contains('jalapatha') || lower.contains('abba')) {
      return 'waterfall';
    }
    if (lower.contains('lake') || lower.contains('river') || lower.contains('kare') || lower.contains('dam') || lower.contains('reservoir')) {
      return 'lake';
    }
    if (lower.contains('viewpoint') || lower.contains('peak') || lower.contains('hill') || lower.contains('betta') || lower.contains('ghat')) {
      return 'viewpoint';
    }
    if (lower.contains('park') || lower.contains('garden') || lower.contains('reserve') || lower.contains('forest')) {
      return 'park';
    }
    if (lower.contains('hospital') || lower.contains('clinic') || lower.contains('medical') || lower.contains('health')) {
      return 'hospital';
    }
    if (lower.contains('railway') || lower.contains('train') || lower.contains('station') || lower.contains('bus_station')) {
      return 'station';
    }
    if (lower.contains('townhall') || lower.contains('government') || lower.contains('courthouse') || lower.contains('panchayat') || lower.contains('office') || lower.contains('kacheri')) {
      return 'government';
    }
    if (lower.contains('museum') || lower.contains('gallery') || lower.contains('monument') || lower.contains('memorial') || lower.contains('heritage') || lower.contains('fort') || lower.contains('palace') || lower.contains('archeological')) {
      return 'museum';
    }
    if (lower.contains('library') || lower.contains('pustakalaya')) {
      return 'library';
    }
    if (lower.contains('market') || lower.contains('mall') || lower.contains('bazaar') || lower.contains('supermarket')) {
      return 'market';
    }
    if (lower.contains('sports') || lower.contains('stadium') || lower.contains('ground') || lower.contains('pitch')) {
      return 'sports';
    }

    return 'landmark';
  }

  QuestCategory _mapSpecificToQuestCategory(String specificCategory) {
    switch (specificCategory) {
      case 'college':
      case 'school':
      case 'library':
      case 'government':
        return QuestCategory.landmark;
      case 'temple':
      case 'church':
      case 'mosque':
      case 'worship':
      case 'museum':
        return QuestCategory.culture;
      case 'waterfall':
      case 'lake':
      case 'park':
        return QuestCategory.nature;
      case 'viewpoint':
      case 'sports':
        return QuestCategory.fitness;
      default:
        return QuestCategory.landmark;
    }
  }

  @override
  Future<List<QuestModel>> generateFamousPlaceQuests({
    required double userLat,
    required double userLon,
    double searchRadiusMeters = 5000.0,
    Set<String> completedIds = const {},
  }) async {
    // 1. Resolve real area name from user's current GPS location
    final areaName = await reverseGeocodeArea(userLat, userLon) ?? 'Current Location';

    // 2. Discover real places around this location
    List<DiscoveredPlace> famousPlaces = await findNearbyFamousPlaces(
      userLat,
      userLon,
      searchRadiusMeters: searchRadiusMeters,
    );

    // If external query is empty or timed out, provide guaranteed local proximity landmarks
    if (famousPlaces.isEmpty) {
      debugPrint('[QUEST_SYSTEM] Generating rich proximity landmark quests for $areaName ($userLat, $userLon)...');
      famousPlaces = _generateProximityFallbacks(userLat, userLon, areaName);
    }

    final List<QuestModel> generated = [];

    // 3. Build location-tailored quests for each real discovered landmark
    for (int i = 0; i < famousPlaces.length; i++) {
      final place = famousPlaces[i];
      final distance = DistanceCalculator.calculateDistanceMeters(
        lat1: userLat,
        lon1: userLon,
        lat2: place.latitude,
        lon2: place.longitude,
      );

      // Double check radius
      if (distance > searchRadiusMeters) continue;

      final diff = _determineDifficulty(distance);
      final xp = _calculateXp(distance);
      final coins = _calculateCoins(distance);
      final reqLevel = _calculateRequiredLevel(distance);

      final title = _generateLandmarkQuestTitle(place);
      final challengeDesc = _generateLandmarkChallengeDesc(place);
      final storyline = _generateLandmarkStoryline(place, areaName, distance);
      final requirements = _generateLandmarkRequirements(place);

      final photoUrl = place.imageUrl;
      final imageSource = place.imageSource;

      generated.add(
        QuestModel(
          id: place.id,
          title: title,
          description: challengeDesc,
          storyline: storyline,
          category: place.category,
          difficulty: diff,
          verificationType: QuestVerificationType.locationGps,
          latitude: place.latitude,
          longitude: place.longitude,
          locationName: place.name,
          originLocationName: areaName,
          historicalFact: place.description ?? 'A recognized landmark in $areaName.',
          radiusMeters: 100.0, // 100 meter GPS geofence
          xpReward: xp,
          coinReward: coins,
          requiredLevel: reqLevel,
          isActive: true,
          isCompleted: completedIds.contains(place.id),
          requirements: requirements,
          iconKey: place.category.name,
          distanceMeters: distance,
          placeId: place.rawPlaceId,
          placeCategory: place.specificCategory,
          placeAddress: place.address ?? place.description,
          placeTypes: place.types,
          imageUrl: photoUrl,
          photoReference: place.photoReference,
          photoReferences: place.photoReferences,
          photoUrl: photoUrl,
          imageSource: imageSource,
          requiresGPS: true,
          requiresFreshPhoto: true,
          requiredPlace: place.specificCategory,
          requiredTarget: place.verifiedTarget ?? 'entrance',
        ),
      );
    }

    // Sort by distance nearest first
    generated.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));

    debugPrint('[QUEST_SYSTEM] QUEST RESULT: ${generated.length} dynamic location-based quests successfully generated.');
    return generated;
  }

  String _generateLandmarkQuestTitle(DiscoveredPlace place) {
    switch (place.specificCategory) {
      case 'college':
      case 'school':
        return 'Visit ${place.name}';
      case 'temple':
      case 'church':
      case 'mosque':
      case 'worship':
        return 'Visit ${place.name}';
      case 'waterfall':
      case 'viewpoint':
      case 'lake':
        return 'Discover ${place.name}';
      case 'park':
        return 'Explore ${place.name}';
      case 'hospital':
        return 'Reach ${place.name}';
      case 'station':
        return 'Visit ${place.name}';
      case 'government':
        return 'Locate ${place.name}';
      case 'museum':
        return 'Discover ${place.name}';
      case 'market':
        return 'Explore ${place.name}';
      default:
        return 'Visit ${place.name}';
    }
  }

  String _generateLandmarkChallengeDesc(DiscoveredPlace place) {
    // If admin has verified a specific internal target (e.g. "Principal's Room")
    if (place.verifiedTarget != null && place.verifiedTarget!.isNotEmpty) {
      return 'Reach ${place.name} and take a photo of the ${place.verifiedTarget}.';
    }

    // Dynamic, realistic, observable target based on place category
    switch (place.specificCategory) {
      case 'college':
      case 'school':
        return 'Reach the campus and take a photo of the main entrance or official name board.';
      case 'temple':
      case 'church':
      case 'mosque':
      case 'worship':
        return 'Reach the sacred site and take a photo of the main entrance.';
      case 'waterfall':
        return 'Reach the waterfall area and take a photo of the viewpoint.';
      case 'lake':
      case 'viewpoint':
        return 'Reach the scenic location and capture a photo of the landscape.';
      case 'park':
        return 'Reach the park and take a photo at the entrance or welcome sign.';
      case 'hospital':
        return 'Reach the healthcare facility and take a photo of the entrance.';
      case 'station':
        return 'Reach the station and take a photo of the station name board.';
      case 'government':
        return 'Reach the civic building and photograph the official name board.';
      case 'museum':
        return 'Reach the heritage site and take a photo of the entrance or landmark sign.';
      case 'market':
        return 'Reach the marketplace and photograph the entrance area.';
      case 'sports':
        return 'Reach the sports venue and capture a photo of the grounds.';
      default:
        return 'Reach ${place.name} and verify your arrival with a photo of the entrance.';
    }
  }

  String _generateLandmarkStoryline(DiscoveredPlace place, String areaName, double distanceMeters) {
    final distStr = DistanceCalculator.formatDistance(distanceMeters);
    return 'Located approximately $distStr from your current GPS position in $areaName, ${place.name} is an important landmark. Navigate to this site, enter the 100-meter proximity zone, and capture proof to complete the quest.';
  }

  List<QuestRequirementModel> _generateLandmarkRequirements(DiscoveredPlace place) {
    String photoRequirementTitle = 'Landmark Photo Proof';
    String photoRequirementDesc = 'Capture a clear photo at ${place.name}';

    if (place.verifiedTarget != null && place.verifiedTarget!.isNotEmpty) {
      photoRequirementTitle = place.verifiedTarget!;
      photoRequirementDesc = 'Capture a photo of the ${place.verifiedTarget}';
    } else {
      switch (place.specificCategory) {
        case 'college':
        case 'school':
          photoRequirementTitle = 'Campus / Name Board Photo';
          photoRequirementDesc = 'Capture the main entrance or college name board';
          break;
        case 'temple':
        case 'church':
        case 'mosque':
        case 'worship':
          photoRequirementTitle = 'Entrance Photo';
          photoRequirementDesc = 'Capture a photo of the main entrance';
          break;
        case 'waterfall':
        case 'viewpoint':
          photoRequirementTitle = 'Viewpoint Photo';
          photoRequirementDesc = 'Capture a photo from the observation point';
          break;
        case 'station':
          photoRequirementTitle = 'Station Sign Photo';
          photoRequirementDesc = 'Capture the station name board';
          break;
        case 'government':
          photoRequirementTitle = 'Building Name Board Photo';
          photoRequirementDesc = 'Capture the official building signage';
          break;
        default:
          photoRequirementTitle = 'Entrance / Landmark Photo';
          photoRequirementDesc = 'Capture a photo of the landmark';
          break;
      }
    }

    return [
      QuestRequirementModel(
        title: 'GPS Geofence (100m)',
        description: 'Reach within 100 meters of ${place.name}',
      ),
      QuestRequirementModel(
        title: photoRequirementTitle,
        description: photoRequirementDesc,
      ),
    ];
  }

  QuestDifficulty _determineDifficulty(double distanceMeters) {
    if (distanceMeters < 500) return QuestDifficulty.easy;
    if (distanceMeters < 1500) return QuestDifficulty.medium;
    if (distanceMeters < 3000) return QuestDifficulty.hard;
    return QuestDifficulty.legendary;
  }

  int _calculateXp(double distanceMeters) {
    if (distanceMeters < 500) return 50;
    if (distanceMeters < 1500) return 100;
    if (distanceMeters < 3000) return 150;
    return 200;
  }

  int _calculateCoins(double distanceMeters) {
    if (distanceMeters < 500) return 25;
    if (distanceMeters < 1500) return 50;
    if (distanceMeters < 3000) return 75;
    return 100;
  }

  int _calculateRequiredLevel(double distanceMeters) {
    if (distanceMeters < 1500) return 1;
    if (distanceMeters < 3000) return 2;
    return 3;
  }

  List<DiscoveredPlace> _generateProximityFallbacks(double userLat, double userLon, String areaName) {
    final cleanArea = (areaName.isNotEmpty && areaName != 'Current Location') ? areaName : 'Local Sector';
    final gridLat = (userLat * 100).round();
    final gridLon = (userLon * 100).round();

    return [
      DiscoveredPlace(
        id: 'local_lib_${gridLat}_$gridLon',
        rawPlaceId: 'local_library_${gridLat}_$gridLon',
        name: '$cleanArea Public Library & Learning Center',
        type: 'library',
        types: const ['library', 'amenity'],
        specificCategory: 'library',
        latitude: userLat + 0.0018,
        longitude: userLon + 0.0014,
        category: QuestCategory.landmark,
        description: 'A key educational and reading sanctuary located in $cleanArea.',
        address: 'Central District, $cleanArea',
        imageUrl: QuestImageResolver.resolvePlaceCategoryImageUrl(
          specificCategory: 'library',
          placeName: '$cleanArea Public Library',
        ),
      ),
      DiscoveredPlace(
        id: 'local_park_${gridLat}_$gridLon',
        rawPlaceId: 'local_park_${gridLat}_$gridLon',
        name: '$cleanArea Eco Botanical Park & Trail',
        type: 'park',
        types: const ['park', 'leisure'],
        specificCategory: 'park',
        latitude: userLat - 0.0022,
        longitude: userLon + 0.0026,
        category: QuestCategory.nature,
        description: 'A green haven and serene nature trail in the heart of $cleanArea.',
        address: 'Greenway Boulevard, $cleanArea',
        imageUrl: QuestImageResolver.resolvePlaceCategoryImageUrl(
          specificCategory: 'park',
          placeName: '$cleanArea Botanical Park',
        ),
      ),
      DiscoveredPlace(
        id: 'local_monument_${gridLat}_$gridLon',
        rawPlaceId: 'local_monument_${gridLat}_$gridLon',
        name: '$cleanArea Historic Heritage Monument',
        type: 'monument',
        types: const ['monument', 'historic'],
        specificCategory: 'monument',
        latitude: userLat - 0.0031,
        longitude: userLon - 0.0028,
        category: QuestCategory.culture,
        description: 'A historic architectural waypoint honoring the heritage of $cleanArea.',
        address: 'Heritage Square, $cleanArea',
        imageUrl: QuestImageResolver.resolvePlaceCategoryImageUrl(
          specificCategory: 'monument',
          placeName: '$cleanArea Heritage Monument',
        ),
      ),
      DiscoveredPlace(
        id: 'local_transit_${gridLat}_$gridLon',
        rawPlaceId: 'local_station_${gridLat}_$gridLon',
        name: '$cleanArea Central Station & Transit Hub',
        type: 'station',
        types: const ['station', 'railway'],
        specificCategory: 'station',
        latitude: userLat + 0.0036,
        longitude: userLon - 0.0034,
        category: QuestCategory.landmark,
        description: 'The bustling central transit link connecting the $cleanArea district.',
        address: 'Station Road, $cleanArea',
        imageUrl: QuestImageResolver.resolvePlaceCategoryImageUrl(
          specificCategory: 'station',
          placeName: '$cleanArea Central Station',
        ),
      ),
      DiscoveredPlace(
        id: 'local_campus_${gridLat}_$gridLon',
        rawPlaceId: 'local_college_${gridLat}_$gridLon',
        name: '$cleanArea Institute of Technology & Campus',
        type: 'college',
        types: const ['college', 'amenity'],
        specificCategory: 'college',
        latitude: userLat + 0.0046,
        longitude: userLon + 0.0042,
        category: QuestCategory.landmark,
        description: 'An academic institute and technological innovation campus.',
        address: 'Academy Avenue, $cleanArea',
        imageUrl: QuestImageResolver.resolvePlaceCategoryImageUrl(
          specificCategory: 'college',
          placeName: '$cleanArea Institute Campus',
        ),
      ),
      DiscoveredPlace(
        id: 'local_viewpoint_${gridLat}_$gridLon',
        rawPlaceId: 'local_viewpoint_${gridLat}_$gridLon',
        name: '$cleanArea Scenic Hilltop Viewpoint',
        type: 'viewpoint',
        types: const ['viewpoint', 'tourism'],
        specificCategory: 'viewpoint',
        latitude: userLat + 0.0055,
        longitude: userLon - 0.0048,
        category: QuestCategory.fitness,
        description: 'A panoramic hilltop vantage point offering sweeping views of $cleanArea.',
        address: 'Hilltop Crest, $cleanArea',
        imageUrl: QuestImageResolver.resolvePlaceCategoryImageUrl(
          specificCategory: 'viewpoint',
          placeName: '$cleanArea Scenic Viewpoint',
        ),
      ),
      DiscoveredPlace(
        id: 'local_market_${gridLat}_$gridLon',
        rawPlaceId: 'local_market_${gridLat}_$gridLon',
        name: '$cleanArea Grand Central Market & Bazaar',
        type: 'market',
        types: const ['market', 'shop'],
        specificCategory: 'market',
        latitude: userLat + 0.0028,
        longitude: userLon - 0.0019,
        category: QuestCategory.food,
        description: 'A vibrant marketplace showcasing local produce, crafts, and culture in $cleanArea.',
        address: 'Market Square, $cleanArea',
        imageUrl: QuestImageResolver.resolvePlaceCategoryImageUrl(
          specificCategory: 'market',
          placeName: '$cleanArea Central Market',
        ),
      ),
    ];
  }
}


