# Axel & Léna — progression et objectifs (tenu par Claude)

Dernière mise à jour : 2026-10-08

## Principe de travail

- Axel veut agir le moins possible : Claude fait tout (code, compilation, livraison) et ne sollicite Axel que pour ce qui est impossible autrement.
- Travail dans une session **Claude Code** sur le PC d'Axel, clone dans `D:\ClaudeCode\axel-et-lena`, `gh` connecté au compte `Axel-Bourgeon` → push direct sur `main`.
- Livraison : APK compilé par GitHub Actions (`.github/workflows/build.yml`) → release GitHub `build-N`.
  - Lien de téléchargement stable : https://github.com/Axel-Bourgeon/axel-et-lena/releases/latest/download/axel-et-lena.apk

## Contraintes techniques

- Pas de Flutter installé en local → compilation uniquement en CI (Java 21 présent en local).
- Le dossier `android/` n'est pas versionné : `flutter create` en CI puis `scripts/patch_android.py` (nom de l'appli, `<queries>` HabitKit/Discord, MainActivity avec canal `axel_lena/launcher`).
- Signature : keystore stable dans le secret GitHub `SIGNING_KEYSTORE_B64` (copié en `~/.android/debug.keystore` en CI) → les mises à jour s'installent par-dessus sans désinstaller.
- L'ancien contournement Cowork (archive `incoming/app.tar.gz` déposée à la main) n'est plus utilisé.

## Décisions

- Stack : Flutter (Dart), Material 3, thème personnalisable (couleur, clair/sombre).
- Identifiant Android : `com.axelbourgeon.axel_lena` (ne plus changer, sinon les mises à jour ne s'installent plus par-dessus).
- HabitKit : package `com.roehl.habitkit` (repli : Play Store).
- Discord : serveur « Léna et Axel », id `1378749282177515722`, ouvert via `https://discord.com/channels/<id>` dans l'appli Discord (`com.discord`). Modifiable dans Réglages.
- Ajouter une sous-appli = une entrée dans `lib/apps/registry.dart`.

## Jeu « Fourmis » — règles retenues (v0.1)

- Photo (galerie/appareil) ou image « Surprise » générée → pixellisée (22/30/40 de large) → k-means à 3–10 couleurs.
- Sachets répartis en 4 colonnes ; seul le sachet du dessus de chaque colonne est prenable. 5 emplacements par défaut (3–7).
- Un sachet ouvert libère ses fourmis une à une ; chacune va au pixel accessible le plus proche de sa couleur (BFS), puis le rapporte au trou de fourmilière commun sous l'image (2026-10-09). Le sachet disparaît dès que toutes ses fourmis ont leur pixel, sans attendre leur retour.
- Accessible = pixel touchant une case vide reliée à l'extérieur. Les pixels non accessibles sont grisés.
- Ordre des sachets généré « de l'extérieur vers l'intérieur » (profondeur + bruit) pour que la partie soit faisable.
- Palette « écartée » (2026-10-08) : après le k-means, les couleurs sont repoussées les unes des autres dans Oklab (clarté peu pondérée → écarts de teinte), lib/games/fourmis/palette.dart. Choix Fidèles / Contrastées (défaut) / Extrêmes.
- Blocage (tous emplacements pris, aucune fourmi ne peut avancer) → « Un emplacement de plus » (max 8) ou recommencer.

## État

- [x] Ossature appli : accueil en tuiles par catégories, réglages, masquage de tuiles
- [x] Boutons HabitKit et Discord
- [x] Jeu Fourmis v0.1 + tests du moteur (joueur automatique)
- [x] Dépôt public, code déposé, secret `SIGNING_KEYSTORE_B64` en place
- [x] Passage sur Claude Code (push direct), workflow CI recréé
- [x] Premier build CI vert (build-1, 2026-10-08 : 8 tests OK, APK signé avec la clé stable)
- [x] Fourmis : palette écartée, sachets visibles, fourmilière commune (retours d'Axel du 2026-10-08/09)
- [x] Accueil : « Ensemble depuis X jours » (depuis le 1er juin 2017) — `lib/core/together.dart`
- [x] Tuile Agenda : Google Agenda ou Outlook (choix dans Réglages)
- [x] Puissance 4 (à deux ou contre le téléphone, minimax 3 niveaux)
- [x] Pipopipette (à deux ou contre le téléphone, 3 tailles)
- [x] Taquin photo (3×3 à 5×5)
- [x] Air hockey (écran partagé multi-touch, ou contre le téléphone)
- [x] Picross photo : grille 10/15/20, 1–4 couleurs + fond ; chaque ligne/colonne terminée révèle la vraie photo en HD ; validation par indices (toute solution valide acceptée)
- [ ] Mot du jour (Wordle FR) : même mot pour les deux le même jour via la date (pas de lien entre téléphones). Il faut une liste de mots français (mots à deviner + mots acceptés).
- [ ] Retours d'Axel et Léna après test sur téléphone

## Idées / prochaines étapes

- Fourmis : sauvegarde de la partie en cours, sons/vibrations légers, niveaux de difficulté, galerie des images terminées, mode duo (deux fourmilières).
- Idées écartées par Axel : roue de décision (téléphones non reliés), liste de courses (déjà sur Discord).
- Autres idées proposées : duel de réflexes, « Qui de nous deux ? », feuille de scores de jeux de société, morpion ultime.
- Icône d'appli personnalisée.
