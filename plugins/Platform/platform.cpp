#include "platform.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDir>
#include <QFile>
#include <QProcessEnvironment>
#include <QStandardPaths>

namespace {
// QML import paths of the engine, handed over at startup by
// PlatformPlugin::initializeEngine(). Empty when no engine was created.
QStringList g_importPaths;

// A module counts as present when one of its directories exists in one of the
// import paths. Versioned directories ("Contacts.0.1") carry the name Qt
// really uses on disk, hence the list of candidates.
bool anyDirExists(const QStringList &candidates)
{
    for (const QString &path : candidates) {
        if (QDir(path).exists()) {
            return true;
        }
    }
    return false;
}

QStringList moduleCandidates(const QString &relativeName, const QStringList &versions)
{
    QStringList candidates;
    for (const QString &importPath : g_importPaths) {
        if (importPath.isEmpty()) {
            continue;
        }
        for (const QString &version : versions) {
            candidates << importPath + QLatin1Char('/') + relativeName + version;
        }
    }
    return candidates;
}

// Lists the names of the installed Qt providers (QtContacts, QtOrganizer) found
// in the given directories. Files follow the "libqtcontacts_<name>.so"
// convention; only the name is kept, without duplicates.
QStringList providerNames(const QStringList &dirs, const QString &libraryPrefix)
{
    QStringList names;
    for (const QString &dir : dirs) {
        QDir candidates(dir);
        if (!candidates.exists()) {
            continue;
        }
        const QStringList entries = candidates.entryList(QStringList() << QStringLiteral("*.so"),
                                                         QDir::Files);
        for (const QString &entry : entries) {
            QString name = entry;
            if (name.startsWith(QStringLiteral("lib"))) {
                name.remove(0, 3);
            }
            if (!libraryPrefix.isEmpty()) {
                name.remove(libraryPrefix, Qt::CaseInsensitive);
            }
            if (name.endsWith(QStringLiteral(".so"))) {
                name.chop(3);
            }
            if (!name.isEmpty() && !names.contains(name)) {
                names << name;
            }
        }
    }
    return names;
}

QStringList providerWithout(const QStringList &providers, const QString &excluded)
{
    QStringList kept;
    for (const QString &provider : providers) {
        if (provider.compare(excluded, Qt::CaseInsensitive) != 0) {
            kept << provider;
        }
    }
    return kept;
}

// Name of the provider the application should use: the one its code was written
// for when it exists, otherwise any other usable provider. "memory" ships with
// Qt and contains no user data, so offering it would only produce an empty
// widget instead of a working feature.
QString selectProvider(const QStringList &providers, const QString &expected)
{
    if (providers.contains(expected, Qt::CaseInsensitive)) {
        return expected;
    }
    return providerWithout(providers, QStringLiteral("memory")).value(0);
}
} // namespace

