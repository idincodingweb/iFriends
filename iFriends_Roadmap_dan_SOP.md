# iFriends — Roadmap Fitur Baru & S.O.P Kerja untuk Lovable

> Dokumen ini dipakai sebagai **brief + aturan kerja** saat melanjutkan pengembangan aplikasi Flutter **iFriends** (social app mirip Instagram, backend Firebase + Google Apps Script/Drive untuk upload media).
> Kirim dokumen ini di percakapan baru sebagai konteks awal sebelum minta Lovable mengerjakan fitur.

---

## BAGIAN 1 — S.O.P / ATURAN KERJA (WAJIB DIBACA DULU)

### A. Tentang environment
- Lo (Lovable) **tidak bisa menjalankan / build Flutter SDK** di environment. **ABAIKAN keterbatasan itu.**
- Tugas lo **HANYA menulis kode Dart + konfigurasi project**. Build APK dijalankan sendiri oleh owner via **GitHub Actions**.
- **JANGAN mengeluh** soal environment, **jangan menolak**, **jangan menawarkan alternatif** React/web/framework lain. Ini proyek Flutter, tetap Flutter.

### B. File yang TIDAK BOLEH disentuh
- **JANGAN** memodifikasi workflow **GitHub Actions** (`.github/workflows/*`).
- **JANGAN** mengubah konfigurasi **Gradle** (`android/`, `build.gradle`, `gradle-wrapper`, dll) kecuali diminta eksplisit.
- **JANGAN** mengubah file setup builder yang sudah ada.
- **JANGAN** mengubah **SDK constraint** di `pubspec.yaml` saat menambah dependency.

### C. Standar kualitas kode
- Kode harus **bersih, modular, dan compile-ready** untuk `flutter build apk --release`.
- Ikuti **struktur & konvensi yang sudah ada** di repo:
  - `lib/models/` → model data
  - `lib/services/` → akses Firestore/Auth/Drive (mis. `FirestoreService.instance`)
  - `lib/screens/` → halaman
  - `lib/widgets/` → komponen reusable
  - `lib/theme/app_theme.dart` → warna lewat `AppColors`, **jangan hardcode** warna baru sembarangan.
- Reuse widget yang sudah ada: `LiveUserAvatar`, `LiveUserName`, `LiveVerifiedBadge`, `UserAvatar`.
- Tambahkan field baru ke model **dengan default aman** (mis. `''`, `[]`, `0`) agar data lama tetap kompatibel — **tidak perlu migrasi**.

### D. Firebase / Apps Script
- Operasi data lewat **Firestore** (realtime via `snapshots()`).
- **Apps Script (`Code.gs`)** hanya untuk upload media ke Drive. **Hanya ubah `Code.gs` bila fitur butuh jenis upload baru** (mis. carousel multi-image, video) — dan kalau diubah, **beri tahu owner bahwa perlu re-deploy Apps Script**.
- Bila menambah field ke Firestore, **cek Security Rules**: pastikan field baru diizinkan kalau rules-nya strict.
- Untuk **push notification** gunakan FCM (`firebase_messaging`); jelaskan setup tambahan (file `google-services.json`, permission) tapi **jangan** utak-atik Gradle sendiri tanpa izin.

### E. Dependency
- Boleh menambah dependency yang dibutuhkan ke `pubspec.yaml` (mis. `firebase_messaging`, `flutter_local_notifications`) **tanpa mengubah SDK constraint**.
- Sebutkan dependency baru yang ditambahkan di akhir pekerjaan.

### F. Alur kerja tiap tugas
1. Baca konteks file terkait dulu sebelum mengedit.
2. Implementasi **hanya yang diminta** — jangan refactor besar tanpa izin.
3. Jaga kompatibilitas data lama.
4. Di akhir: ringkas perubahan singkat + **kemas ulang project ke `iFriends.zip`**.
5. Jangan klaim "selesai/teruji" untuk hal yang butuh build; cukup pastikan kode konsisten & compile-ready.

### G. Reminder penutup tiap tugas
- Kode bersih, modular, compile-ready untuk `flutter build apk --release`.
- JANGAN sentuh GitHub Actions & Gradle.
- Selesai → kemas ulang ke `iFriends.zip`.

---

## BAGIAN 2 — ROADMAP FITUR BARU

Dikelompokkan berdasarkan dampak. Setiap fitur diberi catatan teknis singkat agar Lovable langsung paham arahnya.

### 🔥 Prioritas Tinggi (engagement & retensi)

