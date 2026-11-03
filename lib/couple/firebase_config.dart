import 'package:firebase_core/firebase_core.dart';

/// Configuration Firebase du projet (tirée de google-services.json).
/// null tant que le projet Firebase n'est pas créé : les applis du couple
/// affichent alors un message au lieu de planter.
///
/// Ces valeurs ne sont pas secrètes : l'accès aux données est protégé par les
/// règles Firestore (firebase/firestore.rules).
const FirebaseOptions? kFirebaseOptions = null;
