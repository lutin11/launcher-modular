#!/bin/bash
CLICKABLE_FRAMEWORK=ubuntu-sdk-20.04.1 clickable build --arch arm64
pkill -SIGHUP -f /Applications/Docker.app 'docker serve' 
 
