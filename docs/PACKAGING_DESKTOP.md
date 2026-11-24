# Étude — versions desktop : `.deb` (Ubuntu Lomiri) et AppImage (autres distributions)

> **Statut : étude dépassée par les faits sur plusieurs points — voir §3.1,
> §10 et `PACKAGING_WORKLOG.md`.** Un mode `DESKTOP_INSTALL` est appliqué au
> build, un `.deb` (CPack) et une AppImage (linuxdeploy + appimagetool) sont
> produits et vérifiés en conteneur ; ni l'un ni l'autre n'est testé sur une
> machine réelle.
>
> Direction retenue : un **`.deb`** pour « Ubuntu Lomiri desktop » (base :
> Ubuntu 24.04 + `ppa:lomiri/stable`) et un **AppImage** universel pour les
> autres distributions ; le `.rpm` Mageia / ROSA est écarté (§8). Dans les deux
> cas, une **détection des capacités** au démarrage doit cesser de proposer ce
> dont les dépendances sont absentes (§10).
>
> Convention : **(V)** = vérifié (fichier lu, commande exécutée, source
> officielle consultée — voir annexe A) ; **(I)** = inféré, à confirmer.
> Annexe B liste ce qui reste non vérifié.

## 1. Réponse en bref

- **Clickable ne sait pas faire ça.** Clickable 8.10.0 (version installée ici)
  n'a aucune sortie deb/rpm : `build`, `install`, `publish`, `review`,
  `desktop`, `ci`… uniquement pour le format click **(V)**. Un `.deb` et un
  `.rpm` sont donc du **packaging écrit et maintenu à la main**, avec leur CI
  propre.
- **`.deb` Ubuntu 24.04 : plus facile que prévu.** Vérification faite paquet par
  paquet : **le bureau Lomiri est dans l'archive `noble` (universe)**, empaqueté
  par la « Debian UBports Team » — `lomiri` `0.2.1-10build1`,
  `lomiri-desktop-session` `0.2-11` (session de bureau), `lomiri-app-launch`
  `0.1.9-3`, `content-hub` `1.1.1-1build5`, `lomiri-history-service` `0.5-1build3`,
  `lomiri-download-manager` `0.1.3-4build3`, `maliit-keyboard`, et 22 paquets
  `qml-module-lomiri-*` **(V)**. Toutes les dépendances QML de l'app y sont donc,
  **sauf la pile contacts et les providers de contacts** (§4.2). Le pocket
  `noble-proposed` contient en outre la mise à jour en cours
  (`lomiri` `0.2.1-10ubuntu0.1`), base de test retenue. Le vrai point dur n'est
  pas la dépendance : c'est que l'installation du projet écrit **à la racine `/`**
  et ne peut donc pas devenir un paquet (§3).
- **`.rpm` écarté, et pour cause.** Aucun paquet Lomiri trouvé pour Mageia ni
  ROSA (§8) : sans `qml-module-lomiri-components`, `import Lomiri.Components
  1.3` (`qml/Main.qml:6`) échoue et l'app ne démarre pas. Un `.spec` n'y change
  rien. L'AppImage est la réponse à ce problème d'absence.
- **AppImage : le socle Qt5/QML est relocalisable, les services non.** Les
  chemins d'import QML se règlent par `qt.conf` + RPATH `$ORIGIN`, pas par
  `QML2_IMPORT_PATH`. En revanche `Lomiri.Content`, `.History`, `.Thumbnailer`,
  `.DownloadManager` sont des clients de **démons D-Bus** qu'un AppImage
  n'installe pas : sur une distribution qui ne les a pas, rien ne répond (§9.2).
  **Aucun précédent** d'app `Lomiri.Components` en AppImage trouvé.
- **Le socle du build est imposé par le PPA.** `ppa:lomiri/stable` ne publie
  que Noble et Resolute **(V)** : on ne peut pas construire sur une base plus
  ancienne pour abaisser le glibc minimum. Un AppImage bâti sur Noble risque de
  ne pas démarrer sur une distribution plus ancienne **(I — à mesurer sur place
  avec `ldd --version` avant tout engagement)**.
- **Un paquet ne répare pas les fonctions liées à Ubuntu Touch** : Libertine
  (absent d'Ubuntu 24.04, vérifié), désinstallation via `click`, contacts
  `galera`, dernier appel / dernier message (§5). D'où la **détection des
  capacités** demandée : le concevoir maintenant, car les deux formats en ont
  besoin et que le `.click` n'en est pas dispensé non plus (§10).
- **Coût le plus bas** si l'objectif est de faire essayer l'app : layout `/opt`
  ou AppDir (aucun changement de code pour le binaire, §6 option A), `CPack`
  pour le `.deb`. **Coût le plus haut** pour entrer dans les dépôts d'une
  distribution, ou pour faire tourner les fonctions dépendantes de services.

## 2. Ce que produit l'outil actuel

| Élément | État |
|---|---|
| Clickable 8.10.0, builder `cmake` | produit un `.click`, rien d'autre **(V)** |
| `clickable ci` (`clickable build --libs --app`) | seul pipeline actuel, documenté dans le README |
| `.github/workflows/` | ne compile que le click ; liste des fichiers à ne pas modifier sans accord (`AGENTS.md`) → des jobs deb/rpm supposent un accord explicite |
| `click-review` | ne valide que le format click ; un `.deb` n'a aucun équivalent de relecture automatique |

## 3. Ce qui empêche d'empaqueter en l'état (toutes cibles confondues)

| # | Constat | Emplacement | Conséquence hors click | Correctif minimal |
|---|---|---|---|---|
| 1 | `CMAKE_INSTALL_PREFIX /` et `DATA_DIR /` : la compilation installe `qml/`, `assets/`, le binaire, `launchermodular.desktop`, `manifest.json`, `.apparmor`, `.contenthub` **à la racine du système** ; les traductions vont dans `/share/locale/…` **(V)** | `CMakeLists.txt:25-26`, `:41-49`, `:75`, `po/CMakeLists.txt:55` | un paquet ne peut pas écrire `/qml` ni `/share` (hors FHS, refusé par tout dépôt) | rendre `DATA_DIR` préfixable (`${CMAKE_INSTALL_PREFIX}/…`) |
| 2 | fichiers propres au click installés : `manifest.json`, profil AppArmor de type click, hook content-hub **(V)** | `CMakeLists.txt:45-47` | fichiers inertes dans un paquet ; un profil AppArmor click ne s'applique pas à un binaire système **(I)** | option CMake (`CLICK_PACKAGING`, `ON` par défaut) pour ne les installer que dans le click |
| 3 | chaque plugin s'installe dans `/lib/${ARCH_TRIPLET}/<Module>/` (la racine définit aussi un `QT_IMPORTS_DIR`, sur `lib/…` cette fois, sans s'en servir). Ce chemin n'est un chemin d'import **que parce que le lanceur click pose `QML2_IMPORT_PATH`** **(V)** : la variable est manipulée par `liblomiri-app-launch.so`. Test : le dossier de l'exécutable, lui, est bien un chemin d'import par défaut de Qt **(V)** | `CMakeLists.txt:21` (inutilisé), `plugins/*/CMakeLists.txt:25,27-28` | hors `lomiri-app-launch`, `import MySettings 1.0` & co ne résolvent pas : il faut poser les modules soit à côté du binaire (`<dir>/MySettings/qmldir`), soit dans le dossier QML système | voir §6 (A : destination CMake à côté du binaire, aucun changement de code ; B : `addImportPath` via `__ARCH_TRIPLET__`) |
| 4 | `dpkg-architecture` appelé 2 fois à la racine (`-qDEB_HOST_MULTIARCH`, `-qDEB_HOST_ARCH` pour le manifest) **et 1 fois dans chacun des 7 plugins** **(V)** | `CMakeLists.txt:16` et `:34`, `plugins/*/CMakeLists.txt:20` | outil absent d'une distribution RPM → triplet vide → installation dans `/lib//MySettings` | `find_program` + repli (`gcc -dumpmachine`, ou variable fournie par le `.spec`) |
| 5 | `.desktop` : `Exec=launchermodular`, `Icon=assets/logo.svg`, `X-Lomiri-Touch`, `X-Lomiri-Single-Instance` **(V)** | `launchermodular.desktop.in` | nom d'exécutable introuvable si le binaire n'est pas dans le `PATH` ; icône relative sans sens hors click | `Exec=` absolu + icône installée dans hicolor |
| 6 | `main.cpp` ajoute en dur `/usr/lib/aarch64-linux-gnu/lomiri/qml/` et charge `qml/Main.qml` **relativement au dossier de l'exécutable** **(V)** | `main.cpp:23` (`addImportPath`), `main.cpp:42` (`setSource`) | le chemin codé **n'existe pas** dans le rootfs 24.04 (`ls` et `dpkg -S` vides) et Qt ignore un chemin d'import inexistant → non bloquant pour un desktop x86_64, mais faux pour un desktop arm64 | utiliser la macro `__ARCH_TRIPLET__` déjà définie (`CMakeLists.txt:38`) et jamais employée — c'est déjà le backlog §3.1 de `KNOWN_ISSUES.md` |

