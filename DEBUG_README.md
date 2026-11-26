# DEBUG_README — Piloter l'interface de Launcher Modular depuis l'hôte

Runbook pour rejouer le débogage de l'UI (captures d'écran, clics, swipe, resize)
avec `clickable desktop` dans Docker, sans outil d'automatisation installé.
Testé le 2026-11-25/26 sur l'hôte : session Wayland (KDE/Plasma), application
lancée via `clickable desktop` sur l'affichage X11 `:1` (XWayland).

## 1. Prérequis et permissions

| Besoin | Vérification | Remarque |
|---|---|---|
| Docker fonctionnel, utilisateur dans le groupe `docker` | `docker ps` | Pas de `sudo` nécessaire |
| `clickable` (clickable-ut) | `command -v clickable` | Utilise déjà les images `clickable/amd64-ut24.04-1.x-amd64` |
| Session graphique ouverte (l'app s'affiche sur l'écran de l'utilisateur) | `echo $DISPLAY` → `:1` | Le script clickable montait `/tmp/.X11-unix` |
| Xauth créée par clickable pour le conteneur | `ls /tmp/.docker.xauth` | À exporter pour les outils X11 côté hôte |
| `python3` + `libX11` + `libXtst` | `python3 -c "import ctypes.util; print(ctypes.util.find_library('Xtst'))"` | Présents sur une session desktop standard ; **aucune dépendance pip** |
| Binaire `ffmpeg` (capture d'écran) | `command -v ffmpeg` | ⚠️ `import` (ImageMagick) est éclipsé par un AppImage OpenCode sur cette machine — utiliser ffmpeg |

Pas de `sudo`, pas d'installation : les helpers n'utilisent que `ctypes` sur
`libX11`/`libXtst`. Les événements synthétiques ne sortent pas de la session X
de l'application.

## 2. Lancer l'application (desktop, framework 24.04)

```sh
cd <repo>
CLICKABLE_FRAMEWORK=ubuntu-touch-24.04-1.x clickable desktop   # tourne au premier plan → le lancer en arrière-plan avec redirection
# journal :
CLICKABLE_FRAMEWORK=ubuntu-touch-24.04-1.x clickable desktop > /tmp/clickable-desktop.log 2>&1 &
```

- Les modifications QML sont copiées dans `build/x86_64-linux-gnu/app/install/`
  à chaque invocation — vérifier son diff avec :
  `grep -n "texte du correctif" build/x86_64-linux-gnu/app/install/qml/Main.qml`
- Arrêt propre : `docker ps` → `docker stop <id>` (un `SIGTERM` sur le conteneur suffit).
- Journal applicatif : `tail /tmp/clickable-desktop.log` (les `console.log` QML y vont).

## 3. Localiser la fenêtre de l'application

```sh
export DISPLAY=:1 XAUTHORITY=/tmp/.docker.xauth
xprop -root _NET_CLIENT_LIST              # liste des IDs de fenêtres
xprop -id 0x2000016 WM_CLASS              # doit contenir "launchermodular.lut11"
```

L'ID change à chaque lancement → l'exporter pour les helpers : `export WIN_ID=0x2000016`.

## 4. Captures d'écran — `tools/debug/xgrab.py`

⚠️ Sous **Xwayland**, la capture du *root* (`ffmpeg -f x11grab -i :1`) est noire :
les fenêtres X sont redirigées. Il faut capturer la **fenêtre elle-même** :

```sh
python3 tools/debug/xgrab.py 0x2000016 /tmp/app.png   # PNG de la fenêtre (XGetImage)
```

Un SIGSEGV au moment de la sortie (après `saved …`) est bénin (nettoyage Xlib).

## 5. Souris clavier — `tools/debug/xact.py`

⚠️ **XTEST ne fonctionne pas sous Xwayland** (le compositeur n'injecte pas les
événements factices ; `xtest` ne lève aucune erreur mais rien n'arrive). Le
script envoie donc de vrais événements synthétiques **par fenêtre** via
`XSendEvent` (coordonnées relatives à la fenêtre de l'app) :

```sh
export DISPLAY=:1 XAUTHORITY=/tmp/.docker.xauth WIN_ID=0x2000016
python3 tools/debug/xact.py origin            # position de la fenêtre sur le root
python3 tools/debug/xact.py sclick X Y        # clic (press+release) dans la fenêtre
python3 tools/debug/xact.py sdrag X1 Y1 X2 Y2 # glisser-déposer (ex. swipe du bord bas)
python3 tools/debug/xact.py resize 900 640    # redimensionne la fenêtre
```

Modes `click`/`drag` (XTEST) conservés dans le script mais **sans effet** ici.

### Gestes utiles (fenêtre 360×600)

| Objectif | Commande |
|---|---|
| Retour (flèche haut-gauche des pages empilées) | `sclick 18 20` (ou `sclick 20 26` en grande fenêtre) |
| Ouvrir la barre du bas (item ancré au bord bas) | swipe lent : press en `y = hauteur-1`, puis motions vers le haut (voir `sdrag`) |
| Fermer la barre du bas | `sclick 180 300` (clic sur la couche de fermeture) |
| Swipe haut rapide | préférer des motions progressives de ~8 px tous les ~40 ms |

## 6. Données de test (profils)

- Paramètres persistés (`Qt.labs.settings`) : `~/.config/launchermodular.lut11/launchermodular.lut11.conf`
  → **sauvegarder avant test** : `cp ~/.config/launchermodular.lut11/launchermodular.lut11.conf /tmp/…bak`
  et restaurer après (`cp` en sens inverse). Sauvegarde applicative seulement à
  la destruction propre (`Component.onDestruction` de `Main.qml`) ; un
  `docker stop` n'écrit pas forcément → la conf hôte garde l'état d'avant.
- Le nombre de pages visible dans la barre du bas = clé `page=` de ce fichier
  (liste de Variant) ; modifier ce fichier avant lancement = modifier l'état de départ.

## 7. Limites connues de la méthode

- La barre du bas n'est plus un popup (item ordinaire depuis le correctif de
  rotation, voir §8) : les clics synthétiques doivent l'atteindre comme le reste
  de la page — à re-vérifier. Les vrais popups (dialogues Lomiri, par exemple la
  sélection de page) restent à tester au tactile.
- Délai entre l'action et le contenu visible de la capture : attendre ~0,5–1 s
  (ou forcer un repaint, p. ex. `resize`) avant de capturer.
- Après tout build (`clickable desktop`, CPack), **`po/*.po` sont réécrits**
  (horodatages + n° de lignes `Main.qml`) : nettoyer avec
  `git checkout -- 'po/*.po'` (sauf demande contraire).
- `xgrab.py`/`xact.py` supposent une profondeur 24 / 32 bpp, BGRA (standard).
- `error: XDG_RUNTIME_DIR not set in the environment.` (répété) à l'ouverture
  de la page Musique : message de **libpulse** (backend `Audio` de QtMultimedia),
  pas une erreur de l'app — `clickable desktop` ne définit pas `XDG_RUNTIME_DIR`
  et le son n'y fonctionne pas. Sur appareil, la session le définit.

## 8. Exemple complet (vérification de la barre du bas, correctif `bottomBarSettings`)

```sh
CLICKABLE_FRAMEWORK=ubuntu-touch-24.04-1.x clickable desktop > /tmp/clickable-desktop.log 2>&1 &
export DISPLAY=:1 XAUTHORITY=/tmp/.docker.xauth
xprop -root _NET_CLIENT_LIST && xprop -id <ID> WM_CLASS   # repérer <ID>
export WIN_ID=<ID>
python3 tools/debug/xgrab.py $WIN_ID /tmp/etat-initial.png
python3 tools/debug/xact.py sdrag 180 599 180 427         # ouvrir la barre
python3 tools/debug/xgrab.py $WIN_ID /tmp/barre-ouverte.png
python3 tools/debug/xact.py resize 900 640                # agrandir fenêtre ouverte
python3 tools/debug/xgrab.py $WIN_ID /tmp/apres-resize.png
python3 tools/debug/xact.py sclick 180 300                # refermer
python3 tools/debug/xgrab.py $WIN_ID /tmp/barre-fermee.png
docker stop <id-conteneur> ; git checkout -- 'po/*.po'
```

## 9. Reconstruire les paquets desktop (.deb / AppImage)

Identique à `.github/workflows/desktop.yml`, depuis la racine du dépôt
(`out/` et `.ci-tools/` sont gitignorés) :

```sh
# .deb (CPack), ~2 min :
docker run --rm --entrypoint sh -v "$PWD":/src:ro -v "$PWD/out:/out" \
  clickable/amd64-ut24.04-1.x-amd64:latest /src/packaging/desktop/build-deb.sh

# AppImage, ~5 min : télécharger d'abord les outils (⚠️ le binaire
# appimagetool doit être nommé appimagetool-x86_64.AppImage, même si le
# build continu est épinglé, ex. -954, comme en CI) :
mkdir -p .ci-tools out
curl -sfL -o .ci-tools/linuxdeploy-x86_64.AppImage \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
curl -sfL -o .ci-tools/linuxdeploy-plugin-qt-x86_64.AppImage \
  https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
curl -sfL -o .ci-tools/appimagetool-x86_64.AppImage \
  "https://github.com/probonopd/go-appimage/releases/download/continuous/appimagetool-954-x86_64.AppImage"
INCLUDE_TEST_PLATFORMS=1 docker run --rm --entrypoint sh -e INCLUDE_TEST_PLATFORMS \
  -v "$PWD":/src:ro -v "$PWD/.ci-tools:/tools:ro" -v "$PWD/out:/out" \
  clickable/amd64-ut24.04-1.x-amd64:latest /src/packaging/desktop/build-appimage.sh
```

Résultats dans `out/` : `launchermodular-<version>-Linux.deb`,
`Launcher_Modular-<version>-x86_64.AppImage` (le script fait lui-même un test
de démarrage offscreen — « start-up test: ok »). Vérifier le contenu du .deb :
`ar x out/…deb data.tar.gz && tar -xzf data.tar.gz ./usr/share/launchermodular/qml/Main.qml`.

Les builds CI (`main.yml`) produisent en plus les 6 `.click`
(matrice arch × framework) en artefacts `Launcher-modular_<framework>_<arch>`.
