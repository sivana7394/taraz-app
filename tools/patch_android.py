#!/usr/bin/env python3
"""پس از `flutter create`، پوشهٔ android را برای «تراز» تنظیم می‌کند:
   - نام اپ، مجوز اینترنت
   - minSdk 23
   - امضای release از android/key.properties
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "android", "app")


def read(p):
    with io.open(p, encoding="utf-8") as f:
        return f.read()


def write(p, s):
    with io.open(p, "w", encoding="utf-8") as f:
        f.write(s)


def patch_gradle_kts(p):
    s = read(p)
    orig = s
    # minSdk
    s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", s)
    # applicationId
    s = re.sub(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "ir.sivan.taraz"', s)
    # keystore properties loader (بالای بلوک android)
    if "keystoreProperties" not in s:
        # import ها باید در ابتدای فایل Kotlin باشند
        s = "import java.util.Properties\nimport java.io.FileInputStream\n\n" + s
        loader = (
            "val keystoreProperties = Properties()\n"
            'val keystorePropertiesFile = rootProject.file("key.properties")\n'
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
            "}\n\n"
        )
        s = s.replace("android {", loader + "android {", 1)
    # signingConfigs
    if "signingConfigs {" not in s:
        signing = (
            "    signingConfigs {\n"
            '        create("release") {\n'
            '            if (keystorePropertiesFile.exists()) {\n'
            '                keyAlias = keystoreProperties["keyAlias"] as String\n'
            '                keyPassword = keystoreProperties["keyPassword"] as String\n'
            '                storeFile = file(keystoreProperties["storeFile"] as String)\n'
            '                storePassword = keystoreProperties["storePassword"] as String\n'
            "            }\n"
            "        }\n"
            "    }\n\n"
            "    buildTypes {"
        )
        s = s.replace("    buildTypes {", signing, 1)
    s = re.sub(
        r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
        'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
        s,
    )
    if s != orig:
        write(p, s)
    print("patched", p)


def patch_gradle_groovy(p):
    s = read(p)
    orig = s
    s = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 23", s)
    s = re.sub(r"minSdk\s*=?\s*flutter\.minSdkVersion", "minSdk 23", s)
    s = re.sub(r'applicationId\s*=?\s*"[^"]+"', 'applicationId "ir.sivan.taraz"', s)
    if "keystoreProperties" not in s:
        loader = (
            "def keystoreProperties = new Properties()\n"
            "def keystorePropertiesFile = rootProject.file('key.properties')\n"
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
            "}\n\n"
        )
        s = s.replace("android {", loader + "android {", 1)
    if "signingConfigs {" not in s:
        signing = (
            "    signingConfigs {\n"
            "        release {\n"
            "            if (keystorePropertiesFile.exists()) {\n"
            "                keyAlias keystoreProperties['keyAlias']\n"
            "                keyPassword keystoreProperties['keyPassword']\n"
            "                storeFile file(keystoreProperties['storeFile'])\n"
            "                storePassword keystoreProperties['storePassword']\n"
            "            }\n"
            "        }\n"
            "    }\n\n"
            "    buildTypes {"
        )
        s = s.replace("    buildTypes {", signing, 1)
    s = re.sub(
        r"signingConfig\s+signingConfigs\.debug",
        "signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug",
        s,
    )
    if s != orig:
        write(p, s)
    print("patched", p)


SHARE_FILTERS = '''
            <!-- دریافت عکس رسید از گالری/اسکرین‌شات/پیام‌رسان‌ها (Share ← تراز) -->
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="image/*" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND_MULTIPLE" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="image/*" />
            </intent-filter>
            <!-- میانبرهای آیکون اپ -->
            <meta-data android:name="android.app.shortcuts" android:resource="@xml/shortcuts" />
'''


def patch_manifest(p):
    s = read(p)
    orig = s
    s = re.sub(r'android:label="[^"]*"', 'android:label="تراز"', s, count=1)
    if "android.permission.INTERNET" not in s:
        s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
    if "ACCESS_NETWORK_STATE" not in s:
        s = s.replace("<application", '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n    <application', 1)
    if "android.intent.action.SEND" not in s:
        # اولین intent-filter (MAIN/LAUNCHER) داخل MainActivity را پیدا و پس از آن اضافه می‌کنیم
        m = re.search(r"(<intent-filter>.*?android\.intent\.action\.MAIN.*?</intent-filter>)", s, flags=re.S)
        if m:
            s = s[: m.end()] + SHARE_FILTERS + s[m.end():]
        else:
            print("WARN: MAIN intent-filter not found; share filters not added", file=sys.stderr)
    if s != orig:
        write(p, s)
    print("patched", p)


MAIN_ACTIVITY = '''package ir.sivan.taraz

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * پل بومی: دریافت تصاویر Share شده و میانبرهای آیکون، و تحویل به Dart از طریق MethodChannel.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "ir.sivan.taraz/share"
    private var channel: MethodChannel? = null
    private var pending: HashMap<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShare" -> {
                    result.success(pending)
                    pending = null
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
        val p = pending
        if (p != null) {
            channel?.invokeMethod("onShare", p)
            pending = null
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        val payload = HashMap<String, Any?>()
        when (action) {
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                val paths = ArrayList<String>()
                if (uri != null) copyToCache(uri)?.let { paths.add(it) }
                if (paths.isEmpty()) return
                payload["paths"] = paths
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: return
                val paths = ArrayList<String>()
                for (u in uris) copyToCache(u)?.let { paths.add(it) }
                if (paths.isEmpty()) return
                payload["paths"] = paths
            }
            "ir.sivan.taraz.ADD_EXPENSE" -> payload["shortcut"] = "add"
            "ir.sivan.taraz.ADD_RECEIPT" -> payload["shortcut"] = "receipt"
            else -> return
        }
        // جلوگیری از پردازش دوباره پس از چرخش صفحه
        intent.action = Intent.ACTION_MAIN
        intent.removeExtra(Intent.EXTRA_STREAM)
        pending = payload
    }

    private fun copyToCache(uri: Uri): String? {
        return try {
            val dir = File(cacheDir, "shared")
            if (!dir.exists()) dir.mkdirs()
            val name = "share-" + System.currentTimeMillis() + "-" + (0..99999).random() + ".img"
            val out = File(dir, name)
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(out).use { output -> input.copyTo(output) }
            } ?: return null
            out.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}
'''

SHORTCUTS_XML = '''<?xml version="1.0" encoding="utf-8"?>
<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">
    <shortcut
        android:shortcutId="add_expense"
        android:enabled="true"
        android:icon="@mipmap/ic_launcher"
        android:shortcutShortLabel="@string/shortcut_add_short"
        android:shortcutLongLabel="@string/shortcut_add_long">
        <intent
            android:action="ir.sivan.taraz.ADD_EXPENSE"
            android:targetPackage="ir.sivan.taraz"
            android:targetClass="ir.sivan.taraz.MainActivity" />
    </shortcut>
    <shortcut
        android:shortcutId="add_receipt"
        android:enabled="true"
        android:icon="@mipmap/ic_launcher"
        android:shortcutShortLabel="@string/shortcut_receipt_short"
        android:shortcutLongLabel="@string/shortcut_receipt_long">
        <intent
            android:action="ir.sivan.taraz.ADD_RECEIPT"
            android:targetPackage="ir.sivan.taraz"
            android:targetClass="ir.sivan.taraz.MainActivity" />
    </shortcut>
</shortcuts>
'''

STRINGS_XML = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="shortcut_add_short">ثبت هزینه</string>
    <string name="shortcut_add_long">ثبت سریع هزینه</string>
    <string name="shortcut_receipt_short">عکس رسید</string>
    <string name="shortcut_receipt_long">عکس رسید و ثبت هزینه</string>
</resources>
'''


def write_native(app_dir):
    main = os.path.join(app_dir, "src", "main")
    kt_dir = os.path.join(main, "kotlin", "ir", "sivan", "taraz")
    os.makedirs(kt_dir, exist_ok=True)
    # هر MainActivity دیگری (مثلاً در مسیر پکیج قدیمی) را حذف می‌کنیم تا تداخل پیش نیاید
    for root, _dirs, files in os.walk(os.path.join(main, "kotlin")):
        for f in files:
            if f == "MainActivity.kt" and os.path.abspath(root) != os.path.abspath(kt_dir):
                os.remove(os.path.join(root, f))
    write(os.path.join(kt_dir, "MainActivity.kt"), MAIN_ACTIVITY)
    xml_dir = os.path.join(main, "res", "xml")
    os.makedirs(xml_dir, exist_ok=True)
    write(os.path.join(xml_dir, "shortcuts.xml"), SHORTCUTS_XML)
    values_dir = os.path.join(main, "res", "values")
    os.makedirs(values_dir, exist_ok=True)
    strings = os.path.join(values_dir, "strings.xml")
    if os.path.exists(strings):
        t = read(strings)
        if "shortcut_add_short" not in t:
            t = t.replace("</resources>", STRINGS_XML.split("<resources>")[1])
            write(strings, t)
    else:
        write(strings, STRINGS_XML)
    print("wrote MainActivity.kt, shortcuts.xml, strings.xml")


def patch_gradle_properties(p):
    s = read(p) if os.path.exists(p) else ""
    if "org.gradle.jvmargs" in s:
        s = re.sub(r"org\.gradle\.jvmargs=.*", "org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -XX:+HeapDumpOnOutOfMemoryError", s)
    else:
        s += "\norg.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G\n"
    write(p, s)
    print("patched", p)


def main():
    kts = os.path.join(APP, "build.gradle.kts")
    groovy = os.path.join(APP, "build.gradle")
    if os.path.exists(kts):
        patch_gradle_kts(kts)
    elif os.path.exists(groovy):
        patch_gradle_groovy(groovy)
    else:
        print("ERROR: android/app/build.gradle(.kts) not found", file=sys.stderr)
        sys.exit(1)
    patch_manifest(os.path.join(APP, "src", "main", "AndroidManifest.xml"))
    patch_gradle_properties(os.path.join(ROOT, "android", "gradle.properties"))
    write_native(APP)


if __name__ == "__main__":
    main()
