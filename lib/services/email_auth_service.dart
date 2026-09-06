import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';

class EmailAuthService {
  EmailAuthService({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<EmailSignupStatusResult> checkSignupStatus(String email) {
    return _apiClient.checkEmailSignupStatus(email.trim());
  }

  Future<void> restoreAccount(String email) {
    return _apiClient.restoreEmailAccount(email.trim());
  }

  Future<SendEmailCodeResult> sendSignupCode(String email) {
    return _apiClient.sendEmailSignupCode(email.trim());
  }

  Future<VerifyEmailCodeResult> verifySignupCode({
    required String email,
    required String code,
  }) {
    return _apiClient.verifyEmailSignupCode(
      email: email.trim(),
      code: code.trim(),
    );
  }

  Future<void> register({
    required String signupToken,
    required String password,
    required String passwordConfirm,
  }) {
    return _apiClient.registerEmail(
      signupToken: signupToken,
      password: password,
      passwordConfirm: passwordConfirm,
    );
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final result = await _apiClient.loginWithEmail(
      email: email.trim(),
      password: password,
    );
    await _tokenStorage.saveSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      userId: result.userId,
    );
    return result;
  }
}
