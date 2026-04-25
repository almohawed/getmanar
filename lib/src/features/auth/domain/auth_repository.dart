import '../../../core/domain/models/user.dart';

abstract class AuthRepository {
  Future<User?> login(String email, String password);
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<void> changePassword(String newPassword);
  Future<void> reauthenticate(String password);
  Future<void> authStateReady();

  // Phone Auth Methods
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String message) verificationFailed,
  });

  Future<User?> signInWithPhoneCredential(
    String verificationId,
    String smsCode,
  );

  Future<User?> signInWithCustomToken(String customToken);
}
