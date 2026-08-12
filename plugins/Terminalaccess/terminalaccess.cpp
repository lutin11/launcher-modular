#include <QDebug>
#include <QFile>
#include <QDir>
#include "terminalaccess.h"

Terminalaccess::Terminalaccess() : _proc(), _cmd(), _output(), _err() {
    connect(&_proc,  SIGNAL(readyReadStandardOutput()), this, SLOT(fetchOutput()));
    connect(&_proc,  SIGNAL(readyReadStandardError()), this, SLOT(fetchError()));
    connect(&_proc,  SIGNAL(finished(int, QProcess::ExitStatus)), this, SLOT(procFinished(int, QProcess::ExitStatus)));
}

bool Terminalaccess::run(const QString &cmdline, bool reset_err, bool reset_out) {
    qDebug() << "Running : " << cmdline;
    prepare(cmdline);
    return start(reset_err, reset_out);
}
void Terminalaccess::prepare(const QString &cmdline) {
    _cmd = cmdline;
}
bool Terminalaccess::start(bool reset_err, bool reset_out) {
    _proc.kill();
    _proc.waitForFinished(5000);
    if(reset_err) {
        qDebug() << "Process fail to start :" << _proc.readAllStandardError() << _err;
        _err.clear();
    }
    if(reset_out) {
        _output.clear();
    }
    _proc.start("sh", QStringList() << "-c" << _cmd);
    if(!_proc.waitForStarted(5000)) {
        qDebug() << "Process fail to start :" << _cmd;
        return false;
    }
    return true;
}
QString Terminalaccess::outputUntilEnd() {
    if (!_proc.waitForFinished()) {
        qDebug() << "ERROR RUNNING " << _cmd <<" : " << _proc.errorString();
        qDebug() << _proc.readAllStandardError() << _err;
        return getNewOutput();
    }
    else {
        qDebug() << _proc.readAllStandardError();
        QString ret = getNewOutput()+_proc.readAll();
        qDebug() << "CMD RETURN : " << ret;
        //qDebug() << "CMD RETURN SUCCESS";
        return ret;
    }
}
QString Terminalaccess::getNewOutput() {
    QString newoutput = _output;
    _output = "";
    return newoutput;
}
QString Terminalaccess::getNewError() {
    QString newerror = _err;
    _err = "";
    return newerror;
}
void Terminalaccess::fetchError() {
    QString newerr=QString::fromLocal8Bit(_proc.readAllStandardError());
    if(newerr == "[sudo] password for phablet: ") {
        qDebug() << "Receive Terminalaccess::fetchError()";
        emit needSudoPassword();
    }
    _err+=newerr;
    qDebug() << "SLOT ERR : " << _err;
    if(newerr.contains("\n")){
        emit(newErrorLineAvailable());
    } else {
        emit newErrorAvailable();
    }
}
void Terminalaccess::fetchOutput() {
    QString newout = QString::fromLocal8Bit(_proc.readAllStandardOutput());
    _output+=newout;
    qDebug() << "SLOT READ : " << _output;
    if(newout.contains("\n")){
        emit(newOutputLineAvailable());
    } else {
        emit(newOutputAvailable());
    }

}
bool Terminalaccess::input(QString newinput, bool printDebug) {
    //if(printDebug)
    //    qDebug() << "SLOT WRITE : " << newinput;
    if(_proc.write(newinput.toLocal8Bit())) {
    		return true;
    }
    return false;
}
bool Terminalaccess::inputLine(QString newinput, bool printDebug) {
    return input(newinput+"\n", printDebug);
}
void Terminalaccess::procFinished(int exitcode, QProcess::ExitStatus es) {
    qDebug() << "FINISHED" << exitcode;
    emit(finished(exitcode));
}

bool Terminalaccess::copyFile(const QString &source, const QString &destination) {
    // QFile::copy() échoue si le fichier de destination existe déjà
    if (QFile::exists(destination)) {
        QFile::remove(destination);
    }
    bool ok = QFile::copy(source, destination);
    if (!ok) {
        qDebug() << "copyFile failed:" << source << "->" << destination;
    }
    return ok;
}

bool Terminalaccess::removeFile(const QString &path) {
    if (path.isEmpty() || !QFile::exists(path)) {
        return true; // rien à faire, ce n'est pas un échec
    }
    bool ok = QFile::remove(path);
    if (!ok) {
        qDebug() << "removeFile failed:" << path;
    }
    return ok;
}

bool Terminalaccess::makePath(const QString &path) {
    bool ok = QDir().mkpath(path);
    if (!ok) {
        qDebug() << "makePath failed:" << path;
    }
    return ok;
}

bool Terminalaccess::writeBytes(const QString &path, const QByteArray &data) {
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        qDebug() << "writeBytes failed to open:" << path;
        return false;
    }
    qint64 written = file.write(data);
    file.close();
    if (written != data.size()) {
        qDebug() << "writeBytes incomplete write:" << path << written << "/" << data.size();
        return false;
    }
    return true;
}

int Terminalaccess::removeFilesWithExtensions(const QString &dirPath, const QStringList &extensions) {
    QDir dir(dirPath);
    if (!dir.exists()) return 0;

    QStringList filters;
    for (const QString &ext : extensions) {
        filters << ("*." + ext);
    }

    QStringList files = dir.entryList(filters, QDir::Files);
    int removed = 0;
    for (const QString &file : files) {
        if (dir.remove(file)) {
            removed++;
        } else {
            qDebug() << "removeFilesWithExtensions failed for:" << file;
        }
    }
    return removed;
}
