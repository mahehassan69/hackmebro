#!/usr/bin/env bash
BOLD_BLUE="\033[1;34m"
RED="\033[0;31m"
NC="\033[0m"
BOLD_YELLOW="\033[1;33m"

# Function to display usage message
display_usage() {
    echo ""
    echo "Options:"
    echo "     -h               Display this help message"
    echo "     -d               Single Domain link Spidering"
    echo "     -l               Multi Domain link Spidering"
    echo "     -i               Check required tool installed or not."
    echo -e "${BOLD_YELLOW}Usage:${NC}"
    echo -e "${BOLD_YELLOW}    $0 -d http://example.com${NC}"
    echo -e "${BOLD_YELLOW}    $0 -l http://example.com${NC}"
    echo -e "${RED}Required Tools:${NC}"
    echo -e "              ${RED}
            https://github.com/xnl-h4ck3r/waymore
            https://github.com/tomnomnom/anew
            https://github.com/projectdiscovery/urlfinder${NC}"
    exit 0
}

# Function to check installed tools
check_tools() {
    tools=("katana" "waymore" "urlfinder" "anew" "pm")

    echo "Checking required tools:"
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo -e "${BOLD_BLUE}$tool is installed at ${BOLD_WHITE}$(which $tool)${NC}"
        else
            echo -e "${RED}$tool is NOT installed or not in the PATH${NC}"
        fi
    done
}

# Check if tool installation check is requested
if [[ "$1" == "-i" ]]; then
    check_tools
    exit 0
fi

# help function execution
if [[ "$1" == "-h" ]]; then
    display_usage
    exit 0
fi

# single domain url getting
if [[ "$1" == "-d" ]]; then
    domain_Without_Protocol=$(echo "$2" | sed 's,http://,,;s,https://,,;s,www\.,,;')
    # making directory
    main_dir="PII_bug/$domain_Without_Protocol"
    base_dir="$main_dir/single_domain/recon"

    mkdir -p $main_dir
    waymore -i "$domain_Without_Protocol" -n -mode U --providers wayback,otx,urlscan,virustotal -oU $base_dir/waymore.txt

    katana -u "$domain_Without_Protocol" -fs fqdn -rl 170 -timeout 5 -retry 2 -aff -d 4 -duc -ps -pss waybackarchive,commoncrawl,alienvault -o $base_dir/katana.txt

    cat $base_dir/waymore.txt $base_dir/katana.txt | anew $base_dir/all_urls.txt
    cat $base_dir/all_urls.txt | grep -aE '\.xls|\.xml|\.xlsx|\.pdf|\.sql|\.doc|\.docx|\.pptx|\.txt|\.zip|\.tar\.gz|\.tgz|\.bak|\.7z|\.rar|\.log|\.cache|\.secret|\.db|\.backup|\.yml|\.gz|\.config|\.csv|\.yaml|\.exe|\.dll|\.bin|\.ini|\.bat|\.sh|\.tar|\.deb|\.rpm|\.iso|\.apk|\.msi|\.dmg|\.tmp|\.crt|\.pem|\.key|\.pub|\.asc' | anew $base_dir/all_unique_urls.txt

    pm -f $base_dir/all_urls.txt -p /opt/Pattern-Matching/patterns/db_params.txt -c -i -r "BXSS" -o $base_dir/get_params_bxss.txt

    cat $base_dir/all_unique_urls.txt | grep -aE '\.pdf$' | anew $base_dir/all_pdf.txt

    all_urls_path=$base_dir/all_unique_urls.txt
    all_urls_count=$(cat $base_dir/all_unique_urls.txt | wc -l)
    echo -e "${BOLD_YELLOW}All urls${NC}(${RED}$all_urls_count${NC}): ${BOLD_BLUE}$all_urls_path${NC}"

    document_urls_path=$base_dir/all_pdf.txt
    document_urls_count=$(cat $base_dir/all_pdf.txt | wc -l)
    echo -e "${BOLD_YELLOW}All pdf urls${NC}(${RED}$document_urls_count${NC}): ${BOLD_BLUE}$document_urls_path${NC}"

    bxss_urls_path=$base_dir/get_params_bxss.txt
    bxss_urls_count=$(cat $base_dir/get_params_bxss.txt | wc -l)
    echo -e "${BOLD_YELLOW}All bxss urls${NC}(${RED}$bxss_urls_count${NC}): ${BOLD_BLUE}$bxss_urls_path${NC}"

    chmod -R 777 $main_dir

    exit 0
fi



# multi domain url getting
if [[ "$1" == "-l" ]]; then
    domain_Without_Protocol=$(echo "$2" | sed 's,http://,,;s,https://,,;s,www\.,,;')
    # making directory
    main_dir="PII_bug/$domain_Without_Protocol"
    base_dir="$main_dir/multi_domain/recon"

    mkdir -p $main_dir

    urlfinder -all -d "$domain_Without_Protocol" -o $base_dir/urlfinder.txt

    waymore -i "$domain_Without_Protocol" -mode U --providers wayback,otx,urlscan,virustotal -oU $base_dir/waymore.txt

    katana -u "$domain_Without_Protocol" -rl 170 -timeout 5 -retry 2 -aff -d 4 -duc -ps -pss waybackarchive,commoncrawl,alienvault -o $base_dir/katana.txt

    cat $base_dir/urlfinder.txt $base_dir/waymore.txt $base_dir/katana.txt | anew $base_dir/all_urls.txt
    cat $base_dir/all_urls.txt | grep -aE '\.xls|\.xml|\.xlsx|\.pdf|\.sql|\.doc|\.docx|\.pptx|\.txt|\.zip|\.tar\.gz|\.tgz|\.bak|\.7z|\.rar|\.log|\.cache|\.secret|\.db|\.backup|\.yml|\.gz|\.config|\.csv|\.yaml|\.exe|\.dll|\.bin|\.ini|\.bat|\.sh|\.tar|\.deb|\.rpm|\.iso|\.apk|\.msi|\.dmg|\.tmp|\.crt|\.pem|\.key|\.pub|\.asc' | anew $base_dir/all_unique_urls.txt

    cat $base_dir/all_unique_urls.txt | grep -aE '\.pdf$' | anew $base_dir/all_pdf.txt

    pm -f $base_dir/all_urls.txt -p /opt/Pattern-Matching/patterns/db_params.txt -c -i -r "BXSS" -o $base_dir/get_params_bxss.txt

    all_urls_path=$base_dir/all_unique_urls.txt
    all_urls_count=$(cat $base_dir/all_unique_urls.txt | wc -l)
    echo -e "${BOLD_YELLOW}All urls${NC}(${RED}$all_urls_count${NC}): ${BOLD_BLUE}$all_urls_path${NC}"

    document_urls_path=$base_dir/all_pdf.txt
    document_urls_count=$(cat $base_dir/all_pdf.txt | wc -l)
    echo -e "${BOLD_YELLOW}All pdf urls${NC}(${RED}$document_urls_count${NC}): ${BOLD_BLUE}$document_urls_path${NC}"

    bxss_urls_path=$base_dir/get_params_bxss.txt
    bxss_urls_count=$(cat $base_dir/get_params_bxss.txt | wc -l)
    echo -e "${BOLD_YELLOW}All bxss urls${NC}(${RED}$bxss_urls_count${NC}): ${BOLD_BLUE}$bxss_urls_path${NC}"

    chmod -R 777 $main_dir

    exit 0
fi