### 3.1 Correctifs appliqués

Les six constats sont traités par un **mode desktop** ajouté au `CMakeLists.txt`,
sans changer le build click. Vérifié dans le conteneur de référence : un
`make install` en configuration par défaut reproduit le **même arbre** qu'avant
(binaire, `qml/`, `assets/`, `manifest.json`, `launchermodular.apparmor`,
`launchermodular.contenthub`, `launchermodular.desktop` avec
`Icon=assets/logo.svg`, 8 modules sous `lib/<triplet>/`, 63 langues sous
`share/locale`).

- **Constats 1 et 2** — `option(DESKTOP_INSTALL OFF)` : en mode desktop,
  `<prefix>/bin/launchermodular`, `<prefix>/share/launchermodular/{qml,assets}`,
  `<prefix>/share/applications/launchermodular.desktop`, les icônes en hicolor
  **et** dans `share/pixmaps` (trouvable sans régénérer un cache d'icônes, ce
  qu'un paquet sans debhelper ne fait pas), et les traductions sous
  `<prefix>/share/locale` — destination rendue **relative** dans
  `po/CMakeLists.txt`, ce qui donne `/share/locale` avec le préfixe `/` du
  click comme avant. Un second option, `INSTALL_CLICK_FILES`, ne plus installer
  manifest, profil AppArmor et hook content-hub que pour le click.
- **Constat 3** — `PLUGIN_IMPORT_DIR` est défini à la racine et employé par les
  8 plugins (repli sur la valeur historique quand un plugin est configuré seul).
  En mode desktop les modules vont dans `<prefix>/lib/<triplet>/launchermodular/`
  et le binaire ajoute ce dossier à `engine.addImportPath()` : c'est le
  **layout B du §6**. Le chemin d'installation des plugins est passé d'absolu
  (`/lib/…`, qui ignorait le préfixe) à relatif.
- **Constat 4** — `find_program(dpkg-architecture)` avec repli sur
  `CMAKE_LIBRARY_ARCHITECTURE`, puis `lib/` sans triplet.
- **Constat 5** — `launchermodular.desktop.in` n'est **pas** modifié : en mode
  desktop, `cmake/SetDesktopIcon.cmake` remplace `Icon=` par le nom du thème
  après `intltool-merge`. Note de méthode : un `sed` avec `|` comme séparateur
  ne fonctionne pas ici, CMake écrit l'argument **sans guillemets** dans
  `build.make` et le shell en fait un tuyau (erreur 126).
- **Constat 6** — `main.cpp` cherche `qml/Main.qml` dans l'ordre : variable
  d'environnement `LAUNCHERMODULAR_DATA_DIR` → `$APPDIR/usr/share/…` (AppImage)
  → dossier de l'exécutable (click) → macro `LAUNCHERMODULAR_DATA_DIR` posée par
  CMake. Le chemin d'import Lomiri est bâti depuis `__ARCH_TRIPLET__`, qui sert
  enfin, et le `setSource` passe par `QUrl::fromLocalFile`.
- **Vérification du mode desktop de bout en bout** (24/11/2026, dans le
  conteneur de référence, copie du dépôt hors `/src`) : configuration
  `-DDESKTOP_INSTALL=ON`, compilation, `make install` dans `/usr`, puis
  exécution de `/usr/bin/launchermodular`. Résultats :
  - le binaire contient bien les littéraux attendus (`strings` sur le binaire) :
    `/usr/share/launchermodular`, `/usr/lib/x86_64-linux-gnu/launchermodular`,
    `/usr/lib/%1/lomiri/qml` — les macros `LAUNCHERMODULAR_DATA_DIR`,
    `LAUNCHERMODULAR_IMPORT_DIR` et `__ARCH_TRIPLET__` sont appliquées ;
  - **aucune erreur de chemin au démarrage** : `qml/Main.qml` est trouvé sous
    `/usr/share/launchermodular` (les avertissements QML remontent depuis
    `file:///usr/share/launchermodular/qml/ChangeLogs.qml`, la page Aide se
    charge, l'alarm manager retombe sur `memory` faute de provider `eds` —
    comportement attendu dans ce conteneur) ;
  - `LAUNCHERMODULAR_DATA_DIR=/nonexistent` (avec l'arbre installé déplacé) :
    le message d'aide `qml/Main.qml not found. Set LAUNCHERMODULAR_DATA_DIR…`
    apparaît, la variable d'environnement commande donc bien la résolution.
- Le `.deb` est produit par **CPack** (`cpack -G DEB`), pas par debhelper :
  vérifié, `debhelper` et `dh` sont absents du conteneur Clickable. Version,
  description et mainteneur sont **lus dans `manifest.json.in`**, pour ne pas
  ajouter un cinquième endroit où écrire le numéro de version (§7.1).

## 4. Dépendances réelles

### 4.1 Modules importés et paquets correspondants

Méthode : inventaire des `import` dans `qml/` et `plugins/` (≈70 déclarations),
puis `dpkg -S` de chaque dossier de module dans l'image SDK
`clickable/amd64-ut24.04-1.x-amd64` (base **Ubuntu 24.04.5**, paquets natifs
x86_64), recoupé avec `packages.ubuntu.com` (suite `noble`, toutes sections et
architectures) **(V)**.

| Module importé | Paquet | Dans `noble` |
|---|---|---|
| `QtQuick 2.12`, `QtQuick.Layouts`, `QtQuick.Window`, `QtQml.Models` | `qml-module-qtquick2`, `-qtquick-layouts`, `-qtquick-window2`, `-qtqml-models2` | oui |
| `QtQuick.Controls 2.2` / `2.12` | `qml-module-qtquick-controls2` | oui |
| `QtGraphicalEffects 1.12` (déprécié, règle 7 de `AGENTS.md`) | `qml-module-qtgraphicaleffects` | oui |
| `Qt.labs.settings 1.0`, `Qt.labs.folderlistmodel 2.12` | `qml-module-qt-labs-settings`, `qml-module-qt-labs-folderlistmodel` | oui |
| `QtQuick.LocalStorage 2.0`, `QtQuick.XmlListModel 2.12` | `qml-module-qtquick-localstorage`, `-qtquick-xmllistmodel` | oui |
| `QtMultimedia 5.12`, `QtSensors 5.12` | `qml-module-qtmultimedia`, `qml-module-qtsensors` | oui |
| `QtOrganizer 5.0`, `QtContacts 5.0` (Qt Mobility) | `qml-module-qtorganizer`, `qml-module-qtcontacts` (`5.0~git2020…`) | oui |
| `QtSystemInfo 5.0` | `qml-module-qtsysteminfo` | oui |
| `U1db 1.0` | `qml-module-u1db` + `libu1db-qt5-3` | oui |
| `Lomiri.Components 1.3` (+ `.ListItems`, `.Popups`) | `qml-module-lomiri-components` (`1.3.5100+dfsg`) | oui |
| `Lomiri.Components.Themes 1.3` | `lomiri-ui-toolkit-theme` (installé dans l'image SDK **(V)**) | nom dans l'archive non revérifié **(I)** |
| `Lomiri.History 0.1` | `qml-module-lomiri-history` + service `lomiri-history-service` | oui |
| `Lomiri.Thumbnailer 0.1` | `qml-module-lomiri-thumbnailer` (`3.0.3` dans noble) | oui |
| `Lomiri.Content 1.3` | `qml-module-lomiri-content` + `content-hub` | oui |
| `Lomiri.Connectivity 1.0` | `qml-module-lomiri-connectivity` | oui |
| `Lomiri.DownloadManager 1.2` | `qml-module-lomiri-downloadmanager` + `lomiri-download-manager` | oui |
| `Lomiri.Contacts 0.1` | `qml-module-lomiri-contacts` | **non** dans l'archive ; via le PPA (§4.2) |
| 7 plugins du dépôt (`MySettings`, `AppHandler`, `NetworkHelper`, `Terminalaccess`, `ContactHelper`, `LibertineLauncher`, `CalculatorHelper`) | construits par le dépôt ; liées `Qt5::Core/Qml/Quick/DBus` ; `MySettings` dialogue avec `org.freedesktop.Accounts` **(V)** | dépendances Qt standard disponibles |

### 4.2 Ce qui n'est pas dans l'archive Ubuntu 24.04

- **Pile contacts** — vérification paquet par paquet sur
  `packages.ubuntu.com/noble/<paquet>`, le 22/11/2026 :

  | Nom testé | État dans `noble` |
  |---|---|
  | `qml-module-lomiri-components` | **présent** (`1.3.5100+dfsg-1build2`, libs) |
  | `qml-module-lomiri-content`, `qml-module-lomiri-thumbnailer`, `qml-module-lomiri-history`, `qml-module-lomiri-downloadmanager`, `qml-module-lomiri-connectivity` | **présents** |
  | `qml-module-u1db` | **présent** (`0.1.7-1build2`, libs) |
  | `lomiri` (`0.2.1-10build1`), `lomiri-desktop-session`, `lomiri-app-launch`, `content-hub` (`1.1.1-1build5`), `lomiri-history-service` (`0.5-1build3`), `lomiri-download-manager`, `suru-icon-theme`, `lomiri-sounds` | **présents** |
  | `qml-module-lomiri-contacts` | **existe mais « not available in this suite »** → non installable sur 24.04 |
  | `qtcontact5-galera`, `qtcontacts-sqlite`, `qtorganizer-eds`, `lomiri-thumbnailer`, `lomiri-contacts-service`, `lomiri-ui-toolkit`, `qqc2-suru-style`, `lomiri-session` | **« No such package »** : ce ne sont pas des noms de paquets Ubuntu (dépôt Lomiri / PPA / noms sources) |

  Le module contacts est donc le seul manquant côté archive, et les providers
  ci-dessus ne s'installent que par le PPA. Les noms exacts des **binaires**
  fournis par le PPA restent à confirmer sur une vraie installation
  24.04 + PPA **(I)**.
- **Correction apportée par la recherche sur le PPA** : ce dernier fournit aussi
  des **providers QtContacts / QtOrganizer** — `qtcontacts-sqlite`,
  `qtorganizer-eds`, `qtorganizer-mkcal`, et les sources `qtpim-opensource-src`
  et `qtsystems-opensource-src` **(V, page du PPA ; noms des modules installés
  non revérifiés)**. Le blocage contacts n'est donc **pas** l'absence de contacts
  sur desktop : c'est le **nom du provider écrit en dur**. Le code réclamait
  `galera` (`plugins/ContactHelper/contacthelper.cpp:9`,
  `qml/widgets/SearchContact.qml:46`, `qml/widgets/FavoriteContact.qml:67`)
  et `galera` n'est pas fourni par l'archive **(V ; son existence dans la pile
  UBports est présumée, non revérifiée ici)**. **Fait** : les deux widgets QML
  lisent désormais `Platform.preferredContactManager` (§10.4), qui garde
  `galera` en premier choix et s'adapte sinon ; le constructeur C++ de
  `ContactHelper` conserve `galera` en dur, non modifié (§10.6).
- **Aucun provider de contacts dans l'archive** : la recherche `qtcontact` sur
  `noble` ne renvoie **qu'un seul** paquet, `qml-module-qtcontacts` (le module
  QML), **sans aucun provider** derrière **(V)**. Le module se charge, `QContactManager`
  ne trouve personne. Sans le PPA, les fonctions contacts sont donc
  structurellement vides sur Ubuntu 24.04.
- **Outil `click`** : la page `packages.ubuntu.com/noble/click` existe (section
  admin) mais ses publications n'affichent que **jammy** — `click` n'est **pas
  installable sur 24.04** **(V)**. La désinstallation d'un paquet click n'a donc
  pas de sens dans un `.deb` noble : `Platform.canUninstallApps` est faux et la
  demande de `sudo` disparaît (§10.5).
- **Libertine** : la seule correspondance « libertine » dans `noble` est
  `fonts-linuxlibertine`… une police **(V)**. `libertined` et `python3-libertine`
  viennent du dépôt UBports. La fonction « applications Libertine » est donc
  **impossible sur un Ubuntu 24.04 desktop**, paquet ou non.
- **Dépendances à ne pas recopier aveuglément** : `clickable.yaml` déclare
  `libpam0g-dev` et `libgsettings-qt-dev`, mais aucune utilisation de PAM ni de
  GSettings n'a été trouvée dans le code ni dans les `CMakeLists` **(V, grep)**
  → dépendances présumées héritées du modèle de projet **(I)** ; ne pas les
  mettre dans `debian/control` / `BuildRequires` sans besoin identifié.

### 4.3 Couverture du PPA `lomiri/stable`

- Publie pour **Noble** et **Resolute**, 156 paquets source, dont
  `lomiri-ui-toolkit` (`1.3.6000`, fournit `Lomiri.Components 1.3`),
  `lomiri-content-hub`, `lomiri-history-service`, `lomiri-thumbnailer`,
  `lomiri-download-manager`, `lomiri-app-launch`, `suru-icon-theme`,
  `qqc2-suru-style`, les providers cités au §4.2 **(V, page Launchpad)**.
  **Correction** : le hub de contenu s'appelle **`content-hub`** dans `noble`
  (`1.1.1-1build5`, avec `libcontent-hub1` et `qml-module-lomiri-content`)
  **(V)** ; le nom `lomiri-content-hub`, affiché par la page du PPA, n'existe
  pas dans `noble` et ne doit pas être écrit dans `debian/control`. Comme le
  reste de la pile est déjà dans l'archive (§1), **le PPA n'est en réalité
  nécessaire que pour la pile contacts** — un `.deb` sans le PPA est donc
  possible, avec les fonctions contacts masquées (§10).
- **Certains builds amd64 sont en échec** sur ce PPA (`maliit-framework`,
  `mediascanner2`, `mir`, `morph-browser`) **(V, page Launchpad, état constaté
  lors de la consultation)**. Deux lectures : le clavier virtuel `maliit` en
  échec n'a pas d'impact direct ici (le texte est saisi par le clavier du
  desktop), mais `mediascanner2` peut être une dépendance du service de
  miniatures — **à vérifier au moment du build**, faute de quoi les pages
  Photos / Musique / Vidéos se retrouveraient sans miniatures.
- Le PPA n'est **pas** une garantie de stabilité d'API ni de disponibilité dans
  le temps : un `.deb` qui en dépend déclarera une dépendance forte sur un dépôt
  tiers non archivé par Ubuntu. À écrire noir dans le `README` et dans
  `debian/control` (dépendance, pas conseil).

## 5. Ce qui casse hors Ubuntu Touch (même avec un paquet parfait)

| Fonction | Dépendance | Comportement attendu sur desktop | Gravité |
|---|---|---|---|
| Lancer une application Libertine | `plugins/LibertineLauncher/libertineworker.cpp:20` (`lomiri-app-launch <conteneur>_<app>`), inventaire dans `~/.cache/libertine-container/` (`plugins/AppHandler/apphandler.cpp:43`) | aucun conteneur, et Libertine absent de la distribution (§4.2) | **cassé**, à masquer |
| Désinstaller une application | `qml/pages/Home.qml:512` : `sudo -S click unregister --user=phablet …` via `Terminalaccess` | `click` inexistant ; de plus la saisie du mot de passe pour `sudo -S` est un point sensible déjà documenté | **cassé + risque**, à masquer |
| Contacts (contact favori, recherche contact, `ContactHelper`) | provider `QContactManager("galera")` en dur : `plugins/ContactHelper/contacthelper.cpp:9`, `qml/widgets/SearchContact.qml:46`, `qml/widgets/FavoriteContact.qml:67` **(V)** | `qtcontact5-galera` n'existe que dans la pile UBports, et l'agrégateur n'a aucune source de contacts sur un desktop. Aucun plugin `contactsservice`/`organizerservice` dans l'image SDK **(V)** | **vide** |
| Dernier appel / dernier message | `Lomiri.History 0.1` + `Lomiri.Contacts 0.1` | le service existe dans `noble` mais rien ne l'alimente hors téléphonie | **vide** |
| Partage / import de contenu | `Lomiri.Content 1.3` dans `ImportPage.qml`, `GlobalImportPage.qml`, `Folders`, `NextcloudFolders` | nécessite `content-hub` et un environnement posé par `lomiri-app-launch` ; un lancement direct par `Exec=` risque un échec de la poignée de contenu | **incertain**, à tester **(I)** |
| Miniatures (Photos, Musique, Vidéos, Folders) | `Lomiri.Thumbnailer 0.1` + `lomiri-thumbnailer-service` | service disponible dans `noble` ; dépend qu'il tourne dans la session | dégradable |
| Capteurs et économiseur d'écran (Clock, Music) | `QtSensors 5.12`, `QtSystemInfo 5.0` | modules présents, comportement desktop à valider | à tester |
| Pages, widgets, réglages, persistance | `Lomiri.Components`, `Qt.labs.settings`, `QtQuick.LocalStorage` | attendus fonctionnels | OK (à confirmer sur une vraie session) |
| Instance unique | `X-Lomiri-Single-Instance=true` géré par le lanceur | un binaire lancé sans `lomiri-app-launch` peut s'ouvrir plusieurs fois **(I)** | mineur |

## 6. Trois layouts d'installation possibles

| Option | Description | Changement de code | Contreparties |
|---|---|---|---|
| **A — `/opt` autonome** *(recommandée pour démarrer)* | `/opt/launchermodular/` contient le binaire, `qml/`, `assets/` **et les 7 modules de plugins à côté de lui** ; `/usr/share/applications/launchermodular.desktop` avec `Exec` absolu ; icône dans hicolor ; `.mo` dans `/usr/share/locale` | **aucun** : le binaire résout déjà `qml/Main.qml` par rapport à son dossier **(V)**, et le dossier de l'exécutable fait partie des chemins d'import QML par défaut de Qt **(V, test : un module `TestMod` posé à côté de l'exécutable est chargé sans `QML2_IMPORT_PATH`)** | hors FHS (comme Chrome/Steam) ; les fichiers click (manifest, apparmor, contenthub) sont à exclure ; aucun dépôt officiel n'accepte `/opt` |
| **B — FHS propre** | `/usr/bin/launchermodular` + `/usr/share/launchermodular/{qml,assets}` + modules dans un sous-dossier privé | 2 lignes dans `main.cpp` : répertoire de données passé en définition de compilation, et `engine.addImportPath(<dossier>/lib/<triplet>)` | au passage ferme `KNOWN_ISSUES.md` §3.1 et supprime le chemin arm64 en dur ; seul chemin viable pour un dépôt |
| **C — modules dans le dossier QML système** | `/usr/lib/<triplet>/qt5/qml/{MySettings,AppHandler,…}` | aucun | 7 noms génériques dans l'espace global Qt : collisions et conflits de paquets à éviter |

**Layout retenu : B**, implémenté (§3.1). Le layout A restait possible sans
toucher au code, mais il écarte le paquet d'un dépôt ; le layout C place des noms
génériques hors du contrôle de l'application. Le chemin des modules est une
macro de compilation, donc les trois layouts ne demandent qu'une valeur
différente à `cmake`.

## 7. Formats, outils et coût de maintenance

| Format | Outil | Métadonnées | CI | Limites |
|---|---|---|---|---|
| `.click` (existant) | Clickable 8.10 + Docker | `manifest.json.in`, `.apparmor`, `.contenthub`, `.desktop.in` | 3 arches croisées, inchangées | seul format validé par `click-review` et publié sur l'OpenStore |
| `.deb` | `dpkg-buildpackage` + debhelper (`debian/`), **ou** `CPack` (`GEN_DEB`) depuis le `CMakeLists.txt` | `debian/control` (+ `changelog`) ou `CPACK_DEBIAN_PACKAGE_DEPENDS` ; dépendances du §4.1 | conteneur `ubuntu:24.04` + PPA `lomiri` (ajouter le source et la clé dans le job) | pas de Clickable ici ; `dh_auto_configure` doit passer `-DCMAKE_INSTALL_PREFIX` ; `CPack` ne fait pas un paquet « dépôt » (pas de scripts de maintenance fins, pas de relecture) |
| `.rpm` | `rpmbuild` + `.spec` (puis `mock`, ou un projet OBS) | `BuildRequires` / `Requires` (§4.1) ; macros `%{_libdir}`, et le **dossier QML est propre à chaque distribution** (aucune macro `dpkg-architecture`) | conteneur de la distribution cible, ou OBS | exige une base où Lomiri existe (§8) ; macros Qt5 différentes entre Fedora, Mageia et ROSA → spec non portable sans ajustements **(I)** |
| **AppImage** | `linuxdeploy` + `linuxdeploy-plugin-qt` + `appimagetool`, ou `appimage-builder` avec recette `apt` (§9.3) | `AppRun`, `.desktop`, icône ; pas de métadonnées de dépendances : **tout est embarqué** | conteneur Ubuntu 24.04 + PPA, puis `appimagetool` ; l'AppImage n'a pas de dépôt : publication par **Release GitHub** (+ `.zsync` pour les mises à jour) | ne répare pas les services D-Bus absents (§9.2) ; socle glibc imposé par le PPA (§8) ; FUSE souvent indisponible en conteneur → **test sur machine réelle obligatoire** ; aucun précédent connu pour une app `Lomiri.Components` |

Coûts communs, quel que soit le choix :

1. **Version** : la règle 8 de `AGENTS.md` impose déjà de synchroniser
   `manifest.json.in`, `appVersion` dans `Main.qml` et `ChangeLogs.qml`.
   S'ajoutent `debian/changelog` et le `Version:` du `.spec` → **5 endroits** au
   lieu de 3, avec le risque d'un décalage à chaque publication.
2. **CI** : deux pipelines à déclencher sur chaque MR, alors que la CI actuelle
   se contente de compiler ; les workflows sont dans la liste des fichiers à ne
   pas modifier sans accord.
3. **Validation** : un paquet desktop se valide sur **une vraie installation
   Lomiri desktop**. Dans le présent environnement c'est impossible : tout
   contrôle Lomiri thématisé (`Button`, `Icon`) fait segfaulter le rendu en
   conteneur (point déjà constaté lors du travail sur le tutoriel). Rien de ce
   document ne dispense d'un test en VM ou sur machine.
4. **Support** : chaque format ajoute ses rapports de bogue propres
   (chemins, dépendances, absence de Libertine) sans réduire ceux du click.

## 8. Du `.rpm` à l'AppImage

- La cible retenue d'abord (Mageia / ROSA) **n'a pas de pile Lomiri** : rien
  trouvé dans leurs dépôts. `lomiri-ui-toolkit` n'existe en `.rpm` que pour
  **Fedora**, et la pile complète est empaquetée chez **ALT Linux Sisyphus**
  *(V, d'après des extraits d'index : pages directes non consultées, pkgs.org
  renvoyant HTTP 402 en accès direct.)*
- **Limites de cette vérification** : `madb.mageia.org` en timeout, `pkgs.org`
  en HTTP 402, `api.opensuse.org/search` en HTTP 401 → **recherche non
  exhaustive**, à refaire sur place (`urpmq` sur une liste de médias à jour).
- Sans `qml-module-lomiri-components` (et les modules du §4.1), la ligne
  `import Lomiri.Components 1.3` de `qml/Main.qml:6` échoue : l'app ne démarre
  pas. Écrire un `.spec` ne change rien à cette absence ; il aurait fallu
  d'abord empaqueter la pile Lomiri (ui-toolkit, content-hub, download-manager,
  history, thumbnailer, connectivity, Qt Mobility…), projet distinct et long.
- **L'AppImage lève la contrainte d'emballage** (il apporte ses bibliothèques et
  ses modules QML) **mais pas celle des services** (§9.2), et il en introduit
  une nouvelle : le socle d'exécution.
- **Socle d'exécution, à mesurer avant toute promesse.** `ppa:lomiri/stable` ne
  publie que Noble et Resolute **(V)** : impossible de construire sur une base
  plus ancienne pour abaisser le glibc minimum, alors que la règle usuelle pour
  un AppImage est de bâtir sur la plus vieille distribution encore supportée
  **(V, doc `linuxdeployqt` / doc AppImage)**. Noble apporte donc un glibc
  « haut » : un AppImage bâti là ne démarrera pas sur une distribution dont le
  glibc est plus ancien **(I)**. Vérification simple sur les machines visées :
  `ldd --version`. Si Mageia 9 ou ROSA sont sous le glibc de Noble, elles
  resteront hors portée malgré l'AppImage.

## 9. AppImage : ce qui change par rapport à un paquet

### 9.1 Chemins d'import QML et plugins Qt

- Le mécanisme de relocalisation n'est **pas** `QML2_IMPORT_PATH` : c'est un
  fichier **`qt.conf`** posé à côté de l'exécutable (`Prefix=../`,
  `Qml2Imports=qml`) et le **RPATH `$ORIGIN`** appliqué aux ELF **(V, source :
  `linuxdeploy-plugin-qt`, `src/deployment.h`)**. Les hooks Qt de l'AppRun ne
  posent d'ailleurs **pas** `QML2_IMPORT_PATH`, seulement
  `QT_QPA_PLATFORMTHEME` **(V, même source)**.
- Conséquence directe pour le projet : les 7 modules de plugins (`MySettings`,
  `AppHandler`, …) doivent être copiés dans l'arborescence de l'AppDir
  (`usr/lib/<triplet>/qt5/qml/<Module>/` avec leur `qmldir`) — le même travail
  que pour le `.deb` (§6) — et `main.cpp` doit **cesser de supposer que le
  lanceur click pose l'environnement** (§3, lignes 3 et 6). Un `AppRun`
  personnalisé (`--custom-apprun`) reste possible pour ajouter un chemin
  d'import.
- Il faut déployer le plugin de plateforme : `libqxcb` pour X11 et au moins un
  plugin Wayland (`EXTRA_PLATFORM_PLUGINS` de `linuxdeploy-plugin-qt`) **(V,
  README)**. L'ancien `linuxdeployqt`, abandonné, dit explicitement « ne pas
  utiliser Wayland » **(V, README)** → **tester les deux sessions**, Fedora et
  Mageia démarrant souvent en Wayland.

### 9.2 Les services D-Bus : l'obstacle réel

- `Lomiri.Content`, `.History`, `.Thumbnailer`, `.DownloadManager`,
  `.Connectivity` sont des **clients** de démons. L'activation D-Bus passe par
  des fichiers `.service` installés dans `/usr/share/dbus-1/services` du bus de
  session **(V pour `lomiri-content-hub` : service de partage de contenu ; le
  mécanisme d'activation est celui de D-Bus)** — un AppImage **n'y installe
  rien**. Sur une distribution qui ne fournit pas ces paquets, les modules se
  chargent mais **rien ne répond** **(I, consequence directe du mécanisme)**.
- **Aucun précédent trouvé** d'application `Lomiri.Components` distribuée en
  AppImage. UBports diffuse l'**UBports Installer** en AppImage, mais c'est une
  app Qt/QML de bureau sans toolkit Lomiri **(V)**. Le toolkit est en revanche
  publié en **snap** (`lomiri-ui-toolkit-core24`) **(V)** — preuve qu'un
  empaquetage hors Touch est possible, pas qu'il soit complet.
- C'est exactement ce que doit couvrir la **détection des capacités** (§10) : ne
  pas proposer ce qui ne répondra pas. Lancer les démons depuis l'`AppRun`
  serait possible mais fragile (plusieurs démons, politiques D-Bus, SELinux et
  AppArmor sur Fedora) : **à écarter pour une première version**.

### 9.3 Outils

| Besoin | Outil | Point à connaître |
|---|---|---|
| Construire l'AppDir + déployer les dépendances | `linuxdeploy` + `linuxdeploy-plugin-qt` | options réelles : `-e`, `-l`, `-d`, `-i`, `--appdir`, `--deploy-deps-only` (déploie les dépendances de fichiers **déjà** copiés dans l'AppDir, sans les recopier — cas des fichiers issus des paquets du PPA), `--exclude-library`, `--custom-apprun` **(V, source : `src/main.cpp`)** |
| Empaqueter l'AppDir | `appimagetool` (`go-appimage`) | respecte une *excludelist* (ne embarque pas glibc, libstdc++…) ; `-s` = self-contained ; sur GitHub Actions il génère l'*UpdateInformation* `gh-releases-zsync|…` et le `.zsync` **(V)** |
| Recette déclarative | `appimage-builder` (image Docker `appimagecrafters/appimage-builder`) | recette `apt` : tirer les paquets du PPA vers l'AppDir. Avertissement de la doc : **utiliser les mêmes sources dans la recette et dans le système de build**, sinon bundle défaillant **(V)** |
| CI | action `AppImageCrafters/build-appimage-action@master` (motif documenté, exemple `appimage-demo-qt5`) **(V)** | les noms `xuf-design/action-appimage`, `linuxdeploy/linuxdeploy-action`, `appimage/appimage-builder-action` renvoient **404** : ne pas les utiliser **(V)** |
| Build en conteneur | `docker run ubuntu:24.04` + PPA + `linuxdeploy` | FUSE souvent indisponible dans un conteneur → tests d'exécution à sauter (`--skip-test` pour `appimage-builder`) et validation reportée sur une machine réelle **(V pour l'option ; I pour le comportement exact)** |

