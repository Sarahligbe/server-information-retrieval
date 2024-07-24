#!/bin/bash

# Check if the script is run as root
if [[ $UID != 0 ]]; then
  echo "This script must be run as root or with sudo privileges"
  exit 1
fi

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
    echo "  -t, --time [START END]     Display activities within a time range (format: 'YYYY-MM-DD' or 'YYYY-MM-DD YYYY-MM-DD')"
    echo "  -h, --help           Display this help message"
}

format_table() {
    local default_width="$1"
    local custom_widths="$2"
    
    awk -v BLUE="$(tput setaf 4)" -v BOLD="$(tput bold)" -v RESET="$(tput sgr0)" \
        -v DEFAULT_WIDTH="$default_width" -v CUSTOM_WIDTHS="$custom_widths" '
    function print_horiz_line(corner, tee, dash,    i) {
        printf corner
        for (i=1; i<=NF; i++) {
            printf "%s", repeat(dash, widths[i] + 2)
            printf (i==NF) ? corner : tee
        }
        printf "\n"
    }

    function repeat(str, n,    result, i) {
        result = ""
        for (i = 0; i < n; i++) {
            result = result str
        }
        return result
    }

    function truncate(str, width) {
        if (length(str) <= width) return str
        return substr(str, 1, width - 3) "..."
    }

    BEGIN {
        FS="\t"
        OFS="|"
        if (DEFAULT_WIDTH == "") DEFAULT_WIDTH = 20
        split(CUSTOM_WIDTHS, custom_widths, ",")
        for (i in custom_widths) {
            split(custom_widths[i], pair, ":")
            max_widths[pair[1]] = pair[2]
        }
    }
    NR==1 {
        for (i=1; i<=NF; i++) {
            gsub(/^[ \t]+|[ \t]+$/, "", $i)
            max_width = (i in max_widths) ? max_widths[i] : DEFAULT_WIDTH
            widths[i] = length($i) > max_width ? max_width : length($i)
        }
        header = $0
        next
    }
    /^$/ {next}  # Skip empty lines
    {
        for (i=1; i<=NF; i++) {
            gsub(/^[ \t]+|[ \t]+$/, "", $i)
            max_width = (i in max_widths) ? max_widths[i] : DEFAULT_WIDTH
            if (length($i) > widths[i] && length($i) <= max_width) {
                widths[i] = length($i)
            } else if (length($i) > max_width) {
                widths[i] = max_width
            }
        }
        rows[++datarows] = $0
    }
    END {
        # Print top border
        print_horiz_line("+", "+", "-")
        
        # Print colored header
        split(header, header_fields)
        printf "|"
        for (i=1; i<=NF; i++) {
            printf " %s%s%-*s%s |", BLUE, BOLD, widths[i], truncate(header_fields[i], widths[i]), RESET
        }
        printf "\n"
        
        # Print separator after header
        print_horiz_line("+", "+", "-")
        
        # Print data
        for (row=1; row<=datarows; row++) {
            split(rows[row], fields)
            printf "|"
            for (i=1; i<=NF; i++) {
                printf " %-*s |", widths[i], truncate(fields[i], widths[i])
            }
            printf "\n"
            if (row < datarows) {
                print_horiz_line("+", "+", "-")
            }
        }
        
        # Print bottom border
        print_horiz_line("+", "+", "-")
    }
    '
}

