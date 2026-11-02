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


def patch_manifest(p):
    s = read(p)
    orig = s
    s = re.sub(r'android:label="[^"]*"', 'android:label="تراز"', s, count=1)
    if "android.permission.INTERNET" not in s:
        s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
    if "ACCESS_NETWORK_STATE" not in s:
        s = s.replace("<application", '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n    <application', 1)
    if s != orig:
        write(p, s)
    print("patched", p)


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


if __name__ == "__main__":
    main()
