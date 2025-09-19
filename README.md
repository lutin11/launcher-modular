# Launcher modular

A launcher modular for ubuntu touch

<p float="left">
  <img src="/assets/samples/Home_Page.png" width="100" alt="Main page"/>
  <img src="/assets/samples/Home_Page_Toolbar.png" width="100" alt="Main page toolbar"/> 
  <img src="/assets/samples/Calendar_Page.png" width="100" alt="Calendar page"/>
  <img src="assets/samples/TODO_Page.png" width="100" alt="Page note"/>
  <img src="assets/samples/RSS_Page.png" width="100" alt="RSS note"/>
  <img src="assets/samples/Picture_Page.png" width="100" alt="Picture page"/>
  <img src="assets/samples/Global_Settings.png" width="100" alt="Global settings"/>
  <img src="assets/samples/Add_Icon.png" width="100" alt="Add icon"/>
  <img src="assets/samples/Add_Page.png" width="100" alt="Add page"/>
  <img src="assets/samples/RSS_Setings.png" width="100" alt="RSS setings"/>
</p>

### The “Launcher Modular” lets you quickly view information such as:
- time
- weather forecast
- latest calls
- latest messages
- upcoming events

### It gives quick access to your favorite:
- applications
- contacts

### By clicking on a contact's icon, you can call them or send them a message.

### It give you access to all your applications from Ubports, Libertine, Waydroid

### You have the option of adding “Pages” as:
- Agenda
- Todo list
- Photos
- RSS feeds
- Music
- Videos

### The main search bar will search your contacts, applications and the web at the same time

## How to build

To build Launcher Modular for Ubuntu Touch devices you do need clickable. Follow install instructions at its repo [here](https://gitlab.com/clickable/clickable).
Once clickable is installed you are ready to go.

1. Fork [Launcher Modular at GitHub](https://github.com/lutin11/launcher-modular) into your own namespace. You may need to open an account with GitHub if not already done.
2. Open a terminal: ctl + alt + t.
3. Clone the repo onto your local machine using git: `git clone git@github.com:lutin11/launcher-modular.git`.
4. Change into Launcher Modular folder: `cd launcher-modular`.
5. build for arm64 arch, run: `clickable build --arch arm64`.
6. develop into ide: `clickable ide`.
7. to launch on phone run clickable: `clickable` or on desktop: `clickable desktop`.
8. to view logs: `clickable logs`

font used: https://www.keshikan.net/fonts-e.html

### Fom 2.4.0 the branch develop and master have default framework is 24.04
use `CLICKABLE_FRAMEWORK=ubuntu-touch-24.04-1.x clickable`
if you switch from framwork you may need to execute the following command:
`docker system prune -a --volumes`

### for 22.04 framework 
switch to develop-jammy and master-jammy



