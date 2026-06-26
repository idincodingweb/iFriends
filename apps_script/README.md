# iFriends — Apps Script Drive bridge

The Flutter app stores all text data in Firestore but **does not** use Firebase
Storage. Image uploads (profile photo, posts, chat photos) are pushed as
base64 to this Apps Script web app, which writes them to Google Drive and
returns a public direct-view URL.

## 1. Create the project

1. Open <https://script.google.com> → **New project**.
2. Replace `Code.gs` with the contents of [`Code.gs`](./Code.gs).
3. Save the project (give it a name, e.g. `iFriends Drive Bridge`).

## 2. Deploy as Web App

1. Click **Deploy → New deployment**.
2. Type: **Web app**.
3. Description: `iFriends image bridge`.
4. **Execute as:** *Me* (the Google account that owns the Drive folder).
5. **Who has access:** **Anyone** (required so the Flutter app can POST without OAuth).
6. Click **Deploy**, authorize the requested Drive scopes.
7. Copy the **Web app URL** (looks like `https://script.google.com/macros/s/AKfycb.../exec`).

## 3. Wire it into Flutter

Open `lib/config/app_config.dart` and set:

```dart
static const String appsScriptUrl = 'https://script.google.com/macros/s/AKfycb.../exec';
```

## 4. How the folders are organized

The script auto-creates this tree in the executing account's Drive:

```
My Drive/
  iFriends/
    profiles/   ← avatar uploads
    posts/      ← feed images
    chats/      ← chat attachments
```

Each uploaded file is automatically shared as
**Anyone with the link → Viewer** and returned as
`https://drive.google.com/uc?id=<FILE_ID>` so it can be rendered by
`cached_network_image`.

## Request / response contract

```http
POST <web app url>
Content-Type: application/json

{
  "folder":   "profiles",      // "profiles" | "posts" | "chats"
  "filename": "avatar.jpg",
  "mimeType": "image/jpeg",
  "base64":   "..."             // base64-encoded image bytes
}
```

```json
{
  "url": "https://drive.google.com/uc?id=1AbCdEf...",
  "id":  "1AbCdEf..."
}
```
