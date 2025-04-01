#!/bin/bash

# Define color codes for output formatting
BOLD_WHITE="\033[1;37m"
BOLD_BLUE="\033[1;34m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

# Function to show progress
show_progress() {
    echo -e "${BOLD_WHITE}[*] $1...${NC}"
}

# Function to handle errors
handle_error() {
    echo -e "${RED}[!] Error: $1 failed.${NC}"
    exit 1
}

# Function to display usage message
display_usage() {
    echo -e "${BOLD_BLUE}Usage:${NC}"
    echo -e "  ${CYAN}-d${NC} domain             Specify a single domain to scan."
    echo -e "  ${CYAN}-l${NC} domain_list_file   Specify a file containing a list of domains to scan."
    echo -e "  ${CYAN}-h${NC}                    Show this help message and exit."
    echo -e "${BOLD_BLUE}Examples:${NC}"
    echo -e "  ./linkfinder.sh -d example.com"
    echo -e "  ./linkfinder.sh -l domains.txt"
}

# Check if required tools are installed
for tool in waymore urlfinder katana waybackurls subprober; do
    command -v $tool >/dev/null 2>&1 || { handle_error "$tool is not installed."; }
done

# Parse command-line arguments
input_mode=""
while getopts "d:l:h" option; do
    case $option in
        d)
            domain=$OPTARG
            input_mode="single"
            ;;
        l)
            domain_list=$OPTARG
            input_mode="list"
            ;;
        h)
            display_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            display_usage
            exit 1
            ;;
    esac
done

# Ensure either -d or -l is provided
if [ -z "$input_mode" ]; then
    echo -e "${RED}[!] Error: You must specify either -d or -l.${NC}"
    display_usage
    exit 1
fi

# Prepare the input file for processing
if [ "$input_mode" == "single" ]; then
    domain_name=$(echo "$domain" | sed -E 's~(https?://)?(www\.)?~~')
    echo "$domain_name" > "${domain_name}.txt"
    input_file="${domain_name}.txt"
elif [ "$input_mode" == "list" ]; then
    if [ ! -f "$domain_list" ]; then
        echo -e "${RED}[!] Error: The file ${domain_list} does not exist.${NC}"
        exit 1
    fi
    domain_name="batch"
    input_file="$domain_list"
fi

show_progress "Input prepared: ${input_file}"

# Function to perform URL crawling and filtering
url_crawling() {
    local domain_file="$1"
    local output_prefix="$2"
    show_progress "Starting URL Crawling and Filtering for ${output_prefix}"

    # Waymore
    waymore -i "$domain_file" -mode U -n -oU "waymore-${output_prefix}.txt" || handle_error "Waymore crawl"

    # URLFinder
    urlfinder -all -d "$domain_file" -o "urlfinder-${output_prefix}.txt" || handle_error "URLFinder crawl"

    # Katana
    cat "$domain_file" | katana -fs fqdn -rl 170 -jc -retry 2 -aff -d 5 | tee "katana-${output_prefix}.txt" || handle_error "Katana crawl"

    # Waybackurls
    cat "$domain_file" | waybackurls -no-subs | tee "waybackurls-${output_prefix}.txt" || handle_error "Waybackurls crawl"

    # Gau
    cat "$domain_file" | gau | tee "gau-${output_prefix}.txt" || handle_error "Gau crawl"

    # Filter invalid links
    show_progress "Filtering invalid links"
    for tool in urlfinder; do
        grep -oP 'http[^\s]*' "${tool}-${domain_name}.txt" > "${tool}1-${domain_name}.txt"
    done
    sleep 3

    # Merge and deduplicate
    show_progress "Merging and deduplicating all URLs"
    cat "waymore-${output_prefix}.txt" "katana-${output_prefix}.txt" \
        "urlfinder-${output_prefix}.txt" "waybackurls-${output_prefix}.txt" \
        "gau-${output_prefix}.txt" | anew > "all-link-${output_prefix}.txt"
}

# Run URL crawling
url_crawling "$input_file" "$domain_name"

