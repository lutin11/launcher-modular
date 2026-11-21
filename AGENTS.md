# OpenCode Guidelines — UBports / Lomiri Application

## General priorities

- Follow the instructions in this file, those of the repository, and the actual
  configuration of the project. In case of contradiction, point it out before
  acting and do not implicitly change versions or architecture.
- Favor targeted, readable changes that are compatible with the project and
  limited to the necessary files.
- Do not claim that a build, test, or check succeeded if it was not run.
- At the end, summarize the changes, the checks actually performed, their
  results, and the points that remain to be validated.

## Shell safety and scope

- Stay inside the repository. Do not use `..`, `../`, `../../`, `cd ..`, or any
  other path to reach a parent folder or files outside the project.
  If a task requires such access, stop and ask for permission.
- Do not run destructive or hard-to-reverse commands without explicit
  authorization. This notably includes `rm`, `sudo`, `dd`, `mkfs`, `fdisk`,
  `parted`, `chmod -R`, and `chown -R`.
- Do not bypass permissions through compound commands, scripts, redirections,
  or any other form of indirection.
- Before any command that modifies files, installs packages, accesses the
  network, changes Git state, or acts on a device, briefly explain its effect
  and ask for confirmation if the tool allows it.
- Do not run commands with elevated privileges to work around an error, an
  AppArmor denial, or a restriction of the environment.

## Git and contributions

- Check the state of the repository and any existing changes before modifying
  files. Preserve work that is already present.
- Do not commit, push, rewrite history, or perform any operation on a remote
  repository unless explicitly asked.
- Never push to `develop`, `master`, or `main`, directly or indirectly. Never
  push to the `weblate` remote.
- To prepare a contribution, use a dedicated branch if necessary and
  authorized. Prepare the changes for a Merge Request (MR). Do not create,
  push, or merge an MR without authorization.
- Before any Git operation that modifies a branch, the history, or a remote
  repository, present the operation and ask for confirmation.
- `develop` is the current development branch, `master` the stable version.
  The `*-xenial` branches are in maintenance (framework 16.04): do not port
  changes to them without an explicit request.

## Honesty and uncertainty

- Do not invent APIs, QML modules, properties, paths, command options, or
  behaviors. If you are not certain, check the code or the official
  documentation, or state explicitly that you do not know.
- Distinguish what is verified (code read, command run), what is inferred, and
  what is an assumption.
- If the request is ambiguous, incomplete, or rests on a doubtful assumption,
  ask a precise question before acting rather than choosing for me. Group your
  questions, and ask only if the answer really changes the outcome; for a minor
  detail, pick the safest option and state the assumption.
- If you disagree with my request or see a risk, say so clearly before
  executing, instead of approving by default.
- If a result is partial, a test fails, or a task is not feasible as requested,
  say so plainly, without dressing it up.

## Project context

Launcher Modular (`launchermodular.lut11`) is an alternative full-screen
launcher for Ubuntu Touch / Lomiri: configurable pages (home, calendar, photos,
RSS, music, videos, Nextcloud, tasks), widgets, and application shortcuts.
Main repository: `github.com/lutin11/launcher-modular` (fork of
`ruditimmermans/launcher-modular`). License: GPL-3.0.

- **Read `docs/ARCHITECTURE.md` before any change**: structure, modules,
  dependencies, persistence, and procedures for adding a page, a widget, or a
  plugin. Keep it up to date if your change alters the structure.
- Stack: QML (QtQuick 2.12, Lomiri.Components 1.3) for the UI and most of the
  logic; JavaScript for workers; C++/Qt 5 for the binary and the QML extension
  plugins (`plugins/`); CMake; gettext; Clickable with Docker.
- C++ is only a service provider for QML. Do not move logic between C++ and QML
  without a request.
- Reference framework: `ubuntu-touch-24.04-1.x` (other targets: 20.04 and the
  `*-xenial` branches). The sources of truth are `clickable.yaml` and
  `manifest.json.in`; if they differ from this file, report it.
- The repository documentation was produced by static analysis (version 2.5.0,
  `develop` branch). If the code diverges from the documentation, trust the code
  and report the discrepancy.

## Project-specific rules

1. **Settings**: any property read or written through `launchermodular.settings.*`
   must be declared in the `Settings` block of `Main.qml`. An undeclared
   property fails at runtime.
