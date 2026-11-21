# Known issues and backlog — Launcher Modular

Full list of identified defects and improvement candidates, with a prioritized
backlog. Stable architecture documentation lives in `ARCHITECTURE.md` (its
§13 summarizes this list).

> Snapshot produced by **static analysis** of the `develop` branch (version
> `2.5.0`). No build, desktop run or device test was used to produce it.
> **Re-verify each item against the current code before working on it**: some
> may already be fixed, and severity may have changed. Per `AGENTS.md`, do not
> "fix" these issues as a side effect of another task: report them first.

Maintenance: when an item is fixed, remove it here (or mark it `fixed in
<x.y.z>`) and update the summary in `ARCHITECTURE.md` §13 if it still lists it.

## 1. Security (high priority)

> The `unconfined` AppArmor template (`launchermodular.apparmor`) is a
> **deliberate decision, not an issue**: the app's purpose — running shell
> commands (`Terminalaccess`, `terminal:///` icons, Libertine launching) and
> inventorying files owned by other packages (`.desktop` files, Libertine
> containers) — is incompatible with click confinement (policy groups alone
> cover typed accesses like contacts, calendar, history or media dirs, but
> never arbitrary execution). The OpenStore explicitly supports this case:
> apps with extra privileges go through a manual review including a
> source-code review, which requires the app to be open source (this app is
> GPL-3.0) and a justification — see <https://open-store.io/submit/> and
> <https://docs.ubports.com/en/latest/appdev/platform/apparmor.html>. The
> decision is documented in `ARCHITECTURE.md` §10; do not re-flag it.
> Consequence to stay aware of: custom pages and custom icons inherit the
> same unrestricted access.

1. **sudo password through a QML dialog** (`qml/pages/Home.qml` +
   `Terminalaccess.inputLine`): the password (default `phablet`) is typed into
   an app text field (`echoMode: TextInput.Password`, so masked) and piped to
   `sudo -S` on stdin. The field's placeholder reveals the default password
   (`"Enter password (by defaut : phablet)"`, hard-coded and untranslated —
   only an obsolete entry survives in `po/ta.po`). Detection of the sudo
   prompt relies on matching the exact stderr line
   `"[sudo] password for phablet: "` (`terminalaccess.cpp`), so the whole
   mechanism breaks on any account other than `phablet`. Fragile by design;
   at minimum remove the default password from the placeholder, ideally
   restrict commands to an allow-list and drop the `sudo` path.
2. **Nextcloud credentials in clear text**: `nextcloudUser` /
   `nextcloudPassword` live in `Qt.labs.settings` (world-readable file in the
   user profile) and are sent as an `Authorization: Basic` header over WebDAV;
   `https` is not enforced in `qml/pages/nextcloudfolders/Settings.qml`.
   Recommend an *app password* and consider not persisting the secret.
3. **JavaScript evaluation of user input** (`plugins/CalculatorHelper/`):
   the expression is filtered by a restricted regex before
   `QJSEngine::evaluate`, which limits the risk, but "eval on user input"
   stays a fragile pattern (the regex allows `\s`, hence newlines, and the
   input is evaluated multi-line). A dedicated arithmetic parser would be
   safer.
4. **`Qt.openUrlExternally` on custom-icon actions** (`qml/pages/Home.qml`):
   a custom icon's action string is passed as-is (arbitrary schemes accepted;
   a `browser:///` prefix is stripped in one branch). The search bar is *not*
   affected: it checks `startsWith("http://"/"https://")` before opening the
   text directly and sends everything else, URL-encoded, to the configured
   search engine. Residual risk: imported icon collections carrying exotic
   schemes — validate the scheme at icon creation or at launch.

## 2. Responsiveness and robustness

1. **Probable UI freeze when launching a Libertine app**
   (`plugins/LibertineLauncher/`): `launchLibertineApp` creates a
   `LibertineWorker` and calls `worker->run()` **synchronously on the GUI
   thread**; `run()` ends with `waitForFinished(-1)` — if `lomiri-app-launch`
   stays alive while the app runs, the launcher UI freezes. The class name
   and the `QThread` includes suggest threading was planned but never
   wired. The `new`'d worker is also never deleted (one object leaks per
   launch). → Reproduce, then move to `QThread`/`QtConcurrent` or stop
   waiting for the process.
