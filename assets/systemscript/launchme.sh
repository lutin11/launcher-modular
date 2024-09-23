#!/bin/bash
launched=$(lomiri-app-list | grep launchermodular.lut11)
appid=$(lomiri-app-launch-appids | grep launchermodular.lut11)
if [ -n appid ]
then
    lomiri-app-launch $appid && tail --pid=$(lomiri-app-pid $appid) -f /dev/null
fi