2. **Page contract**: pages are loaded with `Qt.createComponent` in the context
   of `Main.qml` and access the `launchermodular` id and `DEBUG_MODE`, including
   custom pages from `~/.launchermodular/pages/`. Do not rename or remove these
   ids without agreement: they form the API for third-party pages.
3. **Page convention**: `pages/NamePage.qml` + `pages/namepage/Settings.qml`
   (+ `assets/`). Widgets follow the same logic in `widgets/`.
4. **QML arrays**: `.push()` and `.splice()` on a property do not notify
   bindings. Copy the array (`.slice()`), modify the copy, then reassign it.
5. **C++ plugins**: they are independent of each other (no cross C++
   dependencies) and exposed as singletons. `Terminalaccess` has a single shared
   `QProcess` and blocking calls: do not add blocking calls from QML and do not
   run concurrent commands.
6. **Persistence**: the root `ListModel`s are only saved in
   `Component.onDestruction` of `Main.qml`. Do not assume a change survives an
   abrupt shutdown.
7. **QML imports**: they are resolved at runtime and CI does not check them.
   Do not add an import (`QtOrganizer`, `QtContacts`, `Lomiri.History`,
   `QtGraphicalEffects`…) without verifying its availability on the target
   framework, and report any legacy import you encounter.
8. **Versions**: `manifest.json.in`, `appVersion` in `Main.qml`, and
   `ChangeLogs.qml` must be modified together, only for a requested release.
9. **Translations**: use `i18n.tr(...)`. Do not edit `.po` files by hand
   (managed through Weblate). Do not add HTML or hard-coded colors to a
   translatable string.
10. **Files not to modify** without a need tied to the task: `po/*.po`,
    `launchermodular.apparmor`, `manifest.json.in`, `launchermodular.contenthub`,
    `launchermodular.desktop.in`, `.github/workflows/`. Do not modify or run
    `build.sh` (personal, non-portable script). Ignore stray files (`*.files`,
    `*.includes`, `*.iml`, `.DS_Store`, `.clickable/`, `build/`).

## Known sensitive points

Do not fix them in passing: report them, and do not make them worse. The full
list is in `docs/KNOWN_ISSUES.md`.

- The application is `unconfined` (AppArmor): a deliberate, documented
  decision, required by its shell-execution and app-inventory features and
  accepted by the OpenStore manual review for apps with extra privileges
  (see `docs/ARCHITECTURE.md` §10). Do not extend this choice and do not add
  `policy_groups` without justification.
- `Terminalaccess`, `terminal:///` icons, and `sudo -S` run shell commands: do
  not widen this surface and never handle a password in clear text.
- Nextcloud credentials are stored in clear text in `Settings`: do not add any
  other persistent secret.
- `Qt.openUrlExternally` is called on custom-icon action strings in
  `Home.qml` (the search field itself checks `http(s)` before opening).
- `CalculatorHelper` evaluates a user expression with `QJSEngine`.
- Libertine launching is synchronous on the GUI thread.
- `main.cpp` contains a hard-coded import path specific to arm64.

## Understanding the project

Before coding:

1. Read the repository's guidelines and documentation, including
   `docs/ARCHITECTURE.md`.
2. Identify its structure, Git state, build files, manifests, tests,
   resources, and CI workflows.
3. Identify the languages, versions, and tools actually in use, notably
   Ubuntu Touch, Lomiri, Clickable, Qt, C++, and QML.
4. Briefly summarize the modules involved in the task, their role, and their
   interactions.

In particular, consult, if they exist: `README`, `CONTRIBUTING`,
`clickable.yaml`, manifests, CMake/qmake files, tests, and CI workflows.
Do not assume a project is empty or that it follows a standard architecture.
Do not replace its architecture or dependencies without established reason and
the user's agreement.

## Documentation and versions

- For information that may have changed, consult the current official
  documentation of UBports/Lomiri, Qt, or the tool concerned.
- Favor sources matching the versions identified in the project (Qt 5,
  Lomiri.Components 1.3, framework 24.04-1.x). Clearly state the assumptions
  made and the versions verified.
- Do not choose an API, dependency, or version solely because it is more
  recent. Check its compatibility with the project and the target.
- If the configuration and the documentation seem incompatible, report the
  problem before modifying the configuration.

## Clickable

The project uses `clickable-ut` and Docker (compilation happens inside Docker
images; nothing else is required on the host).

- Installation, only after authorization:
  `pipx install clickable-ut`
- Update, only after authorization:
  `pipx upgrade clickable-ut`