#### 1. Sistem Notifikasi (in-app + push)
- Notif untuk: like, comment, **reply komentar**, follow baru, mention, reply story.
- **Teknis:** koleksi `notifications/{uid}/items/{id}` (fields: `type`, `fromUid`, `postId?`, `commentId?`, `text`, `read`, `createdAt`). Badge jumlah unread di app bar. Push via **FCM** (`firebase_messaging`) + simpan `fcmToken` di doc user.
- Halaman "Activity / Aktivitas" dengan list realtime.

#### 2. Like & Reply pada Komentar
- Tombol love kecil di tiap komentar + counter.
- **Teknis:** `likes` (array uid) di doc komentar; toggle transaksi seperti `toggleLike` post. (Reply sudah ada — tinggal like.)

#### 3. Share Post ke DM
- Kirim post sebagai pesan chat.
- **Teknis:** `ChatMessage` tambah field `postId`. Render kartu preview post di bubble chat. Reuse `ChatScreen` & `FirestoreService.sendMessage`.

#### 4. Save / Bookmark Post
- Aktifkan tab **"Saved"** yang sekarang masih kosong.
- **Teknis:** koleksi `users/{uid}/saved/{postId}` atau array `saved` di user doc. Tombol bookmark di `FeedPostCard` & post detail.

---

### 💬 Sosial & Konten

#### 5. Mention @username
- Auto-link `@username` di caption & komentar → buka profil + trigger notifikasi.
- **Teknis:** parse teks dengan RegExp, render pakai `RichText`/`TextSpan` (sudah dipakai di komentar reply).

#### 6. Hashtag #topik + Explore
- `#topik` jadi link → halaman daftar post dengan hashtag sama.
- **Teknis:** simpan array `hashtags` saat create post; query `where('hashtags', arrayContains: tag)`.

#### 7. Reply / Reaksi Story
- Balas story langsung menjadi DM + reaksi emoji cepat.
- **Teknis:** input bar di `StoryViewerScreen` → `ensureChat` + `sendMessage`. (Catatan: tidak butuh ubah Apps Script.)

#### 8. Multi-Image Post (Carousel)
- Upload beberapa foto dalam satu post, swipe di feed.
- **Teknis:** `Post.imageUrls` (List<String>); `PageView` di kartu feed. **Butuh penyesuaian upload di Apps Script** (upload banyak file) → ingatkan re-deploy.

---

### 🛡️ Wajib Sebelum Rilis Nyata (Trust & Safety)

#### 9. Report & Block
- Report post/komentar/user; block user (sembunyikan konten dua arah).
- **Teknis:** koleksi `reports`; array `blocked` di user doc; filter feed/komentar/chat dari uid yang diblok.

#### 10. Edit / Hapus Post & Komentar Sendiri
- Owner konten bisa hapus/edit miliknya.
- **Teknis:** hapus doc + decrement counter; guard `authorId == currentUid`; pastikan tercermin di Security Rules.

#### 11. Akun Privat
- Approve follower sebelum bisa lihat post.
- **Teknis:** `isPrivate` di user doc; koleksi `followRequests`; gating di profil & feed.

#### 12. Moderasi Media
- Minimal: antrian laporan manual. Idealnya: filter konten saat upload.
- **Teknis:** flag `hidden`/`underReview` di post; tampilkan placeholder bila tersembunyi.

---

### ⚙️ Pengalaman & Pertumbuhan

#### 13. Onboarding + Saran Follow
- Setelah daftar: pilih minat + "Orang yang mungkin kamu kenal" agar feed tidak kosong.

#### 14. Search & Explore Lebih Kaya
- Saat ini hanya prefix username/nama. Tambah grid foto populer + tab people/tags.

#### 15. Dark Mode
- Tema gelap penuh via `AppTheme`/`ThemeMode`, simpan preferensi user.

#### 16. Pull-to-Refresh + Infinite Scroll
- Feed sekarang limit 50. Tambah paginasi (`startAfter`) + `RefreshIndicator`.

---

### 💰 Monetisasi (Tahap Lanjut)

#### 17. Verified Berbayar
- Manfaatkan sistem role `verified` yang sudah ada (badge sudah tampil global).

#### 18. Post Promoted / Boost
- Tandai post promosi + slot di feed.

---

## BAGIAN 3 — USULAN URUTAN PENGERJAAN MENUJU RILIS

1. **Notifikasi (in-app + FCM)**
2. **Like komentar**
3. **Report & Block** (wajib untuk user nyata)
4. **Save/Bookmark** (aktifkan tab Saved)
5. **Mention & Hashtag**
6. **Edit/Hapus konten sendiri + Akun privat**
7. Sisanya (carousel, dark mode, paginasi, onboarding, monetisasi) sesuai kebutuhan.

> Saran: kerjakan **satu fitur per percakapan/PR** agar mudah di-review dan di-build.
