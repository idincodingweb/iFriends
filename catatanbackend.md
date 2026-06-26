# 📝 Catatan Arsitektur & Skalabilitas iFriends

## 1. Strategi Storage (Google Drive + Apps Script)
Strategi *bootstrapping* menggunakan Drive 15GB gratis terbukti valid untuk fase awal (pre-revenue) dan tidak memakan biaya server. Namun, wajib menerapkan mitigasi berikut agar infrastruktur bertahan lama:
* **Kompresi Klien (Prioritas Utama):** Gunakan package seperti `flutter_image_compress` **sebelum** proses upload. Atur dimensi maksimal (resize) ke 1080px dan *quality* di angka 75%. Ini menghemat *storage* hingga 10x lipat dan mempercepat upload tanpa membuat gambar pecah/buram.
* **Caching Agresif:** Pertahankan penggunaan `cached_network_image` di aplikasi untuk mencegah limitasi *hotlink* atau pembatasan *traffic* dari Google Drive (mencegah error `Quota exceeded`).
* **Rencana Cadangan (Fallback):** Siapkan 2-3 URL *deployment* Apps Script cadangan. Jika terjadi lonjakan *traffic* tiba-tiba (ratusan upload bersamaan), Google berpotensi melakukan *suspend* pada script karena dianggap *spam/automation abuse*.

## 2. Optimasi Biaya Firestore (Mencegah Tagihan Meledak)
Jika *user base* mulai membesar, arsitektur *realtime database* harus disesuaikan agar jumlah *read/write* tidak boros:
* **Paginasi Feed:** Hindari penggunaan *stream* penuh untuk `feedStream`, `trendingStream`, atau `myActivityStream`. Segera terapkan paginasi (`limit` + `startAfter`) agar aplikasi hanya menarik data yang dilihat *user*.
* **Manajemen Data Interaksi:** Jika array `likes[]` dalam dokumen post semakin besar, setiap satu aksi "like" akan me-rewrite seluruh dokumen. Untuk jangka panjang, pertimbangkan perpindahan ke *subcollection* khusus *likes* dan *counter doc* terpisah.
* **Kalkulasi Skor Trending:** Logika kalkulasi `score` untuk fitur *trending* jangan ditaruh di *client-side* (boros *read*). Idealnya dipindahkan ke *Cloud Functions* (terpicu otomatis saat ada *like/comment*) atau melalui *scheduled job*.

## 3. Keamanan & Maintenance Jangka Panjang
* **Lifecycle FCM Token:** Pastikan FCM token untuk *push notification* selalu di-*refresh* saat *login* dan wajib dihapus (*delete*) dari *database* saat *logout* agar notifikasi tidak nyasar ke perangkat lain atau akun lama.
* **Validasi Server-Side:** Validasi aturan seperti "cooldown ganti username 14 hari" tidak boleh hanya mengandalkan UI aplikasi (*client-side*). Harus dijaga ketat di *Firestore Security Rules* atau *Cloud Functions* agar tidak bisa ditembus lewat REST API pihak ketiga.
* **Skalabilitas Kode:** 
  * Gunakan *State Management* yang konsisten (seperti Riverpod atau Bloc) untuk menggantikan ketergantungan berlebih pada `StreamBuilder`.
  * Tambahkan *Unit Test* khusus untuk `FirestoreService` (mocking) agar proses perombakan kode (*refactor*) ke depannya tidak merusak fitur yang sudah jalan.
  * Pasang Sentry atau Crashlytics untuk melacak *bug/crash* secara *real-time* di HP pengguna.
