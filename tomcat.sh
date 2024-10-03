#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit
fi

# Update package lists
echo "Updating package lists..."
apt-get update

# Install Java (required for Tomcat)
echo "Installing Java..."
apt-get install -y default-jdk

# Define Tomcat version and installation directory
TOMCAT_VERSION=9.0.72
TOMCAT_DIR="/opt/tomcat"

# Download Apache Tomcat
echo "Downloading Apache Tomcat version $TOMCAT_VERSION..."
wget https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz -P /tmp

# Extract Tomcat
echo "Extracting Tomcat..."
mkdir -p $TOMCAT_DIR
tar -xvzf /tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz -C $TOMCAT_DIR --strip-components=1

# Set permissions for Tomcat
echo "Setting up permissions..."
chown -R www-data:www-data $TOMCAT_DIR
chmod -R 755 $TOMCAT_DIR

# Create a systemd service file for Tomcat
echo "Creating systemd service file for Tomcat..."
cat <<EOF >/etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
User=www-data
Group=www-data
Type=forking
Environment=JAVA_HOME=/usr/lib/jvm/default-java
Environment=CATALINA_PID=$TOMCAT_DIR/temp/tomcat.pid
Environment=CATALINA_HOME=$TOMCAT_DIR
Environment=CATALINA_BASE=$TOMCAT_DIR
ExecStart=$TOMCAT_DIR/bin/startup.sh
ExecStop=$TOMCAT_DIR/bin/shutdown.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Start Tomcat service
echo "Starting Tomcat service..."
systemctl start tomcat

# Enable Tomcat service to start on boot
echo "Enabling Tomcat to start on boot..."
systemctl enable tomcat

# Configure Tomcat user authentication for Manager and Host Manager
echo "Configuring user authentication for Tomcat..."
cat <<EOF >> $TOMCAT_DIR/conf/tomcat-users.xml
<role rolename="manager-gui"/>
<role rolename="admin-gui"/>
<user username="admin" password="password" roles="manager-gui,admin-gui"/>
EOF

# Update manager and host-manager access rules
echo "Updating access permissions for Host Manager..."
sed -i 's/<Valve className="org.apache.catalina.valves.RemoteAddrValve".*$/<!--<Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="127\.\d+\.\d+\.\d+|::1" \/>-->/' $TOMCAT_DIR/webapps/manager/META-INF/context.xml
sed -i 's/<Valve className="org.apache.catalina.valves.RemoteAddrValve".*$/<!--<Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="127\.\d+\.\d+\.\d+|::1" \/>-->/' $TOMCAT_DIR/webapps/host-manager/META-INF/context.xml

# Restart Tomcat to apply changes
echo "Restarting Tomcat to apply configuration changes..."
systemctl restart tomcat

# Output the access information
echo "Installation and configuration complete."
echo "Access the Tomcat Manager at: http://<server-ip>:8080/manager/html"
echo "Access the Host Manager at: http://<server-ip>:8080/host-manager/html"
echo "Username: admin"
echo "Password: password"
