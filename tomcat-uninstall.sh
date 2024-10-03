#!/bin/bash

# Variables
TOMCAT_USER=tomcat
TOMCAT_GROUP=tomcat
TOMCAT_HOME=/opt/tomcat

# Stop the Tomcat service
sudo systemctl stop tomcat

# Disable the Tomcat service
sudo systemctl disable tomcat

# Remove the Tomcat service file
sudo rm /etc/systemd/system/tomcat.service

# Reload systemd daemon
sudo systemctl daemon-reload

# Remove Tomcat installation directory
sudo rm -rf $TOMCAT_HOME

# Remove Tomcat user and group
sudo deluser $TOMCAT_USER
sudo delgroup $TOMCAT_GROUP

# Remove any remaining Tomcat configuration and log files
sudo rm -rf /etc/tomcat*
sudo rm -rf /var/lib/tomcat*
sudo rm -rf /var/log/tomcat*

# Clean up package manager
sudo apt-get purge tomcat*
sudo apt-get autoremove
sudo apt-get autoclean

echo "Tomcat has been successfully uninstalled."
