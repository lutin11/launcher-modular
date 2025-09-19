#!/bin/bash
CLICKABLE_FRAMEWORK=ubuntu-touch-24.04-1.x clickable build --arch arm64
pkill -SIGHUP -f /Applications/Docker.app 'docker serve' 
 
