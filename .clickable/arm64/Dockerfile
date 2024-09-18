FROM docker.io/clickable/amd64-20.04-arm64
ARG GOPATH="/home/davidcosse/.clickable/go"
ARG SDK_FRAMEWORK="ubuntu-sdk-20.04.1"
ARG QT_VERSION="5.12"
ARG ARCH="arm64"
ARG ARCH_TRIPLET="aarch64-linux-gnu"
ARG ARCH_RUST="aarch64-unknown-linux-gnu"
ARG NUM_PROCS="16"
ARG ROOT="/home/davidcosse/workspace/launcher-modular"
ARG BUILD_DIR="/home/davidcosse/workspace/launcher-modular/build/aarch64-linux-gnu/app"
ARG SRC_DIR="/home/davidcosse/workspace/launcher-modular"
ARG INSTALL_DIR="/home/davidcosse/workspace/launcher-modular/build/aarch64-linux-gnu/app/install"
ARG CLICK_LD_LIBRARY_PATH="/home/davidcosse/workspace/launcher-modular/build/aarch64-linux-gnu/app/install/lib/aarch64-linux-gnu"
ARG CLICK_PATH="/home/davidcosse/workspace/launcher-modular/build/aarch64-linux-gnu/app/install/lib/aarch64-linux-gnu/bin"
ARG CLICK_QML2_IMPORT_PATH="/home/davidcosse/workspace/launcher-modular/build/aarch64-linux-gnu/app/install/lib/aarch64-linux-gnu"

RUN echo set debconf/frontend Noninteractive | debconf-communicate && echo set debconf/priority critical | debconf-communicate
RUN apt-get update && apt-get install -y --force-yes --no-install-recommends qml-module-lomiri-history0.1:arm64 history-service:arm64 qml-module-lomiri-contacts0.1:arm64 qml-module-lomiri-addressbook0.1:arm64 libpam0g-dev:arm64 libgsettings-qt-dev:arm64 qml-module-gsettings1.0:arm64 && apt-get clean