# iFriends — Project Overview & Architecture

> Aplikasi social media bergaya Instagram, dibangun dengan **Flutter (Android-first)** dengan backend **Firebase (Auth + Firestore)** dan **Google Apps Script + Google Drive** sebagai jembatan upload media.
> Dokumen ini merangkum arsitektur, modul, fitur, menu, serta pengembangan terbaru (Archive, Activity dua-tab, dan Settings ala Instagram).

---

## 1. Stack & Environment

| Layer        | Teknologi |
| ------------ | --------- |
| UI / Client  | Flutter ≥ 3.16, Dart ≥ 3.0, Material 3, `google_fonts` |
| Auth         | `firebase_auth` (Email/Password, reauth, verifyBeforeUpdateEmail, updatePassword, password reset, delete user) |
| Database     | `cloud_firestore` (realtime `snapshots()`) |
| Media upload | Google Apps Script Web App → Google Drive (folder: `profiles`, `posts`, `chats`, `stories`, `covers`) |
| Image utils  | `image_picker`, `image`, `cached_network_image` |
| HTTP         | `http` (panggil Apps Script) |
| Build        | GitHub Actions (APK release). Gradle/Actions **tidak boleh diubah** tanpa izin. |

Konfigurasi global ada di **`lib/config/app_config.dart`** (`AppConfig.firebaseAndroidOptions`, `AppConfig.appsScriptUrl`, dan nama folder Drive).

---

## 2. Struktur Folder

```
lib/
├── config/        app_config.dart                  // Firebase + Apps Script URL
├── models/        post_model.dart, user_model.dart, chat_model.dart,
│                  story.dart, mock_data.dart
├── services/      auth_service.dart                // Sign in/up/out, reauth, delete
│                  firestore_service.dart           // Semua I/O Firestore (singleton)
│                  drive_service.dart               // Upload file → Apps Script → Drive
│                  story_image_cache.dart           // Cache gambar story
├── theme/         app_theme.dart                   // AppColors + tema light
├── widgets/       app_drawer.dart, feed_post_card.dart, gradient_avatar.dart,
│                  linked_text.dart, live_user_avatar.dart,
│                  post_image_carousel.dart, user_avatar.dart
└── screens/       (lihat tabel di bawah)
```

---

## 3. Model Data Inti

### `AppUser` (`lib/models/user_model.dart`)
`uid`, `email`, `displayName`, `username` (+ cooldown 14 hari via `usernameUpdatedAt`), `bio`, `location`, `avatarUrl`, `coverUrl`, `role` (`user` | `verified`), `following[]`, `followers[]`, `saved[]`, `blocked[]`, `isPrivate`, `fcmToken`, `createdAt`.

### `Post` (`lib/models/post_model.dart`)
`id`, `authorId/Name/Username/AvatarUrl`, `imageUrl` (legacy) + `imageUrls[]` (carousel), `caption`, `hashtags[]`, `likes[]`, `commentsCount`, `createdAt`, `editedAt`, **`archived`**, `hidden` (moderasi).
Getter: `images`, `likesCount`, `isEdited`, `score` (trending).

### Chat
`Chat` + `ChatMessage` (mendukung share post via `postId`).

### Story
`Story` + `StoryGroup` (group per author, viewers tracking).

### Notifikasi & Activity
`AppNotification` dan `UserActivity` (didefinisikan di `firestore_service.dart`).

---

## 4. Layer Service

### `AuthService`
Login/Register email-password, reauthenticate, `verifyBeforeUpdateEmail`, `updatePassword`, `sendPasswordResetEmail`, `signOut`, `user.delete()`.

### `FirestoreService` (singleton, instance)
**Users:** `isUsernameTaken`, `createUser`, `getUser`, `userStream`, `updateUser`, `getUserByUsername`, `updateUsername`, `searchUsers`, `toggleFollow`.
**Posts:** `createPost`, `updatePost`, `deletePost`, **`setPostArchived`**, **`archivedPostsStream`**, `feedStream`, `userPostsStream`, `trendingStream`, `hashtagPostsStream`, `toggleLike`, `toggleSavePost`, `savedPostsStream`.
**Komentar:** `commentsStream`, `addComment`, `updateComment`, `deleteComment`, `toggleCommentLike`, plus `_notifyMentionsInText`.
**Chats:** `myChatsStream`, `ensureChat`, `messagesStream`, `sendMessage`, `sendSharedPost`.
**Stories:** `createStory`, `activeStoriesStream`, `markStoryViewed`.
**Notif / Activity:** `notificationsStream`, **`myActivityStream`**, `saveFcmToken`, `_pushNotification`.

### `DriveService`
POST multipart ke `AppConfig.appsScriptUrl` (folder logis: profiles / posts / chats / stories / covers) → return URL Drive yang bisa ditampilkan via `cached_network_image`.

---

## 5. Navigasi Utama

`SplashScreen` → `AuthGate` → (`LoginScreen`/`RegisterScreen`) atau `MainScreen` (bottom nav).

