import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';

class QuestImageResolver {
  // Curated High-Resolution Real-World Landmark & Category Photography
  static const String _collegeImage =
      'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=800&q=80';
  static const String _schoolImage =
      'https://images.unsplash.com/photo-1580582932707-520aed937b7b?auto=format&fit=crop&w=800&q=80';
  static const String _templeImage =
      'https://images.unsplash.com/photo-1599818985160-5a3d76e82a47?auto=format&fit=crop&w=800&q=80';
  static const String _churchImage =
      'https://images.unsplash.com/photo-1548625361-195fe57e1d52?auto=format&fit=crop&w=800&q=80';
  static const String _mosqueImage =
      'https://images.unsplash.com/photo-1564769625905-50e93615e769?auto=format&fit=crop&w=800&q=80';
  static const String _worshipImage =
      'https://images.unsplash.com/photo-1561361066-66236b2fd534?auto=format&fit=crop&w=800&q=80';
  static const String _waterfallImage =
      'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?auto=format&fit=crop&w=800&q=80';
  static const String _lakeImage =
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=800&q=80';
  static const String _hillImage =
      'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=800&q=80';
  static const String _parkImage =
      'https://images.unsplash.com/photo-1519331379826-f10be5486c6f?auto=format&fit=crop&w=800&q=80';
  static const String _gardenImage =
      'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?auto=format&fit=crop&w=800&q=80';
  static const String _farmImage =
      'https://images.unsplash.com/photo-1500595046743-cd271d694d30?auto=format&fit=crop&w=800&q=80';
  static const String _monumentImage =
      'https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?auto=format&fit=crop&w=800&q=80';
  static const String _museumImage =
      'https://images.unsplash.com/photo-1565034946487-077786996e27?auto=format&fit=crop&w=800&q=80';
  static const String _marketImage =
      'https://images.unsplash.com/photo-1533900298318-6b8da08a523e?auto=format&fit=crop&w=800&q=80';
  static const String _libraryImage =
      'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=800&q=80';
  static const String _hospitalImage =
      'https://images.unsplash.com/photo-1587351021759-3e566b6af7cc?auto=format&fit=crop&w=800&q=80';
  static const String _stationImage =
      'https://images.unsplash.com/photo-1474487548417-781cb71495f3?auto=format&fit=crop&w=800&q=80';

  // Activity & Object Specific Photography
  static const String _flowerImage =
      'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80';
  static const String _treeImage =
      'https://images.unsplash.com/photo-1502082553048-f009c37129b9?auto=format&fit=crop&w=800&q=80';
  static const String _cowImage =
      'https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?auto=format&fit=crop&w=800&q=80';
  static const String _appleImage =
      'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=800&q=80';
  static const String _mealImage =
      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80';
  static const String _bookImage =
      'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&w=800&q=80';
  static const String _bicycleImage =
      'https://images.unsplash.com/photo-1485965120184-e220f721d03e?auto=format&fit=crop&w=800&q=80';
  static const String _walkingTrailImage =
      'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?auto=format&fit=crop&w=800&q=80';
  static const String _writingJournalImage =
      'https://images.unsplash.com/photo-1455390582262-044cdead277a?auto=format&fit=crop&w=800&q=80';
  static const String _drawingCanvasImage =
      'https://images.unsplash.com/photo-1513364776144-60967b0f800f?auto=format&fit=crop&w=800&q=80';
  static const String _exerciseWorkoutImage =
      'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&w=800&q=80';
  static const String _gamingPuzzleImage =
      'https://images.unsplash.com/photo-1612287233202-09419b48c414?auto=format&fit=crop&w=800&q=80';
  static const String _natureWildernessImage =
      'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=800&q=80';
  static const String _defaultExplorationImage =
      'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=800&q=80';

  /// Builds official Google Places Photo API URL.
  static String buildGooglePhotoUrl(String photoReference, {int maxWidth = 800}) {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&photo_reference=$photoReference&key=${AppConstants.googleMapsApiKey}';
  }

  /// Resolves the optimal photo URL for any given Quest.
  static String resolveQuestImageUrl(Quest quest) {
    // 1. Exact Google Places Photo (highest priority)
    if (quest.photoUrl != null &&
        quest.photoUrl!.trim().isNotEmpty &&
        (quest.imageSource.toUpperCase() == 'GOOGLE_PLACES' || quest.isGooglePlacesPhoto) &&
        !quest.photoUrl!.contains('hero_poster') &&
        !quest.photoUrl!.contains('logo.png')) {
      return quest.photoUrl!.trim();
    }

    // 2. Google Places Photo Reference
    if (quest.photoReference != null &&
        quest.photoReference!.trim().isNotEmpty &&
        AppConstants.googleMapsApiKey.isNotEmpty) {
      return buildGooglePhotoUrl(quest.photoReference!);
    }

    // 3. Fallback to first photo in photoReferences list if available
    if (quest.photoReferences.isNotEmpty && AppConstants.googleMapsApiKey.isNotEmpty) {
      return buildGooglePhotoUrl(quest.photoReferences.first);
    }

    // 4. Explicit direct image URL on the Quest
    if (quest.imageUrl != null &&
        quest.imageUrl!.trim().isNotEmpty &&
        !quest.imageUrl!.contains('hero_poster') &&
        !quest.imageUrl!.contains('logo.png')) {
      return quest.imageUrl!.trim();
    }

    // 5. Object-Specific Imagery
    if (quest.hasObjectDetection) {
      final obj = quest.requiredObject!.trim().toLowerCase();
      final objImg = _resolveObjectImage(obj);
      if (objImg != null) return objImg;
    }

    // 6. Place Category / Landmark Name Match
    final placeImg = resolvePlaceCategoryImageUrl(
      specificCategory: quest.placeCategory ?? quest.requiredPlace,
      placeName: quest.locationName,
      questTitle: quest.title,
    );
    if (placeImg != null) return placeImg;

    // 7. Quest Activity Category Fallback
    return resolveCategoryFallback(quest.category);
  }

