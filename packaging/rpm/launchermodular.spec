%global debug_package %{nil}
%global _build_id_links none

Name:           launchermodular
Version:        2.5.0
Release:        1%{?dist}
Summary:        Alternative full-screen launcher for Ubuntu Touch / Lomiri

License:        GPL-3.0-or-later
URL:            https://github.com/lutin11/launcher-modular
Source0:        launchermodular-appdir-%{version}.tar.gz

# The AppImage already carries the Qt/Lomiri runtime; do not let rpmbuild add
# a Requires for every bundled soname (they are not provided by Mageia).
AutoReqProv:    no

Requires:       bash
Requires:       glibc
Requires:       libstdc++6
Requires:       libgcc1
Requires:       fontconfig
Requires:       lib64freetype6
Requires:       lib64x11_6
Requires:       lib64gl1
Requires:       lib64egl1
Requires:       lib64glx0
Requires:       lib64glib2.0_0
Requires:       glib2.0-common
Requires:       hicolor-icon-theme
Requires:       gstreamer1.0-plugins-base
Requires:       gstreamer1.0-plugins-good
# libav lives in the tainted repository on Mageia: keep it optional so the
# package installs on a default system, while audio codecs work when enabled.
Recommends:     gstreamer1.0-libav

%description
Launcher Modular is an alternative full-screen launcher for Ubuntu Touch /
Lomiri: configurable pages, widgets and application shortcuts.

This package installs the same self-contained runtime as the AppImage under
/opt/launchermodular, because Mageia does not provide the Lomiri QML modules
or the UBports services. A small wrapper in /usr/bin and a desktop entry make
it available from the application menu.

%prep
%setup -q -n launchermodular-%{version}

%build
# The AppImage bundle is already built.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/opt/launchermodular
cp -a . %{buildroot}/opt/launchermodular/
mkdir -p %{buildroot}%{_bindir}
cat > %{buildroot}%{_bindir}/launchermodular <<'EOF'
#!/bin/sh
exec /opt/launchermodular/AppRun "$@"
EOF
chmod 0755 %{buildroot}%{_bindir}/launchermodular
install -Dpm0644 LauncherModular.desktop \
    %{buildroot}%{_datadir}/applications/LauncherModular.desktop
install -Dpm0644 launchermodular.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/launchermodular.svg

%files
%defattr(-,root,root,-)
%license LICENSE
/opt/launchermodular
%attr(0755,root,root) %{_bindir}/launchermodular
%{_datadir}/applications/LauncherModular.desktop
%{_datadir}/icons/hicolor/scalable/apps/launchermodular.svg

%changelog
* Sat Nov 28 2026 Launcher Modular <noreply@example.com> - 2.5.0-1
- Initial self-contained desktop RPM for Mageia.
