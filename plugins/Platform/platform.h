#ifndef PLATFORM_H
#define PLATFORM_H

#include <QObject>
#include <QString>
#include <QStringList>

// Detects which dependencies are really present on the machine, once at
// startup. The QML layer only reads the booleans exposed here: it never looks
// for binaries, files or services itself.
//
// Rules followed:
//  - no command is executed (no QProcess, no shell);
//  - no blocking call waiting for a service: everything is limited to checking
//    whether a file exists or a binary is in the PATH;
//  - the single D-Bus round trip (the Accounts service) happens on the first
//    read of the property, never in the constructor.
//
// A missing QML import makes the whole file that contains it fail, including
// its parent: an unavailable feature must therefore be removed from the
// composition (a Loader with active: false), not merely hidden with
// visible: false. See docs/PACKAGING_DESKTOP.md, section 10.
class Platform : public QObject
{
    Q_OBJECT

    // Runtime environment
    Q_PROPERTY(bool isTouch READ isTouch CONSTANT)
    Q_PROPERTY(bool isAppImage READ isAppImage CONSTANT)
    Q_PROPERTY(QString sessionDesktop READ sessionDesktop CONSTANT)

    // Binaries the application expects outside Ubuntu Touch
    Q_PROPERTY(bool hasClickTool READ hasClickTool CONSTANT)
    Q_PROPERTY(bool hasLomiriAppLaunch READ hasLomiriAppLaunch CONSTANT)

    // Features tied to Ubuntu Touch
    Q_PROPERTY(bool hasLibertineContainers READ hasLibertineContainers CONSTANT)
    Q_PROPERTY(bool canLaunchLibertine READ canLaunchLibertine CONSTANT)
    Q_PROPERTY(bool canUninstallApps READ canUninstallApps CONSTANT)

    // QtContacts and QtOrganizer providers installed on the machine. The
    // "memory" provider ships with Qt and holds no user data, so it is never
    // counted as a usable feature.
    Q_PROPERTY(QStringList contactProviders READ contactProviders CONSTANT)
    Q_PROPERTY(QStringList organizerProviders READ organizerProviders CONSTANT)
    // Name of the provider to use, empty when none is usable. The QML code used
    // to hard-code "galera" and "eds"; exposing the name keeps the application
    // working on a machine that only offers another provider, such as
    // qtcontacts-sqlite.
    Q_PROPERTY(QString preferredContactManager READ preferredContactManager CONSTANT)
    Q_PROPERTY(QString preferredOrganizerManager READ preferredOrganizerManager CONSTANT)
    // Platform-dependent compatibility: on Ubuntu Touch the contacts and
    // calendar stacks are part of the expected system and cannot be probed from
    // inside the reference container, so the feature is considered available
    // there. Outside Touch, a missing provider hides the feature instead of
    // showing an empty widget.
    Q_PROPERTY(bool hasContactsFeature READ hasContactsFeature CONSTANT)
    Q_PROPERTY(bool hasCalendarFeature READ hasCalendarFeature CONSTANT)

    // External QML modules, missing from some distributions. When a module is
    // absent, the page or widget that imports it is removed.
    Q_PROPERTY(bool hasHistoryModule READ hasHistoryModule CONSTANT)
    Q_PROPERTY(bool hasContactsModule READ hasContactsModule CONSTANT)
    Q_PROPERTY(bool hasQtContactsModule READ hasQtContactsModule CONSTANT)
    Q_PROPERTY(bool hasOrganizerModule READ hasOrganizerModule CONSTANT)
    Q_PROPERTY(bool hasContentModule READ hasContentModule CONSTANT)
    Q_PROPERTY(bool hasThumbnailerModule READ hasThumbnailerModule CONSTANT)
    Q_PROPERTY(bool hasDownloadManagerModule READ hasDownloadManagerModule CONSTANT)
    Q_PROPERTY(bool hasConnectivityModule READ hasConnectivityModule CONSTANT)
    Q_PROPERTY(bool hasMultimediaModule READ hasMultimediaModule CONSTANT)
    Q_PROPERTY(bool hasSensorsModule READ hasSensorsModule CONSTANT)
    Q_PROPERTY(bool hasSystemInfoModule READ hasSystemInfoModule CONSTANT)
    Q_PROPERTY(bool hasLocalStorageModule READ hasLocalStorageModule CONSTANT)