# Deduplicate URLs
    show_progress "Deduplicating URLs with anew"
    cat all-link-${domain_name}.txt | anew > "all-url-${domain_name}.txt" || handle_error "Anew deduplication"


    #Javascript Analyzing URLs
    show_progress "All javascript url seacrh"
    cat "all-url-${domain_name}.txt" | grep -aE '\.js($|\s|\?|&|#|/|\.)|\.json($|\s|\?|&|#|/|\.)' | anew js.txt

    # Step 8: Remove old files
    show_progress "Removing old files"
    rm -r "urlfinder-${domain_name}.txt"
    sleep 3

    # Step 9: Filter similar URLs with URO tool
    show_progress "Filtering similar URLs with URO tool"
    declare -a input_files=("waymore-${domain_name}.txt" \
        "urlfinder1-${domain_name}.txt" "katana-${domain_name}.txt" \
        "waybackurls-${domain_name}.txt" "gau-${domain_name}.txt")

    declare -a output_files=("urowaymore.txt" \
        "urourlfinder.txt" "urokatana.txt" \
        "urowaybackurls.txt" "urogau.txt")

    for i in "${!input_files[@]}"; do
        input="${input_files[$i]}"
        output="${output_files[$i]}"

        if [ -f "$input" ]; then
            uro -i "$input" -o "$output" &
        else
            echo -e "${BOLD_BLUE}[!] Skipping URO for $input: File not found.${NC}"
        fi
    done

    # Wait for all URO processes to finish
    wait
    echo -e "${BOLD_BLUE}URO processing completed. Files created successfully.${NC}"
    sleep 3

    # Step 10: Remove all filtered files
    show_progress "Removing all intermediate filtered files"
    rm -r "waymore-${domain_name}.txt" "katana-${domain_name}.txt" \
        "waybackurls-${domain_name}.txt" "gau-${domain_name}.txt" \
        "urlfinder1-${domain_name}.txt" "all-link-${domain_name}.txt" "${domain_name}.txt"
    sleep 3

    # Step 11: Merge all URO files into one final file
    show_progress "Merging all URO files into one final file"
    cat urowaymore.txt urourlfinder.txt urokatana.txt urowaybackurls.txt urogau.txt > "links-final-${domain_name}.txt"

    # Display the number of URLs in the final merged file
    total_merged_urls=$(wc -l < "links-final-${domain_name}.txt")
    echo -e "${BOLD_WHITE}Total URLs merged: ${RED}${total_merged_urls}${NC}"
    sleep 3

    # Step 12: Clean up URO output files
    show_progress "Removing all URO files"
    rm -r urowaymore.txt urourlfinder.txt urokatana.txt urowaybackurls.txt urogau.txt 
    sleep 3

    # Final message
    echo -e "${BOLD_WHITE}All crawling and filtering steps completed. Final output saved in 'urls/parameters-links-${domain_name}.txt'.${NC}"



