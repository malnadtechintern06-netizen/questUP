import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:quest_up/app/config/app_constants.dart';

abstract class IGooglePlacePhotoService {
  String? buildPhotoUrl(String photoReference, {int maxWidth = 800});
  Future<List<String>> fetchPlacePhotos(String placeId);
  Future<String?> getPlacePhotoUrl(String placeId, {String? defaultPhotoReference});
  Future<String?> fetchRealLocationPhoto({
    required String placeName,
    required double latitude,
    required double longitude,
    String? areaName,
  });
}

class GooglePlacePhotoService implements IGooglePlacePhotoService {
  static final GooglePlacePhotoService _instance = GooglePlacePhotoService._internal();
  factory GooglePlacePhotoService() => _instance;
  GooglePlacePhotoService._internal() : _httpClient = HttpClient();

  @visibleForTesting
  GooglePlacePhotoService.withClient(this._httpClient);

  final HttpClient _httpClient;
  final Map<String, String> _photoUrlCache = {}; // placeId_photoRef -> URL
  final Map<String, List<String>> _placePhotosCache = {}; // placeId -> List<photo_reference>

  @override
  String? buildPhotoUrl(String photoReference, {int maxWidth = 800}) {
    if (photoReference.trim().isEmpty || AppConstants.googleMapsApiKey.isEmpty) {
      return null;
    }
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&photo_reference=$photoReference&key=${AppConstants.googleMapsApiKey}';
  }

  @override
  Future<List<String>> fetchPlacePhotos(String placeId) async {
    if (placeId.isEmpty || AppConstants.googleMapsApiKey.isEmpty) {
      return [];
    }

    if (_placePhotosCache.containsKey(placeId)) {
      return _placePhotosCache[placeId]!;
    }

    try {
      final detailsUri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=photos,name,formatted_address&key=${AppConstants.googleMapsApiKey}',
      );
      final request = await _httpClient.getUrl(detailsUri);
      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final photos = json['result']?['photos'] as List<dynamic>? ?? [];
        final photoRefs = photos
            .map((p) => p['photo_reference']?.toString())
            .whereType<String>()
            .toList();

        _placePhotosCache[placeId] = photoRefs;
        return photoRefs;
      }
    } catch (e) {
      debugPrint('[GOOGLE_PLACE_PHOTO_SERVICE] Notice for $placeId: $e');
    }
    return [];
  }

  @override
  Future<String?> getPlacePhotoUrl(String placeId, {String? defaultPhotoReference}) async {
    // 1. If explicit photo reference provided, build and cache URL directly
    if (defaultPhotoReference != null && defaultPhotoReference.isNotEmpty) {
      final cacheKey = '${placeId}_$defaultPhotoReference';
      if (_photoUrlCache.containsKey(cacheKey)) {
        return _photoUrlCache[cacheKey];
      }
      final url = buildPhotoUrl(defaultPhotoReference);
      if (url != null) {
        _photoUrlCache[cacheKey] = url;
        return url;
      }
    }

    // 2. Otherwise query Place Details for this exact Place ID
    final photos = await fetchPlacePhotos(placeId);
    if (photos.isNotEmpty) {
      final primaryRef = photos.first;
      final cacheKey = '${placeId}_$primaryRef';
      final url = buildPhotoUrl(primaryRef);
      if (url != null) {
        _photoUrlCache[cacheKey] = url;
        return url;
      }
    }

    return null;
  }

  @override
  Future<String?> fetchRealLocationPhoto({
    required String placeName,
    required double latitude,
    required double longitude,
    String? areaName,
  }) async {
    final cacheKey = 'real_photo_${latitude.toStringAsFixed(3)}_${longitude.toStringAsFixed(3)}_$placeName';
    if (_photoUrlCache.containsKey(cacheKey)) {
      return _photoUrlCache[cacheKey];
    }

    // 1. Try Wikipedia PageImages API with specific place name
    try {
      final wikiUri = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&titles=${Uri.encodeComponent(placeName)}&prop=pageimages&format=json&pithumbsize=800',
      );
      final request = await _httpClient.getUrl(wikiUri);
      request.headers.set('User-Agent', 'QuestUP-AdventureApp/1.0 (Mobile Exploration)');
      final response = await request.close().timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final pages = json['query']?['pages'] as Map<String, dynamic>? ?? {};
        for (final entry in pages.values) {
          final source = entry['thumbnail']?['source'] as String?;
          if (source != null && source.startsWith('http')) {
            _photoUrlCache[cacheKey] = source;
            return source;
          }
        }
      }
    } catch (_) {}

    // 2. Try Wikimedia Commons GeoSearch API by exact GPS coordinates
    try {
      final geoUri = Uri.parse(
        'https://commons.wikimedia.org/w/api.php?action=query&generator=geosearch&ggscoord=$latitude|$longitude&ggsradius=5000&ggslimit=3&prop=imageinfo&iiprop=url&iiurlwidth=800&format=json',
      );
      final request = await _httpClient.getUrl(geoUri);
      request.headers.set('User-Agent', 'QuestUP-AdventureApp/1.0 (Mobile Exploration)');
      final response = await request.close().timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final pages = json['query']?['pages'] as Map<String, dynamic>? ?? {};
        for (final entry in pages.values) {
          final imageinfo = entry['imageinfo'] as List<dynamic>?;
          if (imageinfo != null && imageinfo.isNotEmpty) {
            final thumbUrl = imageinfo.first['thumburl'] as String? ?? imageinfo.first['url'] as String?;
            if (thumbUrl != null && thumbUrl.startsWith('http')) {
              _photoUrlCache[cacheKey] = thumbUrl;
              return thumbUrl;
            }
          }
        }
      }
    } catch (_) {}

    // 3. Try Wikipedia PageImages API with Area Name (e.g. Hosanagara)
    if (areaName != null && areaName.trim().isNotEmpty) {
      try {
        final wikiAreaUri = Uri.parse(
          'https://en.wikipedia.org/w/api.php?action=query&titles=${Uri.encodeComponent(areaName)}&prop=pageimages&format=json&pithumbsize=800',
        );
        final request = await _httpClient.getUrl(wikiAreaUri);
        request.headers.set('User-Agent', 'QuestUP-AdventureApp/1.0 (Mobile Exploration)');
        final response = await request.close().timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          final pages = json['query']?['pages'] as Map<String, dynamic>? ?? {};
          for (final entry in pages.values) {
            final source = entry['thumbnail']?['source'] as String?;
            if (source != null && source.startsWith('http')) {
              _photoUrlCache[cacheKey] = source;
              return source;
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }
}