2. **`Terminalaccess` blocks the GUI thread**: `start()` (`_proc.kill()`,
   `waitForFinished(5000)`, `waitForStarted(5000)`) and `outputUntilEnd()`
   (`waitForFinished()` — 30-second default timeout) are synchronous calls
   made from QML; slow commands freeze the interface for up to 30 seconds.
3. **`Terminalaccess` is a singleton with a single `QProcess`**: two
   concurrent commands (music cache + uninstall…) interfere; `_proc.kill()`
   at the start of `start()` can kill an unrelated running command.
4. **`rssFeedChanged` is never declared**: `qml/pages/Rss.qml` and
   `qml/pages/rss/Settings.qml` read/write
   `launchermodular.settings.rssFeedChanged`, but the property does not exist
   in the `Settings` block of `qml/Main.qml`. With `Qt.labs.settings`
   (C++ `QQmlSettings`), assigning an undeclared property fails at runtime:
   the "reload feeds after change" mechanism likely only works by accident
   (reload on page visibility). → Declare the property or replace the flag
   with a direct call.
5. **Raw `AppInfo*` pointers exposed to QML** via `QQmlListProperty`;
   `AppHandler::reload()` does `qDeleteAll` then reloads. If QML still holds
   a reference in between (deferred binding), this is a potential
   use-after-free. Check under AddressSanitizer or redesign with parented
   objects plus a reset signal.
6. **Root ListModels saved only in `Component.onDestruction` of
   `Main.qml`**: a crash or `SIGKILL` loses the latest
   pages/favorites/icons changes. Save on every mutation (as the custom-icon
   dialog already does).
7. **`LibertineWorker::run()` re-injects `DISPLAY` with a `":0"` default**
   (`TODO` in the code) — fragile under Wayland/XWayland.

## 3. Portability and framework compliance

1. **Hard-coded import path in `main.cpp`**:
   `/usr/lib/aarch64-linux-gnu/lomiri/qml/` is arm64-specific, while
   `CMakeLists.txt` already defines `__ARCH_TRIPLET__` at compile time and
   never uses it. → Use the macro (or `QLibraryInfo`); otherwise the
   amd64/armhf builds (present in CI!) rely on incidental import resolution.
   Verify with an amd64 desktop run.
2. **Stale build dependencies**: `clickable.yaml` declares
   `libpam0g-dev` and `libgsettings-qt-dev` in `dependencies_target`, but
   neither PAM nor GSettings appears anywhere in the code. Conversely, the
   packages actually needed to compile the plugins (e.g. QtContacts) are not
   declared and come from the Docker images. → Clean up and/or complete
   `dependencies_host`/`dependencies_target`.
3. **Legacy QML modules with uncertain availability on
   `ubuntu-touch-24.04-1.x`**: `QtOrganizer 5.0` (calendar),
   `QtContacts 5.0`, `Lomiri.History 0.1`, `Lomiri.Thumbnailer 0.1`,
   `U1db 1.0`, `Qt.labs.settings` / `Qt.labs.folderlistmodel`,
   `QtGraphicalEffects` (deprecated; the Lomiri replacement is
   `Lomiri.Effects`). CI only compiles C++: **the presence of these QML
   modules at runtime is checked nowhere**. Calendar/Events/Contacts/History
   are the most exposed. → Make an inventory on a 24.04 device and migrate
   progressively.
4. **Contact backend `"galera"` hard-coded** in `ContactHelper`: breaks if
   the default contacts provider changes; provide a fallback.
5. **Inconsistent import versions** across QML files (`QtQuick 2.4` /
   `2.12` / `2.15`, `QtQuick.Controls 2.2` vs `2.12`): harmless while the
   modules exist, but blurs multi-framework support.

