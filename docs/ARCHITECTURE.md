# Architecture — Launcher Modular

Document de référence sur la structure de l'application, destiné aux
développeurs et aux agents de code. Il décrit **ce qui est stable** :
organisation, modules, contrats et procédures. Les défauts connus et le
backlog sont dans `KNOWN_ISSUES.md` (même répertoire).

> Établi par analyse statique de la branche `develop` (version `2.5.0`).
> Aucune compilation ni exécution (desktop ou appareil) n'a servi à le rédiger.
> En cas de divergence, le code fait foi : corriger ce document.

## 1. Vue d'ensemble

Launcher alternatif plein écran pour Ubuntu Touch / Lomiri. Il affiche des
pages configurables dans un `SwipeView` (accueil, agenda, photos, RSS, musique,
vidéos, Nextcloud, tâches, horloge…) et des widgets sur la page d'accueil.

- Identifiant click : `launchermodular.lut11` — licence GPL-3.0
- Dépôt : `github.com/lutin11/launcher-modular` (fork de
  `ruditimmermans/launcher-modular`)
- Traductions : Hosted Weblate (`ubports/launcher-modular`)

## 2. Stack

| Technologie | Usage | Emplacement |
|---|---|---|
| QML (QtQuick 2.12, Lomiri.Components 1.3) | Interface et l'essentiel de la logique | `qml/` |
| JavaScript | Workers (HTTP, parsing RSS), helpers | `qml/**/*.js` |
| C++ / Qt 5 | Binaire principal, plugins d'extension QML | `main.cpp`, `windowcontroller.*`, `plugins/` |
| CMake | Build (builder `cmake` de Clickable) | `CMakeLists.txt`, `plugins/*/`, `po/` |
| gettext / intltool | Traductions, fusion du `.desktop` | `po/` |
| Clickable + Docker | Build, desktop, déploiement | `clickable.yaml` |

Frameworks ciblés : `ubuntu-touch-24.04-1.x` (référence), `20.04`, et
`ubuntu-sdk-16.04` (branches `*-xenial`). `clickable.yaml` n'en fixe aucun :
c'est la variable d'environnement `CLICKABLE_FRAMEWORK` qui sélectionne le
framework (README, CI). CI : `amd64`, `arm64`, `armhf` croisés avec
`ubuntu-touch-24.04-1.x` et `ubuntu-sdk-20.04`.

## 3. Architecture d'exécution

```
main.cpp  (QGuiApplication + QQmlEngine)
  - context property DEBUG_MODE        (constante compilée)
  - context property WindowController  (bascule plein écran)
  - polices DSEG7 (resources.qrc)
  - addImportPath(...)                 (chemin arm64 codé en dur)
      |
      v charge
qml/Main.qml   (MainView Lomiri) -- nœud central
  - Settings (Qt.labs.settings) : tous les réglages persistés
  - ListModel : pageModel, customIconModel, favoriteAppsModel
  - SwipeView : charge les pages (Qt.createComponent + Loader)
  - barre basse + panneau de réglages du bord bas (item, pas un Drawer) :
    Settings, Pagemanagement, Autostart, Help
      |                                   |
      | imports statiques                 | chargement dynamique
      v                                   v
Plugins C++ (singletons QML)         Pages (embarquées ou
                                     ~/.launchermodular/pages/)
```

Principes :

1. **Le C++ est un fournisseur de services.** Chaque plugin expose une classe
   (en général un singleton via `qmlRegisterSingletonType`). Toute la logique
   applicative vit en QML/JS.
2. **Les pages sont chargées dynamiquement dans le contexte de `Main.qml`.**
   Elles accèdent donc à l'id `launchermodular` (donc
   `launchermodular.settings`) et à `DEBUG_MODE`. Ce couplage implicite est le
   contrat des pages, y compris des pages personnalisées tierces.
3. Pages embarquées et pages externes utilisent le même code ; seul le champ
   `directory` de l'entrée diffère : `"pages/"` pour une page embarquée,
   `MySettings.getHomeLocation() + "/.launchermodular/pages/"` pour une page
   personnalisée (chemin absolu sur le système de fichiers, pas une URL
   `file://` — vérifié dans `Pagemanagement.qml`).

## 4. Structure du dépôt

