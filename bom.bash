#!/bin/bash

# Function to check dependencies
check_dependencies() {
    if ! command -v jq &>/dev/null; then
        echo "jq is required but not installed. Please install it using: sudo apt install jq"
        exit 1
    fi
    if ! command -v curl &>/dev/null; then
        echo "curl is required but not installed. Please install it using: sudo apt install curl"
        exit 1
    fi
}

# Function to parse JSON BOM file
parse_json() {
    local file=$1
    jq -r '.components[] | "\(.name):\(.version)"' "$file"
}

# Function to parse XML BOM file
parse_xml() {
    local file=$1
    grep -oP '(?<=<component>).*?(?=</component>)' "$file" | \
    grep -oP '(?<=<name>).*?(?=</name>)|(?<=<version>).*?(?=</version>)' | \
    awk 'NR%2{printf $0 ":"; next;}1'
}

# Function to query CVE API
query_cve_api() {
    local name=$1
    local version=$2
    local api_key=" Insert yout api key here " # Replace with your actual CVE API key
    echo "Checking $name version $version for vulnerabilities..."

    # API request
    local response=$(curl -s "https://services.nvd.nist.gov/rest/json/cves/1.0?keyword=$name%20$version&apiKey=$api_key")
    local vulnerabilities=$(echo "$response" | jq -r '.result.CVE_Items[]?.cve.description.description_data[]?.value')

    if [ -z "$vulnerabilities" ]; then
        echo "No vulnerabilities found for $name version $version."
    else
        echo "Vulnerabilities for $name version $version:"
        echo "$vulnerabilities"
    fi
    echo "------------------------------------------------------"
}

# Main function to process the BOM file
process_bom_file() {
    local bom_file=$1

    if [[ $bom_file == *.json ]]; then
        components=$(parse_json "$bom_file")
    elif [[ $bom_file == *.xml ]]; then
        components=$(parse_xml "$bom_file")
    else
        echo "Unsupported file format. Please provide a .json or .xml file."
        exit 1
    fi

    echo "Processing BOM file: $bom_file"

    while IFS= read -r component; do
        name=$(echo "$component" | cut -d: -f1)
        version=$(echo "$component" | cut -d: -f2)
        query_cve_api "$name" "$version"
    done <<< "$components"
}

# Script entry point
main() {
    check_dependencies

    if [ $# -ne 1 ]; then
        echo "Usage: $0 <BOM file (.json or .xml)>"
        exit 1
    fi

    local bom_file=$1

    if [ ! -f "$bom_file" ]; then
        echo "File $bom_file does not exist."
        exit 1
    fi

    process_bom_file "$bom_file"
}

# Start the script
main "$@"