Platform::Platform(QObject *parent)
    : QObject(parent)
{
    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();

    // --- runtime environment ------------------------------------------------
    m_appId = env.value(QStringLiteral("APP_ID"));
    m_sessionDesktop = env.value(QStringLiteral("XDG_SESSION_DESKTOP"));
    if (m_sessionDesktop.isEmpty()) {
        m_sessionDesktop = env.value(QStringLiteral("DESKTOP_SESSION"));
    }
    m_isAppImage = !env.value(QStringLiteral("APPIMAGE")).isEmpty();

    // Two signals of a launch by the Ubuntu Touch application launcher: the
    // APP_ID variable it sets (verified: the string is present in
    // liblomiri-app-launch), and the UBports image file (usual on UBports
    // images, not re-verified here). When both are missing isTouch is false,
    // which is safe on its own: no feature is hidden because of that single
    // flag (see docs/PACKAGING_DESKTOP.md, section 10), every capability is
    // tested for itself.
    const bool launchedByClick = !m_appId.isEmpty();
    const bool ubportsImage = QFile::exists(QStringLiteral("/etc/ubports/version"));
    m_isTouch = launchedByClick || ubportsImage;

    // --- binaries -----------------------------------------------------------
    m_hasClickTool = !QStandardPaths::findExecutable(QStringLiteral("click")).isEmpty();
    m_hasLomiriAppLaunch =
        !QStandardPaths::findExecutable(QStringLiteral("lomiri-app-launch")).isEmpty();

    // --- Libertine ----------------------------------------------------------
    QDir containers(QDir::homePath() + QStringLiteral("/.cache/libertine-container"));
    m_hasLibertineContainers =
        containers.exists() && !containers.entryList(QDir::Dirs | QDir::NoDotAndDotDot).isEmpty();
    m_canLaunchLibertine = m_hasLibertineContainers && m_hasLomiriAppLaunch;

    // Uninstalling a click package runs "click unregister": without the command
    // the button would only ask for a sudo password for nothing.
    m_canUninstallApps = m_hasClickTool;

    // --- contacts and calendar providers ------------------------------------
    // QtContacts and QtOrganizer load their providers from sub-directories of
    // the Qt plugin paths ("contacts" and "organizer"; older packagings used
    // "contactsservice" and "organizerservice"). With no provider installed,
    // QContactManager finds nobody: the contacts widgets show up but stay
    // empty, without a message. The check is limited to file existence, it runs
    // nothing and opens no database.
    QStringList libraryPaths = QCoreApplication::instance()
        ? QCoreApplication::libraryPaths() : QStringList();
    for (const QString &extra : qAsConst(g_importPaths)) {
        if (!libraryPaths.contains(extra)) {
            libraryPaths << extra;
        }
    }
    QStringList contactDirs;
    QStringList organizerDirs;
    for (const QString &path : qAsConst(libraryPaths)) {
        contactDirs << path + QStringLiteral("/contacts")
                    << path + QStringLiteral("/contactsservice");
        organizerDirs << path + QStringLiteral("/organizer")
                      << path + QStringLiteral("/organizerservice");
    }
    m_contactProviders = providerNames(contactDirs, QStringLiteral("qtcontacts_"));
    m_organizerProviders = providerNames(organizerDirs, QStringLiteral("qtorganizer_"));

    // The QML code names its providers explicitly: "galera" for contacts
    // (qml/widgets/FavoriteContact.qml, SearchContact.qml, plugins/ContactHelper)
    // and "eds" for the calendar (qml/pages/Calendar.qml, qml/widgets/Event.qml).
    // Those names stay the first choice, but a machine offering another
    // provider, such as qtcontacts-sqlite from the Lomiri PPA, is used instead
    // of being reported as unusable.
    m_preferredContactManager = selectProvider(m_contactProviders, QStringLiteral("galera"));
    m_preferredOrganizerManager = selectProvider(m_organizerProviders, QStringLiteral("eds"));

    // Compatibility per platform: inside the reference Touch container neither
    // galera nor eds is installed, so probing them there would hide widgets
    // that do work on a phone. On Touch the feature is therefore taken as
    // available; outside Touch the missing provider hides it.
    m_hasContactsFeature = m_isTouch || !m_preferredContactManager.isEmpty();
    m_hasCalendarFeature = m_isTouch || !m_preferredOrganizerManager.isEmpty();

    // --- external QML modules -----------------------------------------------
    // Versioned modules of the Lomiri stack are installed in a directory named
    // after the version ("Lomiri/Contacts.0.1"), others in a plain directory
    // ("Lomiri/Content"): both forms are tested.
    m_hasHistoryModule = anyDirExists(moduleCandidates(QStringLiteral("Lomiri/History"),
                                                       QStringList() << QStringLiteral(".0.1")
                                                                      << QString()));
    m_hasContactsModule = anyDirExists(moduleCandidates(QStringLiteral("Lomiri/Contacts"),
                                                        QStringList() << QStringLiteral(".0.1")
                                                                       << QString()));
    m_hasQtContactsModule = anyDirExists(moduleCandidates(QStringLiteral("QtContacts"),
                                                          QStringList() << QString()));
    m_hasOrganizerModule = anyDirExists(moduleCandidates(QStringLiteral("QtOrganizer"),
                                                         QStringList() << QString()));
    m_hasContentModule = anyDirExists(moduleCandidates(QStringLiteral("Lomiri/Content"),
                                                       QStringList() << QString()));
    m_hasThumbnailerModule = anyDirExists(moduleCandidates(QStringLiteral("Lomiri/Thumbnailer"),
                                                           QStringList() << QStringLiteral(".0.1")
                                                                          << QString()));
    m_hasDownloadManagerModule =
        anyDirExists(moduleCandidates(QStringLiteral("Lomiri/DownloadManager"),
                                      QStringList() << QStringLiteral(".1.2")
                                                     << QStringLiteral(".1")
                                                     << QString()));
    m_hasConnectivityModule = anyDirExists(moduleCandidates(QStringLiteral("Lomiri/Connectivity"),
                                                            QStringList() << QStringLiteral(".1")
                                                                           << QString()));
    m_hasMultimediaModule = anyDirExists(moduleCandidates(QStringLiteral("QtMultimedia"),
                                                          QStringList() << QStringLiteral(".5.12")
                                                                         << QStringLiteral(".5")
                                                                         << QString()));
    // Qt ships these three as separate packages on Debian-based distributions
    // (qml-module-qtsensors, qml-module-qtsysteminfo, qml-module-qtquick-localstorage2-0),
    // so a desktop may have one and not the others.
    m_hasSensorsModule = anyDirExists(moduleCandidates(QStringLiteral("QtSensors"),
                                                       QStringList() << QStringLiteral(".5.12")
                                                                      << QStringLiteral(".5")
                                                                      << QString()));
    m_hasSystemInfoModule = anyDirExists(moduleCandidates(QStringLiteral("QtSystemInfo"),
                                                          QStringList() << QStringLiteral(".5.0")
                                                                         << QStringLiteral(".5")
                                                                         << QString()));
    m_hasLocalStorageModule = anyDirExists(moduleCandidates(QStringLiteral("QtQuick/LocalStorage"),
                                                            QStringList() << QStringLiteral(".2.0")
                                                                           << QStringLiteral(".2")
                                                                           << QString()));
}

