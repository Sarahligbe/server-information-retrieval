#!/bin/bash

# Function to display help information
show_help() {
    echo "Usage: devopsfetch [OPTION]"
    echo "Retrieve and display system information."
    echo
    echo "Options:"
    echo "  -p, --port [PORT]    Display port information"
    echo "  -d, --docker [CONTAINER]  Display Docker information"
    echo "  -n, --nginx [DOMAIN] Display Nginx information"
    echo "  -u, --users [USER]   Display user information"
    echo "  -t, --time RANGE     Display activities within a time range (format: 'YYYY-MM-DD HH:MM:SS,YYYY-MM-DD HH:MM:SS')"
    echo "  -h, --help           Display this help message"
}

# Function to format output as a table
format_table() {
    column -t -s $'\t' | sed 's/^/| /' | sed 's/$/ |/' | sed '2s/[^|]/-/g'
}

# Function to get port information
get_ports() {
    local port=$1
    if [ -n "$port" ]; then
        ss -tlpn | grep ":$port" | awk '{print $4, $6}' | sed 's/users:(("//g' | sed 's/",.*//g' | format_table
    else
        ss -tlpn | awk 'NR>1 {print $4, $6}' | sed 's/users:(("//g' | sed 's/",.*//g' | format_table
    fi
}

# Function to get Docker information
get_docker_info() {
    local container=$1
    if [ -n "$container" ]; then
        docker inspect "$container" | jq -r '.[0] | ["ID", "Name", "Image", "Status", "Ports"], [.Id[0:12], .Name, .Config.Image, .State.Status, (.NetworkSettings.Ports | to_entries | map(.key) | join(", "))] | @tsv' | format_table
    else
        docker ps --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}" | format_table
    fi
}

# Function to get Nginx information
get_nginx_info() {
    local domain=$1
    if [ -n "$domain" ]; then
        grep -R "server_name $domain" /etc/nginx/sites-enabled/ | cut -d: -f1 | xargs grep -H -E "server_name|listen|root|location" | sed 's/^/| /' | sed 's/$/ |/' | column -t -s: | sed '2s/[^|]/-/g'
    else
        grep -R "server_name" /etc/nginx/sites-enabled/ | cut -d: -f2- | sed 's/server_name//g' | tr -d ';' | format_table
    fi
}

# Function to get user information
get_user_info() {
    local username=$1
    if [ -n "$username" ]; then
        local user_info=$(getent passwd "$username")
        local last_login=$(last -1 "$username" | awk 'NR==1 {print $4, $5, $6, $7}')
        echo -e "Username\tUID\tGID\tHome\tShell\tLast Login" | format_table
        echo -e "$user_info" | awk -F: -v last="$last_login" '{print $1 "\t" $3 "\t" $4 "\t" $6 "\t" $7 "\t" last}' | format_table
    else
        echo -e "Username\tUID\tGID\tHome" | format_table
        getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1 "\t" $3 "\t" $4 "\t" $6}' | format_table
    fi
}

# Function to get activities within a time range
get_time_range_activities() {
    local start_time=$(echo "$1" | cut -d',' -f1)
    local end_time=$(echo "$1" | cut -d',' -f2)
    journalctl --since "$start_time" --until "$end_time" | format_table
}

# Main execution
case "$1" in
    -p|--port)
        get_ports "$2"
        ;;
    -d|--docker)
        get_docker_info "$2"
        ;;
    -n|--nginx)
        get_nginx_info "$2"
        ;;
    -u|--users)
        get_user_info "$2"
        ;;
    -t|--time)
        get_time_range_activities "$2"
        ;;
    -h|--help)
        show_help
        ;;
    *)
        echo "Invalid option. Use -h or --help for usage information."
        exit 1
        ;;
esac
