import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/app/config/email_config.dart';
import 'package:quest_up/core/errors/exceptions.dart';
import 'package:quest_up/core/services/email_service.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:quest_up/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:quest_up/features/auth/domain/usecases/initiate_login_otp_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/resend_login_otp_usecase.dart';
import 'package:quest_up/features/auth/domain/usecases/verify_login_otp_usecase.dart';

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
  group('EmailConfig & EmailService Tests', () {
    test('EmailConfig default parameters are configured properly', () {
      final config = EmailConfig.defaults();
      expect(config.host, isNotEmpty);
      expect(config.port, 587);
      expect(config.fromName, 'QuestUP Security');
      expect(config.enableBackendApi, isTrue);
      expect(config.isConfigured, isTrue);
    });

    test('EmailService dispatches/logs OTP and caches last dispatched OTP', () async {
      final service = EmailService();
      const testEmail = 'test.explorer@questup.app';
      const testOtp = '849201';

      final sent = await service.sendOtpEmail(
        recipientEmail: testEmail,
        otpCode: testOtp,
        userName: 'Explorer Prime',
      );
      expect(sent, isTrue);

      final cachedOtp = service.getLastDispatchedOtp(testEmail);
      expect(cachedOtp, equals(testOtp));
    });
  });

  group('Email OTP Authentication System Integration Tests', () {
    late MockMemoryStorage storage;
    late AuthMySqlDataSource dataSource;
    late AuthRepositoryImpl repository;
    late InitiateLoginOtpUseCase initiateLoginOtpUseCase;
    late VerifyLoginOtpUseCase verifyLoginOtpUseCase;
    late ResendLoginOtpUseCase resendLoginOtpUseCase;

    setUp(() {
      storage = MockMemoryStorage();
      dataSource = AuthMySqlDataSource(storage);
      repository = AuthRepositoryImpl(remoteDataSource: dataSource);
      initiateLoginOtpUseCase = InitiateLoginOtpUseCase(repository);
      verifyLoginOtpUseCase = VerifyLoginOtpUseCase(repository);
      resendLoginOtpUseCase = ResendLoginOtpUseCase(repository);
    });

    test('Register user and complete OTP login flow successfully', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'alex.explorer_$ts@gmail.com';
      const password = 'questPassword123!';
      const name = 'Alex Hunter';

      // 1. Register User
      final user = await dataSource.register(
        name: name,
        email: email,
        password: password,
      );
      expect(user.email, email);
      expect(user.displayName, name);

      // Logout to reset session
      await dataSource.logout();
      expect(await dataSource.getCurrentUser(), isNull);

      // 2. Initiate OTP Login with Wrong Password -> Should fail
      expect(
        () => initiateLoginOtpUseCase(email: email, password: 'wrongPassword'),
        throwsA(isA<AppException>()),
      );

      // 3. Initiate OTP Login with Correct Credentials -> Success
      final otpSent = await initiateLoginOtpUseCase(
        email: email,
        password: password,
      );
      expect(otpSent, isTrue);

      // Inspect stored pending OTP
      final pendingOtps = await storage.getJson(AppConstants.keyPendingOtps);
      expect(pendingOtps, isNotNull);
      expect(pendingOtps[email], isNotNull);
      final storedOtp = pendingOtps[email]['otp_code'] as String;
      expect(storedOtp.length, 6);

      // 4. Verify OTP with Invalid Code -> Should fail
      expect(
        () => verifyLoginOtpUseCase(email: email, otp: '000000'),
        throwsA(isA<AppException>()),
      );

      // 5. Verify OTP with Valid 6-Digit Code -> Success
      final loggedInUser = await verifyLoginOtpUseCase(
        email: email,
        otp: storedOtp,
      );
      expect(loggedInUser.email, email);
      expect(loggedInUser.displayName, name);

      // Verify session was established
      final currentSession = await dataSource.getCurrentUser();
      expect(currentSession, isNotNull);
      expect(currentSession?.id, loggedInUser.id);
    });

    test('Resend OTP generates new passcode for pending login', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'sara.quest_$ts@gmail.com';
      const password = 'secureExplorerPass99';

      await dataSource.register(
        name: 'Sara Quest',
        email: email,
        password: password,
      );
      await dataSource.logout();

      // Initiate OTP
      await initiateLoginOtpUseCase(email: email, password: password);
      final pendingOtps1 = await storage.getJson(AppConstants.keyPendingOtps);
      final otp1 = pendingOtps1[email]['otp_code'] as String;
      expect(otp1.length, 6);

      // Resend OTP
      final resendSuccess = await resendLoginOtpUseCase(email: email);
      expect(resendSuccess, isTrue);

      final pendingOtps2 = await storage.getJson(AppConstants.keyPendingOtps);
      final otp2 = pendingOtps2[email]['otp_code'] as String;
      expect(otp2.length, 6);

      // Successfully verify with the latest resent OTP
      final user = await verifyLoginOtpUseCase(email: email, otp: otp2);
      expect(user.email, email);
    });
  });
}
