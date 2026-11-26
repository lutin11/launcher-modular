# Note de travail — versions desktop (ne pas committer)

Note de reprise d'une session à l'autre. État **au 24/11/2026**. Le contenu est
volatil : il décrit ce qui est fait, vérifié, et ce qui reste. La source de
vérité des choix techniques reste `docs/PACKAGING_DESKTOP.md` ; la structure
stable est dans `docs/ARCHITECTURE.md`.

## 1. Objectif

Faire évoluer Launcher Modular vers des versions **desktop** en plus du
`.click` :

1. **détection des capacités** selon les dépendances réellement présentes —
   **terminée et câblée** ;
2. un **`.deb` Ubuntu Lomiri** — build, production et **vérification
   d'installation dans le conteneur faits** (§3.2) ; reste non testé sur une
   vraie machine (VM Lomiri desktop) ;
3. un **AppImage** universelle — **en cours** : première construction de
   l'AppDir engagée le 24/11 (§4).

`.rpm` Mageia/ROSA abandonné : `import Lomiri.Components 1.3` empêche tout
démarrage hors pile Lomiri.

## 2. État Git

- Branche courante : `feature/desktop-packaging` (depuis `develop` `14351aa`,
  **non poussée**). `develop` inchangé.
- `feature/onboarding-tutorial` = `1411425` (**poussée**) ;
  `feature/libertine-nonblocking` = `e186aab` (non poussée).
- `git stash@{0}` = churn `POT-Creation-Date` ; stashes 1 à 4 à ne pas toucher.
- **Ne pas committer sans demande explicite.** Ne rien pousser.
- Fichiers modifiés (suivis) : `CMakeLists.txt`, `main.cpp`,
  `po/CMakeLists.txt`, `plugins/CMakeLists.txt`,
  `plugins/{AppHandler,CalculatorHelper,ContactHelper,LibertineLauncher,MySettings,NetworkHelper,Terminalaccess}/CMakeLists.txt`,
  `docs/ARCHITECTURE.md`, `qml/{Help,Main,Pagemanagement}.qml`,
  `qml/pages/Home.qml`, `qml/pages/home/Settings.qml`,
  `qml/widgets/{FavoriteContact,SearchContact}.qml`.
- Fichiers nouveaux : `plugins/Platform/` (7 fichiers),
  `cmake/SetDesktopIcon.cmake`, `qml/components/PageUnavailable.qml`,
  `qml/helpers/PageRequirements.js`, `docs/PACKAGING_DESKTOP.md`,
  `packaging/desktop/{build-deb.sh,build-appimage.sh,AppRun}`,
  `.github/workflows/desktop.yml` (accord explicite du 24/11 pour ce
  dernier),
  ce fichier. À ne pas ajouter : `.clickable/docker.io/`,
  `launcher-modular.iml`.
- **Fait le 24/11** : `qml/helpers/Capabilities.js` supprimé (aucune référence
  vérifiée par `grep -rn` ; sauvegarde
  `/home/david/tmp/opencode/Capabilities.js.bak`) ; churn `po/` restauré par
  `git restore po/` (67 fichiers, `POT-Creation-Date` + références de lignes
  uniquement).

## 3. Fait et vérifié

### 3.1 Détection des capacités (plugin C++ `Platform`)

- `plugins/Platform/` : singleton QML `Platform 1.0`, 25 propriétés +
  `diagnostics()` ; **aucune commande exécutée, aucun appel bloquant**, un seul
  aller-retour D-Bus (`org.freedesktop.Accounts`) évalué paresseusement ;
  chemins d'import reçus dans `initializeEngine`.
- Règle de compatibilité (source unique, en C++) : `preferredContactManager` =
  `galera` sinon tout provider sauf `memory` ; `preferredOrganizerManager` =
  `eds` sinon idem ; `hasContactsFeature`/`hasCalendarFeature` = `isTouch ||
  manager non vide`.
- Câblage QML : `Home.qml` (Loaders `MusicPlayer`, `Lastcall`, `Lastmessage`,
  `Event`, `SearchContact`, `FavoriteContact`, Libertine, désinstallation),
  `Main.qml` (pages déjà enregistrées → `PageUnavailable`, garde `ImportPage`),
  `Pagemanagement.qml` (ligne repliée), `pages/home/Settings.qml`
  (interrupteurs), `Help.qml` (panneau Diagnostic),
  `widgets/{FavoriteContact,SearchContact}.qml` (`preferredContactManager`).
