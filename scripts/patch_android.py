"""Adapte le projet Android généré par `flutter create` (exécuté en CI).

- nom affiché de l'appli
- visibilité des applis externes (<queries>) pour HabitKit et Discord
- MainActivity avec le canal de lancement d'applis
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAIN = ROOT / "android" / "app" / "src" / "main"
MANIFEST = MAIN / "AndroidManifest.xml"

QUERIES = """
        <package android:name="com.roehl.habitkit" />
        <package android:name="com.discord" />
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
        </intent>"""


def patch_manifest() -> None:
    text = MANIFEST.read_text(encoding="utf-8")
    text = re.sub(r'android:label="[^"]*"', 'android:label="Axel &amp; Léna"', text, count=1)
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


if __name__ == "__main__":
    patch_manifest()
    patch_activity()
    print(MANIFEST.read_text(encoding="utf-8"))
