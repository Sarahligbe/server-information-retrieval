#!/bin/bash

LOG_FILE="/var/log/devopsfetch.log"

touch $LOG_FILE

# Check if the script is run as root
if [[ $UID != 0 ]]; then
  echo "This script must be run as root or with sudo privileges"
  exit 1
fi

# Function to check if a package is available in the repositories
check_package_availability() {
    if ! apt-cache show "$1" &> /dev/null; then
        echo "Error: Package $1 is not available in the repositories."
        exit 1
    fi
}

# Function to check if a package is already installed
is_package_installed() {
    dpkg -s "$1" &> /dev/null
}

# Update package lists
sudo apt update

# Array of packages to install
packages=(
    "coreutils"
    "iproute2"
    "apt-transport-https"
    "ca-certificates"
    "curl"
    "software-properties-common"
    "nginx"
    "gawk"
    "grep"
    "sed"
    "systemd"
    "net-tools"
    "procps"
)

# Check availability and install packages
for package in "${packages[@]}"; do
    if ! is_package_installed "$package"; then
        check_package_availability "$package"
        echo "Installing $package..."
        sudo apt install -y "$package"
    else
        echo "$package is already installed."
    fi
done

# Check and install Docker (Docker has a different installation process)
if ! is_package_installed "docker-ce"; then
    # Check if Docker repository is already added
    if ! grep -q "download.docker.com" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
        echo "Adding Docker repository..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt update
    fi
    
    check_package_availability "docker-ce"
    echo "Installing docker-ce..."
    sudo apt install -y docker-ce
else
    echo "docker-ce is already installed."
fi

# Enable and start Docker service
if systemctl is-active --quiet docker; then
    echo "Docker service is already running."
else
    echo "Starting Docker service..."
    sudo systemctl enable docker
    sudo systemctl start docker
fi

# Enable and start Nginx service
if systemctl is-active --quiet nginx; then
    echo "Nginx service is already running."
else
    echo "Starting Nginx service..."
    sudo systemctl enable nginx
    sudo systemctl start nginx
fi

cp devopsfetch.sh /usr/local/bin/devopsfetch
chmod +x /usr/local/bin/devopsfetch

# Create and copy the monitoring script
cat << EOF > /usr/local/bin/devopsfetch_monitor.sh
#!/bin/bash

while true; do
    echo "--- $(date) ---" >> "$LOG_FILE"
    echo "Ports:" >> "$LOG_FILE"
    devopsfetch -p >> "$LOG_FILE"
    echo "Docker:" >> "$LOG_FILE"
    devopsfetch -d >> "$LOG_FILE"
    echo "Nginx:" >> "$LOG_FILE"
    devopsfetch -n >> "$LOG_FILE"
    echo "Users:" >> "$LOG_FILE"
    devopsfetch -u >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    sleep 3000
done
EOF

chmod +x /usr/local/bin/devopsfetch_monitor.sh

# Create systemd service file
cat << EOF > /etc/systemd/system/devopsfetch.service
[Unit]
Description=DevOpsFetch Monitoring Service
After=network.target

[Service]
ExecStart=/usr/local/bin/devopsfetch_monitor.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable devopsfetch.service
systemctl start devopsfetch.service

# Set up log rotation
cat << EOF > /etc/logrotate.d/devopsfetch
/var/log/devopsfetch.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF


echo "DevOpsFetch has been installed and the monitoring service has been started."