# Function to get port information
get_ports() {
    local port=$1
    
    if [ -n "$port" ]; then
        echo "Displaying information for port $port"
        ss -tulpne | grep ":$port" | awk '
        BEGIN { 
            OFS="\t"
            print "Port\tUser\tPID\tPeer\tCGroup\tType\tIPv6\tState"
        }
        {
            split($1, protocol, "")
            split($5, local, ":")
            split($6, remote, ":")
            
            port = local[length(local)]
            remote_address = $6
            state = $2
            protocol_full = (protocol[1] == "t") ? "tcp" : "udp"
            ipv6 = ($5 ~ /\[/) ? "true" : "false"
            
            # Extract service name, PID, and cgroup
            match($0, /users:\(\("([^"]+)",pid=([0-9]+),[^)]+\)\).*cgroup:([^ ]+)/, arr)
            service_name = arr[1]
            pid = arr[2]
            cgroup = arr[3]
            
            key = port protocol_full
            
            if (!(key in seen)) {
                seen[key] = 1
                data[key] = port OFS service_name OFS pid OFS remote_address OFS cgroup OFS protocol_full OFS ipv6 OFS state
            } else {
                split(data[key], fields, OFS)
                fields[4] = fields[4] " " remote_address
                fields[7] = (fields[7] == "true" || ipv6 == "true") ? "true" : "false"
                data[key] = join(fields, OFS)
            }
        }
        END {
            for (key in data) {
                print data[key]
            }
        }
        function join(array, sep,    result, i) {
            for (i in array)
                result = result sep array[i]
            return substr(result, length(sep) + 1)
        }
        ' | format_table
    else
        echo "Displaying all active ports"
        ss -tulpne | awk '
        BEGIN { 
            OFS="\t"
            print "Port\tUser\tType\tIPv6\tState"
        }
        NR>1 {
            split($1, protocol, "")
            split($5, local, ":")
            
            port = local[length(local)]
            state = $2
            protocol_full = (protocol[1] == "t") ? "tcp" : "udp"
            ipv6 = ($5 ~ /\[/) ? "true" : "false"
            
            # Extract service name
            match($0, /users:\(\("([^"]+)"/, arr)
            service_name = arr[1]
            
            key = port protocol_full
            
            if (!(key in seen)) {
                seen[key] = 1
                data[key] = port OFS service_name OFS protocol_full OFS ipv6 OFS state
            } else {
                split(data[key], fields, OFS)
                fields[4] = (fields[4] == "true" || ipv6 == "true") ? "true" : "false"
                data[key] = join(fields, OFS)
            }
        }
        END {
            for (key in data) {
                print data[key]
            }
        }
        function join(array, sep,    result, i) {
            for (i in array)
                result = result sep array[i]
            return substr(result, length(sep) + 1)
        }
        ' | format_table
    fi
}

# Function to get Docker information
get_docker_info() {
    local container=$1
    
    if [ -n "$container" ]; then
        echo "Displaying information for $container docker container"
        # Get basic container info
        (
            echo -e "ID\tName\tImage\tStatus\tPorts\tNetwork Name\tStats"
            docker ps -a --filter "name=$container" --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | \
            while read line; do
                stats=$(docker stats $container --no-stream --format \
                    "CPU: {{.CPUPerc}}; MEM: {{.MemPerc}}" | \
                    tr -d '\n')
                network=$(docker inspect $container --format '{{.HostConfig.NetworkMode}}')
                echo -e "${line}\t${network}\t${stats}"
            done
        ) | format_table "7:50"
    else
        echo "Displaying information for all containers and images"
        # List all images and containers
        (
            echo -e "ID\tType\tName\tCreated"
            
            # List images
            docker images -a --format "{{.ID}}\tImage\t{{.Repository}}:{{.Tag}}\t{{.CreatedAt}}"
            
            # List containers
            docker ps -a --format "{{.ID}}\tContainer\t{{.Names}}\t{{.CreatedAt}}"
        ) | format_table 30 "4:70"
    fi
}

# Functions to get Nginx information
extract_nginx_config() {
    local server_name="$1"
    local nginx_output
    nginx_output=$(nginx -T 2>&1)

    # Use awk to extract server blocks and their corresponding configuration files
    config_and_blocks=$(echo "$nginx_output" | awk -v server_name="$server_name" '
        /^# configuration file/ {
            config_file = $NF
            sub(/:$/, "", config_file)
        }
        /server[[:space:]]*{/ {
            if (block) {
                if (block ~ "server_name[[:space:]]+"server_name) 
                    print "CONFIG_FILE:" last_config_file "\n" block
            }
            block = $0
            braces = 1
            last_config_file = config_file
            next
        }
        {
            block = block "\n" $0
            braces += gsub(/{/, "{")
            braces -= gsub(/}/, "}")
            if (braces == 0) {
                if (block ~ "server_name[[:space:]]+"server_name) 
                    print "CONFIG_FILE:" last_config_file "\n" block
                block = ""
            }
        }
        END {
            if (block && block ~ "server_name[[:space:]]+"server_name) 
                print "CONFIG_FILE:" last_config_file "\n" block
        }
    ')

    if [ -z "$config_and_blocks" ]; then
        echo "No server blocks found for $server_name"
        return 1
    fi

    # Extract configuration file
    config_file=$(echo "$config_and_blocks" | grep "^CONFIG_FILE:" | head -n1 | cut -d':' -f2- | sed 's/^ *//')

    # Extract server blocks
    server_blocks=$(echo "$config_and_blocks" | sed '/^CONFIG_FILE:/d')

    listen_ports=$(echo "$server_blocks" | grep -oP 'listen\s+\K\d+' | sort -u | paste -sd ',' -)

    if echo "$server_blocks" | grep -q 'ssl_certificate'; then
        ssl="true"
    else
        ssl="false"
    fi

    # Extract all locations and their corresponding proxy_pass
    locations_and_proxies=$(echo "$server_blocks" | awk '
        /location[[:space:]]+[^{]+{/ {
            loc = $2
            in_location = 1
            proxy = ""
            next
        }
        in_location && /proxy_pass[[:space:]]/ {
            proxy = $2
            sub(/;$/, "", proxy)
            print loc "," proxy
        }
        /}/ {
            if (in_location) in_location = 0
        }
    ')

    # Process locations and proxy_pass
    locations=""
    proxy_passes=""
    while IFS=',' read -r loc proxy; do
        locations="${locations:+$locations,}$loc"
        proxy_passes="${proxy_passes:+$proxy_passes,}$proxy"
    done <<< "$locations_and_proxies"

    echo -e "$server_name\t$config_file\t$listen_ports\t$ssl\t$locations\t$proxy_passes"
}

list_all_servers() {
    local nginx_output
    nginx_output=$(nginx -T 2>&1)

    # First, extract server names and config files
    server_info=$(echo "$nginx_output" | awk '
    BEGIN { OFS="\t" }
    /^# configuration file/ {
        config_file = $NF
        sub(/:$/, "", config_file)
    }
    /^\s*server_name\s+/ {
        for (i=2; i<=NF; i++) {
            name = $i
            sub(/;$/, "", name)
            print name, config_file
        }
    }
    ' | sort -u)

    # Process each server
    while IFS=$'\t' read -r server_name config_file; do
        # Call extract_nginx_config to get proxy passes
        proxy_passes=$(extract_nginx_config "$server_name" | cut -f6)
        
        # If proxy_passes is empty, use "-"
        proxy_passes=${proxy_passes:-"-"}

        # Print the result
        echo -e "${server_name}\t${config_file}\t${proxy_passes}"
    done <<< "$server_info"
}

get_nginx_info() {
    local server_name="$1"
    if [ -n "$server_name" ]; then
    echo "Displaying nginx config information for the $server_name domain"
    (
        echo -e "Server Name\tConfiguration File\tListen Ports\tSSL Enabled\tLocations\tProxy Pass"
        extract_nginx_config "$server_name"
    ) | format_table 20 "2:50,6:70"
    else
    echo "Displaying information for all domains on the server"
    (
        echo -e "Server Name\tConfig File\tProxy Pass"
        list_all_servers
    ) | format_table 40
    fi
}

# Functions to get user information
get_detailed_user_info() {
    local user="$1"
    local user_info=$(getent passwd "$user")
    
    if [ -z "$user_info" ]; then
        echo "User $user not found."
        return 1
    fi

    local groups=$(groups "$user" | cut -d: -f2- | sed 's/^ //' | tr ' ' ',')
    local home_dir=$(echo "$user_info" | cut -d: -f6)
    local shell=$(echo "$user_info" | cut -d: -f7)
    local last_login=$(lastlog -u "$user" | awk 'NR==2 { 
        if ($0 ~ /Never logged in/) {
            print "Never logged in"
        } else if (NF > 1) {
            print $4, $5, $6, $7, $8
        } else {
            print "Unknown"
        }
        }')
    echo -e "$user\t$groups\t$home_dir\t$shell\t$last_login"
}

get_regular_users_lastlog() {
    getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' | while read -r user; do
        lastlog -u "$user" | awk 'NR==2 { 
            if ($0 ~ /Never logged in/) {
                printf "%s\tNever logged in\t-\n", $1
            } else if (NF > 1) {
                printf "%s\t%s %s %s %s %s\t%s\n", $1, $4, $5, $6, $7, $8, $3
            } else {
                printf "%s\tUnknown\t-\n", $1
            }
        }'
    done
}

get_user_info() {
    local user="$1"
    if [ -n "$user" ]; then
    echo "Displaying information on your user - $user"
    (
        echo -e "User\tGroups\tHome Directory\tShell\tLast Logged In"
        get_detailed_user_info "$user"
    ) | format_table
    else
    echo "Displaying information of all users and their last login time"
    (
        echo -e "User\tLast Login\tFrom"
        get_regular_users_lastlog
    ) | format_table
    fi
}

# Function to get activities within a time range
get_time_range_activities() {
    local start_date
    local end_date

    if [ $# -eq 0 ]; then
        echo "Please specify a time range or date"
        return 1
    elif [ $# -eq 1 ]; then
        start_date=$(date -d "$1" +"%Y-%m-%d 00:00:00")
        end_date=$(date -d "$1 +1 day" +"%Y-%m-%d 00:00:00")    
    elif [ $# -eq 2 ]; then
        start_date=$(date -d "$1" +"%Y-%m-%d 00:00:00")
        end_date=$(date -d "$2 + 1 day" +"%Y-%m-%d 00:00:00")
    else
        echo "Invalid number of arguments. Please provide valid arguments in this format 'YYYY-MM-DD' or 'YYYY-MM-DD YYYY-MM-DD'"
        return 1
    fi
    (
        echo -e "Timestamp\tUser\tProcess\tMessage"
        journalctl --since "$start_date" --until "$end_date" | 
        awk '
        {
            timestamp = $1 " " $2 " " $3
            server = $4
            process = $5
            $1=$2=$3=$4=$5=""
            message = substr($0,6)
            printf "%s\t%s\t%s\t%s\n", timestamp, server, process, message
        }'
    ) | format_table 20 "1:40,4:70"
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
        shift
        get_time_range_activities "$@"
        ;;
    -h|--help)
        show_help
        ;;
    *)
        echo "Invalid option. Use -h or --help for usage information."
        exit 1
        ;;
esac
