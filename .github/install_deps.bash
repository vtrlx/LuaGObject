set -x
sudo apt-get update -qq
sudo apt-get install -y libgirepository1.0-dev libgirepository-2.0-dev libcairo2-dev gir1.2-gtk-4.0 gir1.2-adw-1 libffi-dev libglib2.0-dev
sudo apt-get install -y xvfb dbus-x11 at-spi2-core
