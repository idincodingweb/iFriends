# iFriends Android build fix v3

Ini revisi yang bener untuk error terbaru:

```text
Your project's Gradle version (8.4.0) is lower than Flutter's minimum supported version of 8.7.0
```

## Yang berubah dari v2

- `android/gradle/wrapper/gradle-wrapper.properties` dinaikkan ke **Gradle 8.7**
- `android/settings.gradle` dinaikkan ke **Android Gradle Plugin 8.5.2**
- Tetap pakai deklaratif `plugins {}` agar kompatibel dengan Flutter terbaru
- Tetap pakai Kotlin **1.9.22** untuk kompatibilitas Firebase/Auth dependency yang sebelumnya bikin D8 error
- Tetap disable shrinker di release untuk menghindari error R8/D8 lama

## Cara pakai

Extract isi zip ini ke root repo `iFriends`, pilih overwrite/replace semua file.

File yang akan tertimpa:

- `android/settings.gradle`
- `android/build.gradle`
- `android/app/build.gradle`
- `android/gradle/wrapper/gradle-wrapper.properties`

Lalu commit dan push ulang ke GitHub Action.

## Versi final

- Flutter: mengikuti GitHub Action kamu
- Gradle Wrapper: **8.7**
- Android Gradle Plugin: **8.5.2**
- Kotlin Gradle Plugin: **1.9.22**
- Google Services: **4.4.1**
- Desugar JDK libs: **2.0.4**
