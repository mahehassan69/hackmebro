#!/bin/bash

# Function to check if a tool is installed
check_tool() {
    command -v $1 >/dev/null 2>&1 || { echo >&2 "$1 is required but not installed. Aborting."; exit 1; }
}

# Check if subzy and subjack and aquatone are installed
check_tool subzy
check_tool subjack
chech_tool aquaton

# Prompt user to enter the path to the file containing subdomains
read -p "Enter the path to the file containing subdomains: " subdomains_file

# Remove single quotes from user input
subdomains_file="${subdomains_file//\'/}"

# Check if the file exists
if [ ! -f "$subdomains_file" ]; then
    echo "File not found. Please enter a valid file path."
    exit 1
fi

echo =================Subzy Run=============================

    # Run subzy
    echo "Running subzy for $subdomain"
    subzy run --hide_fails --targets "$subdomains_file"
echo =================Subjack Run=============================

    # Run subjack
    echo "Running subjack for $subdomain"
    subjack -w "$subdomains_file" -v 
    
echo =================Aquatone Run=============================  
 
    # Run aquaton
    echo "Running aquaton for $subdomain"
    aquatone-takeover --list-detectors "$subdomains_file"

    
echo "Script completed."