Note : la « spec AppImage 1.1 » n'existe pas — la spec est un brouillon continu
sans numéro de version, et le runtime monte le payload dans un dossier temporaire
en FUSE (`$APPDIR`), pas sous `/usr` **(V, docs.appimage.org)**.

### 9.4 Ce qui reste à prouver pour l'AppImage

Démarrage réel sur Fedora (Wayland **et** X11) ; comportement des modules liés
à un démon quand le démon est absent (erreur muette, exception, ou blocage) ;
rendu du thème Suru hors session Lomiri ; état amd64 réel des paquets du PPA
au jour du build.

**Déjà prouvé en conteneur (24/11, annexe A, cinquième round)** : la
relocalisation effective des 8 plugins maison et des modules `Lomiri.*` /
`QtOrganizer` / `QtContacts` / `QtSystemInfo` — l'AppImage extraite, dans un
conteneur où le chemin compilé n'existe pas, charge `Main.qml`, `Home.qml` et
les widgets depuis son propre arbre, sans aucun module manquant. Reste à
prouver : l'exécution **montée** (FUSE) et le rendu complet sur machine réelle
; la plateforme **Wayland** n'est pas embarquée (l'image SDK n'a pas les
plugins QtWayland — sans eux, session Wayland passe par XWayland).

## 10. Détection des capacités — implémentée

