/*
 * <one line to give the program's name and a brief idea of what it does.>
 * Copyright (C) 2022  Eran <darkeye@librem.one>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "helperfunctions.h"
#include <QtCore/QFile>
#include <QtCore/qtextstream.h>
#include <QtCore/QDebug>
#include <QtCore/QXmlStreamWriter>
#include <QtCore/QDateTime>
#include <QtCore/QJsonObject>


HelperFunctions::HelperFunctions()
{

}

HelperFunctions::~HelperFunctions()
{

}

bool HelperFunctions::exportToFile(const QString path, const QVariant data){
	qDebug() << "Writing to file at : " <<  path;
	QFile file(path);
	if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) return false;
	QTextStream out(&file);
	out << data.toString();
	
	if(out.status() == QTextStream::WriteFailed) return false;
	file.close();
	return true;
}

QString HelperFunctions::generateOPMLFromList(QVariant list) {
	QString retStr = QString();
	QXmlStreamWriter *writer = new QXmlStreamWriter(&retStr);
	writer->setAutoFormatting(true);
	writer->writeStartDocument();
	writer->writeStartElement("opml");
		writer->writeStartElement("head");
			writer->writeTextElement("title","uRsses OPML Export");
			writer->writeTextElement("dateCreated",QDateTime::currentDateTime().toString());
		writer->writeEndElement();
		writer->writeStartElement("body");
		 	for(QVariant item: list.toList()) {
				QJsonObject json = item.toJsonObject();
				writer->writeStartElement("outline");
				writer->writeAttribute("title",json.value("title").toString());
				writer->writeAttribute("text",json.value("text").toString());
				writer->writeAttribute("description",json.value("description").toString());
				writer->writeAttribute("type",json.value("type").toString());
				writer->writeAttribute("xmlUrl",json.value("xmlUrl").toString());
				writer->writeEndElement();
			}
		writer->writeEndElement();
	writer->writeEndElement();
	writer->writeEndDocument();
	
	return retStr;
}