## 4. Architecture and maintainability

1. **Implicit coupling of pages to `Main.qml`**: direct access to the id
   `launchermodular` and to `DEBUG_MODE` only works because of the
   `Qt.createComponent` load in `Main.qml`'s context. Third-party custom
   pages rely on it, but the contract is invisible to tooling (no static
   analysis, no error until runtime). An explicit API (injected properties or
   a context singleton) would be more robust — this is also the API surface
   to freeze for third-party page compatibility.
2. **Monolithic QML files**: `Main.qml` mixes persistence, navigation and the
   custom-icon dialog; `Home.qml`, `Folders.qml` and `Rss.qml` are also very
   large candidates for splitting (the custom-icon dialog in `Main.qml` is
   the obvious first extraction).
3. **Business logic inside views**: WebDAV parsing, weather URL building,
   feed sorting, HTTP orchestration… live in QML files with no model/view
   separation and are untestable. The total absence of automated tests (no
   QML/C++ test anywhere, CI compiles only) is the main evolution risk.
4. **Hard-coded text, colors and HTML**: the UBports orange `#E95420`,
   `#111111`, `<font color=…>` and `<b>` tags inside `i18n.tr(...)` strings;
   `Lomiri.Components.Themes` is only partially used, so translated strings
   carry cosmetic choices.
5. **Version triple**: `manifest.json.in`, `appVersion` in `Main.qml` and
   `ChangeLogs.qml` must be updated together manually; a single injected
   source (CMake configure) would remove this risk.
6. **Generated/IDE files committed or unignored**: `launcher-modular.files`
   and `launcher-modular.includes` (auto-generated lists pointing at a local
   `build/` directory), `launcher-modular.iml`, `.DS_Store`;
   `.clickable/docker.io/` is not covered by `.gitignore` (only
   `.clickable/<arch>/…` files are). → Clean up and extend `.gitignore`.
7. **`DEBUG_MODE` is a compiled constant** (`main.cpp`): remote debugging
   requires a rebuild; an environment variable or build option would be more
   practical.
8. **`build.sh`** at the repository root is a personal script (macOS/Docker
   Desktop oriented, with a dubious `pkill` quoting); move it out of the
   repository or document it. Do not run it.
9. **CMake quirks**: `list(APPEND I18N_SRC_FILES ${DESKTOP_FILE_NAME}.in.h)`
   references a file that does not exist in the sources (it is an
   `intltool-extract` build artifact); `file(GLOB_RECURSE ...)` for QML/i18n
   sources is not re-evaluated when files are added (missing
   `CONFIGURE_DEPENDS`).
10. **`skip_review: true`** in `clickable.yaml`: packaging review is
    disabled — acceptable for development, re-enable before publication.

## 5. Prioritized backlog

| # | Action | Severity | Cost |
|---|---|---|---|
| 1 | Test Libertine launching (UI freeze), then thread `LibertineWorker` | High | Low |
| 2 | Harden the `sudo` path: remove the default-password hint, match the prompt without hard-coding `phablet`, restrict `terminal:///` commands to an allow-list | Medium | Low |
| 3 | Fix the hard-coded import path (`__ARCH_TRIPLET__`) | High | Very low |
| 4 | Declare `rssFeedChanged` (or drop the mechanism) | Medium | Very low |
| 5 | Runtime QML module inventory on 24.04 / 20.04 (QtOrganizer, QtContacts, Lomiri.History…) | High | Medium |
| 6 | Clean `clickable.yaml` (PAM/GSettings) and stray files (`*.files`, `*.includes`, `*.iml`, `.DS_Store`) | Low | Very low |
| 7 | Enforce `https` for Nextcloud and steer users to an "app password" | Medium | Low |
| 8 | First test baseline (QTest / QML `TestCase` on pure functions: WebDAV parsing, feed sorting, version comparison) | Medium | Medium |
| 9 | Single source of truth for the version | Low | Low |
| 10 | Split `Main.qml` / `Home.qml` and freeze an explicit API for custom pages | Medium | High |