- Commands documented in the repository (`README.md`, "How to build"), to be
  run from the project root, after confirmation (they use Docker and may
  access the network):
  - build: `CLICKABLE_FRAMEWORK=ubuntu-touch-24.04-1.x clickable build --arch arm64`
  - desktop run (tests):
    `CLICKABLE_FRAMEWORK=ubuntu-touch-24.04-1.x clickable desktop`
  - device logs: `CLICKABLE_FRAMEWORK=ubuntu-touch-24.04-1.x clickable logs`
  - build + install + launch on the device:
    `CLICKABLE_FRAMEWORK=ubuntu-touch-24.04-1.x clickable`
    (action on a device: requires explicit confirmation)
  - CI command: `clickable build --libs --app`
- Do not invent other Clickable commands. For a build, installation, test, or
  deployment not documented in the repository, consult the Clickable
  documentation for the version in use and propose the command before running
  it.
- Ask for confirmation before an installation, an update, a network operation,
  or an action on a device.
- Do not treat a desktop test as a validation on a device: confinement,
  permissions, services, and hardware may differ. Specify what was tested and
  what remains to be verified.

## Application security

- Apply the principle of least privilege. Request only the AppArmor
  permissions required by an identified feature.
- Before adding a permission, explain which function needs it and why. Do not
  disable AppArmor and do not bypass confinement to solve a problem.
- Do not assume that access that works on desktop will be allowed or available
  on Ubuntu Touch. Check the behavior in the target context.
- Treat user input, imported files, network data, settings, RSS feeds, WebDAV
  responses, and content received from other applications, as well as custom
  pages, as untrusted.
- Validate inputs and paths. Avoid command injection, code evaluation,
  execution of downloaded content, and arbitrary file access.
- Do not add any secret, token, password, or private data to the code, tests,
  logs, or screenshots.
- Before adding a dependency, check its necessity, provenance, license,
  version, and compatibility with the target. Pin its version if the project
  allows it.
- Do not modify permissions, hooks, credentials, manifests, or publication
  metadata unless required by the task.

## C++, Qt, and QML

- Respect the Qt versions and the project's conventions. Check the
  availability and compatibility of the APIs used.
- In C++, avoid undefined behavior, dangling pointers, lifetime issues,
  uncontrolled concurrent access, and dangerous conversions.
- In Qt, check the lifetime of objects and of signal/slot connections. Do not
  needlessly block the UI thread, and handle asynchronous operations and their
  errors.
- In QML, respect the Lomiri components and conventions already in use. Avoid
  side effects in bindings, duplicated state, and business logic that is hard
  to maintain inside views.
- Provide for loading, empty-content, error, and success states when the
  feature requires it.
- Take into account screen sizes, orientation, touch targets, and the
  application lifecycle.
- Respect the existing internationalization: do not add hard-coded visible
  text if the project uses a translation system.
- Preserve existing interfaces and search for their usages before any API
  change. Do not add a dependency for a simple need already safely covered by
  the project.

## Build, tests, and review

- Use `clickable.yaml` and the repository's build files as the reference.
  Identify the commands and procedures actually intended before running them.
- Do not assume that a desktop build validates the package for the device or
  for all target architectures.
- **The project has no automated tests, and CI only compiles.** A green CI
  proves neither correct behavior nor the presence of QML modules at runtime.
  Always distinguish "compiles", "tested on desktop", and "tested on device".
- For a logic change, suggest (without imposing it) QTest or QML `TestCase`
  tests targeting pure functions (WebDAV parsing, feed sorting, version
  comparison), and ask before introducing any test infrastructure.
- For C++/Qt, check the results and transitions concerned. For QML, check the
  views and interactions affected. Distinguish automated tests from manual
  checks.
- Ask for confirmation before a command that installs dependencies, modifies
  the environment, accesses the network, or acts on a device.
- Do not delete a failing test or reduce its scope to make the suite pass
  without justification.
- After the changes, review the diff to spot accidental changes, generated or
  vendored files modified without reason, regressions, and sensitive data.
- Do not publish, install, or deploy any package without an explicit request.
- In the report, list the commands actually run and clearly distinguish
  checks that succeeded, failed, were not run, and are manual.

## Definition of "done"

A task is done when: the change is limited to what was needed, the diff has
been reviewed, visible strings go through `i18n.tr`, no permission or sensitive
file was modified without justification, versions and documentation
(`docs/ARCHITECTURE.md`) remain consistent with the code, and the report states
what remains to be validated on desktop or on a device.
