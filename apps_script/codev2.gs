/**
 * iFriends — Google Drive bridge.
 *
 * POST JSON body:
 *   {
 *     "folder":   "profiles" | "posts" | "chats" | "covers",
 *     "filename": "myphoto.jpg",
 *     "mimeType": "image/jpeg",
 *     "base64":   "<base64-encoded bytes>"
 *   }
 *
 * Response JSON:
 *   { "url": "https://drive.google.com/uc?id=<FILE_ID>", "id": "<FILE_ID>" }
 *
 * The script lazily creates this folder tree inside the executing user's Drive:
 *   /iFriends
 *     /profiles
 *     /posts
 *     /chats
 *     /covers   <-- foto sampul profil
 *
 * Folder dibuat otomatis saat upload pertama (via _ensureFolder).
 * Setiap file di-share "Anyone with the link → Viewer" agar bisa di-embed
 * di aplikasi Flutter.
 */

const ROOT_FOLDER = 'iFriends';
const ALLOWED_FOLDERS = ['profiles', 'posts', 'chats', 'covers'];

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return _json({ error: 'Missing body' }, 400);
    }
    const body = JSON.parse(e.postData.contents);

    const folder = String(body.folder || '').toLowerCase();
    const filename = String(body.filename || 'upload.jpg');
    const mimeType = String(body.mimeType || 'image/jpeg');
    const base64 = String(body.base64 || '');

    if (ALLOWED_FOLDERS.indexOf(folder) === -1) {
      return _json({ error: 'Invalid folder' }, 400);
    }
    if (!base64) {
      return _json({ error: 'Missing base64' }, 400);
    }

    const bytes = Utilities.base64Decode(base64);
    const blob = Utilities.newBlob(bytes, mimeType, filename);

    const targetFolder = _ensureFolder(folder);
    const file = targetFolder.createFile(blob);
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);

    const id = file.getId();
    const url = 'https://drive.google.com/uc?id=' + id;

    return _json({ url: url, id: id });
  } catch (err) {
    return _json({ error: String(err) }, 500);
  }
}

function doGet() {
  return _json({ ok: true, service: 'iFriends Drive bridge' });
}

function _ensureFolder(name) {
  const root = _findOrCreate(DriveApp.getRootFolder(), ROOT_FOLDER);
  return _findOrCreate(root, name);
}

function _findOrCreate(parent, name) {
  const it = parent.getFoldersByName(name);
  if (it.hasNext()) return it.next();
  return parent.createFolder(name);
}

function _json(obj, status) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