    // Services
    Q_PROPERTY(bool hasAccountsService READ hasAccountsService NOTIFY capabilitiesChanged)

public:
    explicit Platform(QObject *parent = nullptr);

    // QML import paths, handed over by the plugin when the engine is created.
    // Without them the presence of a module cannot be checked.
    static void setImportPaths(const QStringList &paths);

    bool isTouch() const { return m_isTouch; }
    bool isAppImage() const { return m_isAppImage; }
    QString sessionDesktop() const { return m_sessionDesktop; }

    bool hasClickTool() const { return m_hasClickTool; }
    bool hasLomiriAppLaunch() const { return m_hasLomiriAppLaunch; }

    bool hasLibertineContainers() const { return m_hasLibertineContainers; }
    bool canLaunchLibertine() const { return m_canLaunchLibertine; }
    bool canUninstallApps() const { return m_canUninstallApps; }

    QStringList contactProviders() const { return m_contactProviders; }
    QStringList organizerProviders() const { return m_organizerProviders; }
    QString preferredContactManager() const { return m_preferredContactManager; }
    QString preferredOrganizerManager() const { return m_preferredOrganizerManager; }
    bool hasContactsFeature() const { return m_hasContactsFeature; }
    bool hasCalendarFeature() const { return m_hasCalendarFeature; }

    bool hasHistoryModule() const { return m_hasHistoryModule; }
    bool hasContactsModule() const { return m_hasContactsModule; }
    bool hasQtContactsModule() const { return m_hasQtContactsModule; }
    bool hasOrganizerModule() const { return m_hasOrganizerModule; }
    bool hasContentModule() const { return m_hasContentModule; }
    bool hasThumbnailerModule() const { return m_hasThumbnailerModule; }
    bool hasDownloadManagerModule() const { return m_hasDownloadManagerModule; }
    bool hasConnectivityModule() const { return m_hasConnectivityModule; }
    bool hasMultimediaModule() const { return m_hasMultimediaModule; }
    bool hasSensorsModule() const { return m_hasSensorsModule; }
    bool hasSystemInfoModule() const { return m_hasSystemInfoModule; }
    bool hasLocalStorageModule() const { return m_hasLocalStorageModule; }

    bool hasAccountsService();

    // Multi-line "key: value" text for the diagnostic screen. Deliberately not
    // translated: it describes the machine and is meant to be pasted into a bug
    // report, it is not a user interface label.
    Q_INVOKABLE QString diagnostics();

signals:
    void capabilitiesChanged();

private:
    QStringList m_contactProviders;
    QStringList m_organizerProviders;
    QString m_preferredContactManager;
    QString m_preferredOrganizerManager;
    QString m_sessionDesktop;
    QString m_appId;
    bool m_isTouch = false;
    bool m_isAppImage = false;
    bool m_hasClickTool = false;
    bool m_hasLomiriAppLaunch = false;
    bool m_hasLibertineContainers = false;
    bool m_canLaunchLibertine = false;
    bool m_canUninstallApps = false;
    bool m_hasContactsFeature = false;
    bool m_hasCalendarFeature = false;
    bool m_hasHistoryModule = false;
    bool m_hasContactsModule = false;
    bool m_hasQtContactsModule = false;
    bool m_hasOrganizerModule = false;
    bool m_hasContentModule = false;
    bool m_hasThumbnailerModule = false;
    bool m_hasDownloadManagerModule = false;
    bool m_hasConnectivityModule = false;
    bool m_hasMultimediaModule = false;
    bool m_hasSensorsModule = false;
    bool m_hasSystemInfoModule = false;
    bool m_hasLocalStorageModule = false;
    bool m_accountsChecked = false;
    bool m_hasAccountsService = false;
};

#endif // PLATFORM_H
