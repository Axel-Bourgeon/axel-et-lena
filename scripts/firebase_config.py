"""Génère lib/couple/firebase_config.dart à partir de google-services.json.

usage : python scripts/firebase_config.py chemin/vers/google-services.json
"""
import json
import pathlib
import sys

PACKAGE = "com.axelbourgeon.axel_lena"
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "lib" / "couple" / "firebase_config.dart"

data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
info = data["project_info"]
client = next(
    (c for c in data["client"] if c["client_info"]["android_client_info"]["package_name"] == PACKAGE),
    None,
)
if client is None:
    sys.exit(f"Aucune appli Android « {PACKAGE} » dans ce fichier")

values = {
    "apiKey": client["api_key"][0]["current_key"],
    "appId": client["client_info"]["mobilesdk_app_id"],
    "messagingSenderId": info["project_number"],
    "projectId": info["project_id"],
    "storageBucket": info.get("storage_bucket", ""),
}
fields = "\n".join(f"  {k}: '{v}'," for k, v in values.items() if v)
OUT.write_text(
    f"""import 'package:firebase_core/firebase_core.dart';

/// Configuration Firebase du projet (générée depuis google-services.json par
/// scripts/firebase_config.py).
///
/// Ces valeurs ne sont pas secrètes : l'accès aux données est protégé par les
/// règles Firestore (firebase/firestore.rules).
const FirebaseOptions? kFirebaseOptions = FirebaseOptions(
{fields}
);
""",
    encoding="utf-8",
)
(ROOT / ".firebaserc").write_text(json.dumps({"projects": {"default": info["project_id"]}}, indent=2) + "\n", encoding="utf-8")
print("projet", info["project_id"], "->", OUT)
