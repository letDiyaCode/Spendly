import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/app_user.dart';
import '../auth_repository.dart';
import '../user_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Configuration for Google Sign-In
  // Note: clientId is only required for iOS and Web. On Android, it's read from google-services.json.
  static const String _webClientId = "445139054884-95qd16k57ia8ii3asj9qem0943rar2in.apps.googleusercontent.com";

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: (kIsWeb || Platform.isIOS) ? _webClientId : null,
  );
  final UserRepository _userRepo;

  FirebaseAuthRepository(this._userRepo);

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      name: user.displayName ?? 'No Name',
      email: user.email ?? '',
      avatarUrl: user.photoURL,
    );
  }

  Exception _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return Exception('Please enter a valid email address.');
      case 'user-disabled':
        return Exception('This account has been disabled.');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return Exception('Invalid email or password.');
      case 'email-already-in-use':
        return Exception('This email is already in use.');
      case 'weak-password':
        return Exception('Password must be at least 6 characters long.');
      case 'network-request-failed':
        return Exception('Network error. Please check your connection.');
      case 'too-many-requests':
        return Exception('Too many attempts. Please try again later.');
      default:
        return Exception(e.message ?? 'Authentication failed.');
    }
  }

  @override
  AppUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Stream<AppUser?> get authStateStream =>
      _auth.authStateChanges().map(_mapUser);

  @override
  Future<void> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      // Ensure profile exists in users collection for name resolution across the app.
      final user = credential.user;
      if (user != null) {
        final existingProfile = await _userRepo.getUserById(user.uid);
        final fallbackName = (user.displayName != null &&
                user.displayName!.trim().isNotEmpty)
            ? user.displayName!
            : (user.email?.split('@').first ?? 'User');

        await _userRepo.saveUser(
          (existingProfile ??
                  AppUser(
                    id: user.uid,
                    name: fallbackName,
                    email: user.email?.trim().toLowerCase() ??
                        email.trim().toLowerCase(),
                  ))
              .copyWith(
            name: existingProfile?.name.trim().isNotEmpty == true
                ? existingProfile!.name
                : fallbackName,
            email:
                user.email?.trim().toLowerCase() ?? email.trim().toLowerCase(),
            avatarUrl: existingProfile?.avatarUrl ?? user.photoURL,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<void> register(String name, String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      await credential.user?.updateDisplayName(name);

      final user = credential.user;

      if (user != null) {
        await _userRepo.saveUser(AppUser(
          id: user.uid,
          name: name,
          email: email.trim().toLowerCase(),
        ));
      }
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      // 🔥 IMPORTANT: force account picker (fixes silent issues)
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('Google sign-in cancelled');
        return null;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user != null) {
        final appUser = AppUser(
          id: user.uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          avatarUrl: user.photoURL,
        );

        await _userRepo.saveUser(appUser);

        debugPrint('Google Sign-In SUCCESS: ${user.email}');

        return appUser;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e, stack) {
      debugPrint('GOOGLE SIGN IN ERROR: $e');
      debugPrint('STACKTRACE: $stack');
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
