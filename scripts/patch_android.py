"""Adapte le projet Android généré par `flutter create` (exécuté en CI).

- nom affiché de l'appli
- autorisation de lire les photos (photo au hasard)
- build.gradle.kts : desugaring (notifications) et minSdk ≥ 23 (Firebase)
- visibilité des applis externes (<queries>) : HabitKit, Discord, agendas
- MainActivity avec le canal de lancement d'applis
"""
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAIN = ROOT / "android" / "app" / "src" / "main"
MANIFEST = MAIN / "AndroidManifest.xml"

QUERIES = """
        <package android:name="com.roehl.habitkit" />
        <package android:name="com.discord" />
        <package android:name="com.google.android.calendar" />
        <package android:name="com.microsoft.office.outlook" />
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL" />
            <data android:scheme="tel" />
        </intent>
        <intent>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
        </intent>"""


PERMISSIONS = """
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
"""


def patch_manifest() -> None:
    text = MANIFEST.read_text(encoding="utf-8")
    text = re.sub(r'android:label="[^"]*"', 'android:label="Axel &amp; Léna"', text, count=1)
    # Photo au hasard dans la galerie (photo_manager).
    if "READ_MEDIA_IMAGES" not in text:
        text = re.sub(r"(<manifest[^>]*>)", r"\1" + PERMISSIONS.replace("\\", "\\\\"), text, count=1)
    if "com.roehl.habitkit" not in text:
        if "<queries>" in text:
            text = text.replace("<queries>", "<queries>" + QUERIES, 1)
        else:
            text = text.replace("<application", "<queries>" + QUERIES + "\n    </queries>\n    <application", 1)
    MANIFEST.write_text(text, encoding="utf-8")


def patch_activity() -> None:
    candidates = list(MAIN.glob("kotlin/**/MainActivity.kt"))
    if not candidates:
        sys.exit("MainActivity.kt introuvable")
    target = candidates[0]
    original = target.read_text(encoding="utf-8")
    m = re.search(r"^package\s+([\w.]+)", original, re.M)
    if not m:
        sys.exit("package introuvable dans MainActivity.kt")
    template = (ROOT / "scripts" / "android_overrides" / "MainActivity.kt").read_text(encoding="utf-8")
    target.write_text(template.replace("__PACKAGE__", m.group(1)), encoding="utf-8")


GRADLE = ROOT / "android" / "app" / "build.gradle.kts"


def patch_gradle() -> None:
    """Desugaring (flutter_local_notifications) et minSdk 23 (Firebase)."""
    text = GRADLE.read_text(encoding="utf-8")
    if "isCoreLibraryDesugaringEnabled" not in text:
        text, n = re.subn(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", text, count=1)
        if n == 0:
            sys.exit("compileOptions introuvable dans build.gradle.kts")
        text += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    text = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = maxOf(flutter.minSdkVersion, 23)", text)
    # Signature stable : sans elle, chaque build aurait une clé différente et
    # les mises à jour refuseraient de s'installer par-dessus.
    if os.environ.get("RELEASE_KEYSTORE") and "create(\"release\")" not in text:
        block = (
            "signingConfigs {\n"
            "        create(\"release\") {\n"
            "            storeFile = file(System.getenv(\"RELEASE_KEYSTORE\"))\n"
            "            storePassword = System.getenv(\"RELEASE_KEYSTORE_PASSWORD\")\n"
            "            keyAlias = \"axel-lena\"\n"
            "            keyPassword = System.getenv(\"RELEASE_KEYSTORE_PASSWORD\")\n"
            "        }\n"
            "    }\n\n"
            "    buildTypes {"
        )
        text, n = re.subn(r"buildTypes\s*\{", block, text, count=1)
        if n == 0:
            sys.exit("buildTypes introuvable dans build.gradle.kts")
        text, n = re.subn(
            r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
            'signingConfig = signingConfigs.getByName("release")',
            text,
        )
        if n == 0:
            sys.exit("signingConfig de release introuvable dans build.gradle.kts")
    GRADLE.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    patch_manifest()
    patch_activity()
    patch_gradle()
    print(GRADLE.read_text(encoding="utf-8"))
    print(MANIFEST.read_text(encoding="utf-8"))
