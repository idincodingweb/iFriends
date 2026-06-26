import 'package:firebase_core/firebase_core.dart';

/// =====================================================================
/// iFriends — Konfigurasi Global
/// ---------------------------------------------------------------------
/// TODO (WAJIB DIISI SETELAH DOWNLOAD):
///
/// 1) FIREBASE
///    - Buat project di https://console.firebase.google.com
///    - Tambahkan app Android (package name: sesuaikan dengan android/app/build.gradle,
///      misal: com.ifriends.app).
///    - Download google-services.json → letakkan di android/app/google-services.json
///    - Aktifkan Authentication → Email/Password
///    - Aktifkan Cloud Firestore (mode production).
///    - Ganti nilai placeholder di [firebaseAndroidOptions] di bawah dengan
///      milik project lo (apiKey, appId, messagingSenderId, projectId, storageBucket).
///
/// 2) APPS SCRIPT (Google Drive bridge untuk upload gambar)
///    - Lihat folder /apps_script/ di repo ini.
///    - Deploy Code.gs sebagai Web App ("Anyone" can execute).
///    - Copy URL hasil deploy → tempel ke [appsScriptUrl] di bawah.
///
/// =====================================================================
class AppConfig {
  AppConfig._();

  // ---------- FIREBASE ----------
  static const FirebaseOptions firebaseAndroidOptions = FirebaseOptions(
    apiKey: 'AIzaSyDd-QVyzhriaQUbi1X48pMr5DSx9JtHRUw',
    appId: '1:147677869835:android:20d2479f0ea86317ff140e',
    messagingSenderId: '147677869835',
    projectId: 'ifriends-app-e11da',
    storageBucket: 'ifriends-app-e11da.firebasestorage.app',
  );

  // ---------- APPS SCRIPT (Google Drive) ----------
  /// URL hasil deploy /apps_script/Code.gs sebagai Web App.
  /// Contoh: https://script.google.com/macros/s/AKfycb.../exec
  static const String appsScriptUrl = 'https://script.google.com/macros/s/AKfycbyweg1rIAITwUIO9OXhodOidpm8HhFwkLR8D72Q4weukB7ayT1d6uB_rkde1cfwPkt2/exec';

  // Folder logical name yang dikirim ke Apps Script (mapping ke folder Drive).
  static const String folderProfiles = 'profiles';
  static const String folderPosts = 'posts';
  static const String folderChats = 'chats';
  static const String folderStories = 'stories';
  static const String folderCovers = 'covers';

  static bool get isAppsScriptConfigured =>
      appsScriptUrl.isNotEmpty && !appsScriptUrl.startsWith('TODO_');
}
