# DevOpsFetch Documentation
DevOpsFetch is a Bash script that retrieves and displays various system information for DevOps purposes. It provides insights into ports, Docker containers, Nginx configurations, user information, and system activities within specified time ranges.

## Installation
1. Clone this repo
```bash
   git clone https://github.com/Sarahligbe/server-information-retrieval
```
2. cd into the directory with the script and run the `install.sh` as a root or a user with sudo privileges. 
```bash
   ./install.sh
```
- The script checks for and installs necessary packages using apt, including core utilities, Docker, and Nginx. It adds the Docker repository if not already present.
- The main DevOpsFetch script (devopsfetch.sh) is copied to /usr/local/bin/devopsfetch and made executable.

The installation process automates the setup of both DevOpsFetch and its monitoring service, ensuring that system information is continuously logged for later analysis. The log rotation setup helps manage log file sizes over time.

## Configuration
- No explicit configuration is required for DevOpsFetch itself.
- The script ensures that Docker and Nginx services are enabled and running.

## Usage
DevOpsFetch must be run with root privileges. Use sudo when executing the script:
```bash
   sudo devopsfetch [OPTION] [ARGUMENT]
```

### Command-line Options
```bash
-p, --port [PORT]           Display port information"
-d, --docker [CONTAINER]    Display Docker information"
-n, --nginx [DOMAIN]        Display Nginx information"
-u, --users [USER]          Display user information"
-t, --time [START END]      Display activities within a time range (format: 'YYYY-MM-DD' or 'YYYY-MM-DD YYYY-MM-DD')"
-h, --help                  Display this help message"
```

### Examples
1. Help:
```bash
   sudo devopsfetch -h
```
![Help output](images/help)

This will display the help message with usage information.

2. Port Information:
```bash
   sudo devopsfetch -p [PORT]
```
![port output](images/port)
This will display information about port 22. If no port is specified, it will show information for all active ports.

3. Docker Information:
```bash
   sudo devopsfetch -d [CONTAINER]
```
![docker output](images/docker)
This will display information about the specified Docker container. If no container is specified, it will show information for all containers and images.

4. Nginx Information:
```bash
   sudo devopsfetch -n [DOMAIN]
```
![docker output](images/docker)
This will display Nginx configuration information for the specified domain. If no domain is specified, it will show information for all domains on the server.

5. User Information:
```bash
   sudo devopsfetch -u [USER]
```
![docker output](images/docker)
This will display detailed information about the specified user. If no user is specified, it will show information for all regular users on the system.

6. Time Range Activities:
```bash
   sudo devopsfetch -t [START_DATE] [END_DATE]
```
![docker output](images/docker)
This will display system activities within the specified date range. If only one date is provided, it will show activities for that specific day.

## Logging Mechanism:
1. A log file is created at /var/log/devopsfetch.log via the installation script
2. Log rotation is set up using logrotate:
- Logs are rotated daily
- 7 rotated logs are kept
- Rotated logs are compressed
- Missing log files are ignored
- Empty log files are not rotated

## Continuous Monitoring:
1. A monitoring script (devopsfetch_monitor.sh) is created in /usr/local/bin/ via the installation script. This script runs DevOpsFetch commands every 3000 seconds (50 minutes) and logs the output. It captures information about ports, Docker, Nginx, and users.
2. A systemd service (devopsfetch.service) is created to run this monitoring script continuously. The service is enabled to start on boot and is immediately started after installation.