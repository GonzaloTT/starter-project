# Publication persistence validation — Phase 5, Unit 6

## Scope

Unit 5 is omitted. No `confirmationPending`, new packages, credentials,
production configuration changes or rule changes are introduced.

The user selected service integrations with the existing Firebase JavaScript SDK
(12.19.0). These tests do **not** execute Flutter datasources, repository, GetIt,
native Android plugins or UI. Flutter coverage remains unit/widget tests with
controlled doubles, static analysis and APK compilation.

## Repeatable execution and protections

Requirements: Node.js >=20, installed backend dependencies, Firebase CLI, Java 21.
From `backend`, run sequentially:

```sh
npm run test:safety
npm test
npm run test:integration
```

`npm test` runs the original 52 rule tests unchanged. `test:integration` runs 8
safety unit tests and 12 integrations. Expected permission-denied logs belong to
negative assertions; they are not failures when those assertions pass.

Both emulator commands explicitly select `demo-symmetry-rules` and
`firebase.test.json`, which loads the existing rules and indexes. Endpoints:

| Service | Endpoint |
| --- | --- |
| Firestore | `127.0.0.1:18080` |
| Storage | `127.0.0.1:19199` |
| Hub / logging | `14400` / `14500` |
| Bucket | `demo-symmetry-rules.appspot.com` |

The CLI starts/stops both emulators. There is no data import/export. Integration
fixtures use unique IDs and disappear with the disposable emulator run. The new
integration suite does not bypass rules. The old rules suite retains its existing
emulator-only fixture reset mechanism.

Before initializing Firebase, the new integration suite requires the exact demo
project and BOTH emulator environment variables on their specified loopback ports.
Missing, remote or mismatched endpoints fail before Firebase initialization.
Every SDK session explicitly connects both services before any operation. Project
and bucket are fixed test constants, never loaded from `.firebaserc` or production
Flutter options. No Auth, API key or service account is configured.

Before fetching a returned download URL, the test requires HTTP, `127.0.0.1`, port
19199, the demo bucket path, and no user information. Redirects are disabled.
The HTTPS Firestore fixture is never fetched. The safety tests exercise missing
variables, a real-project name, wrong/remote endpoints and unsafe download URLs.
Direct invocation of the integration file without this environment intentionally
fails closed.

## Coverage and observed limitation

### Firestore emulator: 6 tests

- Allocate an automatic ID without creating a document.
- Write exactly eight fields with three server timestamps.
- Read using `getDocFromServer` from another SDK app/client, asserting no cached
  data or pending writes. This establishes server persistence beyond one client's
  state, not persistence across emulator restarts.
- Assert resolved timestamps, conversion to JavaScript dates and equality of all
  three timestamps for this immediate-publication workflow.
- Deny update/delete of an existing document and confirm unchanged content.
- Deny missing/extra fields, wrong type and non-server creation timestamp.

The thumbnail HTTPS Firebase Storage URL is a **schema fixture only**. It has no
uploaded object, is never fetched, and is not end-to-end publication evidence.

### Storage emulator: 5 tests

- Upload a PNG byte fixture to `media/articles/{id}/thumbnail.png`.
- From another SDK app verify bucket, exact path, size, `image/png` metadata and
  exact bytes. Fetch the actual returned local URL and verify bytes/MIME again.
- Assert `storage/object-not-found` for an absent object.
- Deny replacement/deletion of an existing object and confirm it remains readable.
- Deny an invalid path and invalid MIME.

These verify transfer and metadata, not image decoding or the Android gallery.
The existing 52-rule suite also covers JPEG/WebP and the 5 MiB boundaries.

### Cross-service incompatibility: 1 negative test

Upload an image, get its actual URL, and try creating the matching article with
that unchanged URL. The observed URL is `http://127.0.0.1:19199/...`, which fails
the required `https://firebasestorage.googleapis.com/...` pattern. Assert creation
is denied, the article is absent and the uploaded image still exists.

This expected rejection passes the negative test. It is **not** a successful
integral publication. No HTTPS substitution, alternate rule, proxy, mixed real/
emulated service or emulator-specific production branch is used.

### Flutter integration feasibility

The frontend lacks `integration_test` and a native integration entry point. The
user chose not to add that dependency in this unit. No Flutter-to-emulator test
was added or run. Even with a harness, the unchanged integral flow would remain
blocked by the observed URL mismatch.

A future isolated Flutter service harness must use a separate demo Firebase app
and explicitly connect BOTH services before any calls; it must not invoke the
normal production `main()` or Firebase options. No production change is needed now.

## Pending manual Android / Firebase Console checklist