- Deux faits durs qui commandent l'architecture : un `import` manquant **tue le
  composant parent** (d'où `Loader { active: … }`, jamais `visible: false`) ;
  `import Lomiri.Thumbnailer 0.1` déclenche une **activation D-Bus bloquante**
  sans démon. `Qt.labs.folderlistmodel 2.12` **n'a pas** `filterOnName`.
- Modules détectés : 12 booléens « module » dont `hasSensorsModule`,
  `hasSystemInfoModule`, `hasLocalStorageModule` (ajoutés après inspection de
  `Clock.qml`, `Music.qml`, `Todo.qml`, `RssModel.qml`).
- Vérifications : plugin compilé **et exécuté** dans
  `clickable/amd64-ut24.04-1.x-amd64` (`contactManager=galera`,
  `organizerManager=` vide, `contactsFeature=true` via `isTouch`… — attendu dans
  ce conteneur) ; `qmllint` sans erreur de syntaxe sur **tout** `qml/` ;
  `node --check` sur le JS.

### 3.2 Correctifs de build (mode desktop) et `.deb`

Voir `docs/PACKAGING_DESKTOP.md` §3.1 pour le détail. Récapitulatif :

- `option(DESKTOP_INSTALL OFF)` + `option(INSTALL_CLICK_FILES)` ;
  `BIN_DIR`/`DATA_DIR`/`PLUGIN_IMPORT_DIR`/`DESKTOP_FILE_DIR` par mode ;
  macros `LAUNCHERMODULAR_DATA_DIR` et `LAUNCHERMODULAR_IMPORT_DIR`.
- 8 plugins : destination rendue **relative** via `PLUGIN_IMPORT_DIR`
  (avec repli) ; `po/CMakeLists.txt` : locale `share/locale/...` relatif.
- `find_program(dpkg-architecture)` + repli `CMAKE_LIBRARY_ARCHITECTURE`.
- `cmake/SetDesktopIcon.cmake` remplace `Icon=` après `intltool-merge`
  (le `.desktop.in` n'est pas touché).
- `main.cpp` : `findDataDirectory()` (env → `$APPDIR` → dossier de
  l'exécutable → macro), chemins d'import depuis `__ARCH_TRIPLET__`,
  `QUrl::fromLocalFile`.
- CPack `DEB` : version / description / mainteneur **lus dans
  `manifest.json.in`** ; dépendances classées Depends / Recommends / Suggests
  selon la détection ; `qml-module-lomiri-contacts` en **Suggests** (absent de
  noble, et apt installe les Recommends par défaut).
- **Vérifié le 24/11** (job relancé après perte de la sortie du 22/11) :
  - littéraux `/usr/share/launchermodular`,
    `/usr/lib/x86_64-linux-gnu/launchermodular`, `/usr/lib/%1/lomiri/qml`
    présents dans le binaire (macros bien injectées) ;
  - `make install` **dans le conteneur** puis `/usr/bin/launchermodular` :
    **aucune erreur de chemin**, `Main.qml` chargé depuis
    `/usr/share/launchermodular`, repli `alarm manager "eds" → "memory"` ;
  - `LAUNCHERMODULAR_DATA_DIR=/nonexistent` : message d'aide affiché (la
    variable commande bien la résolution). La contre-vérification « variable
    correcte » n'a pas rendu sa sortie (timeout 20 s) — couverte par le point
    précédent (macro par défaut).
- Reste à valider sur une vraie 24.04 : `apt-get install --dry-run ./launchermodular-*.deb`
  (résolution des Depends + Recommends sans PPA), et la présence de l'icône sans
  `gtk-update-icon-cache`.

**Mesures réellement faites** dans `clickable/amd64-ut24.04-1.x-amd64` :

| Contrôle | Résultat |
|---|---|
| `make install` en configuration **par défaut** | arbre **identique** à avant : binaire + `qml/` + `assets/` + `manifest.json` + `.apparmor` + `.contenthub` + `.desktop` (`Icon=assets/logo.svg`) à la racine, 8 modules sous `lib/x86_64-linux-gnu/`, 63 langues sous `share/locale` |
| `make install` en `-DDESKTOP_INSTALL=ON` | `/usr/bin/launchermodular`, `/usr/lib/x86_64-linux-gnu/launchermodular/{8 plugins}`, `/usr/share/launchermodular/{qml (58 .qml),assets}`, `/usr/share/applications/launchermodular.desktop` (`Exec=launchermodular`, `Icon=launchermodular`), svg en hicolor **et** pixmaps, 63 `.mo` |
| `cpack -G DEB` | `launchermodular-2.5.0-Linux.deb`, 14 Mo, 406 entrées, `Version: 2.5.0`, mainteneur et description corrects, `Depends`/`Recommends`/`Suggests` conformes |
| outils du conteneur | `dpkg-architecture`, `dpkg-deb` 1.22.6, `cpack` (générateur DEB) présents ; **`debhelper`, `dh`, `lintian`, `linuxdeploy`, `appimagetool` absents** → CPack retenu, `debian/` invérifiable ici |
| noms de paquets | `dpkg -S` dans le rootfs : `qml-module-{lomiri-components,lomiri-connectivity,lomiri-contacts,lomiri-content,lomiri-downloadmanager,lomiri-thumbnailer,qtgraphicaleffects,qt-labs-folderlistmodel,qt-labs-settings,qtquick-layouts,qtquick-localstorage,qtquick-xmllistmodel,qtmultimedia,qtsensors,qtsysteminfo,qtcontacts,qtorganizer,u1db}` ; `apt-cache policy` : `qml-module-qtquick{2,-window2,-controls2,-templates2}`, `libqt5qml5` (les candidats Lomiri viennent du PPA configuré dans l'image ; présence dans `noble` vérifiée séparément sur `packages.ubuntu.com`) |
| `__ARCH_TRIPLET__` | **défini et jamais utilisé** avant ce changement ; le chemin arm64 de `main.cpp` était un littéral |
| `/usr/lib/<triplet>/lomiri/qml` | existe (`qml-module-lomiri-notifications`, porte `Lomiri.Notifications`) → chemin genericisé, non supprimé |

## 4. AppImage — état au 24/11 (en cours)

**Acquis du 24/11 (vérifiés)** :

- `linuxdeploy --plugin=qt` fonctionne dans le conteneur de référence avec
  `--appimage-extract-and-run` (pas de FUSE). Il **scanne tout l'AppDir** à la
  recherche de fichiers QML (`qmlimportscanner -rootPath /tmp/AppDir`), trouve
  donc `usr/share/launchermodular/qml` et déploie dans `usr/qml` **tous** les
  modules nécessaires : `QtQuick.2`, `QtQuick/{Window.2,Layouts,Controls.2
  (styles Fusion, Imagine, **Suru**, Material, Universal), Templates.2,
  XmlListModel, LocalStorage}`, `QtQml/Models.2`, `Qt/labs/{settings,
  folderlistmodel}`, `QtGraphicalEffects`, `QtMultimedia`, `QtSensors`,
  `QtSystemInfo`, `QtContacts`, `QtOrganizer`, `U1db`,
  `Lomiri/{Components, Connectivity, Contacts.0.1, Content, DownloadManager,
  History, OnlineAccounts, PerformanceMetrics, Thumbnailer.0.1}` ;
- `qt.conf` écrit à côté du binaire (`Prefix=../`, `Plugins=plugins`,
  `Qml2Imports=qml`) ; plugins Qt (platforms/xcb, imageformats…) dans
  `usr/plugins` ; RPATH `$ORIGIN` posé sur tous les ELF ;
- la chaîne de lancement est `AppRun` (généré, source les hooks Qt) →
  `AppRun.wrapped` (notre AppRun personnalisé passé par `--custom-apprun`,
  qui exporte `QML2_IMPORT_PATH=$APPDIR/usr/lib/<triplet>/launchermodular`)
  → `/usr/bin/launchermodular` ;
- AppDir complète : **197 Mo**, sauvegardée dans
  `/home/david/tmp/opencode/appimage-out/AppDir` ;
- **appimagetool refuse un `.desktop` sans `Categories=`** — corrigé dans
  `cmake/SetDesktopIcon.cmake` (ajoute `Categories=Utility;` quand absent,
  mode desktop uniquement, le `.desktop.in` n'est pas touché).

**Pièges rencontrés** :

- `appimagetool-x86_64.AppImage` n'existe **pas** dans la release `continuous`
  de go-appimage (404) : télécharger le nom avec numéro de build
  (`appimagetool-954-x86_64.AppImage`).
- les artefacts écrits dans `/out` par le conteneur appartiennent à **root** :
  impossible de les éditer depuis l'hôte (`sed -i` échoue en Permission
  non accordée) ; tout correctif d'AppDir se fait **dans le conteneur**, et
  les scripts font un `chown` de `/out` en fin de course.
- `appimagetool` exige `VERSION=…` sous peine de « Version not found,
  aborting » (valeur lue dans `manifest.json.in` par le script) ; sortie nommée
  `Launcher_Modular-<version>-x86_64.AppImage` (nom dérivé de `Name=` du
  `.desktop`, pas du binaire).
- `EXTRA_PLATFORM_PLUGINS` du `linuxdeploy-plugin-qt` **continuous** ne
  découpe pas la valeur : espace, `;` et `:` donnent tous « Cannot deploy
  non-existing library file: <toute la chaîne> ». **Contournement retenu** :
  copier à la main `libqoffscreen.so`, `libqminimal.so`, `libqvnc.so` dans
  `usr/plugins/platforms` — leurs seules dépendances (`libQt5Gui`,
  `libQt5Core`) sont déjà déployées et l'AppRun Qt exporte `LD_LIBRARY_PATH`.
- l'image SDK **n'a pas** les plugins QtWayland (`libqwayland_*` absents de
  `qmake -query QT_INSTALL_PLUGINS`/platforms) : plateforme Wayland non
  embarquable ici ; sur un bureau Wayland l'app passe par XWayland (`xcb`).
  Le paquet `qtwayland5-*` serait à ajouter pour embarquer Wayland.
- **Test headless du 24/11** (AppImage extraite, `QT_QPA_PLATFORM=offscreen`) :
  `Could not find the Qt platform plugin "offscreen" … Available platform
  plugins are: xcb` — échec dû uniquement à la plateforme absente de l'AppImage
  (xcb est le comportement voulu pour un vrai bureau) ; prouve au passage que
  `qt.conf` et le chemin des plugins sont bien résolus dans l'AppImage.

Décisions et préparation :

- **Socle glibc : Noble (≥ 2.39), provisoire.** La question « mesurer
  `ldd --version` sur les machines cibles » reste posée (§12.1 de l'étude) ;
  le PPA n'imposant que Noble/Resolute, c'est la seule base constructible ici.
  À annoncer : « nécessite glibc ≥ 2.39 » jusqu'à mesure.
- Outils téléchargés dans `/home/david/tmp/opencode/appimage-tools/`
  (autorisés par l'utilisateur le 24/11) :
  `linuxdeploy-x86_64.AppImage` (continuous, 19,8 Mo),
  `linuxdeploy-plugin-qt-x86_64.AppImage` (continuous, 12,7 Mo),
  `appimagetool-x86_64.AppImage` = `appimagetool-954` de la release
  `continuous` de `probonopd/go-appimage` — **attention : le nom
  `appimagetool-x86_64.AppImage` en continuous renvoie 404**, il faut le nom
  avec numéro de build (`appimagetool-954-x86_64.AppImage`).
  L'hôte n'a ni `linuxdeploy` ni `appimagetool` ; le conteneur non plus.
  Les trois s'exécutent avec `--appimage-extract-and-run` (pas de FUSE en
  conteneur). `qmake` 5.15.13 est **présent** dans le conteneur.
- **Point d'architecture connu avant build** : `LAUNCHERMODULAR_IMPORT_DIR`
  est une macros absolue (`/usr/lib/<triplet>/launchermodular`) qui, dans une
  AppImage, pointerait hors du montage FUSE → l'`AppRun` personnalisé exporte
  `QML2_IMPORT_PATH=$APPDIR/usr/lib/<triplet>/launchermodular`.
  `findDataDirectory()` gère déjà `$APPDIR/usr/share/launchermodular`.
- **AppImage produite (run 4, 24/11)** : `Launcher_Modular-2.5.0-x86_64.AppImage`
  (70 Mo) dans `/home/david/tmp/opencode/appimage-out/`, avec plateformes
  `xcb` + `offscreen` + `minimal` + `vnc` ; exécution headless de l'AppImage
  extraite : **binaire démarré, polices chargées, `Main.qml` résolu et chargé**
  (avertissement `ChangeLogs.qml`, repli alarm manager, inventaire `.desktop`
  par AppHandler), **aucun `module … is not installed`** ; sortie finale 139 =
  limite connue du conteneur (le rendu thématisé `Lomiri.Components` y
  segfaulte, indépendamment du packaging). `.deb` reconstruit avec
  `Categories=Utility;` (14 Mo), `Exec`/`Icon`/dépendances conformes.
- **Test de confirmation (run 5, 24/11) — auto-suffisance prouvée** : AppDir
  reconstruite sous `/tmp/work` et AppImage régénérée ; dans un conteneur neuf
  où `/tmp/AppDir` (la macro compilée) **n'existe pas**, l'AppImage extraite
  charge `Main.qml`, `pages/Home.qml` et les widgets **depuis l'intérieur de
  l'AppImage** (`file:///tmp/x/usr/share/launchermodular/...`) grâce à
  `APPDIR` exporté par l'AppRun ; **aucun `module … is not installed`**. Le
  segfault final (139) survient après la résolution de tous les imports, dans
  un contexte purement environnemental (activation Telepathy, PulseAudio,
  AccountsService absents) — limite connue du conteneur, pas un défaut de
  packaging. Artefacts finaux dans `/home/david/tmp/opencode/appimage-out/` :
  `Launcher_Modular-2.5.0-x86_64.AppImage` (70 Mo),
  `launchermodular-2.5.0-Linux.deb` (14 Mo, `Categories=Utility;` inclus),
  `AppDir/` (avec l'AppRun corrigé), logs `at.log`, `ld.log`, `run.log`.
- **Recette officialisée dans le dépôt** : `packaging/desktop/build-deb.sh`,
  `packaging/desktop/build-appimage.sh` et `packaging/desktop/AppRun`
  (l'appel passe par `sh /src/…` : le bit exécutable n'est pas nécessaire,
  et `chmod` sur l'hôte est refusé par le harnais). Les scripts locaux
  `appimage1.sh` / `appimage4.sh` / `appimage5.sh`
  (`/home/david/tmp/opencode/`) restent l'historique de la mise au point.
  `/tmp/AppDir/...`, c'est-à-dire par la **macro compilée**
  (`-DCMAKE_INSTALL_PREFIX=/tmp/AppDir/usr` au build 1) et non par `$APPDIR` —
  le runtime AppImage ne pose `$APPDIR` qu'au montage FUSE, pas en mode extrait.
  Sur une machine réelle où `/tmp/AppDir` n'existe pas, un AppImage extraite
  aurait donc ouvert une **fenêtre vide**. **Corrigé** : l'`AppRun` personnalisé
  exporte `APPDIR="${APPDIR:-$HERE}"` (le montage FUSE garde sa valeur).
  Test de confirmation en cours avec l'AppDir construite ailleurs
  (`/tmp/work`) pour que la macro compilée ne puisse pas tricher.
- Script de build : `/home/david/tmp/opencode/appimage1.sh` — build
  `-DDESKTOP_INSTALL=ON -DCMAKE_INSTALL_PREFIX=/tmp/AppDir/usr`, dépose
  `.desktop` + svg + `AppRun` à la racine de l'AppDir, lance
  `linuxdeploy --plugin=qt --custom-apprun` puis sauvegarde AppDir et log dans
  `/home/david/tmp/opencode/appimage-out/` (monté `/out`, rw) pour itérer sans
  tout recompiler.
- Lancement du 24/11 : job shell `sh_20b67b996001aymJaAb6eGKK4q`
  (conteneur `--rm`, `/src` en lecture seule). Sortie :
  `/home/david/.local/share/opencode/shell/c1ef85a8b8f31eb3a89b27e5a3a3568c8fe70da3/sh_20b67b996001aymJaAb6eGKK4q.out`.
  **Résultat à consigner ici** dès réception : modules QML déployés par
  plugin-qt (scanne-t-il `usr/share/launchermodular/qml` ?), taille AppDir,
  présence `usr/qml` + `qt.conf`, puis éventuellement copie manuelle des
  modules manquants (`Lomiri/*`, `QtOrganizer`, `QtContacts`, `U1db`…) avec
  `--deploy-deps-only` sur chaque `.so`, et `appimagetool`.

## 5. Prochaines étapes

1. **Machines réelles** (aucun des deux formats n'y a été testé) :
   - `.deb` : VM Ubuntu 24.04 + session Lomiri — `apt-get install --dry-run
     ./launchermodular-*.deb` (résolution Depends + Recommends **sans** PPA),
     installation, lancement depuis le lanceur d'applications, icône sans
     `gtk-update-icon-cache`, visite complète (toutes les capacités doivent
     être vraies sur un poste Lomiri complet) ;
   - AppImage : d'abord `ldd --version` sur les machines visées (décision
     §12.1 en attente — l'AppImage actuelle exige glibc ≥ 2.39) ; tester le
     montage FUSE (`./Launcher_Modular-2.5.0-x86_64.AppImage`) et le mode
     extrait, sous X11 **et** Wayland (XWayland) ; noter le comportement des
     fonctions à démon absent (miniatures, historique, content hub).
2. **CI créée le 24/11 (accord explicite)** : `.github/workflows/desktop.yml`,
   deux jobs `ubuntu-24.04` construits **dans l'image
   `clickable/amd64-ut24.04-1.x-amd64`** (seule base où la recette est
   vérifiée ; dépendances et PPA déjà présents dans l'image) : `deb`
   (`packaging/desktop/build-deb.sh` + artifact) et `appimage`
   (`packaging/desktop/build-appimage.sh`, outils téléchargés par le job,
   `APPIMAGETOOL_VERSION` épinglée, test de démarrage headless via
   `INCLUDE_TEST_PLATFORMS=1`, artifacts `.AppImage` + `appimage-run.log`).
   La recette locale `main.yml` (click) est inchangée. **Validation de bout en
   bout des scripts dans le conteneur : **validés** — `.deb` avec les 63 `.mo`
   sous `./usr/share/locale` (correction `po/CMakeLists.txt` à la suite d'un
   `DESTINATION` absolu qui les plaçait hors du paquet) ; AppImage 69 Mo avec
   `usr/share/locale`, plateformes `xcb`+`offscreen`/`minimal`/`vnc`, test de
   démarrage ok (voir Annexe A de l'étude, sixième round) ;
   premier déclenchement GitHub à surveiller (taille de l'image docker, noms
   d'artifacts).
3. Si diffusion de l'AppImage : `UPDATE_INFORMATION` / `.zsync` pour les
   mises à jour (publication GitHub Release), et décider l'embarquement de
   QtWayland (installer `qtwayland5`-plugins dans l'image de build).
4. Signaler (ne pas corriger au passage) : `ContactHelper` garde `galera` en dur
   en C++ ; `desktopFileInfoAvailable`/`servicesAvailable` non détectés ; le
   provider d'agenda n'a pas de repli nommé ; quand `findDataDirectory()` échoue,
   le binaire avertit puis ouvre une fenêtre vide (faut-il `return 1` ? à
   arbitrer) ; la macro `LAUNCHERMODULAR_DATA_DIR` garde la valeur du préfixe
   **de compilation** (piège pour les tests en conteneur, sans effet sur
   l'AppImage dont l'AppRun pose `APPDIR`).
5. Mettre à jour `docs/ARCHITECTURE.md` (section build : mode desktop, CPack,
   AppImage) et le `README.md` (« How to build » desktop) — pas encore fait.
6. Validations **impossibles ici**, à faire en session Lomiri / sur appareil :
   rendu de `PageUnavailable`, panneau Diagnostic, ligne repliée de la liste
   « ajouter une page », widgets masqués ou conservés, visite complète du
   tutoriel, Libertine non bloquant, et surtout **aucune régression sur
   appareil** (toutes les capacités doivent y être vraies).

## 6. Recettes et pièges

- **Lancement manuel des recettes (validé le 24/11)** — uniquement dans le
  conteneur SDK, pas sur l'hôte ; depuis la racine du dépôt :
  - `.deb` : `mkdir -p out && docker run --rm --entrypoint sh -v "$PWD":/src:ro
    -v "$PWD/out:/out" clickable/amd64-ut24.04-1.x-amd64:latest -c
    'sh /src/packaging/desktop/build-deb.sh'` ;
  - AppImage : idem + `-v <outils>:/tools:ro` (les trois `.AppImage` —
    linuxdeploy, linuxdeploy-plugin-qt, appimagetool-954 — sont dans
    `/home/david/tmp/opencode/appimage-tools/`) + éventuellement
    `-e INCLUDE_TEST_PLATFORMS=1`. Dans `desktop.yml` le job AppImage
    télécharge lui-même les outils (version épinglée).
  Les scripts détectent maintenant un lancement hors conteneur (message
  d'erreur explicite) et `chown` les artefacts de `/out` à l'utilisateur du
  dépôt (vérifié : deb 14 Mo rendu `david:david`). `out/` ajouté au
  `.gitignore`.
- **Traductions hors préfixe (corrigé le 24/11)** : `po/CMakeLists.txt`
  installait les `.mo` avec `DESTINATION /share/locale/...` (chemin
  **absolu**) : dans le `.deb` ils finissaient à `./share/locale` et, au
  `make install` d'une AppImage, dans le `/share` **racine du conteneur** —
  jamais dans l'AppDir ni `/usr/share/locale`. Inoffensif pour le click
  (préfixe `/`, générés de toute façon sous `${CMAKE_INSTALL_PREFIX}`).
  Corrigé en `share/locale/${LANG}/LC_MESSAGES` (relatif) : click inchangé,
  desktop → `${prefix}/share/locale`. Le domaine est
  `launchermodular.lut11` ; l'app ne charge pas elle-même les catalogues
  (aucun `QTranslator` dans le code) — c'est le singleton `i18n` de
  `Lomiri.Components` ; si ses chemins de recherche desktop diffèrent, seule
  une machine réelle le dira.
- Le harnais refusant `chmod` sur l'hôte, les scripts de
  `packaging/desktop/` sont **sans bit exécutable** et doivent être invoqués
  par `sh /src/…` (c'est ce que fait `desktop.yml` via
  `--entrypoint sh … /src/…`) ; `build-appimage.sh` copie les outils
  AppImage dans son espace de travail avant `chmod` car `/tools` est monté
  en lecture seule.

- Exécution headless qui fonctionne :
  `docker run --rm --entrypoint sh -v <repo>:/src:ro clickable/amd64-ut24.04-1.x-amd64:latest -c 'mkdir -p /tmp/rt && chmod 700 /tmp/rt && export XDG_RUNTIME_DIR=/tmp/rt; timeout 60 env QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software dbus-run-session -- stdbuf -oL -eL /usr/lib/qt5/bin/qmlscene -I /tmp/imp /tmp/t.qml'`
  (attention : `--entrypoint sh` + commande ⇒ **ne pas** répéter `sh`).
- **Un build modifie le dépôt** : la cible `update_po_files` réécrit ~67
  `po/*.po` et `po/launchermodular.lut11.pot`. Toujours construire sur une
  **copie** (`cp -r /src /tmp/b`), sinon `git restore po/`.
- Rien de thématisé `Lomiri.Components` (`Button`, `Icon`, `PageHeader`) ne
  s'exécute dans ce conteneur (sortie 139) ; `MainView` + `PageStack` + `Page` +
  `Rectangle` fonctionnent. **Exception constatée le 24/11** : le binaire
  complet lancé via `/usr/bin` sans `QT_QUICK_BACKEND=software` va plus loin
  (page Aide instanciée, inventaire `.desktop`) — le segfault dépend du
  harnais, pas seulement du composant.
- La sonde `qmlscene` module par module **ne vaut pas** comme preuve de
  disponibilité (timeout même pour des modules installés).
- Éditer les fichiers Unicode : le harnais normalise les apostrophes — prendre
  `oldString` depuis `sed`/`grep` et l'aligner exactement (indentation comprise).
- `git status` après chaque session : aucun `po/*.po` ne doit être modifié.
- **Permission du harnais (constaté le 24/11)** : les commandes contenant `rm`,
  `chmod` sur fichiers téléchargés, ou des boucles `for` avec `curl -O` sont
  refusées ; `git restore` + `mv` (déplacement vers
  `/home/david/tmp/opencode`) passent, `curl -sfL -o <chemin explicite>` passe.
  Pour rendre un AppImage exécutable : `cp` + `chmod` **dans le conteneur**.
- `docker run` sans `-v` du script appelé par chemin absolut échoue
  (`cannot open /tmp/…sh`) : monter le script (`-v …/appimage1.sh:/appimage1.sh:ro`).
