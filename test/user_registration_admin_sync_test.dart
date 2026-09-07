import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/core/errors/exceptions.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:quest_up/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:quest_up/features/auth/domain/usecases/register_usecase.dart';

class MockMemoryStorage implements ILocalStorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<dynamic> getJson(String key) async => _data[key];

  @override
  Future<String?> getString(String key) async => _data[key] as String?;

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Future<void> saveJson(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> saveString(String key, String value) async => _data[key] = value;
}

void main() {
  group('User Registration and Cloud/Admin Sync Tests', () {
    late MockMemoryStorage storage;
    late AuthMySqlDataSource dataSource;
    late AuthRepositoryImpl repository;
    late RegisterUseCase registerUseCase;

    setUp(() {
      storage = MockMemoryStorage();
      dataSource = AuthMySqlDataSource(storage);
      repository = AuthRepositoryImpl(remoteDataSource: dataSource);
      registerUseCase = RegisterUseCase(repository);
    });

    test('User registration persists account in local users and generates credentials', () async {
      const email = 'hero.explorer@questup.app';
      const name = 'Hero Explorer';
      const password = 'SuperSecretPassword123!';

      final user = await registerUseCase(
        name: name,
        email: email,
        password: password,
      );

      expect(user.id, isNotEmpty);
      expect(user.email, email);
      expect(user.displayName, name);

      // Verify stored in local users map for background sync
      final localUsers = await storage.getJson(AppConstants.keyLocalUsers);
      expect(localUsers, isNotNull);
      expect(localUsers is Map, isTrue);
      expect(localUsers[email], isNotNull);
      expect(localUsers[email]['id'], user.id);
      expect(localUsers[email]['name'], name);
      expect(localUsers[email]['password_hash'], isNotEmpty);
      expect(localUsers[email]['salt'], isNotEmpty);

      // Verify active session was saved
      final session = await storage.getJson(AppConstants.keyAuthSession);
      expect(session, isNotNull);
      expect(session['email'], email);
      expect(session['id'], user.id);
    });

    test('Duplicate email registration is properly rejected', () async {
      const email = 'duplicate@questup.app';
      await registerUseCase(name: 'User 1', email: email, password: 'password123');

      expect(
        () => registerUseCase(name: 'User 2', email: email, password: 'password123'),
        throwsA(isA<AppException>()),
      );
    });

    test('Multiple registered users all exist in local users store for admin sync', () async {
      for (int i = 1; i <= 5; i++) {
        await registerUseCase(
          name: 'Explorer $i',
          email: 'explorer_$i@questup.app',
          password: 'password123',
        );
      }

      final localUsers = await storage.getJson(AppConstants.keyLocalUsers) as Map<String, dynamic>;
      expect(localUsers.length, 5);

      for (int i = 1; i <= 5; i++) {
        expect(localUsers.containsKey('explorer_$i@questup.app'), isTrue);
      }
    });
  });
}
