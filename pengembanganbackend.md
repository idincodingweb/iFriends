# 🚀 iFriends Next Action Items & Checklist

Urutan pengerjaan di bawah ini disusun berdasarkan prioritas dari yang paling krusial untuk kestabilan aplikasi saat ini, hingga optimasi skala besar untuk jangka panjang.

---

## 🛠️ Fase 1: Penyelamat Kestabilan & Storage (Prioritas Utama)
*Fokus pada efisiensi media dan pencegahan rate limit dari Google Drive.*

- [ ] **1. Implementasi Kompresi Gambar di Flutter (`image_utils`)**
  - Pasang package `flutter_image_compress` (atau sejenisnya).
  - Integrasikan ke alur sebelum `DriveService` memanggil Apps Script.
  - Batasi resolusi maksimal di 1080px dengan kualitas pengompresan ~75%.
- [ ] **2. Setup URL Mirror/Cadangan Apps Script**
  - Deploy ulang `Code.gs` ke 1-2 akun Google cadangan sebagai cadangan endpoint.
  - Daftarkan daftarnya di `lib/config/app_config.dart` sebagai fallback jika URL utama terkena limitasi traffic.
- [ ] **3. Finetuning Sistem Caching & Exponential Backoff**
  - Pastikan `cached_network_image` terpasang erat di widget `FeedPostCard` dan `PostImageCarousel`.
  - Tambahkan jeda waktu berlipat (2s -> 4s -> 8s) pada logika *retry mechanism* saat koneksi gagal agar tidak membebani API.

---

## 📉 Fase 2: Efisiensi Firestore & Anti Biaya Membengkak
*Fokus pada penghematan kuota Read/Write Firebase ketika user mulai aktif.*

- [ ] **4. Refactor Feed Terbuka Menjadi Paginasi (Pagination)**
  - Ubah `feedStream`, `trendingScreen`, dan `myActivityStream` di `FirestoreService` agar tidak menarik seluruh data sekaligus.
  - Terapkan metode `.limit(10)` dan kurser `.startAfter()` untuk memuat postingan secara berkala saat user melakukan *scroll* ke bawah.
- [ ] **5. Validasi Aturan Cooldown Username (Server-Side)**
  - Pindahkan atau kunci logika pengecekan batas waktu ganti username 14 hari (`usernameUpdatedAt`) ke dalam *Firestore Security Rules*.
  - Pastikan aturan ini tidak bisa ditembus dari REST API luar tanpa melalui UI aplikasi.

---

## 🔒 Fase 3: Keamanan Siklus Akun (Security & Cleanup)
*Fokus pada penanganan data user yang aman saat terjadi perubahan status login.*

- [ ] **6. Manajemen Siklus Hidup (Lifecycle) FCM Token**
  - Tambahkan fungsi pembersihan token di `AuthService.signOut()` agar token FCM dihapus dari dokumen user di Firestore saat keluar.
  - Pastikan token baru langsung didaftarkan ulang ke Firestore tiap kali user berhasil login/register.
- [ ] **7. Penanganan Hapus Akun (Danger Zone)**
  - Lengkapi fungsi `user.delete()` di halaman Settings dengan penghapusan dokumen terkait user tersebut di Firestore (opsional: atau gunakan Cloud Trigger untuk menghapus postingan miliknya otomatis).

---

## 🚀 Fase 4: Refactor & Kesiapan Rilis (Skalabilitas Kode)
*Fokus pada kerapian struktur kode agar maintenance ke depannya tidak bikin pusing.*

- [ ] **8. Migrasi State Management dari StreamBuilder Berlebih**
  - Mulai cicil integrasi State Management (Riverpod / BLoC) untuk memisahkan logika bisnis dari UI, terutama pada modul Chat dan Feed.
- [ ] **9. Pemasangan Crashlytics / Sentry**
  - Hubungkan Firebase Crashlytics untuk memantau bug secara real-time dari perangkat penguji (beta tester).
- [ ] **10. Final Testing untuk Build Production**
  - Jalankan pengujian menyeluruh sebelum melakukan `flutter build apk --release` untuk memastikan tidak ada fungsi esensial yang patah.