```
.
├── main.cpp, windowcontroller.{h,cpp}   # binaire natif
├── CMakeLists.txt                       # exécutable, ressources, i18n, install
├── clickable.yaml                       # config Clickable
├── manifest.json.in                     # manifeste click (généré par CMake)
├── launchermodular.apparmor             # profil AppArmor
├── launchermodular.contenthub           # partages Content Hub
├── launchermodular.desktop.in           # fichier desktop (traduit via intltool)
├── resources.qrc, fonts/                # polices DSEG7 (horloge)
├── qml/
│   ├── Main.qml                         # point d'entrée, réglages globaux
│   ├── Settings, Pagemanagement, ImportPage, GlobalImportPage,
│   │   Autostart, Help, ChangeLogs, Translators (.qml)
│   ├── pages/                           # pages du SwipeView (+ <nom>/Settings.qml)
│   ├── widgets/                         # widgets de l'accueil (+ Settings)
│   ├── components/                      # composants réutilisables (RSS, formes…)
│   ├── helpers/                         # CachedHttpRequest (worker + cache U1db)
│   └── Jslibs/Processing/               # workers JS (flux, parsing)
├── plugins/                             # extensions QML en C++
├── po/                                  # traductions gettext (~60 langues)
├── assets/                              # logo, icônes, captures
└── .github/workflows/main.yml           # CI : build seulement
```

## 5. Plugins C++ (`plugins/`)

Gabarit commun : un `QQmlExtensionPlugin` (`plugin.cpp/h`), un `qmldir`, un
`CMakeLists.txt` propre ; installation dans `/lib/<triplet>/<Plugin>/`. **Les
plugins sont indépendants entre eux** et ne communiquent que par QML.

| Plugin | Rôle | Qt | Utilisé par |
|---|---|---|---|
| `AppHandler` | Inventaire des apps (`.desktop`, conteneurs Libertine), filtres, favoris, désinstallation | Core, Qml, Quick, DBus | `Main`, `Home`, `home/Settings`, `FavoriteApp` |
| `MySettings` | Locales utilisateur, fond d'écran via D-Bus AccountsService | Core, Qml, Quick, DBus | `Main`, Musique, Vidéos, Dossiers, Nextcloud, RSS settings, `FavoriteApp`, `Pagemanagement` |
| `Terminalaccess` | Exécution de commandes (`QProcess`, `sh -c`), helpers fichiers, détection de l'invite `sudo` | Core, Qml, Quick, DBus | `Home`, `MusicPlayer`, `NextcloudFolders` |
| `NetworkHelper` | Teste une URL et détecte un flux RSS/Atom | Core, Qml, Quick, DBus | `Rss`, `rss/Settings` |
| `ContactHelper` | Nom d'un contact depuis son id (backend `galera` codé en dur) | Qml, Quick, DBus, Contacts | `Lastcall`, `Lastmessage` |
| `LibertineLauncher` | Lance une app Libertine via `lomiri-app-launch` | Core, Qml, Quick, DBus | `Home` |
| `CalculatorHelper` | Mini-calculatrice (regex puis `QJSEngine`) | Core, Qml, Quick, DBus | `Home`, `widgets/Calculator` |
| `Platform` | Dépendances réellement présentes (fichiers, binaires du `PATH`, providers, un seul service D-Bus évalué paresseusement) et texte de diagnostic | Core, Qml, Quick, DBus | `Main`, `Home`, `Help`, `Pagemanagement`, `home/Settings`, `SearchContact`, `FavoriteContact` |

Hors plugins : `WindowController` (plein écran), utilisé par `Clock` et
`Picture`.

## 6. Code QML

### 6.1 `Main.qml`

Cœur de l'application : bloc `Settings` (≈65 propriétés persistées), trois
`ListModel` persistés, `SwipeView` des pages, barre de navigation, panneau de
réglages du bord bas et dialogue de création d'icône personnalisée. C'est aussi le
principal point de couplage : presque toutes les pages, widgets et composants
référencent `launchermodular`, `settings` et les `ListModel` racine.

### 6.2 Pages (`qml/pages/`)

Convention (identique pour pages embarquées et personnalisées) :

```
pages/
├── NomPage.qml            # composant affiché dans le SwipeView
└── nompage/               # nom en minuscules
    ├── Settings.qml       # réglages de la page (pageStack)
    └── assets/{icon.svg, page.png}
```

| Page | Points notables |
|---|---|
| `Home` | Grille d'apps, recherche (apps, contacts, web, calculatrice), favoris, lancement (`terminal:///`, Libertine), désinstallation |
| `Calendar` | QtOrganizer 5.0 |
| `Clock` | Horloge plein écran (DSEG7), `WindowController` |
| `Picture` | Galerie (FolderListModel, Thumbnailer) |
| `Music` + `music/` | `QtMultimedia`, playlists JSON, copie via `Terminalaccess` |
| `Videos` | FolderListModel + Thumbnailer |
| `Rss` + `rss/` | Singleton `RssModel` (LocalStorage), workers, cache U1db, `NetworkHelper` |
| `Todo` + `todo/` | Singleton `TodoModel` (LocalStorage) |
| `Folders` | Fichiers/dossiers, Content Hub |
| `NextcloudFolders` | Client WebDAV maison (`XMLHttpRequest` PROPFIND, auth Basic) |