void Platform::setImportPaths(const QStringList &paths)
{
    if (!paths.isEmpty()) {
        g_importPaths = paths;
    }
}

bool Platform::hasAccountsService()
{
    if (!m_accountsChecked) {
        m_accountsChecked = true;
        QDBusConnectionInterface *interface = QDBusConnection::systemBus().interface();
        m_hasAccountsService =
            interface && interface->isServiceRegistered(QStringLiteral("org.freedesktop.Accounts")).value();
    }
    return m_hasAccountsService;
}

QString Platform::picturesLocation() const
{
    QString location = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    if (location.isEmpty())
        location = QDir::homePath() + QStringLiteral("/Pictures");
    return location;
}

QString Platform::diagnostics()
{
    QStringList lines;
    lines << QStringLiteral("isTouch: %1").arg(m_isTouch);
    lines << QStringLiteral("APP_ID: %1").arg(m_appId.isEmpty() ? QStringLiteral("-") : m_appId);
    lines << QStringLiteral("XDG_SESSION_DESKTOP: %1")
                 .arg(m_sessionDesktop.isEmpty() ? QStringLiteral("-") : m_sessionDesktop);
    lines << QStringLiteral("AppImage: %1").arg(m_isAppImage);
    lines << QStringLiteral("click: %1").arg(m_hasClickTool);
    lines << QStringLiteral("lomiri-app-launch: %1").arg(m_hasLomiriAppLaunch);
    lines << QStringLiteral("libertine containers: %1").arg(m_hasLibertineContainers);
    lines << QStringLiteral("canLaunchLibertine: %1").arg(m_canLaunchLibertine);
    lines << QStringLiteral("canUninstallApps: %1").arg(m_canUninstallApps);
    lines << QStringLiteral("contact providers: %1")
                 .arg(m_contactProviders.isEmpty() ? QStringLiteral("-")
                                                   : m_contactProviders.join(QStringLiteral(", ")));
    lines << QStringLiteral("organizer providers: %1")
                 .arg(m_organizerProviders.isEmpty() ? QStringLiteral("-")
                                                     : m_organizerProviders.join(QStringLiteral(", ")));
    lines << QStringLiteral("contact manager: %1")
                 .arg(m_preferredContactManager.isEmpty() ? QStringLiteral("-")
                                                          : m_preferredContactManager);
    lines << QStringLiteral("contacts feature: %1").arg(m_hasContactsFeature);
    lines << QStringLiteral("calendar manager: %1")
                 .arg(m_preferredOrganizerManager.isEmpty() ? QStringLiteral("-")
                                                            : m_preferredOrganizerManager);
    lines << QStringLiteral("calendar feature: %1").arg(m_hasCalendarFeature);
    lines << QStringLiteral("Lomiri.History: %1").arg(m_hasHistoryModule);
    lines << QStringLiteral("Lomiri.Contacts: %1").arg(m_hasContactsModule);
    lines << QStringLiteral("QtContacts: %1").arg(m_hasQtContactsModule);
    lines << QStringLiteral("QtOrganizer: %1").arg(m_hasOrganizerModule);
    lines << QStringLiteral("Lomiri.Content: %1").arg(m_hasContentModule);
    lines << QStringLiteral("Lomiri.Thumbnailer: %1").arg(m_hasThumbnailerModule);
    lines << QStringLiteral("Lomiri.DownloadManager: %1").arg(m_hasDownloadManagerModule);
    lines << QStringLiteral("Lomiri.Connectivity: %1").arg(m_hasConnectivityModule);
    lines << QStringLiteral("QtMultimedia: %1").arg(m_hasMultimediaModule);
    lines << QStringLiteral("QtSensors: %1").arg(m_hasSensorsModule);
    lines << QStringLiteral("QtSystemInfo: %1").arg(m_hasSystemInfoModule);
    lines << QStringLiteral("QtQuick.LocalStorage: %1").arg(m_hasLocalStorageModule);
    lines << QStringLiteral("org.freedesktop.Accounts: %1").arg(hasAccountsService());
    lines << QStringLiteral("import paths: %1").arg(g_importPaths.join(QStringLiteral(", ")));
    return lines.join(QLatin1Char('\n'));
}
