import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../errors/exceptions.dart';

abstract class ILocalStorageService {
  Future<void> saveString(String key, String value);
  Future<String?> getString(String key);
  Future<void> saveJson(String key, dynamic value);
  Future<dynamic> getJson(String key);
  Future<void> remove(String key);
  Future<void> clear();
}

class LocalStorageService implements ILocalStorageService {
  SharedPreferences? _prefs;
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, String> _stringCache = {};

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<void> saveString(String key, String value) async {
    _stringCache[key] = value;
    try {
      final prefs = await _getPrefs();
      await prefs.setString(key, value);
    } catch (e) {
      throw StorageException('Failed to save string: $e');
    }
  }

  @override
  Future<String?> getString(String key) async {
    if (_stringCache.containsKey(key)) {
      return _stringCache[key];
    }
    try {
      final prefs = await _getPrefs();
      final value = prefs.getString(key);
      if (value != null) {
        _stringCache[key] = value;
      }
      return value;
    } catch (e) {
      throw StorageException('Failed to get string: $e');
    }
  }

  @override
  Future<void> saveJson(String key, dynamic value) async {
    _memoryCache[key] = value;
    try {
      final prefs = await _getPrefs();
      final jsonString = jsonEncode(value);
      _stringCache[key] = jsonString;
      await prefs.setString(key, jsonString);
    } catch (e) {
      throw StorageException('Failed to save JSON: $e');
    }
  }

  @override
  Future<dynamic> getJson(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    try {
      final prefs = await _getPrefs();
      final jsonString = prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) return null;
      _stringCache[key] = jsonString;
      final decoded = jsonDecode(jsonString);
      _memoryCache[key] = decoded;
      return decoded;
    } catch (e) {
      throw StorageException('Failed to get JSON: $e');
    }
  }

  @override
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    _stringCache.remove(key);
    try {
      final prefs = await _getPrefs();
      await prefs.remove(key);
    } catch (e) {
      throw StorageException('Failed to remove key: $e');
    }
  }

  @override
  Future<void> clear() async {
    _memoryCache.clear();
    _stringCache.clear();
    try {
      final prefs = await _getPrefs();
      await prefs.clear();
    } catch (e) {
      throw StorageException('Failed to clear storage: $e');
    }
  }
}