# Function to run step 2 (In-depth URL Filtering)
echo -e "${BOLD_YELLOW}🔀Filtering extensions from the URLs for $domain_name${NC}"

    # Step 14: Filtering extensions from the URLs
    show_progress "Filtering extensions from the URLs"
    cat links-final-${domain_name}.txt | grep -E -v '\.(css|js|jpe?g|png|gif|avi|dll|pl|webm|c|py|bat|tar|swp|tmp|sh|deb|exe|zip|mpe?g|flv|wmv|wma|aac|m4a|ogg|mp4|mp3|dat|cfg|cfm|bin|pdf|docx?|pptx?|ppsx|xlsx?|mpp|mdb|json|woff2?|icon|svg|ttf|csv|gz|tiff?|txt|jar|[0-4]|m4r|kml|pro|yao|gcn3|egy|par|lin|yht)($|\s|\?|&|#|/|\.)' > filtered-extensions-links.txt
    sleep 5

    # Step 15: Renaming filtered extensions file
    show_progress "Renaming filtered extensions file"
    mv filtered-extensions-links.txt "links-clean-${domain_name}.txt"
    sleep 3

    # Step 16: Filtering unwanted domains from the URLs
    show_progress "Filtering unwanted domains from the URLs"
    grep -E "^(https?://)?([a-zA-Z0-9.-]+\.)?${domain_name}" "links-clean-${domain_name}.txt" > "links-clean1-${domain_name}.txt"
    sleep 3

    # Step 17: Removing old filtered file
    show_progress "Removing old filtered file"
    rm -r links-clean-${domain_name}.txt links-final-${domain_name}.txt
    sleep 3

    # Step 18: Renaming new filtered file
    show_progress "Renaming new filtered file"
    mv links-clean1-${domain_name}.txt links-clean-${domain_name}.txt
    sleep 3

    # Step 19: Running URO tool again to filter duplicate and similar URLs
    show_progress "Running URO tool again to filter duplicate and similar URLs"

    # Ensure input file exists
    input_file="links-clean-${domain_name}.txt"
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}Error: Input file '$input_file' does not exist.${NC}"
        exit 1
    fi

    # Run URO tool in the background and capture PID
    uro -i "$input_file" -o "uro-${domain_name}.txt"

    echo -e "${BOLD_BLUE}URO tool finished processing clean URLs.${NC}"

    # Display the number of URLs in the URO output file
    echo -e "${BOLD_WHITE}Total URLs in final output: ${RED}$(wc -l < "uro-${domain_name}.txt")${NC}"
    sleep 3

    # Step 20: Removing old file
    show_progress "Removing old file"
    rm -r "links-clean-${domain_name}.txt"
    sleep 3

    # Step 23: Rename to new file
    show_progress "Rename to new file"
    mv uro-${domain_name}.txt "links-${domain_name}.txt"
    sleep 3

    # Step 24: Filtering ALIVE URLS
    show_progress "Filtering ALIVE URLS"
    subprober -f "links-${domain_name}.txt" -sc -ar -o "links-${domain_name}.txt1337" -nc -mc 200 201 202 204 301 302 304 307 308 403 500 504 401 407 -c 40 || handle_error "subprober"
    sleep 5

    # Step 25: Removing old file
    show_progress "Removing old file"
    rm -r links-${domain_name}.txt
    sleep 3

    # Step 26: Filtering valid URLS
    show_progress "Filtering valid URLS"
    grep -oP 'http[^\s]*' "links-${domain_name}.txt1337" > links-${domain_name}.txt1338 || handle_error "grep valid urls"
    sleep 5

    # Step 27: Removing intermediate file and renaming final output
    show_progress "Final cleanup and renaming"
    rm -r links-${domain_name}.txt1337
    mv links-${domain_name}.txt1338 live-links-${domain_name}.txt
    sleep 3

    echo -e "${BOLD_BLUE}Filtering process completed successfully. Final output saved as live-links-${domain_name}.txt.${NC}"

