# Bomoko Terminal

Client SSH élégant en Flutter, par **Bomoko Solution** (package `com.bomoko.terminal`).
Contact : WhatsApp +243891989036 · Telegram @worldsolutiontv

## Fonctions
- Hôtes : groupes, étiquettes, favoris, couleurs, rebond (host chaining), variables d'environnement,
  extrait lancé à la connexion, encodage UTF-8 / Latin-1, touche Suppr = Ctrl-H, couleurs par hôte.
- Terminaux : sessions multiples, connexion rapide (`ssh user@hôte -p port`), barre de touches (Échap, Tab, Ctrl, flèches…), copier/coller.
- SFTP : parcourir, créer, renommer, supprimer, aperçu, **envoi et téléchargement** avec barre de progression.
- Redirection de ports locale, extraits, trousseau de clés (stockage chiffré), historique, hôtes connus (vérification d'empreinte).
- Thèmes : clair / sombre / système, 3 ambiances sombres (Nuit, Graphite, Noir pur), 8 palettes de terminal.
- Langues : français et anglais (autres langues : ajouter une table dans `lib/l10n.dart`).
- Sécurité : verrouillage PIN, mots de passe et clés dans le coffre Android.

## Compiler
**Sur PC (Flutter ≥ 3.22)** : `./setup.sh` (ou `setup.bat`), puis `flutter build apk --release`.

**Sans rien installer** : poussez ce dossier sur GitHub, onglet *Actions* › *Build APK* › *Run workflow*,
puis téléchargez l'APK dans les artefacts.

`android/` est généré par `setup.sh` (aucun conflit Gradle/Kotlin). L'icône vient de `tools/make_icon.py`
et est intégrée par `flutter_launcher_icons`.

## Non inclus
Mosh, Telnet, agent forwarding, proxy SOCKS/HTTP, connexions maintenues en arrière-plan avec notification,
déverrouillage par schéma.
