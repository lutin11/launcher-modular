#ifndef CONTACTHELPER_H
#define CONTACTHELPER_H

#include <QObject>
#include <QVariantMap>
#include <QtContacts/QContactManager>
#include <QtContacts/QContact>
#include <QtContacts/QContactId>
#include <QtContacts/QContactName>

class ContactHelper : public QObject {
    Q_OBJECT
public:
    explicit ContactHelper(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap getContactById(const QString &contactIdString);

private:
    QtContacts::QContactManager manager;  // Use QtContacts namespace for QContactManager
};

#endif // CONTACTHELPER_H
