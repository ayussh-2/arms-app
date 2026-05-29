# Reusable Flutter Multipart Upload Service

This guide explains how to use the newly created dynamic, reusable `UploadService` in the ARMS Flutter codebase.

---

## 🛠️ Upload Service Implementation (`upload_service.dart`)

The `UploadService` class handles direct multipart files/image uploads to Next.js R2 CDN API endpoints. It is located at:
👉 [upload_service.dart](file:///d:/Projects/arms/arms/lib/core/services/upload_service.dart)

### Key Features
1. **Dynamic Host Resolution**: It automatically parses the current API hostname and port from `DebugService().apiBaseUrl.value` (whether running on Localhost, an IP address, or production).
2. **Dynamic Extension/Mime Inferences**: Works with `.jpg`, `.jpeg`, `.png`, `.pdf`, or falls back to raw octet-stream bytes seamlessly.
3. **Fully Dynamic Parameters**: Customize endpoints, form keys, parent organizational folders, and extra metadata payloads.

---

## 🚀 How Image Compression is Kept Native and Fast
Instead of adding the heavy `image` package which compiles single-threaded Dart code (causing frame-drops and large app sizes), the app uses native `ImagePicker` settings during selection:
```dart
final picker = ImagePicker();
final pickedFile = await picker.pickImage(
  source: ImageSource.gallery,
  maxWidth: 1600, // Maximum dimensions
  maxHeight: 1600,
  imageQuality: 85, // Native highly-optimized JPG/PNG compression
);
```

---

## 📂 Custom Usage Examples

### Example 1: Uploading Leave Application Documents (Active Implementation)
Automatically integrated inside the `LeaveApplyScreen` submit action:
```dart
final orgFolder = AuthService.currentAdmin?.organization?.name ?? 'org';

final uploadedUrl = await UploadService.uploadFile(
  apiUrlPath: '/api/leave-applications',
  organisationFolder: orgFolder,
  filenameBase: 'timestamp-roll_no-school-class-section',
  file: File(localAttachmentPath),
  formFieldName: 'image', // custom Next.js form-data field name
);
```

### Example 2: Dynamic Uploading of Student Profile Avatars (Dynamic endpoint)
You can easily repurpose the function to upload to `/api/students/profile` with extra custom form fields:
```dart
final profileUrl = await UploadService.uploadFile(
  apiUrlPath: '/api/students/profile',
  organisationFolder: 'avatars',
  filenameBase: 'student_1234_avatar',
  file: avatarFile,
  formFieldName: 'avatar',
  extraFields: {
    'studentId': '1234',
    'uploadedBy': 'admin',
  },
);
```
