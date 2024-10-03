#To allow access from remote hosts, you need to modify the context.xml file for the Host Manager. Open the file located at conf/Catalina/localhost/host-manager.xml:


#!/bin/bash

# Update and install dependencies
sudo apt update
sudo apt install -y openjdk-11-jdk wget curl

# Set the Tomcat version to install
TOMCAT_VERSION="10.1.30"
TOMCAT_USER="tomcat"

# Create a user for running Tomcat
sudo useradd -m -U -d /opt/tomcat -s /bin/false $TOMCAT_USER

# Download Tomcat
wget https://dlcdn.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz

# Extract Tomcat
sudo mkdir -p /opt/tomcat
sudo tar -xzf apache-tomcat-$TOMCAT_VERSION.tar.gz -C /opt/tomcat --strip-components=1
sudo rm apache-tomcat-$TOMCAT_VERSION.tar.gz

# Update ownership of Tomcat files
sudo chown -R $TOMCAT_USER: /opt/tomcat
sudo chmod -R 755 /opt/tomcat

# Create systemd service file for Tomcat
sudo bash -c 'cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd and enable Tomcat
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl start tomcat

# Wait for Tomcat to start
sleep 10

# Configure User Authentication for Tomcat
sudo bash -c 'cat <<EOF > /opt/tomcat/conf/tomcat-users.xml
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
               version="1.0">

  <!-- Define roles and users here -->
  <role rolename="manager-gui"/>
  <role rolename="admin-gui"/>
  <user username="admin" password="admin_password" roles="manager-gui,admin-gui"/>
  
</tomcat-users>
EOF'

# Set permissions for the users configuration file
sudo chown tomcat: /opt/tomcat/conf/tomcat-users.xml
sudo chmod 600 /opt/tomcat/conf/tomcat-users.xml

# Restart Tomcat to apply changes
sudo systemctl restart tomcat

# Output the status of the Tomcat server
sudo systemctl status tomcat

echo "Apache Tomcat has been installed and user authentication has been configured."
