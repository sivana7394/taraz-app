// تنظیمات اتصال به Firebase و کد دعوت.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// مشخصات اتصال: تنظیمات پروژهٔ Firebase + شناسهٔ اتاق مشترک.
class FirebaseConn {
  final String apiKey;
  final String appId;
  final String projectId;
  final String messagingSenderId;
  final String roomId;

  const FirebaseConn({
    required this.apiKey,
    required this.appId,
    required this.projectId,
    required this.messagingSenderId,
    required this.roomId,
  });

  FirebaseConn copyWith({String? roomId}) => FirebaseConn(
        apiKey: apiKey,
        appId: appId,
        projectId: projectId,
        messagingSenderId: messagingSenderId,
        roomId: roomId ?? this.roomId,
      );

  Map<String, dynamic> toJson() => {
        'k': apiKey,
        'a': appId,
        'p': projectId,
        's': messagingSenderId,
        'r': roomId,
      };

  static FirebaseConn? fromJson(Map<String, dynamic>? m) {
    if (m == null) return null;
    final k = m['k'] as String?, a = m['a'] as String?, p = m['p'] as String?;
    if (k == null || a == null || p == null) return null;
    return FirebaseConn(
      apiKey: k,
      appId: a,
      projectId: p,
      messagingSenderId: (m['s'] as String?) ?? '',
      roomId: (m['r'] as String?) ?? '',
    );
  }

  String toStorageString() => jsonEncode(toJson());
  static FirebaseConn? fromStorageString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- کد دعوت

  static const _prefix = 'TARAZ1-';

  /// کد دعوت: فشرده و base64url، با پیشوند قابل تشخیص.
  String toInviteCode() {
    final raw = utf8.encode(jsonEncode(toJson()));
    final z = gzip.encode(raw);
    return _prefix + base64Url.encode(z).replaceAll('=', '');
  }

  /// از کد دعوت (با یا بدون فاصله/خط جدید) اتصال را استخراج می‌کند.
  static FirebaseConn? fromInviteCode(String input) {
    var s = input.trim().replaceAll(RegExp(r'\s+'), '');
    final i = s.indexOf(_prefix);
    if (i < 0) return null;
    s = s.substring(i + _prefix.length);
    // فقط کاراکترهای مجاز base64url
    s = s.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');
    try {
      final padded = s + '=' * ((4 - s.length % 4) % 4);
      final z = base64Url.decode(padded);
      final raw = gzip.decode(z);
      final m = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
      final c = fromJson(m);
      if (c == null || c.roomId.length < 20) return null;
      return c;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------- خواندن تنظیمات از کنسول Firebase

  /// متن کپی‌شده از کنسول Firebase را می‌خواند؛ هر دو شکل پشتیبانی می‌شود:
  ///  ۱) قطعهٔ firebaseConfig وب (apiKey, appId, projectId, messagingSenderId)
  ///  ۲) محتوای فایل google-services.json اندروید
  static FirebaseConn? parseConsoleText(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;

    // حالت google-services.json
    if (t.contains('project_info') && t.contains('mobilesdk_app_id')) {
      try {
        final m = jsonDecode(_extractJsonObject(t)) as Map<String, dynamic>;
        final pi = m['project_info'] as Map<String, dynamic>;
        final clients = (m['client'] as List).cast<Map<String, dynamic>>();
        final client = clients.first;
        final info = client['client_info'] as Map<String, dynamic>;
        final keys = (client['api_key'] as List).cast<Map<String, dynamic>>();
        return FirebaseConn(
          apiKey: keys.first['current_key'] as String,
          appId: info['mobilesdk_app_id'] as String,
          projectId: pi['project_id'] as String,
          messagingSenderId: (pi['project_number'] ?? '').toString(),
          roomId: '',
        );
      } catch (_) {
        return null;
      }
    }

    // حالت firebaseConfig (JS یا JSON یا حتی متن خام)
    String? grab(String key) {
      final re = RegExp('["\']?$key["\']?\\s*[:=]\\s*["\']([^"\']+)["\']');
      return re.firstMatch(t)?.group(1)?.trim();
    }

    final apiKey = grab('apiKey') ?? grab('api_key') ?? grab('current_key');
    final appId = grab('appId') ?? grab('mobilesdk_app_id');
    final projectId = grab('projectId') ?? grab('project_id');
    final sender = grab('messagingSenderId') ?? grab('project_number') ?? '';
    if (apiKey == null || appId == null || projectId == null) return null;
    if (!apiKey.startsWith('AIza') || !appId.contains(':')) return null;
    return FirebaseConn(
      apiKey: apiKey,
      appId: appId,
      projectId: projectId,
      messagingSenderId: sender,
      roomId: '',
    );
  }

  static String _extractJsonObject(String t) {
    final s = t.indexOf('{');
    final e = t.lastIndexOf('}');
    if (s < 0 || e <= s) return t;
    return t.substring(s, e + 1);
  }

  /// شناسهٔ اتاق تصادفی و غیرقابل‌حدس (۲۶ کاراکتر).
  static String newRoomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(26, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

/// قوانین امنیتی Firestore که کاربر باید در کنسول جای‌گذاری کند.
const firestoreRulesText = r'''rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // هر اتاق با یک شناسهٔ تصادفی بلند شناخته می‌شود؛ فهرست‌کردن اتاق‌ها ممنوع است.
    match /rooms/{roomId} {
      allow get, create, update: if roomId.size() >= 20;
      allow list, delete: if false;

      // همهٔ زیرمجموعه‌های اتاق (entries, receipts, settlements, inbox, …)
      match /{collection}/{docId} {
        allow read, write: if roomId.size() >= 20;
      }
    }
  }
}
''';