### Bottom Navigation (`main_screen.dart`)
| Tab | Screen |
| --- | ------ |
| 🏠 Home | `HomeFeedScreen` (stories + feed) |
| 🔍 Explore | `TrendingScreen` (search user + hashtag + trending) |
| ➕ Create | `CreatePostScreen` (single/multi-image + crop) |
| 💬 Chats | `ChatsInboxScreen` → `ChatScreen` |
| 👤 Profile | `ProfileScreen` (tabs: Posts / Saved / Tagged) |

### Sidebar / Drawer (`app_drawer.dart`)
`Your Profile`, `Your Activity`, `Saved`, **`Archive`**, `Insights`, `QR Code`, `Switch Account`, **`Settings`**, `Log Out`.

### Screen lainnya
`PostDetailScreen`, `EditPostScreen`, `EditProfileScreen`, `FollowRequestsScreen`, `FriendsScreen`, `HashtagScreen`, `ImageCropScreen`, `SavedScreen`, `ShareToChatScreen`, `StoryCreateScreen`, `StoryViewerScreen`, `ActivityScreen`, **`ArchiveScreen`**, **`SettingsScreen`**.

---

## 6. Daftar Fitur

### Core
- Auth email/password + profile bootstrap (username unik, cooldown 14 hari).
- Feed realtime + stories aktif + mark viewed.
- Posting: single image **atau multi-image carousel** (`PostImageCarousel`), caption + hashtag auto-parse, edit & delete owner-only.
- Like post + like komentar, reply komentar, mention `@username` (auto-link + notif).
- Hashtag `#topik` (auto-link + `HashtagScreen`).
- Save / Bookmark post → tab **Saved**.
- Chat 1:1 + share post ke DM (kartu preview), `ensureChat`.
- Stories: create, viewer, reply story → DM.
- Trending: skor `likes + 2 * comments`.
- Search user, follow / unfollow.

### Trust & Safety
- Akun privat + follow request (approve sebelum bisa lihat).
- Block / unblock user (filter dua arah).
- Moderasi: flag `hidden` / under review.
- Edit / hapus post & komentar sendiri.

### Notifikasi
- In-app stream (`notificationsStream`) — like, comment, reply, follow, mention, story reply.
- FCM token tersimpan di user doc (`saveFcmToken`).

---

## 7. Apps Script Bridge (Google Drive)

`apps_script/Code.gs` di-deploy sebagai Web App ("Anyone can execute").
Aplikasi POST file + nama folder logis; script menyimpan ke folder Drive yang sesuai dan mengembalikan URL publik.
**Re-deploy** wajib jika ada perubahan endpoint (mis. dukungan upload baru).

---

## 8. Pengembangan Terbaru (Latest Changes)

### 🗄️ Archive
- Field baru **`archived`** di model `Post` (default `false`, backward-compatible).
- Method **`setPostArchived(postId, archived)`** dan stream **`archivedPostsStream(uid)`** di `FirestoreService`.
- Entry **"Archive post"** di bottom-sheet `feed_post_card.dart` (owner only).
- Layar baru **`archive_screen.dart`** — grid post yang diarsipkan + aksi **Unarchive**.
- Menu **Archive** di drawer (`app_drawer.dart`) sudah di-wire ke `ArchiveScreen`.

### 🔔 Activity (2 tab)
`activity_screen.dart` di-refactor jadi dua tab:
1. **Notifications** — stream `notificationsStream` (like, komentar, follow, mention, dst).
2. **Your Activity** — stream baru **`myActivityStream`** (post, like, komentar milik user sendiri).

### ⚙️ Settings (ala Instagram)
Item **Settings** di sidebar membuka **`SettingsScreen`** dengan struktur lengkap:

- **Account**
  - Edit profile
  - Username (info cooldown 14 hari)
  - Ubah Email — reauth + `verifyBeforeUpdateEmail`
  - Ubah Password — reauth + `updatePassword`
  - Lupa password — `sendPasswordResetEmail`
- **Privacy & Security**
  - Toggle **Akun Privat**
  - Daftar **Permintaan Follow** (muncul jika privat)
  - Daftar **Pengguna Diblokir** + tombol **Unblock**
- **Notifikasi**
  - Toggle Like / Komentar / Follower / Pesan
- **Tampilan**
  - Tema & Bahasa (placeholder)
- **Bantuan**
  - Help, Privacy policy, About dialog
- **Danger zone**
  - Log out
  - **Hapus akun** — reauth + `user.delete()`

---

## 9. Konvensi Kerja (S.O.P singkat)

- Kode harus **compile-ready** untuk `flutter build apk --release`.
- **Jangan sentuh** `.github/workflows/*` maupun konfigurasi Gradle.
- Reuse widget: `LiveUserAvatar`, `LiveUserName`, `LiveVerifiedBadge`, `UserAvatar`.
- Warna selalu via `AppColors` di `app_theme.dart`.
- Tambah field baru dengan default aman (`''`, `[]`, `0`, `false`) — **tanpa migrasi**.
- Tambah dependency boleh, **jangan ubah SDK constraint** di `pubspec.yaml`.
- Akhir tugas: ringkas perubahan + repack project jadi `iFriends.zip`.
- 