  /// Resolves image based on object name.
  static String? _resolveObjectImage(String objectName) {
    final lower = objectName.toLowerCase();
    if (lower.contains('flower') || lower.contains('rose') || lower.contains('flora')) {
      return _flowerImage;
    }
    if (lower.contains('tree') || lower.contains('plant') || lower.contains('forest')) {
      return _treeImage;
    }
    if (lower.contains('cow') || lower.contains('cattle') || lower.contains('bull') || lower.contains('animal')) {
      return _cowImage;
    }
    if (lower.contains('apple') || lower.contains('fruit')) {
      return _appleImage;
    }
    if (lower.contains('meal') || lower.contains('food') || lower.contains('breakfast') || lower.contains('dinner')) {
      return _mealImage;
    }
    if (lower.contains('book') || lower.contains('novel') || lower.contains('study')) {
      return _bookImage;
    }
    if (lower.contains('bicycle') || lower.contains('cycle') || lower.contains('bike')) {
      return _bicycleImage;
    }
    return null;
  }

  /// Resolves image based on place category or landmark keywords.
  static String? resolvePlaceCategoryImageUrl({
    String? specificCategory,
    String? placeName,
    String? questTitle,
  }) {
    final combined = '${specificCategory ?? ''} ${placeName ?? ''} ${questTitle ?? ''}'.toLowerCase();

    if (combined.contains('college') || combined.contains('university') || combined.contains('campus') || combined.contains('institute')) {
      return _collegeImage;
    }
    if (combined.contains('school') || combined.contains('vidyalaya') || combined.contains('academy')) {
      return _schoolImage;
    }
    if (combined.contains('temple') || combined.contains('mandir') || combined.contains('devasthana') || combined.contains('kovil') || combined.contains('gudi')) {
      return _templeImage;
    }
    if (combined.contains('church') || combined.contains('cathedral') || combined.contains('chapel')) {
      return _churchImage;
    }
    if (combined.contains('mosque') || combined.contains('masjid') || combined.contains('dargah')) {
      return _mosqueImage;
    }
    if (combined.contains('worship') || combined.contains('shrine') || combined.contains('gurdwara')) {
      return _worshipImage;
    }
    if (combined.contains('waterfall') || combined.contains('falls') || combined.contains('jalapatha') || combined.contains('cascade')) {
      return _waterfallImage;
    }
    if (combined.contains('lake') || combined.contains('river') || combined.contains('dam') || combined.contains('reservoir') || combined.contains('kare')) {
      return _lakeImage;
    }
    if (combined.contains('hill') || combined.contains('mountain') || combined.contains('peak') || combined.contains('viewpoint') || combined.contains('betta') || combined.contains('ghat')) {
      return _hillImage;
    }
    if (combined.contains('garden') || combined.contains('botanical')) {
      return _gardenImage;
    }
    if (combined.contains('park') || combined.contains('reserve') || combined.contains('sanctuary')) {
      return _parkImage;
    }
    if (combined.contains('farm') || combined.contains('pasture') || combined.contains('rural') || combined.contains('agriculture')) {
      return _farmImage;
    }
    if (combined.contains('hospital') || combined.contains('clinic') || combined.contains('medical') || combined.contains('health')) {
      return _hospitalImage;
    }
    if (combined.contains('museum') || combined.contains('gallery')) {
      return _museumImage;
    }
    if (combined.contains('heritage') || combined.contains('fort') || combined.contains('palace') || combined.contains('monument') || combined.contains('memorial')) {
      return _monumentImage;
    }
    if (combined.contains('market') || combined.contains('mall') || combined.contains('bazaar') || combined.contains('supermarket')) {
      return _marketImage;
    }
    if (combined.contains('library') || combined.contains('pustakalaya')) {
      return _libraryImage;
    }
    if (combined.contains('station') || combined.contains('railway') || combined.contains('bus')) {
      return _stationImage;
    }

    return null;
  }

  /// Fallback image based on QuestCategory.
  static String resolveCategoryFallback(QuestCategory category) {
    switch (category) {
      case QuestCategory.reading:
        return _bookImage;
      case QuestCategory.writing:
        return _writingJournalImage;
      case QuestCategory.drawing:
        return _drawingCanvasImage;
      case QuestCategory.exercise:
      case QuestCategory.fitness:
        return _exerciseWorkoutImage;
      case QuestCategory.walking:
        return _walkingTrailImage;
      case QuestCategory.food:
        return _mealImage;
      case QuestCategory.gaming:
        return _gamingPuzzleImage;
      case QuestCategory.nature:
        return _natureWildernessImage;
      case QuestCategory.study:
        return _bookImage;
      case QuestCategory.photo:
      case QuestCategory.observation:
        return _natureWildernessImage;
      case QuestCategory.culture:
        return _templeImage;
      case QuestCategory.landmark:
      case QuestCategory.location:
      case QuestCategory.mystery:
      case QuestCategory.video:
      case QuestCategory.timed:
      case QuestCategory.custom:
        return _defaultExplorationImage;
    }
  }
}