# Function to run step 6 (HiddenParamFinder)
echo -e "${BOLD_YELLOW}🔎HiddenParamFinder for $domain_name${NC}"


    # Step 1: Preparing URLs with clean extensions
    show_progress "Preparing URLs with clean extensions, created 2 files: arjun-urls.txt and output-php-links.txt"

    # Extract all URLs with specific extensions into arjun-urls.txt and output-php-links.txt
    cat "live-links-${domain_name}.txt" | grep -E "\.php($|\s|\?|&|#|/|\.)|\.asp($|\s|\?|&|#|/|\.)|\.aspx($|\s|\?|&|#|/|\.)|\.cfm($|\s|\?|&|#|/|\.)|\.jsp($|\s|\?|&|#|/|\.)" | \
    awk '{print > "arjun-urls.txt"; print > "output-php-links.txt"}'
    sleep 3

    # Step 2: Clean parameters from URLs in arjun-urls.txt
    show_progress "Filtering and cleaning arjun-urls.txt to remove parameters and duplicates"

    # Clean parameters from URLs and save the cleaned version back to arjun-urls.txt
    awk -F'?' '{print $1}' arjun-urls.txt | awk '!seen[$0]++' > temp_arjun_urls.txt

    # Replace arjun-urls.txt with the cleaned file
    mv temp_arjun_urls.txt arjun-urls.txt

    show_progress "Completed cleaning arjun-urls.txt. All URLs are now clean, unique, and saved."

        # Check if Arjun generated any files
        if [ ! -s arjun-urls.txt ] && [ ! -s output-php-links.txt ]; then
            echo -e "${RED}Arjun did not find any new links or did not create any files.${NC}"
            echo -e "${BOLD_BLUE}Renaming live-links-${domain_name}.txt to urls-ready.txt and continuing...${NC}"
            mv "live-links-${domain_name}.txt" urls-ready.txt || handle_error "Renaming live-links-${domain_name}.txt"
            sleep 3
            # run_step_7  # Automatically proceed to step 7
            # return
        fi

        echo -e "${BOLD_BLUE}URLs prepared successfully and files created.${NC}"
        echo -e "${BOLD_BLUE}arjun-urls.txt and output-php-links.txt have been created.${NC}"

        # Step 2: Running Arjun on clean URLs if arjun-urls.txt is present
    if [ -s arjun-urls.txt ]; then
        show_progress "Running Arjun on clean URLs"
        arjun -i arjun-urls.txt -oT arjun_output.txt -t 10 -w /home/haxshadow/privt-payload/parametri.txt || handle_error "Arjun command"

        # Merge files and process .php links
    if [ -f arjun-urls.txt ] || [ -f output-php-links.txt ] || [ -f arjun_output.txt ]; then
        # Merge and extract only the base .php URLs, then remove duplicates
        cat arjun-urls.txt output-php-links.txt arjun_output.txt 2>/dev/null | awk -F'?' '/\.php/ {print $1}' | anew > arjun-final.txt

        echo -e "${BOLD_BLUE}arjun-final.txt created successfully with merged and deduplicated links.${NC}"
    else
        echo -e "${YELLOW}No input files for merging. Skipping merge step.${NC}"
    fi

    sleep 5
     
            # Count the number of new links discovered by Arjun
            if [ -f arjun_output.txt ]; then
                new_links_count=$(wc -l < arjun_output.txt)
                echo -e "${BOLD_BLUE}Arjun has completed running on the clean URLs.${NC}"
                echo -e "${BOLD_RED}Arjun discovered ${new_links_count} new links.${NC}"
                echo -e "${CYAN}The new links discovered by Arjun are:${NC}"
                cat arjun_output.txt
            else
                echo -e "${YELLOW}No output file was created by Arjun.${NC}"
            fi
        else
            echo -e "${RED}No input file (arjun-urls.txt) found for Arjun.${NC}"
        fi

        # Continue with other steps or clean up
        show_progress "Cleaning up temporary files"
        if [[ -f arjun-urls.txt || -f arjun_output.txt || -f output-php-links.txt ]]; then
            [[ -f arjun-urls.txt ]] && rm -r arjun-urls.txt
            [[ -f output-php-links.txt ]] && rm -r output-php-links.txt
            sleep 3
        else
            echo -e "${RED}No Arjun files to remove.${NC}"
        fi

        echo -e "${BOLD_BLUE}Files merged and cleanup completed. Final output saved as arjun-final.txt.${NC}"

    # Step 5: Creating a new file for XSS testing
    if [ -f arjun-final.txt ]; then
        show_progress "Creating a new file for XSS, OR, SQLI, LFI  testing"

        # Ensure arjun-final.txt is added to urls-ready.txt
        cat "live-links-${domain_name}.txt" arjun-final.txt > urls-ready1337.txt || handle_error "Creating XSS testing file"
        rm -r "live-links-${domain_name}.txt"
        mv urls-ready1337.txt "links-${domain_name}.txt"
        sleep 3
        mv "links-${domain_name}.txt" urls-ready.txt || handle_error "Renaming links-${domain_name}.txt"
        echo -e "${BOLD_BLUE}Final output saved as urls-ready.txt.${NC}"
    fi
# Automatically start step 7 after completing step 6

