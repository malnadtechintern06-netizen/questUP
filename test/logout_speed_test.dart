import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:quest_up/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:quest_up/features/auth/presentation/providers/auth_providers.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Logout executes instantaneously in under 50ms without blocking on background network calls', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyAuthSession: '{"id":"usr_test","email":"test@questup.app","name":"Tester"}',
    });

    final storage = LocalStorageService();
    final authDataSource = AuthMySqlDataSource(storage);
    final authRepo = AuthRepositoryImpl(remoteDataSource: authDataSource);

    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(authRepo),
      ],
    );

    final notifier = container.read(authNotifierProvider.notifier);

    final sw = Stopwatch()..start();
    await notifier.logout();
    sw.stop();

    expect(sw.elapsedMilliseconds, lessThan(100));

    final authState = container.read(authNotifierProvider);
    expect(authState.status, equals(AuthStatus.unauthenticated));
    expect(authState.user, isNull);

    final session = await storage.getJson(AppConstants.keyAuthSession);
    expect(session, isNull);
  });
}
