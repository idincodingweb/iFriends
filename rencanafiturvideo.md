# 📑 RENCANA PENGEMBANGAN LANJUTAN: FITUR VIDEO PENDEK (iFriends V4)

Dokumen arsitektur teknis untuk penambahan fitur unggah dan putar video pendek dengan batasan durasi maksimal 90 detik dan ukuran file maksimal 20MB secara 100% GRATIS.

---

## 🛠️ OPSI 1: JALUR GERILYA (GOOGLE DRIVE VIA APPS SCRIPT)
Memanfaatkan ekosistem Google Drive sebagai Object Storage unlimited dengan metode multi-account routing.

### 1. Alur Kerja Sistem (Data Flow)
1. **Flutter:** User memilih video (maks 20MB) -> Filter durasi -> Konversi ke format Base64 atau kirim via Multipart Request.
2. **Google Apps Script:** Menerima payload -> Convert kembali menjadi file video `.mp4` -> Simpan ke folder `/iFriends/videos` -> Atur permission menjadi "Anyone with link" -> Return URL Direct Stream.
3. **Firestore:** Menyimpan URL direct stream tersebut ke dalam dokumen `posts` di field `videoUrl`.

### 2. Cetak Biru Kode Google Apps Script (`Code.gs`)
```javascript
function doPost(e) {
  try {
    var jsonString = e.postData.contents;
    var data = JSON.parse(jsonString);
    
    var base64Video = data.videoBase64;
    var fileName = data.fileName;
    
    // Decode Base64 ke Blob Video
    var videoBlob = Utilities.newBlob(Utilities.base64Decode(base64Video), 'video/mp4', fileName);
    
    // Cari atau buat folder khusus video
    var folder, folders = DriveApp.getFoldersByName("iFriends_Videos");
    if (folders.hasNext()) {
      folder = folders.next();
    } else {
      folder = DriveApp.createFolder("iFriends_Videos");
    }
    
    // Simpan file ke Drive
    var file = folder.createFile(videoBlob);
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    
    // Buat Direct Download/Stream Link
    var directUrl = "[https://drive.google.com/uc?export=download&id=](https://drive.google.com/uc?export=download&id=)" + file.getId();
    
    return ContentService.createTextOutput(JSON.stringify({
      "status": "success",
      "videoUrl": directUrl,
      "fileId": file.getId()
    })).setMimeType(ContentService.MimeType.JSON);
    
  } catch(error) {
    return ContentService.createTextOutput(JSON.stringify({
      "status": "error",
      "message": error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}