C'est la partie qui a de la valeur **pour les trois formats** : un `.click` sur un
appareil sans pile téléphonique, un `.deb` sur un desktop et un AppImage n'ont
pas les mêmes dépendances disponibles.

### 10.1 Principe

Un seul endroit calcule l'état, l'UI ne fait que le lire. Le calcul est fait
**une fois au démarrage** et exposé en propriétés `CONSTANT` en lecture seule,
sans effet de bord dans un binding (règle QML de `AGENTS.md`). Les fichiers QML
testent un booléen ; ils ne font pas eux-mêmes la recherche de binaire, de
dossier ou de service.

Trois contraintes, vérifiées dans le code de `plugins/Platform/` :

- **aucune commande exécutée** : ni `QProcess`, ni shell, donc rien qui puisse
  bloquer l'interface ou dépendre des droits d'exécution ;
- **aucun appel bloquant en attente d'un service** ;
- un seul aller-retour D-Bus (`org.freedesktop.Accounts` sur le bus système),
  fait **à la première lecture** de la propriété, jamais dans le constructeur.

### 10.2 Le plugin `Platform`

`plugins/Platform/` est un singleton QML `Platform 1.0` (8ᵉ plugin du dépôt),
calqué sur `LibertineLauncher`. Les chemins d'import QML du moteur lui sont
confiés dans `initializeEngine(QQmlEngine *, const char *)` : sans eux, la
présence d'un module ne pourrait pas être vérifiée.