### 6.3 Widgets, singletons, composants

- Widgets (`qml/widgets/`, chacun avec son `Settings.qml`) : `Clock`, `Weather`
  (OpenWeatherMap, clé API utilisateur), `Lastcall`, `Lastmessage`, `Event`,
  `Alarm`, `Calculator`, `FavoriteApp`, `FavoriteContact`, `SearchContact`.
- Singletons QML (`pragma Singleton`, via `qmldir`) : `RssModel`, `TodoModel`.
- `qml/components/` : `FeedsModel`, `Feed`, `FeedItem`, `RssChannel`,
  `RssChannelItems`, `PageUnavailable` (état vide d'une page non chargeable).
  `qml/helpers/` : `CachedHttpRequest` (worker + cache U1db),
  `PageRequirements.js` (table page embarquée → modules extérieurs requis).

### 6.4 Capacités : que faire d'une dépendance absente

Le lanceur peut se retrouver sur une machine où un module QML, un binaire ou un
provider manque (versions desktop, `.click` sans pile téléphonique). Règles :

- **l'état vient du plugin `Platform`** (§5), jamais d'une recherche faite dans
  un fichier QML ;
- **une dépendance fausse retire de la composition** : `Loader { active:
  Platform.<capacité> ; source: "…" }`. Un `visible: false` ne suffit **pas** :
  un `import` absent dans un fichier enfant fait échouer tout le composant
  parent, quelle que soit la propriété ;
- **une page déjà enregistrée** dont le module manque est remplacée par
  `components/PageUnavailable.qml`, qui nomme le module (§7, table dans
  `helpers/PageRequirements.js`) ;
- **les listes de sélection** (ajouter une page, réglages des widgets) ne
  proposent pas ce qui ne peut pas fonctionner ;
- **providers contacts et agenda** : `Platform.hasContactsFeature` et
  `hasCalendarFeature` valent vrai sur Ubuntu Touch (pile attendue, non sondable
  depuis le conteneur de référence) et exigent un provider exploitable ailleurs ;
  le nom du provider vient de `Platform.preferredContactManager`.

Détails, vérifications et limites : `docs/PACKAGING_DESKTOP.md` §10.

## 7. Dépendances

**Qt C++** : Core/Gui/Qml/Quick (binaire) ; DBus (AppHandler, MySettings,
LibertineLauncher…) ; Contacts (ContactHelper) ; Network (NetworkHelper).
**À l'exécution** : bus D-Bus (AccountsService), `sh`, `lomiri-app-launch`,
`click`.

**Modules QML** (résolus à l'exécution, selon le framework — **non vérifiés
par la CI**) :

- Lomiri : `Components 1.3` (+ Popups, ListItems, Themes), `History 0.1`,
  `Contacts 0.1`, `Thumbnailer 0.1`, `Content 1.3`, `Connectivity 1.0`,
  `DownloadManager 1.2`
- Qt : `QtGraphicalEffects 1.12`, `Qt.labs.settings`, `Qt.labs.folderlistmodel`,
  `QtQuick.XmlListModel`, `QtMultimedia 5.12`, `QtOrganizer 5.0`,
  `QtContacts 5.0`, `QtSystemInfo 5.0`, `QtSensors 5.12`,
  `QtQuick.LocalStorage 2.0`, `QtQml.Models`
- Tiers : `U1db 1.0` (cache RSS)

Ces modules ne sont **pas** garantis hors Ubuntu Touch. `Platform` (§5) teste
ceux dont dépend une fonctionnalité, et le code QML retire la fonction plutôt
que de l'afficher vide (§6.4). Les modules importés par `Main.qml`
(`QtGraphicalEffects`, `Qt.labs.folderlistmodel`, `Lomiri.Components`) restent
des dépendances **dures** du démarrage.

## 8. Données et persistance

| Mécanisme | Contenu | Emplacement |
|---|---|---|
| `Qt.labs.settings` (`Main.qml`) | ≈65 réglages, listes JSON `page`/`customIcon`/`favoriteApps`, identifiants Nextcloud | profil click |
| LocalStorage (SQLite) | Flux RSS (`RssModel`), tâches (`TodoModel`) | profil click |
| Fichiers | Playlists, caches musique/Nextcloud (`~/.cache/launchermodular.lut11/`), cache RSS U1db | dossier utilisateur |
| Pages personnalisées | Composants QML | `~/.launchermodular/pages/` |

Les `ListModel` racine sont sauvegardés dans `Component.onDestruction` de
`Main.qml` : un arrêt brutal perd les dernières modifications.

## 9. Internationalisation

- Code : `i18n.tr(...)`. Domaine gettext : `launchermodular.lut11`.
- Extraction `xgettext` vers `po/launchermodular.lut11.pot` (cible CMake
  `generate_pot`), fusion `update_po_files` (`msgmerge`), compilation `.mo` et
  installation par `po/CMakeLists.txt`.
- Traduction via Hosted Weblate (remote Git `weblate`) : **ne pas éditer les
  `.po` à la main**.

## 10. Build, packaging, CI

- `CMakeLists.txt` : exécutable `launchermodular`, ressources Qt,
  `configure_file(manifest.json.in)` (`@CLICK_ARCH@` fourni par
  dpkg-architecture ; `@CLICK_FRAMEWORK@` n'est défini nulle part dans le
  CMake et dépend du système de build — Clickable — pour être substitué),
  installation de `qml/`, `assets/`, manifeste, AppArmor, desktop, contenthub,
  `.mo`, plugins.
- AppArmor : template `unconfined` avec `policy_groups` calendar, networking,
  history, contacts, connectivity. **Décision délibérée, pas un défaut** : le
  launcher exécute des commandes shell (`Terminalaccess`, icônes
  `terminal:///`, lancement Libertine) et inventorie les fichiers d'autres
  paquets (`.desktop`, conteneurs Libertine) — impossible sous confinement
  click, les `policy_groups` seuls ne couvrant que des accès typés.
  L'OpenStore encadre ce cas : privilèges étendus ⇒ revue manuelle avec
  lecture du code source (app open source exigée, justification à fournir —
  open-store.io/submit, docs.ubports.com « AppArmor Policy Groups »). Ne pas
  étendre ce choix sans justification.
- Commandes Clickable : voir `AGENTS.md` (section Clickable).
- CI (`.github/workflows/main.yml`) : matrice `arch × framework`,
  `clickable build --libs --app`, artefacts `.click`.
  **Aucun test automatisé n'existe ; la CI ne fait que compiler.**
- **Versions desktop (`.deb`, AppImage) : non réalisées.** Clickable ne produit
  que du `.click` ; l'installation est pensée pour ce format
  (`CMAKE_INSTALL_PREFIX` et `DATA_DIR` valant `/`). L'étude de faisabilité —
  contrainte d'installation, dépendances réelles, fonctions indisponibles hors
  Ubuntu Touch, détection des capacités à ajouter, coûts de maintenance — est
  dans `PACKAGING_DESKTOP.md` (même répertoire).

## 11. Procédures

### Ajouter un réglage
Déclarer la propriété dans le bloc `Settings` de `Main.qml`, puis l'utiliser via
`launchermodular.settings.<nom>`. Une propriété non déclarée échoue à
l'exécution.

### Ajouter une page
1. Créer `pages/NomPage.qml`, `pages/nompage/Settings.qml` et
   `pages/nompage/assets/{icon.svg,page.png}`.
2. L'enregistrer comme entrée de `pageModel`. `Pagemanagement.qml` ajoute
   l'entrée au toucher (scan des deux dossiers via `FolderListModel`) ;
   `Main.qml` recharge la liste depuis `settings.page` au démarrage et en
   écrit une entrée par défaut. Forme exacte d'une entrée :

   ```qml
   // launchermodular.pageModel — append (Pagemanagement.qml)
   {
       "name": fileName,        // nom du fichier, ex. "Home.qml"
       "icon": <chemin icône>,  // "pages/<nomminuscule>/assets/icon.svg"
                                // ou absolu pour une page personnalisée
       "data": {},              // objet JSON libre persisté, injecté dans la
                                // page sous le nom "pageData"
       "directory": "pages/"    // page embarquée ; page personnalisée :
                                // MySettings.getHomeLocation()
                                //   + "/.launchermodular/pages/"
   }
   ```

   Le `Loader` de `Main.qml` instancie `Qt.createComponent(model.directory +
   model.name)` ; l'entrée par défaut créée au premier lancement est
   `{"name": "Home.qml", "icon": "pages/home/assets/icon.svg", "data": {},
   "directory": "pages/"}`.
3. Ajouter les chaînes avec `i18n.tr(...)` ; les `.po` sont régénérés via la
   cible CMake `generate_pot`, pas à la main.
4. Vérifier que tout import QML utilisé existe sur le framework cible. Si la
   page dépend d'un module **extérieur au projet** (`Lomiri.Thumbnailer`,
   `Lomiri.Content`, `QtMultimedia`…), l'inscrire dans
   `qml/helpers/PageRequirements.js` : la liste « ajouter une page » la retirera
   et `Main.qml` affichera `PageUnavailable` là où elle est déjà configurée
   (§6.4).

