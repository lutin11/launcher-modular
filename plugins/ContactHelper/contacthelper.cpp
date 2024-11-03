#include "contacthelper.h"
#include <QDebug>


// Use the QtContacts namespace
using namespace QtContacts;

ContactHelper::ContactHelper(QObject *parent)
    : QObject(parent), manager("galera") {
}

QVariantMap ContactHelper::getContactById(const QString &contactIdString) {
    qDebug() << "Receive contactId:" << contactIdString;
    QVariantMap contactMap;

    // Convert the contactIdString into a QContactId object
    QContactId contactId = QContactId::fromString(contactIdString);
    qDebug() << "The first contactId:" << contactId;
    // Wrap the contactId in a QList and fetch the contact
    QList<QContactId> contactIds = { contactId };
    QList<QContact> contacts = manager.contacts(contactIds);

    if (!contacts.isEmpty()) {
        QContact contact = contacts.first();

        // Retrieve contact's name (if available)
        QContactName contactName = contact.detail<QContactName>();
        QString firstName = contactName.firstName();
        QString lastName = contactName.lastName();

        // Retrieve contact's phone number(s) (if available)
        QStringList phoneNumbers;
        for (const QContactPhoneNumber &phoneDetail : contact.details<QContactPhoneNumber>()) {
            phoneNumbers.append(phoneDetail.number());
        }

        // Populate contactMap with details to return to QML
        contactMap["firstName"] = firstName;
        contactMap["lastName"] = lastName;
        contactMap["phoneNumbers"] = phoneNumbers;

        qDebug() << "Contact map to return:" << contactMap;
    } else {
        qDebug() << "No contact found for this ID.";
    }

    return contactMap;  // Empty map if contact not found
}