# Function to run step 7 (Getting ready for XSS & URLs with query strings)

# echo -e "${BOLD_WHITE}You selected: Preparing for XSS Detection and Query String URL Analysis for $domain_name${NC}"

#     # Step 1: Filtering URLs with query strings
#     show_progress "Filtering URLs with query strings"
#     grep '=' urls-ready.txt > "$domain_name-query.txt"
#     sleep 5
#     echo -e "${BOLD_BLUE}Filtering completed. Query URLs saved as ${domain_name}-query.txt.${NC}"

#     # Step 2: Renaming the remaining URLs
#     show_progress "Renaming remaining URLs"
#     mv urls-ready.txt "$domain_name-ALL-links.txt"
#     sleep 3
#     echo -e "${BOLD_BLUE}All-links URLs saved as ${domain_name}-ALL-links.txt.${NC}"

#     # Step 3: Analyzing and reducing the query URLs based on repeated parameters
# show_progress "Analyzing query strings for repeated parameters"

# # Start the analysis in the background and get the process ID (PID)
# (> ibro-xss.txt; > temp_param_names.txt; > temp_param_combinations.txt; while read -r url; do base_url=$(echo "$url" | cut -d'?' -f1); extension=$(echo "$base_url" | grep -oiE '\.php|\.asp|\.aspx|\.cfm|\.jsp'); if [[ -n "$extension" ]]; then echo "$url" >> ibro-xss.txt; else params=$(echo "$url" | grep -oE '\?.*' | tr '?' ' ' | tr '&' '\n'); param_names=$(echo "$params" | cut -d'=' -f1); full_param_string=$(echo "$url" | cut -d'?' -f2); if grep -qx "$full_param_string" temp_param_combinations.txt; then continue; else new_param_names=false; for param_name in $param_names; do if ! grep -qx "$param_name" temp_param_names.txt; then new_param_names=true; break; fi; done; if $new_param_names; then echo "$url" >> ibro-xss.txt; echo "$full_param_string" >> temp_param_combinations.txt; for param_name in $param_names; do echo "$param_name" >> temp_param_names.txt; done; fi; fi; fi; done < "${domain_name}-query.txt"; echo "Processed URLs with unique parameters: $(wc -l < ibro-xss.txt)") &

# # Save the process ID (PID) of the background task
# analysis_pid=$!

# # Monitor the process in the background
# while kill -0 $analysis_pid 2> /dev/null; do
#     echo -e "${BOLD_BLUE}Analysis tool is still running...⌛️${NC}"
#     sleep 30  # Check every 30 seconds
# done

# # When finished
# echo -e "${BOLD_GREEN}Analysis completed. $(wc -l < ibro-xss.txt) URLs with repeated parameters have been saved.${NC}"
# rm temp_param_names.txt temp_param_combinations.txt
# sleep 3

#     # Step 4: Cleanup and rename the output file
#     show_progress "Cleaning up intermediate files and setting final output"
#     rm -r "${domain_name}-query.txt"
#     mv ibro-xss.txt "${domain_name}-query.txt"
#     echo -e "${BOLD_BLUE}Cleaned up and renamed output to ${domain_name}-query.txt.${NC}"
#     sleep 3

# # Step 4: Cleanup and rename the output file
# show_progress "Cleaning up intermediate files and setting final output"

# # Filter the file ${domain_name}-query.txt using the specified awk command
# show_progress "Filtering ${domain_name}-query.txt for unique and normalized URLs"
# awk '{ gsub(/^https:/, "http:"); gsub(/^http:\/\/www\./, "http://"); if (!seen[$0]++) print }' "${domain_name}-query.txt" | tr -d '\r' > "${domain_name}-query1.txt"

# # Remove the old query file
# rm -r "${domain_name}-query.txt"

# # Rename the filtered file to the original name
# mv "${domain_name}-query1.txt" "${domain_name}-query.txt"

# # Count the number of URLs in the renamed file
# url_count=$(wc -l < "${domain_name}-query.txt")

