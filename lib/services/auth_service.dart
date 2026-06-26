import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _db = FirestoreService.instance;

  Stream<User?> authChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) async {
    final name = displayName.trim();
    final uname = username.trim().toLowerCase().replaceAll('@', '');

    final taken = await _db.isUsernameTaken(uname);
    if (taken) {
      throw FirebaseAuthException(
        code: 'username-taken',
        message: 'Username "$uname" sudah dipakai.',
      );
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.updateDisplayName(name);

    final profile = AppUser(
      uid: cred.user!.uid,
      email: email.trim(),
      displayName: name,
      username: uname,
      createdAt: DateTime.now(),
    );
    await _db.createUser(profile);
    return profile;
  }

  Future<void> signOut() => _auth.signOut();
}
