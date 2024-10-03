#To restrict access to the Tomcat server to only specific IP addresses, you can modify the RemoteAddrValve configuration in the context.xml files for the Manager and Host Manager applications. Here’s how you can update the script to include this restriction:

#!/bin/bash

# Variables
TOMCAT_VERSION=10.1.30
TOMCAT_USER=tomcat
TOMCAT_GROUP=tomcat
TOMCAT_HOME=/opt/tomcat
TOMCAT_DOWNLOAD_URL=https://dlcdn.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
ALLOWED_IPS="192\\.168\\.1\\.100|192\\.168\\.1\\.101"  # Replace with your allowed IP addresses

# Update and install necessary packages
sudo apt update
sudo apt install -y default-jdk wget

# Create Tomcat user and group
sudo useradd -m -U -d $TOMCAT_HOME -s /bin/false $TOMCAT_USER

# Download and extract Tomcat
cd /tmp
wget $TOMCAT_DOWNLOAD_URL
sudo mkdir -p $TOMCAT_HOME
sudo tar xzvf apache-tomcat-$TOMCAT_VERSION.tar.gz -C $TOMCAT_HOME --strip-components=1
sudo chown -R $TOMCAT_USER:$TOMCAT_GROUP $TOMCAT_HOME
sudo chmod -R u+x $TOMCAT_HOME/bin

# Create systemd service file for Tomcat
sudo bash -c 'cat << EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/default-java"
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

# Reload systemd and start Tomcat
sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat

# Configure user authentication
sudo bash -c 'cat << EOF > /opt/tomcat/conf/tomcat-users.xml
<tomcat-users>
  <role rolename="manager-gui"/>
  <role rolename="admin-gui"/>
  <user username="admin" password="s3cret" roles="manager-gui,admin-gui"/>
</tomcat-users>
EOF'

# Ensure necessary directories exist
sudo mkdir -p /opt/tomcat/conf/Catalina/localhost

# Allow access from specific IPs for Manager and Host Manager
sudo bash -c "cat << EOF > /opt/tomcat/conf/Catalina/localhost/manager.xml
<Context antiResourceLocking=\"false\" privileged=\"true\">
  <Valve className=\"org.apache.catalina.valves.RemoteAddrValve\" allow=\"$ALLOWED_IPS\" />
</Context>
EOF"

sudo bash -c "cat << EOF > /opt/tomcat/conf/Catalina/localhost/host-manager.xml
<Context antiResourceLocking=\"false\" privileged=\"true\">
  <Valve className=\"org.apache.catalina.valves.RemoteAddrValve\" allow=\"$ALLOWED_IPS\" />
</Context>
EOF"

# Restart Tomcat to apply changes
sudo systemctl restart tomcat

echo "Tomcat installation and configuration complete. Access it at http://your_server_ip:8080"
