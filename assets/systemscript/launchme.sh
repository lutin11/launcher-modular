#!/bin/bash
launched=$(ubuntu-app-list | grep launchermodular.lut11)
appid=$(ubuntu-app-launch-appids | grep launchermodular.lut11)
if [ -n appid ]
then
    ubuntu-app-launch $appid && tail --pid=$(ubuntu-app-pid $appid) -f /dev/null
fi