| Propriété | Comment elle est calculée | Consommateurs |
|---|---|---|
| `isTouch` | `APP_ID` positionné (lanceur d'applications) **ou** `/etc/ubports/version` | heuristic affichée dans le diagnostic, **jamais** motif suffisant pour masquer |
| `isAppImage`, `sessionDesktop` | `APPIMAGE`, `XDG_SESSION_DESKTOP`/`DESKTOP_SESSION` | diagnostic |
| `hasClickTool` | `click` dans le `PATH` | — |
| `hasLomiriAppLaunch` | `lomiri-app-launch` dans le `PATH` | — |
| `hasLibertineContainers`, `canLaunchLibertine` | `~/.cache/libertine-container` non vide, et binaire ci-dessus | `qml/pages/Home.qml` (lancement) |
| `canUninstallApps` | `click` dans le `PATH` | `qml/pages/Home.qml` (`sudo -S click unregister …`) |
| `contactProviders`, `organizerProviders` | fichiers `libqtcontacts_*.so` / `libqtorganizer_*.so` dans `contacts`/`contactsservice` et `organizer`/`organizerservice` des chemins de plugins Qt | diagnostic |
| `preferredContactManager`, `preferredOrganizerManager` | `galera` (resp. `eds`) si présent, sinon tout autre provider sauf `memory`, sinon vide | `qml/widgets/SearchContact.qml`, `qml/widgets/FavoriteContact.qml` |
| `hasContactsFeature`, `hasCalendarFeature` | règle de compatibilité §10.4 | page d'accueil et réglages des widgets |
| `hasHistoryModule`, `hasContactsModule`, `hasQtContactsModule`, `hasOrganizerModule`, `hasContentModule`, `hasThumbnailerModule`, `hasDownloadManagerModule`, `hasConnectivityModule`, `hasMultimediaModule`, `hasSensorsModule`, `hasSystemInfoModule`, `hasLocalStorageModule` | existence du dossier du module dans les chemins d'import, avec et sans suffixe de version (`Lomiri/Contacts.0.1`, `Lomiri/Content`, `QtQuick/LocalStorage` sans suffixe) | `qml/Main.qml`, `qml/pages/Home.qml`, `qml/Pagemanagement.qml`, `qml/helpers/PageRequirements.js` |
| `hasAccountsService` | service enregistré sur le bus système, évalué paresseusement | diagnostic (répéré, non consommé) |

Les dossiers réels sont ceux du rootfs `clickable/amd64-ut24.04-1.x-amd64` : les
modules versionnés de la pile Lomiri sont installés **dans un dossier portant le
suffixe de version** (`Lomiri/Contacts.0.1`, `Lomiri/Thumbnailer.0.1`), les
autres dans le dossier du nom seul (`Lomiri/Content`). Un test qui ignorerait
cette forme renvoie « absent » pour un module installé.

### 10.3 Deux faits durs, vérifiés, qui commandent l'architecture

1. **Un `import` manquant fait échouer tout le fichier qui le contient, et
   l'erreur remonte à son parent.** Reproduit sans interface graphique dans le
   conteneur de référence : un composant enfant dont l'`import` est absent
   produit `Type MusicPlayer unavailable` suivi de `module "QtMultimedia" is not
   installed`, et le fichier parent ne se charge pas du tout — `visible: false`
   n'y change rien, car la résolution de l'`import` a lieu avant toute évaluation
   de propriété.
   **Conséquence :** indisponible veut dire **retiré de la composition**. Les
   composants concernés sont donc instanciés par
   `Loader { active: Platform.<capacité> ; source: "…" }` — un `Loader` inactif
   ne charge pas le fichier, l'`import` absent ne peut pas nuire — et non par
   `visible: false`.
2. **`import Lomiri.Thumbnailer 0.1` déclenche une activation D-Bus
   `com.lomiri.Thumbnailer`.** Sans démon, le processus reste suspendu (sonde
   `qmlscene` en timeout dans le conteneur, y compris pour d'autres modules).
   **Conséquence :** aucun test « service joignable » n'est fait, ni pour le
   thumbnailer ni pour le service d'historique. On ne teste que l'existence du
   module ; le rendu dégradé **sans** miniature (icône + nom à la place d'une
   image) est reporté (§10.6).

Corollaire de méthode : une sonde `qmlscene` module par module **ne vaut pas**
comme preuve de disponibilité dans ce harnais (elle sort en timeout même pour des
modules installés). La disponibilité est établie par le test filesystem du plugin
croisé avec `QML2_IMPORT_PATH` du conteneur.

### 10.4 Compatibilité par plateforme

Le code de l'application nome ses providers : `galera` pour les contacts, `eds`
pour l'agenda. Or le conteneur Touch de référence n'a **ni l'un ni l'autre**
(seul le provider `memory` livré avec Qt, plus `galera` côté contacts selon le
miroir utilisé) : masquer sur ce seul critère ferait disparaître, sur un vrai
téléphone, des widgets qui y fonctionnent. Règle retenue, appliquée dans le C++
et non dans les fichiers QML :

- la capacité contacts/agenda vaut `vrai` **sur Ubuntu Touch** (`isTouch`), parce
  que cette pile fait partie du système attendu et n'est pas sondable depuis là ;
- **hors Touch**, elle exige un provider exploitable : `galera`/`eds` si présent,
  sinon n'importe quel autre provider, `memory` étant exclu — il ne contient
  aucune donnée de l'utilisateur et afficherait un widget vide ;
- le nom du provider à utiliser vient de `preferredContactManager`, donc un
  desktop qui n'a que `qtcontacts-sqlite` (PPA, §4.3) n'est pas déclaré inutile.

Une dépendance de type **module** ne suit pas cette règle : un module absent
fait échouer le fichier qui l'importe sur toutes les machines (§10.3), elle est
donc toujours bloquante.

### 10.5 Ce qui est câblé

| Emplacement | Garde | Comportement quand ça manque |
|---|---|---|
| `qml/pages/Home.qml` — `MusicPlayer` | `hasMultimediaModule` | objet non créé, place non prise |
| `qml/pages/Home.qml` — widgets dernier appel / derniers messages | `hasHistoryModule && hasContactsModule` | non créés + réglages correspondants masqués dans `qml/pages/home/Settings.qml` |
| `qml/pages/Home.qml` — widget agenda | `hasOrganizerModule && hasCalendarFeature` | idem |
| `qml/pages/Home.qml` — recherche et favoris contacts | `hasQtContactsModule && hasContactsFeature` | idem |
| `qml/pages/Home.qml` — lancement Libertine | `canLaunchLibertine` | appel évité, trace en console au lieu d'un clic sans effet |
| `qml/pages/Home.qml` — désinstallation | `canUninstallApps` | `sudo -S` non demandé, trace en console |
| `qml/Main.qml` — page déjà enregistrée dont un module manque | `PageRequirements.isAvailable()` | état vide `qml/components/PageUnavailable.qml`, qui nomme le ou les modules manquants |
| `qml/Main.qml` — `pageStack.push("ImportPage.qml")` | `hasContentModule` | ouverture évitée, trace en console |
| `qml/Pagemanagement.qml` — liste « ajouter une page » | même table | ligne repliée (`height: 0`, `visible: false`) : `Qt.labs.folderlistmodel 2.12` **n'a pas** de propriété de filtrage par motif, l'essai par `filterOnName` échoue à l'exécution |
| `qml/helpers/PageRequirements.js` | table page → modules | source unique des dépendances des pages embarquées ; les pages personnelles de `~/.launchermodular/pages/` ne sont jamais filtrées |

### 10.6 Ce qui n'est pas fait

- rendu **sans miniature** dans les pages Photos/Musique/Vidéos/Folders : ces
  pages sont retirées plutôt que dégradées ;
- `desktopFileInfoAvailable` et `servicesAvailable` (table initiale de cette
  étude) : non détectés, aucun câblage ne les exige. `sensorsAvailable` est
  détecté (`hasSensorsModule`) depuis que la page Horloge a été inspectée ;
- le **provider** d'agenda n'a pas de repli : le code nomme `eds`, et un desktop
  sans `eds` masque le widget agenda plutôt que d'utiliser un autre provider ;
- `ContactHelper` (C++) garde `galera` en dur dans son constructeur ;
- les nouveaux libellés passent par `i18n.tr`, mais les `.po` sont alimentés par
  Weblate et ne sont pas modifiés ici ;
- le texte du panneau de diagnostic est **volontairement non traduit** : c'est un
  état technique destiné à être copié dans un rapport de bogue.

### 10.7 Diagnostic

`qml/Help.qml` expose un bouton « Diagnostic » qui ouvre la sortie de
`Platform.diagnostics()` : environnement (`isTouch`, `APP_ID`, session, AppImage),
binaires, Libertine, providers et managers, chaque module testé, service
`org.freedesktop.Accounts`, et les chemins d'import réellement utilisés. C'est ce
qui rendra les rapports de bogue desktop exploitables, et ce n'est pas un risque
pour le `.click`.


## 11. Séquence proposée

1. **Détection des capacités d'abord** (§10) — **fait et câblé** (§10.5).
2. **Correctifs de build, utiles aussi au click** — **fait** (§3.1) ; commande
   exacte du `.deb` : `cmake -S . -B build -DDESKTOP_INSTALL=ON && make -C
   build && cpack -G DEB` (dans `build/`), vérifiée de bout en bout dans le
   conteneur de référence. Détail :
   dans `main.cpp` et déclarer le dossier des plugins comme chemin d'import
   (ferme `KNOWN_ISSUES.md` §3.1) ; rendre `DATA_DIR` / `CMAKE_INSTALL_PREFIX`
   préfixables ; rendre `dpkg-architecture` optionnel avec repli ; option CMake
   pour exclure les fichiers click ; `.desktop` avec `Exec` et `Icon` système.
   Après un build local, penser à `git restore po/` (la cible `update_po_files`
   modifie les `.po`).
3. **`.deb`** : `debian/` (ou `CPack`) → build dans un conteneur Ubuntu 24.04
   avec le PPA `lomiri` activé → **test sur une VM Lomiri desktop**,
   indispensable. Rien de ce qui suit n'est validable dans le présent
   environnement (les contrôles Lomiri thématisés y font segfaulter le rendu).
4. **AppImage** : après le `.deb`, en réutilisant la même installation
   déplaçable. Prototyper d'abord sur **une** machine cible réelle, en la
   montant (`--appimage-mount`) pour voir ce qui manque vraiment : la
   construction en conteneur ne prouve rien sans exécution sur la cible.
5. **`.spec`** : seulement si une base RPM où Lomiri existe est retenue (Fedora,
   ou un projet OBS à monter).
6. **CI** en jobs séparés, sans toucher aux jobs existants ; mettre à jour
   `docs/ARCHITECTURE.md` (section build) et `README.md`.

## 12. Décisions

1. **Socle AppImage** : quelles machines réelles viser, et quel `ldd --version`
   y tourne ? Sans cette mesure, on risque de produire un AppImage qui ne
   démarre qu'_sur Ubuntu 24.04 et plus récent_. **En attente.** Décision
   provisoire (24/11) : construire sur Noble et annoncer « nécessite glibc ≥
   2.39 » ; la première AppImage produite (Annexe A, cinquième round) a ce socle.
2. **Périmètre visible de la détection** : **décidé — masquer** (la fonction est
   retirée de la composition) **avec état vide explicite** quand une page déjà
   enregistrée devient chargable. **Appliqué** (§10.5).
3. **Où vit la détection** : **décidé — 8ᵉ plugin C++ `Platform`** (§10.2).
   **Appliqué**, avec les fichiers QML listés §10.5.
4. **Diagnostic visible** dans la page Aide : **décidé — oui**. **Appliqué**
   (§10.7).
5. **Autorisation de toucher** `main.cpp`, `CMakeLists.txt`,
   `plugins/*/CMakeLists.txt`, `launchermodular.desktop.in` et
   `.github/workflows/` — tous dans la liste des fichiers à ne pas modifier sans
   accord (règle 10 de `AGENTS.md`) ? **Autorisation accordée**, non encore mise
   à profit : les correctifs de build du §3 ne sont pas appliqués.
6. Le projet accepte-t-il une **dépendance forte au PPA** `lomiri/stable` pour
   le `.deb` ? **Réponse possible maintenant** : l'archive `noble` fournit tout
   sauf la pile contacts (§4.2), donc un `.deb` sans PPA est viable avec les
   fonctions contacts masquées ; le PPA ne serait nécessaire que pour les
   activer. **Arbitrage en attente**, et à annoncer dans le `README` et
   `debian/control` si retenu.
7. **Langue des commentaires** : **décidé — anglais** dans le code, le français
   restant la langue de `docs/ARCHITECTURE.md` et de cette étude.

## Annexe A — vérifications réellement effectuées

- `clickable --version` → 8.10.0 ; `clickable --help` et
  `clickable build --help` → aucune sortie deb/rpm.
- Lecture : `CMakeLists.txt`, `po/CMakeLists.txt`, `plugins/CMakeLists.txt`,
  `plugins/*/CMakeLists.txt`, `main.cpp`, `launchermodular.desktop.in`,
  `plugins/AppHandler/apphandler.cpp`, `plugins/LibertineLauncher/*`,
  `plugins/ContactHelper/contacthelper.cpp`, `plugins/MySettings/accountsservice.cpp`.
- `grep` : inventaire des `import` QML ; usages de `sudo`/`click` ; providers
  `galera` ; recherche de `pam`/`gsettings` (aucun résultat).
- Conteneur `clickable/amd64-ut24.04-1.x-amd64:latest` (`/etc/os-release` :
  Ubuntu 24.04.5 LTS) : `dpkg -L` / `dpkg -S` sur les dossiers de modules QML,
  `dpkg -s qml-module-lomiri-contacts`, `dpkg -l`, `apt-cache search`,
  `ls` des modules `Lomiri/*`, des dossiers `contactsservice` et
  `organizerservice` (absents), `strings liblomiri-app-launch.so` →
  `QML2_IMPORT_PATH`.
- Test de résolution d'import : module QML pur `TestMod` placé à côté d'un
  exécutable copié dans le même dossier, chargé avec `qmlscene` sans
  `QML2_IMPORT_PATH` → le module est trouvé (seule erreur : une instanciation
  récursive dans mon fichier de test).
- `packages.ubuntu.com`, suite `noble`, toutes sections/arches : recherches
  `lomiri` (24 paquets), `qml-module-qt*` (62), `qml-module-lomiri` (22),
  `u1db` (5), `content-hub` (7), `libertine` (1 : `fonts-linuxlibertine`),
  `address-book` (0) ; liste des fichiers du paquet `lomiri-calculator-app`
  (modèle de layout desktop : `/usr/bin/<app>`, `/usr/share/<app>/*.qml`,
  `/usr/share/applications/<app>.desktop`, `/usr/share/locale/…`).
- Launchpad, PPA `lomiri/stable` : publie pour `Resolute` et `Noble`, 221
  sources ; source `lomiri-addressbook-app` 0.9.1 publiée pour Noble.
- Recherche web (Lomiri, paquets RPM) : `lomiri-ui-toolkit` en RPM pour Fedora ;
  pile Lomiri dans ALT Linux Sisyphus ; rien pour Mageia / ROSA ;
  statut « discontinued » de Mandriva Linux.
- **Second round, axé AppImage** (recherche web, sources primaires lues) :
  `github.com/linuxdeploy/linuxdeploy` (`src/main.cpp` : options réelles, dont
  `--deploy-deps-only`, `--custom-apprun`) ; `github.com/linuxdeploy/linuxdeploy-plugin-qt`
  (`src/deployment.h` : `qt.conf` avec `Prefix=../` et `Qml2Imports=qml`, hook
  Qt5 ne posant que `QT_QPA_PLATFORMTHEME` ; `EXTRA_PLATFORM_PLUGINS`) ;
  `probonopd/linuxdeployqt` (abandonné, « do not use Wayland », règle du plus
  vieil LTS) ; `probonopd/go-appimage` (`appimagetool`, excludelist, `-s`,
  UpdateInformation `gh-releases-zsync`) ; `docs.appimage.org` (variables
  `APPDIR`/`APPIMAGE`/`OWD`, architecture, AppDir, spec sans numéro de version,
  `--appimage-mount`) ; `appimage-builder.readthedocs.io` (recette `apt`, image
  Docker, avertissement « mêmes sources que le système de build », action
  `AppImageCrafters/build-appimage-action`) ; `launchpad.net/~lomiri/+archive/ubuntu/stable`
  (Noble + Resolute, 156 sources, `lomiri-ui-toolkit` 1.3.6000, content-hub,
  history-service, thumbnailer, download-manager, `suru-icon-theme`,
  `qqc2-suru-style`, `qtcontacts-sqlite`, `qtorganizer-eds`, `qtorganizer-mkcal`,
  `qtpim-opensource-src`, `qtsystems-opensource-src`, builds amd64 en échec :
  `maliit-framework`, `mediascanner2`, `mir`, `morph-browser`) ;
  `packages.ubuntu.com/noble/libqt5qml5` (5.15.13, nom sans `t64`) et
  `packages.ubuntu.com/noble/lomiri-content-hub` (absent de noble) ;
  `snapcraft.io/lomiri-ui-toolkit-core24` ; `github.com/vanyasem/Lomiri-Arch` ;
  `docs.ubports.com` (UBports Installer en AppImage).
  **Limite** : les pages GitLab amont (`lomiri-ui-toolkit`, `lomiri-app-launch`,
  `lomiri-content-hub`) n'ont pas pu être lues (HTTP 429) ; les affirmations
  correspondantes sont marquées **(I)**.

- **Troisième round, détection implémentée** :
  - le plugin `plugins/Platform/` est **compilé et exécuté** dans
    `clickable/amd64-ut24.04-1.x-amd64:latest` (`cmake` + `make`, puis
    `qmlscene -I …` hors écran) : les propriétés et la sortie de
    `Platform.diagnostics()` sont celles décrites §10.2 ;
  - dossier des modules relevé dans le rootfs : les modules versionnés de la
    pile Lomiri sont dans un dossier **suffixé par la version**
    (`Lomiri/Contacts.0.1`, `Lomiri/Thumbnailer.0.1`), les providers dans
    `qt5/plugins/contacts` et `qt5/plugins/organizer` (et non
    `contactsservice`) ;
  - **échec d'import propagé au parent reproduit** : un `import` absent dans un
    fichier enfant donne `Type … unavailable` + `module "…" is not installed`
    et le fichier parent ne se charge pas ;
  - **`import Lomiri.Thumbnailer 0.1` déclenche `Activating service name
    'com.lomiri.Thumbnailer'`** et le processus reste suspendu quand le démon
    est absent ; la sonde `qmlscene` module par module sort en timeout, y compris
    pour des modules installés → elle ne vaut pas comme preuve (§10.3) ;
  - **`Qt.labs.folderlistmodel 2.12` n'a pas de propriété `filterOnName`** :
    `Cannot assign to non-existent property "filterOnName"` à l'exécution ; le
    filtrage de la liste des pages est donc fait dans le delegate ;
  - `packages.ubuntu.com/noble/<paquet>` interrogé **paquet par paquet** pour
    14 noms (tableau du §4.2), dont la découverte que `click` n'est publié que
    pour `jammy` ;
  - contrôle statique : `qmllint` sur les huit fichiers QML modifiés (aucune
    erreur de syntaxe), `node --check` sur `qml/helpers/PageRequirements.js`.
- **Quatrième round, vérification desktop de bout en bout** (24/11/2026) :
  - reprise du job de contrôle dont la sortie avait été perdue :
    `cmake -DDESKTOP_INSTALL=ON` + `make` + `make install` **dans le conteneur
    `clickable/amd64-ut24.04-1.x-amd64:latest`** (copie du dépôt dans `/tmp`,
    montage `/src` en lecture seule, aucun effet sur le dépôt) ;
  - `strings` sur le binaire : littéraux `/usr/share/launchermodular`,
    `/usr/lib/x86_64-linux-gnu/launchermodular`, `/usr/lib/%1/lomiri/qml`
    présents (macros bien injectées) ;
  - exécution `/usr/bin/launchermodular` (`QT_QPA_PLATFORM=offscreen`,
    `dbus-run-session`) : `Main.qml` chargé sans erreur de chemin, avertissements
    QML depuis `/usr/share/launchermodular/qml/` et repli `alarm manager "eds"
    not installed, using "memory"` — l'échec attendu (Lomiri hors session) ne
    survient pas, le chemin d'installation fonctionne ;
  - `LAUNCHERMODULAR_DATA_DIR=/nonexistent` : message d'aide affiché, variable
    bien prioritaire. **Limite** : la contre-vérification « variable correcte »
    n'a pas rendu sa sortie (échancier de 20 s écoulé) ; elle est couverte de
    fait par l'exécution précédente, qui utilisait la macro par défaut.
  - le `grep` des `-D…` dans `build-d/…/flags.make` n'a rien affiché (motif
    trop strict) — ce sont les littéraux du binaire qui établissent l'injection.
- **Cinquième round, première AppImage** (24/11/2026) :
  - outils téléchargés (autorisés) : `linuxdeploy` et `linuxdeploy-plugin-qt`
    (release `continuous`) ; **attention**, le nom `appimagetool-x86_64.AppImage`
    en continuous renvoie 404, il faut le nom avec numéro de build
    (`appimagetool-954-x86_64.AppImage`, `probonopd/go-appimage`) ;
  - les trois s'exécutent en conteneur avec `--appimage-extract-and-run`
    (pas de FUSE) ; `qmake` 5.15.13 est présent dans l'image SDK ;
  - `linuxdeploy --plugin=qt` **scanne tout l'AppDir** à la recherche de QML
    (`qmlimportscanner -rootPath <AppDir>`) : il trouve donc
    `usr/share/launchermodular/qml` et déploie dans `usr/qml` tous les modules
    requis, y compris `Lomiri/{Components, …}`, `QtContacts`, `QtOrganizer`,
    `U1db`, `Qt/labs/{settings,folderlistmodel}` et le **style Suru** de
    `QtQuick/Controls.2` ; `qt.conf` (`Prefix=../`, `Qml2Imports=qml`) posé à
    côté du binaire, RPATH `$ORIGIN` sur tous les ELF ;
  - `appimagetool` exige `VERSION=…` (sinon « Version not found, aborting »)
    et un `.desktop` avec `Categories=` (sinon refus) — ajouté par
    `cmake/SetDesktopIcon.cmake` en mode desktop ;
  - plateforme Qt : par défaut seul `xcb` est déployé ; l'exécution `offscreen`
    échoue donc en conteneur (`Available platform plugins are: xcb` — preuve
    que `qt.conf` et le chemin des plugins sont bien résolus). `EXTRA_PLATFORM_PLUGINS`
    (`libqoffscreen.so libqminimal.so libqwayland-egl.so libqwayland-generic.so`)
    ajoute les plateformes de test et Wayland ;
  - chaîne de lancement : `AppRun` généré (source les hooks Qt) →
    `AppRun.wrapped` (AppRun personnalisé via `--custom-apprun`, exporte
    `QML2_IMPORT_PATH=$APPDIR/usr/lib/<triplet>/launchermodular`) → binaire ;
  - `EXTRA_PLATFORM_PLUGINS` (version continue du plugin) ne découpe pas la
    valeur : espace, `;` et `:` produisent tous une erreur « non-existing
    library file » avec la chaîne entière. Contournement : copier
    `libqoffscreen.so`, `libqminimal.so`, `libqvnc.so` dans
    `usr/plugins/platforms` (dépendances `libQt5Gui`/`libQt5Core` déjà
    déployées) ; les plugins QtWayland sont **absents de l'image SDK** ;
  - **l'`AppRun` doit exporter `APPDIR=${APPDIR:-$HERE}`** : le runtime ne pose
    `$APPDIR` qu'au montage FUSE ; en mode extrait (`--appimage-extract`),
    sans cette ligne, la recherche des données ne tient plus qu'au chemin
    compilé — valide en conteneur par coïncidence, cassé sur machine réelle ;
  - test d'auto-suffisance (conteneur neuf sans le chemin compilé) : AppImage
    extraite charge `Main.qml`, `pages/Home.qml`, `widgets/Calculator.qml`
    depuis `/tmp/x/usr/share/launchermodular` ; aucun `module … is not
    installed` ; segfault final après les imports, contexte Telepathy /
    PulseAudio / AccountsService (limite du conteneur). Artefacts :
    `Launcher_Modular-2.5.0-x86_64.AppImage` (70 Mo) et
    `launchermodular-2.5.0-Linux.deb` (14 Mo) dans
    `/home/david/tmp/opencode/appimage-out/`.
- **Limite de méthode** : rien de ce qui touche `Lomiri.Components` thématisé
  (`Button`, `Icon`, `PageHeader`) ne s'exécute dans ce conteneur (sortie 139) ;
  les rendus ne peuvent donc être validés qu'en session Lomiri.
- **Sixième round, recette officialisée et testée comme la CI l'exécutera**
  (24/11/2026) : recette déplacée dans le dépôt —
  `packaging/desktop/build-deb.sh`, `packaging/desktop/build-appimage.sh`,
  `packaging/desktop/AppRun` — et nouveau workflow `.github/workflows/desktop.yml`
  (accord explicite ; `main.yml` inchangé), les deux jobs construisant dans
  l'image `clickable/amd64-ut24.04-1.x-amd64` via `docker run --entrypoint sh`
  (les scripts, sans bit exécutable sur l'hôte, sont invoqués par `sh`).
  Trois défauts trouvés par ce test à l'identique et corrigés :
  - `chmod +x` sur `/tools` monté **lecture seule** échouait → la recette copie
    les outils AppImage dans son espace de travail ;
  - `appimagetool` écrit l'`.AppImage` dans le **répertoire courant**, pas à
    côté de l'AppDir → la recette se place dans `$WORK` avant de l'appeler
    (sinon « Almost a success » puis fichier introuvable) ;
  - **les traductions n'étaient dans aucun paquet au bon endroit** :
    `po/CMakeLists.txt` installait les `.mo` vers `/share/locale` (chemin
    **absolu**) — dans le `.deb` ils étaient packagés à `./share/locale` (hors
    `/usr`, donc hors des chemins de recherche standard) et le `make install`
    de l'AppImage les écrivait à la **racine du conteneur**, jamais dans
    l'AppDir. Pour le click c'était neutre (préfixe `/`). Corrigé en
    `DESTINATION share/locale/…` relatif : `.deb` vérifié reconstruit avec les
    63 `.mo` sous `./usr/share/locale/<lang>/LC_MESSAGES/` (domaine
    `launchermodular.lut11`). Le rechargement réel des catalogues par
    `i18n`(`Lomiri.Components`) sur un bureau reste à vérifier en session.
  - **Résultat (fin du sixième round)** : `build-appimage.sh` mené au bout
    dans un conteneur neuf — `Launcher_Modular-2.5.0-x86_64.AppImage`
    (69 Mo) contenant `usr/share/locale` (63 langues), plateformes `xcb` +
    `offscreen`/`minimal`/`vnc`, test de démarrage réussi (l'app charge ses
    QML depuis `squashfs-root/usr/share/launchermodular`, aucun module
    manquant) ; artifacts `.AppImage` + `appimage-run.log` dans
    `/home/david/tmp/opencode/ci-test4/out/`. Les deux jobs de
    `desktop.yml` reposent donc sur des commandes exécutées avec succès
    hors GitHub ; le premier déclenchement GitHub réel reste à surveiller.

## Annexe B — ce qui n'est pas vérifié

- Aucun build, aucune installation, aucune exécution de l'app. Aucune validation
  desktop, aucune validation sur appareil.
- Noms exacts des paquets binaires fournis par le PPA pour la pile contacts ;
  présence effective de `lomiri-ui-toolkit-theme` dans l'archive `noble`.
- État réel des dépôts Mageia et ROSA (outils injoignables : timeout, HTTP 402,
  HTTP 401) et macros RPM propres à ces distributions.
- Rendu effectif des changements de ce troisième round : état vide d'une page
  (`PageUnavailable`), panneau Diagnostic, ligne repliée dans « ajouter une
  page », widgets masqués ou conservés selon les capacités. Aucun de ces rendus
  n'a pu être ouvert ici (§limite de méthode, Annexe A) : **à voir en session
  Lomiri et sur appareil**.
- Sur un appareil réel, les capacités modules doivent toutes être vraies et le
  comportement ne doit **pas** changer ; c'est le principal risque de régression
  du câblage, et il n'est pas testable ici.
- `isTouch` sur un appareil réel : `APP_ID` est positionné par
  `lomiri-app-launch` (chaîne vérifiée dans la bibliothèque), mais
  `/etc/ubports/version` n'a pas été revérifié.
- Providers QtContacts / QtOrganizer réellement utilisables sur un desktop, et
  comportement de `Lomiri.Content` sans lancement par `lomiri-app-launch`.
- Rendu et ergonomie de l'app dans une session Lomiri desktop (résolution,
  clavier/souris, absence de geste d'arête inférieure).
- **Socle glibc des distributions cibles** : aucune mesure prise. Le point est
  bloquant pour promettre un AppImage « universel » (§8) — `ldd --version` sur
  la machine visée suffit.
- Noms réels des modules QML installés par les paquets de providers du PPA
  (`qtcontacts-sqlite`, `qtorganizer-eds`, `qtorganizer-mkcal`) et providers
  effectivement chargeables hors Touch.
- Comportement des modules clients d'un démon D-Bus quand le démon est absent :
  **observé pour `Lomiri.Thumbnailer`** (activation D-Bus puis suspension du
  processus, §10.3). Les autres modules clients (historique, contacts, hub de
  contenu) n'ont pas été observés un par un ; la détection ne teste donc que
  l'existence des fichiers, jamais le service.
- API exacte de `Lomiri.Content` pour détecter la disponibilité du hub de
  contenu, et nom d'enregistrement D-Bus du service d'historique.
- Rendu du thème Suru et du clavier (`maliit` en échec amd64) hors session
  Lomiri ; relocalisation effective des 7 plugins C++ maison dans une AppDir.
- État amd64 des paquets du PPA **au jour du build** (la page consultée montrait
  des builds en échec ; état non figé).