### Ajouter un widget
Créer `widgets/Nom.qml` et `widgets/nom/Settings.qml`, puis l'intégrer à
`pages/Home.qml` en suivant un widget existant (par exemple `Calculator`). Si le
widget importe un module extérieur, l'insérer dans un
`Loader { active: Platform.<capacité> ; source: "…" }` comme `Lastcall` ou
`Event`, et masquer l'interrupteur correspondant dans `pages/home/Settings.qml`
(§6.4).

### Ajouter un plugin C++
Créer `plugins/<Nom>/` sur le modèle d'un plugin existant
(`CMakeLists.txt`, `plugin.cpp/h`, `qmldir`), enregistrer le type avec
`qmlRegisterSingletonType` si c'est un service, puis déclarer le plugin : le
`CMakeLists.txt` racine ne fait qu'appeler `add_subdirectory(plugins)`, et
c'est `plugins/CMakeLists.txt` qui liste un `add_subdirectory` par plugin.

```cmake
# CMakeLists.txt (racine)
add_subdirectory(plugins)

# plugins/CMakeLists.txt — une ligne par plugin
add_subdirectory(AppHandler)
# ... (MySettings, NetworkHelper, Terminalaccess, ContactHelper,
#      LibertineLauncher, CalculatorHelper, Platform)
```

