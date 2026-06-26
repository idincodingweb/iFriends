# iFriends Android Build Fix v5

Fix untuk error AndroidX AAR metadata terbaru:

> Dependency androidx.* requires Android Gradle plugin 8.9.1 or higher. This build currently uses Android Gradle plugin 8.6.1.

## Isi paket

Overwrite file berikut ke repo kamu:

- android/settings.gradle
- android/build.gradle
- android/app/build.gradle
- android/gradle/wrapper/gradle-wrapper.properties

## Versi yang dipakai

- Android Gradle Plugin: 8.9.1
- Gradle Wrapper: 8.14
- Kotlin Android Plugin: 1.9.24
- Google Services Plugin: 4.4.2
- Desugar JDK Libs: 2.1.4

## Cara pakai

1. Extract zip ini.
2. Copy folder `android/` ke root project iFriends kamu.
3. Replace/overwrite file yang sama.
4. Commit dan push ke GitHub.
5. Run ulang GitHub Action.

## Catatan penting

Kalau `namespace` atau `applicationId` project kamu bukan `com.example.ifriends`, samakan lagi dengan value lama dari project kamu.