**Prepared only. None of these real-project steps were executed in Unit 6.**
Perform one controlled run when real-project testing is explicitly authorized.

### 1. Prepare the run

- APK: `frontend/build/app/outputs/flutter-apk/app-debug.apk`.
- Android application ID: `com.example.news_app_clean_architecture`.
- Console project: `symmetry-technical-test-62d73`.
- Bucket: `symmetry-technical-test-62d73.firebasestorage.app`.
- Image: ordinary, non-sensitive JPEG named `symmetry-u6-01.jpg`, around 800x600
  pixels, preferably below 500 KiB and always <=5,242,880 bytes. Record its byte
  size. Do not merely rename HEIC/GIF to JPEG.
- Record APK build/commit, device model, Android version, time and timezone.
- Use marker `20260918-01` for this first run; increment it for subsequent runs.

### 2. Exact input

| Field | Value |
| --- | --- |
| Author | `Symmetry QA` |
| Title | `Symmetry U6 - persistencia Android - 20260918-01` |
| Description | `Prueba manual de persistencia Firestore y Storage. Ejecucion 20260918-01.` |
| Content | `Articulo de prueba creado desde Android para validar la publicacion real. Marcador: 20260918-01. Debe conservarse al cerrar y volver a abrir la aplicacion.` |
| Image | JPEG described above, selected from the gallery |

### 3. Expected application behavior

1. Open the publication form from Home. Capture filled fields and image preview.
2. Tap Publish once. Expect loading and disabled submit while pending, then return
   to Home and `Article published successfully.`
3. The new article is **not expected in Home's NewsAPI feed**; it is unchanged.
4. On failure, preserve the form and collect evidence. Do not repeatedly submit
   or edit content before investigating the existing attempt.
5. After confirmed success, close the app completely and reopen it. Refresh the
   same document/object in Console and verify both persist. Reopening Home alone
   cannot establish persistence because it does not read Firestore articles.

### 4. Firestore checks

In Firestore Database's data view, locate the document in `articles` with the exact
run title. Record its generated document ID as `articleId`. Review exactly:

| Field | Expected type/value |
| --- | --- |
| `author` | String: exact author above |
| `title` | String: exact title above |
| `description` | String: exact description above |
| `content` | String: exact content above |
| `thumbnailURL` | String: real HTTPS Firebase Storage download URL |
| `publishedAt` | Timestamp near publication time |
| `createdAt` | Timestamp near publication time |
| `updatedAt` | Timestamp near publication time |

The three timestamps should be equal for this creation flow (Console may render
local time). No `id`, bytes, `storagePath` or status belongs inside the document.
Check that the URL decodes to the project's bucket and
`media/articles/{articleId}/thumbnail.jpg`; open it and verify the selected image.

### 5. Storage checks

Inspect exactly `media/articles/{articleId}/thumbnail.jpg` in Storage's files view.
Its folder ID must equal the Firestore document ID. Verify `contentType=image/jpeg`,
size matching selected source bytes and <=5 MiB, creation time near the run and the
correct image preview. The safe uploaded name is `thumbnail.jpg`, regardless of
the original gallery filename.

### 6. Evidence before cleanup

- Filled form and selected image preview.
- Loading state if practical, and Home's transient success message; a short screen
  recording can capture both.
- Firestore document ID, eight fields, timestamp types/values.
- Storage bucket/path, matching ID, MIME, size and preview.
- Successful image display through its download URL.
- The same document/object after closing/reopening the app and refreshing Console.
- Run marker, APK build, device and timestamps alongside the captures.
- Redact download-token query strings in shared screenshots/reports; retain the
  bucket/path evidence without sharing bearer download tokens.

### 7. Manual cleanup in Console after collecting evidence

1. Close the Android app so it has no pending publication operation.
2. Reconfirm the project name, run marker and exact recorded `articleId`.
3. Delete **only** `articles/{articleId}` using Firestore Console's document delete
   action. Do not delete the collection.
4. Delete **only** `media/articles/{articleId}/thumbnail.jpg` in Storage Console.
   Do not delete the bucket or unrelated folders; empty virtual folders may vanish.
5. Refresh both views, verify both exact resources are absent and capture cleanup
   evidence. Review any additional objects from failed attempts individually.

An authorized Console administrator performs cleanup. Do not change client rules,
add Flutter delete operations or deploy anything. These are two separate deletions,
not an atomic operation.

## Validation record

On 2026-09-18: 52/52 original rules tests passed; the new emulator command passed
20/20 tests (8 safety units + 12 integrations). The real local URL rejection was
observed with unchanged rules. Flutter validation results are reported separately
in the task. No real Firebase project validation has been performed by this unit.
