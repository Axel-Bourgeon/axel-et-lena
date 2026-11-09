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
- Signature : jusqu'au build-23 la clé `SIGNING_KEYSTORE_B64` n'était PAS utilisée (chaque APK avait une clé aléatoire). Depuis le 2026-11-04 : clé `axel-lena-release.p12` (sauvegarde dans `D:\ClaudeCode\axel-et-lena-cle-signature`, hors dépôt), secrets `RELEASE_KEYSTORE_B64` / `RELEASE_KEYSTORE_PASSWORD`, signingConfig explicite (patch_android.py) et contrôle de l'empreinte en CI (`scripts/signing_sha256.txt`). Une désinstallation unique a été nécessaire.
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
- [x] Mot du jour (Wordle FR, build-14) : mot choisi par le numéro du jour depuis le 2026-10-09 dans une liste mélangée de façon fixe → même mot pour les deux s'ils ont la même version. Listes tirées de Lexique 3.83 (CC BY-SA), `assets/words/` ; ne pas modifier `answers.txt` à la légère. Accents ignorés, clavier AZERTY, stats, résultat à copier pour Discord.
- [x] Fourmis : plus de grisé sur les pixels inaccessibles (2026-10-09, demande d'Axel)
- [x] « Au hasard » : photo tirée dans la galerie (album appareil photo de préférence) via photo_manager, pour Fourmis, Taquin, Picross ; aperçu masqué (« Photo mystère ») pour Taquin et Picross. L'écran Picross n'affiche plus la grille solution.
- [x] Pipopipette : photo cachée (au hasard dans la galerie, paysage dessiné en repli), chaque carré fermé révèle son morceau teinté de la couleur du joueur
- [x] Picross (build-16) : colorier recouvre tout, repasser la même couleur efface, outil gomme ; cases révélées teintées de la couleur posée (vides éclaircies), photo sans teinte à la victoire
- [x] Fourmis (build-16) : la fenêtre de réussite montre la photo d'origine (non pixellisée)
- [x] Outil Dés : pile ou face, D4–D100, formules (« 5D6 + 3 »), animation
- [x] C'est un 10, mais… (nombre secret 0–9, devinette avec points d'équipe)
- [x] Le Disque (façon Longueur d'onde) : banque `assets/disque/concepts.json` (230 couples + 16 thèmes, générée par un sous-agent Haiku, relue) ; 30 % des axes tirés dans un thème (deux éléments d'un même thème)
- [x] Accueil : chaque catégorie en bande horizontale de deux rangées (on glisse au-delà de 4 tuiles)
- [x] Mot du jour : toucher une case pour y placer une lettre (build-20)
- [x] Section Couple en tête de l'accueil : décompte jusqu'au 1er mai 2027 (naissance) + SA (convention 41 SA) ; Réglages « Ce téléphone est celui de Axel / Léna »
- [x] Applis couple codées (build-20), désactivées tant que `lib/couple/firebase_config.dart` est vide : Messages (dernière alerte de chacun), Bébé agenda (biberon mL, tétée, couche, dodo, autre, commentaires), Notes partagées
- [x] Firebase configuré le 2026-11-04 (build-21) : projet `lenaaxel-d83e0`, règles déployées (`npx firebase-tools deploy --only firestore:rules`, CLI connecté sur le PC d'Axel)
- [x] build-26 (2026-11-09) : Notes (curseur corrigé, Markdown, bouton enregistrer, copier), Devine-tête (écran maintenu allumé), lien 1000 premiers jours, valise « Pour Léna »
- [ ] Clé API Firebase : alerte GitHub « secret détecté » (non secret par conception) ; restreindre la clé dans Google Cloud (package + SHA-1 CF:AC:6E:6F:3E:25:CB:B0:F9:8E:BA:B1:D0:3B:12:7C:5E:97:D6:B4)
- [ ] Retours d'Axel et Léna après test sur téléphone

## Couple / Firebase — décisions

- Offre Spark (gratuite) : pas de Cloud Functions, donc pas de push serveur. Notifications = écoute Firestore en direct quand l'appli tourne + WorkManager toutes les ~15 min appli fermée (flutter_local_notifications).
- Auth anonyme ; espace `/couples/{code}` (code 10 caractères) ; rejoindre = s'ajouter à `members` ; règles dans `firebase/firestore.rules`.
- Hors ligne : cache local Firestore, écritures sans await.

## Idées / prochaines étapes

- Fourmis : sauvegarde de la partie en cours, sons/vibrations légers, niveaux de difficulté, galerie des images terminées, mode duo (deux fourmilières).
- Idées écartées par Axel : roue de décision (téléphones non reliés), liste de courses (déjà sur Discord).
- Autres idées proposées : duel de réflexes, « Qui de nous deux ? », feuille de scores de jeux de société, morpion ultime.
- Icône d'appli personnalisée.

## Plan « grosse update » (décidé le 2026-11-04)

Phase 1 — avant la naissance :
- [x] Réglages : « Notre espace » (revoir le code de liaison) (build-23)
- [x] Minuteur de contractions partagé (alerte 5-1-1 : toutes les 5 min pendant 1 h) (build-23)
- [x] Check-list valise maternité partagée (build-23)
- [x] (build-23, 28 fiches dans assets/conseils/conseils.json) Appli « Conseils bébé » : par âge et par thème, hors ligne, sources officielles citées (ameli, Santé publique France / 1000 premiers jours, HAS, OMS), urgences avec numéros

Phase 2 — pour avril :
- [ ] Agenda : dodo avec chrono partagé ou heures début/fin ; tétée avec durée et côté
- [ ] Agenda : stats 24 h / jour / semaine, graphiques, frise des 24 h
- [ ] Date de naissance réelle → âge du bébé à l'accueil, conseils selon l'âge

Phase 3 :
- [ ] Croissance (poids, taille, PC) avec courbes OMS
- [ ] Repérage de tendances

Idées non retenues pour l'instant : prénoms (vote secret), photos du ventre, tour de garde, humeur du jour.
