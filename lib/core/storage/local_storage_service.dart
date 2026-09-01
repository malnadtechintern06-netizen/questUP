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

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<void> saveString(String key, String value) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(key, value);
    } catch (e) {
      throw StorageException('Failed to save string: $e');
    }
  }

  @override
  Future<String?> getString(String key) async {
    try {
      final prefs = await _getPrefs();
      return prefs.getString(key);
    } catch (e) {
      throw StorageException('Failed to get string: $e');
    }
  }

  @override
  Future<void> saveJson(String key, dynamic value) async {
    try {
      final prefs = await _getPrefs();
      final jsonString = jsonEncode(value);
      await prefs.setString(key, jsonString);
    } catch (e) {
      throw StorageException('Failed to save JSON: $e');
    }
  }

  @override
  Future<dynamic> getJson(String key) async {
    try {
      final prefs = await _getPrefs();
      final jsonString = prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) return null;
      return jsonDecode(jsonString);
    } catch (e) {
      throw StorageException('Failed to get JSON: $e');
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(key);
    } catch (e) {
      throw StorageException('Failed to remove key: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await _getPrefs();
      await prefs.clear();
    } catch (e) {
      throw StorageException('Failed to clear storage: $e');
    }
  }
}