Chaque plugin s'installe avec son propre `CMakeLists.txt` (le modèle à
copier) :

```cmake
find_package(Qt5 REQUIRED COMPONENTS Core Qml Quick DBus)
add_library(${PLUGIN} MODULE ${SRC})
target_link_libraries(${PLUGIN} Qt5::Core Qt5::Qml Qt5::Quick Qt5::DBus)
set(QT_IMPORTS_DIR "/lib/${ARCH_TRIPLET}")   # via dpkg-architecture
install(TARGETS ${PLUGIN} DESTINATION ${QT_IMPORTS_DIR}/${PLUGIN}/)
install(FILES qmldir DESTINATION ${QT_IMPORTS_DIR}/${PLUGIN}/)
```

Le `qmldir` contient `module <Nom>` + `plugin <Nom>` ; l'import QML
`import <Nom> 1.0` est résolu à l'exécution depuis ce chemin d'installation.
Pas de dépendance C++ vers un autre plugin.

## 12. Contrats et invariants à préserver

- L'id `launchermodular` et `DEBUG_MODE` restent accessibles aux pages
  (compatibilité des pages tierces).
- Convention de nommage des pages et de leurs `Settings.qml`.
- Plugins indépendants ; la composition se fait uniquement en QML.
- Détection des dépendances : un seul producteur, le plugin `Platform`. Une
  capacité fausse **retire** la fonction de la composition (`Loader`), ne la
  cache pas avec `visible` — un `import` manquant casse le composant parent
  (§6.4).
- `Terminalaccess` : un seul `QProcess` partagé, appels bloquants — ne pas
  empiler de commandes concurrentes ni ajouter d'appels bloquants.
- Versions dupliquées à modifier ensemble : `manifest.json.in`, `appVersion`
  (`Main.qml`), `ChangeLogs.qml`.

## 13. Points sensibles (résumé)

Liste complète, détails et priorités : `KNOWN_ISSUES.md`.

- Sécurité : exécution de commandes shell et `sudo -S` ;
  identifiants Nextcloud en clair ; `Qt.openUrlExternally` sur les actions
  d'icônes personnalisées ; évaluation JS dans `CalculatorHelper`.
- Robustesse : lancement Libertine synchrone dans le thread GUI ; `Terminalaccess`
  bloquant et mono-processus ; propriété `rssFeedChanged` non déclarée ;
  pointeurs bruts `AppInfo` ; sauvegarde uniquement à la destruction.
- Portabilité : chemin d'import arm64 codé en dur dans `main.cpp` ;
  dépendances `clickable.yaml` obsolètes ; modules QML legacy à vérifier sur
  24.04 ; backend contacts `galera` codé en dur.
- Maintenabilité : fichiers QML monolithiques, logique métier dans les vues,
  aucun test, fichiers parasites suivis dans le dépôt.