# ## Final message with progress count
# echo -e "${BOLD_BLUE}Cleaned up and renamed output to ${domain_name}-query.txt.${NC}"
# echo -e "${BOLD_BLUE}Total URLs to be tested for Page Reflection: ${url_count}${NC}"
# sleep 3

# # Add links from arjun_output.txt into ${domain_name}-query.txt
# if [ -f "arjun_output.txt" ]; then
#     echo -e "${BOLD_WHITE}Adding links from arjun_output.txt into ${domain_name}-query.txt.${NC}"
#     cat arjun_output.txt >> "${domain_name}-query.txt"
#     echo -e "${BOLD_BLUE}Links from arjun_output.txt added to ${domain_name}-query.txt.${NC}"
# else
#     echo -e "${YELLOW}No Arjun output links to add. Proceeding without additional links.${NC}"
# fi

# # Extract unique subdomains and append search queries
# echo -e "${BOLD_WHITE}Processing unique subdomains to append search queries...${NC}"

# # Define the list of search queries to append
# search_queries=(
#     "search?q=aaa"
#     "?query=aaa"
#     "en-us/Search#/?search=aaa"
#     "Search/Results?q=aaa"
#     "q=aaa"
#     "foo?q=aaa"
#     "search.php?query=aaa"
#     "en-us/search?q=aaa"
#     "s=aaa"
#     "find?q=aaa"
#     "result?q=aaa"
#     "query?q=aaa"
#     "search?term=aaa"
#     "search?query=aaa"
#     "search?keywords=aaa"
#     "search?text=aaa"
#     "search?word=aaa"
#     "find?query=aaa"
#     "result?query=aaa"
#     "search?input=aaa"
#     "search/results?query=aaa"
#     "search-results?q=aaa"
#     "search?keyword=aaa"
#     "results?query=aaa"
#     "search?search=aaa"
#     "search?searchTerm=aaa"
#     "search?searchQuery=aaa"
#     "search?searchKeyword=aaa"
#     "search.php?q=aaa"
#     "search/?query=aaa"
#     "search/?q=aaa"
#     "search/?search=aaa"
#     "search.aspx?q=aaa"
#     "search.aspx?query=aaa"
#     "search.asp?q=aaa"
#     "index.asp?id=aaa"
#     "dashboard.asp?user=aaa"
#     "blog/search/?query=aaa"
#     "pages/searchpage.aspx?id=aaa"
# )

# # Extract unique subdomains (normalize to remove protocol and www)
# normalized_subdomains=$(awk -F/ '{print $1 "//" $3}' "${domain_name}-query.txt" | sed -E 's~(https?://)?(www\.)?~~' | sort -u)

# # Create a mapping of preferred protocols for unique subdomains
# declare -A preferred_protocols
# while read -r url; do
#     # Extract protocol, normalize subdomain
#     protocol=$(echo "$url" | grep -oE '^https?://')
#     subdomain=$(echo "$url" | sed -E 's~(https?://)?(www\.)?~~' | awk -F/ '{print $1}')

#     # Set protocol preference: prioritize http over https
#     if [[ "$protocol" == "http://" ]]; then
#         preferred_protocols["$subdomain"]="http://"
#     elif [[ -z "${preferred_protocols["$subdomain"]}" ]]; then
#         preferred_protocols["$subdomain"]="https://"
#     fi
# done < "${domain_name}-query.txt"

# # Create a new file for the appended URLs
# append_file="${domain_name}-query-append.txt"
# > "$append_file"

# # Append each search query to the preferred subdomains
# for subdomain in $normalized_subdomains; do
#     protocol="${preferred_protocols[$subdomain]}"
#     for query in "${search_queries[@]}"; do
#         echo "${protocol}${subdomain}/${query}" >> "$append_file"
#     done
# done

# # Combine the original file with the appended file
# cat "${domain_name}-query.txt" "$append_file" > "${domain_name}-query-final.txt"

# # Replace the original file with the combined result
# mv "${domain_name}-query-final.txt" "${domain_name}-query.txt"

