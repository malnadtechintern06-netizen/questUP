import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/core/errors/exceptions.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/auth/data/models/auth_user_model.dart';

abstract class IAuthRemoteDataSource {
  Future<AuthUserModel> login({
    required String email,
    required String password,
  });

  Future<AuthUserModel> register({
    required String name,
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<void> sendPasswordReset(String email);

  Stream<AuthUserModel?> get authStateChanges;

  Future<AuthUserModel?> getCurrentUser();
}

class AuthFirebaseDataSource implements IAuthRemoteDataSource {
  final ILocalStorageService _storage;
  final StreamController<AuthUserModel?> _localAuthStreamController =
      StreamController<AuthUserModel?>.broadcast();

  AuthFirebaseDataSource(this._storage);

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  fb.FirebaseAuth get _firebaseAuth {
    if (!_isFirebaseReady) {
      throw const AppException(
        'Firebase is not yet configured. Please add google-services.json to android/app or run "flutterfire configure".',
      );
    }
    return fb.FirebaseAuth.instance;
  }

  @override
  Stream<AuthUserModel?> get authStateChanges {
    if (_isFirebaseReady) {
      return fb.FirebaseAuth.instance.authStateChanges().map((user) {
        if (user == null) return null;
        return AuthUserModel.fromFirebaseUser(user);
      });
    }

    // Local stream fallback for initial session preservation
    return _localAuthStreamController.stream;
  }

  @override
  Future<AuthUserModel?> getCurrentUser() async {
    if (_isFirebaseReady) {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user != null) {
        final model = AuthUserModel.fromFirebaseUser(user);
        await _storage.saveJson(AppConstants.keyAuthSession, model.toJson());
        return model;
      }
    }

    // Check cached session (fallback for mock mode or offline startup)
    final cached = await _storage.getJson(AppConstants.keyAuthSession);
    if (cached != null && cached is Map<String, dynamic>) {
      final model = AuthUserModel.fromJson(cached);
      _localAuthStreamController.add(model);
      return model;
    }

    return null;
  }

  @override
  Future<AuthUserModel> login({
    required String email,
    required String password,
  }) async {
    if (_isFirebaseReady) {
      try {
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        final user = credential.user;
        if (user == null) {
          throw const AppException('Failed to retrieve logged in user.');
        }

        final model = AuthUserModel.fromFirebaseUser(user);
        await _storage.saveJson(AppConstants.keyAuthSession, model.toJson());
        return model;
      } on fb.FirebaseAuthException catch (e) {
        throw _handleFirebaseAuthException(e);
      } catch (e) {
        if (e is AppException) rethrow;
        throw AppException('Login failed: $e');
      }
    }

    // Development fallback when testing before google-services.json is attached
    debugPrint('Firebase not connected yet. Simulating authentic login for: $email');
    final mockUser = AuthUserModel(
      id: 'usr_${email.hashCode}',
      email: email.trim(),
      displayName: email.split('@').first,
      isEmailVerified: true,
      createdAt: DateTime.now(),
    );

    await _storage.saveJson(AppConstants.keyAuthSession, mockUser.toJson());
    _localAuthStreamController.add(mockUser);
    return mockUser;
  }

  @override
  Future<AuthUserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_isFirebaseReady) {
      try {
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        final user = credential.user;
        if (user == null) {
          throw const AppException('Failed to create user account.');
        }

        // Update display name
        await user.updateDisplayName(name.trim());
        await user.reload();

        final updatedUser = _firebaseAuth.currentUser ?? user;
        final model = AuthUserModel.fromFirebaseUser(updatedUser);
        await _storage.saveJson(AppConstants.keyAuthSession, model.toJson());
        return model;
      } on fb.FirebaseAuthException catch (e) {
        throw _handleFirebaseAuthException(e);
      } catch (e) {
        if (e is AppException) rethrow;
        throw AppException('Registration failed: $e');
      }
    }

    // Development fallback when testing before google-services.json is attached
    debugPrint('Firebase not connected yet. Simulating authentic registration for: $name ($email)');
    final mockUser = AuthUserModel(
      id: 'usr_${email.hashCode}',
      email: email.trim(),
      displayName: name.trim(),
      isEmailVerified: false,
      createdAt: DateTime.now(),
    );

    await _storage.saveJson(AppConstants.keyAuthSession, mockUser.toJson());
    _localAuthStreamController.add(mockUser);
    return mockUser;
  }

  @override
  Future<void> logout() async {
    try {
      if (_isFirebaseReady) {
        await _firebaseAuth.signOut();
      }
    } catch (e) {
      debugPrint('Logout notice: $e');
    } finally {
      await _storage.remove(AppConstants.keyAuthSession);
      _localAuthStreamController.add(null);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (_isFirebaseReady) {
      try {
        await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
        return;
      } on fb.FirebaseAuthException catch (e) {
        throw _handleFirebaseAuthException(e);
      } catch (e) {
        throw AppException('Password reset failed: $e');
      }
    }

    debugPrint('Mock password reset sent to $email');
  }

  AppException _handleFirebaseAuthException(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const AppException('No explorer account found with this email address.');
      case 'wrong-password':
      case 'invalid-credential':
        return const AppException('Incorrect email or password. Please try again.');
      case 'email-already-in-use':
        return const AppException('An account is already registered with this email.');
      case 'invalid-email':
        return const AppException('Please enter a valid email address.');
      case 'weak-password':
        return const AppException('Password should be at least 6 characters.');
      case 'network-request-failed':
        return const AppException('Network error. Please check your internet connection.');
      case 'too-many-requests':
        return const AppException('Too many failed attempts. Please try again later.');
      default:
        return AppException(e.message ?? 'Authentication error occurred (${e.code}).');
    }
  }
}