# echo -e "${BOLD_BLUE}Appended URLs saved and combined into ${domain_name}-query.txt.${NC}"

# # Step 3: Checking page reflection on the URLs
# if [ -f "reflection.py" ]; then
#     echo -e "${BOLD_WHITE}Checking page reflection on the URLs with command: reflection.py ${domain_name}-query.txt --threads 2${NC}"
#     python3 reflection.py "${domain_name}-query.txt" --threads 2 || handle_error "reflection execution"
#     sleep 5

#     # Check if xss.txt is created after reflection.py
#     if [ -f "xss.txt" ]; then
#         # Check if xss.txt has any URLs (non-empty file)
#         total_urls=$(wc -l < xss.txt)
#         if [ "$total_urls" -eq 0 ]; then
#             # If no URLs were found, stop the tool
#             echo -e "\033[1;36mNo reflective URLs were identified. The process will terminate, and no further XSS testing will be conducted.\033[0m"
#             exit 0
#         else
#             echo -e "${BOLD_WHITE}Page reflection done! New file created: xss.txt${NC}"

#             # Display the number of URLs affected by reflection
#             echo -e "${BOLD_WHITE}Total URLs reflected: ${RED}${total_urls}${NC}"

#             # Filtering duplicate URLs
#             echo -e "${BOLD_BLUE}Filtering duplicate URLs...${NC}"
#             awk '{ gsub(/^https:/, "http:"); gsub(/^http:\/\/www\./, "http://"); if (!seen[$0]++) print }' "xss.txt" | tr -d '\r' > "xss1.txt"
#             sleep 3

#             # Remove the original xss.txt file
#             echo -e "${BOLD_BLUE}Removing the old xss.txt file...${NC}"
#             rm -r xss.txt arjun_output.txt arjun-final.txt "${domain_name}-query-append.txt"
#             sleep 3

#             # Removing 99% similar parameters with bash command
#             echo -e "${BOLD_BLUE}Removing 99% similar parameters...${NC}"
#             awk -F'[?&]' '{gsub(/:80/, "", $1); base_url=$1; domain=base_url; params=""; for (i=2; i<=NF; i++) {split($i, kv, "="); if (!seen[domain kv[1]]++) {params=params kv[1]; if (i<NF) params=params "&";}} full_url=base_url"?"params; if (!param_seen[full_url]++) print $0 > "xss-urls.txt";}' xss1.txt
#             sleep 5

#             # Remove the intermediate xss1.txt file
#             echo -e "${BOLD_BLUE}Removing the intermediate xss1.txt file...${NC}"
#             rm -r xss1.txt
#             sleep 3

#             # Running URO for xss-urls.txt file
#             echo -e "${BOLD_BLUE}Running URO for xss-urls.txt file...${NC}"
#             uro -i xss-urls.txt -o xss-urls1337.txt
#             rm -r xss-urls.txt
#             mv xss-urls1337.txt xss-urls.txt
#             sleep 5

#             # Final message with the total number of URLs in xss-urls.txt
#             total_urls=$(wc -l < xss-urls.txt)
#             echo -e "${BOLD_WHITE}New file is ready for XSS testing: xss-urls.txt with TOTAL URLs: ${total_urls}${NC}"
#             echo -e "${BOLD_WHITE}Initial Total Merged URLs in the beginning : ${RED}${total_merged_urls}${NC}"
#             echo -e "${BOLD_WHITE}Filtered Final URLs for XSS Testing: ${RED}${total_urls}${NC}"

#             # Automatically run the xss0r command after reflection step
#             ./xss0r --get --urls xss-urls.txt --payloads payloads.txt --shuffle --threads 10 --path || handle_error "Launching xss0r Tool"

#         fi
#     else
#         echo -e "${RED}xss.txt not found. No reflective URLs identified.${NC}"
#         echo -e "\033[1;36mNo reflective URLs were identified. The process will terminate, and no further XSS testing will be conducted.\033[0m"
#         exit 0
#     fi
# else
#     echo -e "${RED}reflection.py not found in the current directory. Skipping page reflection step.${NC}"
# fi