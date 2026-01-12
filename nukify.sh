#!/bin/bash

# ☢️ NUKIFY - Nuclear Disk Cleanup Tool ☢️
# Scans for files/folders and NUKES them from orbit

# Radiation colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BRIGHT_RED='\033[1;31m'
BRIGHT_GREEN='\033[1;32m'
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_MAGENTA='\033[1;35m'
ORANGE='\033[38;5;208m'
TOXIC_GREEN='\033[38;5;118m'
RADIATION_YELLOW='\033[38;5;226m'
NC='\033[0m' # No Color

# Minimum size in MB
MIN_SIZE_MB=512

# Temporary files
SCAN_RESULTS="/tmp/disk_scan_results.txt"
SCAN_SIZE_MARKER="/tmp/disk_scan_size_marker.txt"
SELECTED_ITEMS="/tmp/disk_selected_items.txt"
STATS_FILE="/tmp/disk_cleanup_stats.txt"
DUPLICATES_FILE="/tmp/disk_duplicates.txt"
SCAN_IN_PROGRESS="/tmp/disk_scan_in_progress.txt"
SCAN_CACHE="/tmp/disk_scan_cache.txt"
SCAN_INTERRUPTED=0

# Filters
FILTER_EXTENSION=""
FILTER_AGE_DAYS=""
DELTA_SCAN_ENABLED=1

# Check if running with sudo, if not, re-execute with sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}This script requires sudo privileges. Requesting sudo...${NC}"
    exec sudo bash "$0" "$@"
    exit $?
fi

# Trap Ctrl+C during scan
handle_scan_interrupt() {
    if [ -f "$SCAN_IN_PROGRESS" ]; then
        SCAN_INTERRUPTED=1
        echo -e "\n\n${YELLOW}⚠️  Scan interrupted by user!${NC}"
        echo -e "${BLUE}Processing partial results...${NC}"
        rm -f "$SCAN_IN_PROGRESS"
    else
        echo -e "\n${YELLOW}Exiting...${NC}"
        exit 0
    fi
}

trap handle_scan_interrupt SIGINT

# Function to convert bytes to human readable
bytes_to_human() {
    local bytes=$1
    if [ $bytes -ge 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")GB"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")MB"
    fi
}

# Function to get file extension
get_extension() {
    local filepath="$1"
    echo "${filepath##*.}"
}

# Function to get file age in days
get_file_age_days() {
    local filepath="$1"
    if [ -f "$filepath" ]; then
        local mod_time=$(stat -f%m "$filepath" 2>/dev/null)
        local current_time=$(date +%s)
        echo $(( (current_time - mod_time) / 86400 ))
    else
        echo "0"
    fi
}

# Function to calculate MD5 hash for duplicate detection
get_file_hash() {
    local filepath="$1"
    if [ -f "$filepath" ]; then
        md5 -q "$filepath" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Function to update statistics
update_stats() {
    local size_freed=$1
    local items_deleted=$2
    
    if [ ! -f "$STATS_FILE" ]; then
        echo "0|0|0" > "$STATS_FILE"
    fi
    
    local current_stats=$(cat "$STATS_FILE")
    IFS='|' read -r total_size total_items total_runs <<< "$current_stats"
    
    total_size=$((total_size + size_freed))
    total_items=$((total_items + items_deleted))
    total_runs=$((total_runs + 1))
    
    echo "$total_size|$total_items|$total_runs" > "$STATS_FILE"
}

# Function to show statistics dashboard
show_statistics() {
    echo -e "\n${TOXIC_GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${TOXIC_GREEN}║            ☢️  NUKIFICATION STATISTICS  ☢️                 ║${NC}"
    echo -e "${TOXIC_GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    
    if [ ! -f "$STATS_FILE" ]; then
        echo -e "${YELLOW}No statistics available yet. Delete some items first!${NC}"
        return
    fi
    
    local stats=$(cat "$STATS_FILE")
    IFS='|' read -r total_size total_items total_runs <<< "$stats"
    
    local total_human=$(bytes_to_human $total_size)
    
    echo -e "${GREEN}Total Space Freed:${NC}     $total_human"
    echo -e "${GREEN}Total Items Deleted:${NC}   $total_items"
    echo -e "${GREEN}Total Cleanup Runs:${NC}    $total_runs"
    
    if [ $total_runs -gt 0 ]; then
        local avg_per_run=$((total_size / total_runs))
        local avg_human=$(bytes_to_human $avg_per_run)
        echo -e "${GREEN}Average per Run:${NC}       $avg_human"
    fi
    
    # Show file type breakdown if scan results exist
    if [ -f "$SCAN_RESULTS" ]; then
        echo -e "\n${BLUE}Current Scan - File Type Breakdown:${NC}"
        grep "^FILE|" "$SCAN_RESULTS" | awk -F'|' '{
            split($4, parts, ".")
            ext = parts[length(parts)]
            if (ext != $4) {
                count[ext]++
                size[ext] += $2
            }
        }
        END {
            for (e in count) {
                printf "  .%-10s %3d files\n", e, count[e]
            }
        }' | sort -k2 -rn | head -10
    fi
    
    echo ""
}

# Function to show visual disk usage graph
show_disk_graph() {
    if [ ! -f "$SCAN_RESULTS" ] || [ ! -s "$SCAN_RESULTS" ]; then
        echo -e "${YELLOW}No scan results available.${NC}"
        return
    fi
    
    echo -e "\n${TOXIC_GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${TOXIC_GREEN}║          ☢️  CONTAMINATION VISUALIZATION  ☢️              ║${NC}"
    echo -e "${TOXIC_GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    
    # Get top 15 items
    local max_width=50
    local max_size=$(head -1 "$SCAN_RESULTS" | cut -d'|' -f2)
    
    echo -e "${YELLOW}Top 15 Largest Items:${NC}\n"
    
    head -15 "$SCAN_RESULTS" | while IFS='|' read -r type size human_size path; do
        # Calculate bar width
        local bar_width=$((size * max_width / max_size))
        if [ $bar_width -lt 1 ]; then
            bar_width=1
        fi
        
        # Create bar
        local bar=""
        for ((i=0; i<bar_width; i++)); do
            bar="${bar}█"
        done
        
        # Truncate path if too long
        local display_path="$path"
        if [ ${#display_path} -gt 40 ]; then
            display_path="...${display_path: -37}"
        fi
        
        # Color code by type
        if [ "$type" = "DIR" ]; then
            printf "${BLUE}%-10s${NC} ${GREEN}%-50s${NC} %s\n" "$human_size" "$bar" "$display_path"
        else
            printf "${BLUE}%-10s${NC} ${YELLOW}%-50s${NC} %s\n" "$human_size" "$bar" "$display_path"
        fi
    done
    
    echo -e "\n${GREEN}█${NC} = Directories  ${YELLOW}█${NC} = Files"
    echo ""
}

# Function to find duplicate files
find_duplicates() {
    echo -e "\n${BLUE}Scanning for duplicate files...${NC}"
    echo -e "${YELLOW}This may take a while. Press ${RED}Ctrl+C${YELLOW} to stop.${NC}\n"
    
    if [ ! -f "$SCAN_RESULTS" ] || [ ! -s "$SCAN_RESULTS" ]; then
        echo -e "${YELLOW}No scan results available. Run a scan first.${NC}"
        return
    fi
    
    # Mark scan as in progress
    touch "$SCAN_IN_PROGRESS"
    SCAN_INTERRUPTED=0
    
    > "$DUPLICATES_FILE"
    
    # Create associative array for hashes
    declare -A file_hashes
    local dup_count=0
    local total_dup_size=0
    local files_checked=0
    
    # Only check files, not directories
    grep "^FILE|" "$SCAN_RESULTS" | while IFS='|' read -r type size human_size path; do
        if [ $SCAN_INTERRUPTED -eq 1 ]; then
            break
        fi
        
        if [ -f "$path" ]; then
            ((files_checked++))
            echo -ne "\r${BLUE}Checked $files_checked files...${NC} ${path:0:50}..."
            local hash=$(get_file_hash "$path")
            
            if [ -n "$hash" ]; then
                # Check if hash already exists
                if grep -q "^$hash|" "$DUPLICATES_FILE" 2>/dev/null; then
                    # Duplicate found
                    echo "$hash|$size|$human_size|$path" >> "$DUPLICATES_FILE"
                else
                    # First occurrence
                    echo "$hash|$size|$human_size|$path" >> "$DUPLICATES_FILE.tmp"
                fi
            fi
        fi
    done
    
    # Clear scan in progress flag
    rm -f "$SCAN_IN_PROGRESS"
    
    if [ $SCAN_INTERRUPTED -eq 1 ]; then
        echo -e "\r${YELLOW}Duplicate scan interrupted!${NC}                                                  "
        echo -e "${BLUE}Showing partial results...${NC}\n"
    else
        echo -e "\r${GREEN}Scan complete! Checked $files_checked files.${NC}                                                  "
    fi
    
    # Find actual duplicates (hashes that appear more than once)
    if [ -f "$DUPLICATES_FILE.tmp" ]; then
        sort "$DUPLICATES_FILE.tmp" | uniq -d -w 32 > "$DUPLICATES_FILE.dups"
        
        if [ -s "$DUPLICATES_FILE.dups" ]; then
            echo -e "\n${RED}Duplicate Files Found:${NC}\n"
            
            while IFS='|' read -r hash size human_size path; do
                echo -e "${YELLOW}$human_size${NC} - $path"
                # Show all files with this hash
                grep "^$hash|" "$DUPLICATES_FILE.tmp" "$DUPLICATES_FILE" 2>/dev/null | while IFS='|' read -r h s hs p; do
                    if [ "$p" != "$path" ]; then
                        echo -e "  ${RED}↳ DUPLICATE:${NC} $p"
                        ((dup_count++))
                        total_dup_size=$((total_dup_size + s))
                    fi
                done
                echo ""
            done < "$DUPLICATES_FILE.dups"
            
            local dup_size_human=$(bytes_to_human $total_dup_size)
            echo -e "${GREEN}Potential space savings: $dup_size_human${NC}"
        else
            echo -e "${GREEN}No duplicate files found!${NC}"
        fi
        
        rm -f "$DUPLICATES_FILE.tmp" "$DUPLICATES_FILE.dups"
    fi
}

# Function to apply filters
apply_filters() {
    if [ ! -f "$SCAN_RESULTS" ] || [ ! -s "$SCAN_RESULTS" ]; then
        echo -e "${YELLOW}No scan results to filter.${NC}"
        return
    fi
    
    local filtered="/tmp/disk_scan_filtered.txt"
    cp "$SCAN_RESULTS" "$filtered"
    
    # Apply extension filter
    if [ -n "$FILTER_EXTENSION" ]; then
        grep "^FILE|.*\.$FILTER_EXTENSION$" "$filtered" > "$filtered.tmp" || true
        mv "$filtered.tmp" "$filtered"
    fi
    
    # Apply age filter
    if [ -n "$FILTER_AGE_DAYS" ]; then
        > "$filtered.tmp"
        while IFS='|' read -r type size human_size path; do
            if [ "$type" = "FILE" ] && [ -f "$path" ]; then
                local age=$(get_file_age_days "$path")
                if [ $age -ge $FILTER_AGE_DAYS ]; then
                    echo "$type|$size|$human_size|$path" >> "$filtered.tmp"
                fi
            elif [ "$type" = "DIR" ]; then
                echo "$type|$size|$human_size|$path" >> "$filtered.tmp"
            fi
        done < "$filtered"
        mv "$filtered.tmp" "$filtered"
    fi
    
    # Update scan results with filtered data
    mv "$filtered" "$SCAN_RESULTS"
    
    local item_count=$(wc -l < "$SCAN_RESULTS" | tr -d ' ')
    echo -e "${GREEN}Filter applied. $item_count items remaining.${NC}"
}

# Function to configure filters
configure_filters() {
    echo -e "\n${BLUE}=== Configure Filters ===${NC}\n"
    
    echo "Current filters:"
    if [ -n "$FILTER_EXTENSION" ]; then
        echo -e "  Extension: ${GREEN}.$FILTER_EXTENSION${NC}"
    else
        echo -e "  Extension: ${YELLOW}None${NC}"
    fi
    
    if [ -n "$FILTER_AGE_DAYS" ]; then
        echo -e "  Age: ${GREEN}$FILTER_AGE_DAYS+ days${NC}"
    else
        echo -e "  Age: ${YELLOW}None${NC}"
    fi
    
    echo ""
    echo "1) Filter by file extension (e.g., log, tmp, zip)"
    echo "2) Filter by file age (days)"
    echo "3) Clear all filters"
    echo "4) Apply filters to current scan"
    echo "5) Back to main menu"
    echo ""
    read -p "Choose an option: " filter_choice
    
    case $filter_choice in
        1)
            read -p "Enter file extension (without dot): " ext
            FILTER_EXTENSION="$ext"
            echo -e "${GREEN}Extension filter set to: .$ext${NC}"
            ;;
        2)
            read -p "Enter minimum age in days: " days
            if [[ "$days" =~ ^[0-9]+$ ]]; then
                FILTER_AGE_DAYS="$days"
                echo -e "${GREEN}Age filter set to: $days+ days${NC}"
            else
                echo -e "${RED}Invalid number${NC}"
            fi
            ;;
        3)
            FILTER_EXTENSION=""
            FILTER_AGE_DAYS=""
            echo -e "${GREEN}All filters cleared${NC}"
            ;;
        4)
            apply_filters
            ;;
        5)
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
}

# Function to manage scan settings
scan_settings() {
    echo -e "\n${ORANGE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${ORANGE}║            ⚙️  RADIATION SCANNER SETTINGS  ⚙️              ║${NC}"
    echo -e "${ORANGE}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    
    echo "Current settings:"
    if [ $DELTA_SCAN_ENABLED -eq 1 ]; then
        echo -e "  Delta Scan: ${GREEN}ENABLED${NC} (faster, skips unchanged files)"
    else
        echo -e "  Delta Scan: ${YELLOW}DISABLED${NC} (full scan every time)"
    fi
    
    if [ -f "$SCAN_CACHE" ]; then
        local cache_size=$(wc -l < "$SCAN_CACHE" | tr -d ' ')
        echo -e "  Cache: ${GREEN}$cache_size items cached${NC}"
    else
        echo -e "  Cache: ${YELLOW}Empty${NC}"
    fi
    
    echo ""
    echo "1) Toggle delta scan (on/off)"
    echo "2) Clear scan cache (force full rescan)"
    echo "3) View cache statistics"
    echo "4) Back to main menu"
    echo ""
    read -p "Choose an option: " setting_choice
    
    case $setting_choice in
        1)
            if [ $DELTA_SCAN_ENABLED -eq 1 ]; then
                DELTA_SCAN_ENABLED=0
                echo -e "${YELLOW}Delta scan disabled. Next scan will be full.${NC}"
            else
                DELTA_SCAN_ENABLED=1
                echo -e "${GREEN}Delta scan enabled. Next scan will skip unchanged files.${NC}"
            fi
            ;;
        2)
            if [ -f "$SCAN_CACHE" ]; then
                local cache_size=$(wc -l < "$SCAN_CACHE" | tr -d ' ')
                rm -f "$SCAN_CACHE"
                echo -e "${GREEN}Cache cleared! Removed $cache_size cached items.${NC}"
                echo -e "${YELLOW}Next scan will be a full scan.${NC}"
            else
                echo -e "${YELLOW}Cache is already empty.${NC}"
            fi
            ;;
        3)
            if [ -f "$SCAN_CACHE" ]; then
                local total=$(wc -l < "$SCAN_CACHE" | tr -d ' ')
                local dirs=$(grep -c "^/.*/$" "$SCAN_CACHE" 2>/dev/null || echo "0")
                
                # Ensure counts are valid integers and remove leading zeros
                total=${total:-0}
                dirs=${dirs:-0}
                total=$((10#$total))
                dirs=$((10#$dirs))
                
                local files=$((total - dirs))
                
                echo -e "\n${BLUE}Cache Statistics:${NC}"
                echo -e "  Total cached items: $total"
                echo -e "  Directories: $dirs"
                echo -e "  Files: $files"
                
                if [ $total -gt 0 ]; then
                    local oldest=$(head -1 "$SCAN_CACHE" | cut -d'|' -f2)
                    local newest=$(tail -1 "$SCAN_CACHE" | cut -d'|' -f2)
                    
                    # Ensure timestamps are valid integers
                    oldest=${oldest:-0}
                    newest=${newest:-0}
                    oldest=$((10#$oldest))
                    
                    local current_time=$(date +%s)
                    local age_days=$(( (current_time - oldest) / 86400 ))
                    echo -e "  Cache age: $age_days days"
                fi
            else
                echo -e "${YELLOW}No cache statistics available.${NC}"
            fi
            ;;
        4)
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
}

# Function for quick cleanup actions
quick_actions() {
    echo -e "\n${BRIGHT_RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_RED}║              ⚡  QUICK NUKIFICATION ACTIONS  ⚡            ║${NC}"
    echo -e "${BRIGHT_RED}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    
    echo "1) Clean Downloads folder (files older than 30 days)"
    echo "2) Clean system logs (*.log files)"
    echo "3) Clean cache files (*/Cache/* directories)"
    echo "4) Clean old disk images (*.dmg, *.iso)"
    echo "5) Clean development artifacts (node_modules, .git)"
    echo "6) Back to main menu"
    echo ""
    read -p "Choose a quick action: " action_choice
    
    case $action_choice in
        1)
            echo -e "${YELLOW}Scanning Downloads folder...${NC}"
            scan_disk "$HOME/Downloads"
            FILTER_AGE_DAYS=30
            apply_filters
            display_results
            ;;
        2)
            echo -e "${YELLOW}Scanning for log files...${NC}"
            scan_disk "/Users/$SUDO_USER" "/Library"
            FILTER_EXTENSION="log"
            apply_filters
            display_results
            ;;
        3)
            echo -e "${YELLOW}Scanning cache directories...${NC}"
            if [ -d "$HOME/Library/Caches" ]; then
                scan_disk "$HOME/Library/Caches"
                display_results
            else
                echo -e "${RED}Cache directory not found${NC}"
            fi
            ;;
        4)
            echo -e "${YELLOW}Scanning for disk images...${NC}"
            scan_disk "/Users/$SUDO_USER"
            FILTER_EXTENSION="dmg"
            apply_filters
            local dmg_count=$(wc -l < "$SCAN_RESULTS" | tr -d ' ')
            
            # Also scan for ISO files
            scan_disk "/Users/$SUDO_USER"
            FILTER_EXTENSION="iso"
            apply_filters
            
            display_results
            ;;
        5)
            echo -e "${YELLOW}Scanning for development artifacts...${NC}"
            echo -e "${RED}This will find node_modules and .git directories${NC}"
            find "/Users/$SUDO_USER" -type d \( -name "node_modules" -o -name ".git" \) 2>/dev/null | while read -r dir; do
                size_kb=$(du -sk "$dir" 2>/dev/null | cut -f1)
                if [ -n "$size_kb" ] && [ "$size_kb" -ge $((MIN_SIZE_MB * 1024)) ]; then
                    size_bytes=$((size_kb * 1024))
                    human_size=$(bytes_to_human $size_bytes)
                    echo "DIR|$size_bytes|$human_size|$dir"
                fi
            done > "$SCAN_RESULTS"
            
            sort -t'|' -k2 -rn "$SCAN_RESULTS" -o "$SCAN_RESULTS"
            display_results
            ;;
        6)
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
}

# Function to get file metadata for caching
get_file_metadata() {
    local filepath="$1"
    if [ -e "$filepath" ]; then
        local mtime=$(stat -f%m "$filepath" 2>/dev/null)
        local size=$(stat -f%z "$filepath" 2>/dev/null)
        echo "$filepath|$mtime|$size"
    fi
}

# Function to check if file changed since last scan
file_has_changed() {
    local filepath="$1"
    local current_meta=$(get_file_metadata "$filepath")
    
    if [ ! -f "$SCAN_CACHE" ]; then
        return 0  # No cache, consider changed
    fi
    
    local cached_meta=$(grep "^$(echo "$filepath" | sed 's/[\/&]/\\&/g')|" "$SCAN_CACHE" 2>/dev/null)
    
    if [ -z "$cached_meta" ]; then
        return 0  # Not in cache, consider changed
    fi
    
    if [ "$current_meta" != "$cached_meta" ]; then
        return 0  # Metadata changed
    fi
    
    return 1  # No change
}

# Function to update cache
update_cache() {
    local filepath="$1"
    local metadata=$(get_file_metadata "$filepath")
    
    if [ -n "$metadata" ]; then
        # Remove old entry if exists
        if [ -f "$SCAN_CACHE" ]; then
            grep -v "^$(echo "$filepath" | sed 's/[\/&]/\\&/g')|" "$SCAN_CACHE" > "$SCAN_CACHE.tmp" 2>/dev/null || true
            mv "$SCAN_CACHE.tmp" "$SCAN_CACHE" 2>/dev/null || true
        fi
        # Add new entry
        echo "$metadata" >> "$SCAN_CACHE"
    fi
}

# Spinner function
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to scan disk (optimized with delta scanning)
scan_disk() {
    local custom_paths=("$@")
    
    if [ ${#custom_paths[@]} -eq 0 ]; then
        # Default scan paths
        custom_paths=(
            "/Users/$SUDO_USER"
            "/Applications"
            "/Library"
        )
    fi
    
    # Mark scan as in progress
    touch "$SCAN_IN_PROGRESS"
    SCAN_INTERRUPTED=0
    
    echo -e "${TOXIC_GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${TOXIC_GREEN}║            ⚡  FAST SCAN MODE ENABLED!  ⚡                 ║${NC}"
    echo -e "${TOXIC_GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Scanning for items ${MIN_SIZE_MB}MB or larger...${NC}"
    
    if [ $DELTA_SCAN_ENABLED -eq 1 ] && [ -f "$SCAN_CACHE" ]; then
        echo -e "${GREEN}Delta scan: Skipping unchanged files${NC}"
    fi
    
    echo -e "${YELLOW}Press ${RED}Ctrl+C${YELLOW} to stop and view partial results.${NC}\n"
    
    # Temporary files
    local temp_all="/tmp/disk_scan_all.txt"
    local temp_dirs="/tmp/disk_scan_dirs_temp.txt"
    local temp_files="/tmp/disk_scan_files_temp.txt"
    > "$temp_all"
    
    local min_size_kb=$((MIN_SIZE_MB * 1024))
    local total_skipped=0
    local total_dirs=0
    local total_files=0
    
    for base_path in "${custom_paths[@]}"; do
        # Check if interrupted
        if [ $SCAN_INTERRUPTED -eq 1 ]; then
            break
        fi
        
        # Expand ~ to home directory
        base_path="${base_path/#\~/$HOME}"
        
        if [ ! -d "$base_path" ]; then
            echo -e "${RED}✗ Skipped (not found): $base_path${NC}"
            continue
        fi
        
        echo -e "${YELLOW}Scanning: $base_path${NC}"
        
        # DIRECTORIES: Use du to get all at once
        echo -ne "${BLUE}  → Finding large directories...${NC}"
        
        > "$temp_dirs"
        du -k "$base_path" 2>/dev/null | \
        awk -v min="$min_size_kb" '$1 >= min {print $0}' | \
        sort -rn > "$temp_dirs" &
        
        show_spinner $!
        
        local dir_count=0
        local dir_skipped=0
        
        while read -r size_kb dir; do
            if [ $SCAN_INTERRUPTED -eq 1 ]; then
                break
            fi
            
            # Delta scan check
            if [ $DELTA_SCAN_ENABLED -eq 1 ]; then
                if ! file_has_changed "$dir"; then
                    ((dir_skipped++))
                    continue
                fi
            fi
            
            size_bytes=$((size_kb * 1024))
            human_size=$(bytes_to_human $size_bytes)
            echo "DIR|$size_bytes|$human_size|$dir" >> "$temp_all"
            update_cache "$dir"
            ((dir_count++))
        done < "$temp_dirs"
        
        total_dirs=$((total_dirs + dir_count))
        total_skipped=$((total_skipped + dir_skipped))
        
        echo -e "\r${GREEN}  ✓ Directories: $dir_count found (skipped: $dir_skipped)${NC}                    "
        
        # Check if interrupted
        if [ $SCAN_INTERRUPTED -eq 1 ]; then
            break
        fi
        
        # FILES: Use find with size filter
        echo -ne "${BLUE}  → Finding large files...${NC}"
        
        > "$temp_files"
        find "$base_path" -type f -size +${MIN_SIZE_MB}M 2>/dev/null > "$temp_files" &
        
        show_spinner $!
        
        local file_count=0
        local file_skipped=0
        
        while read -r file; do
            if [ $SCAN_INTERRUPTED -eq 1 ]; then
                break
            fi
            
            # Delta scan check
            if [ $DELTA_SCAN_ENABLED -eq 1 ]; then
                if ! file_has_changed "$file"; then
                    ((file_skipped++))
                    continue
                fi
            fi
            
            size_bytes=$(stat -f%z "$file" 2>/dev/null)
            
            if [ -n "$size_bytes" ] && [ "$size_bytes" -ge $((MIN_SIZE_MB * 1048576)) ]; then
                human_size=$(bytes_to_human $size_bytes)
                echo "FILE|$size_bytes|$human_size|$file" >> "$temp_all"
                update_cache "$file"
                ((file_count++))
            fi
        done < "$temp_files"
        
        total_files=$((total_files + file_count))
        total_skipped=$((total_skipped + file_skipped))
        
        echo -e "\r${GREEN}  ✓ Files: $file_count found (skipped: $file_skipped)${NC}                    "
        
        if [ $SCAN_INTERRUPTED -eq 0 ]; then
            echo -e "${GREEN}✓ Completed: $base_path${NC}"
        else
            echo -e "${YELLOW}⚠ Interrupted: $base_path${NC}"
            break
        fi
    done
    
    # Cleanup temp files
    rm -f "$temp_dirs" "$temp_files" "$SCAN_IN_PROGRESS"
    
    # Check if we found anything
    if [ ! -s "$temp_all" ]; then
        if [ $SCAN_INTERRUPTED -eq 1 ]; then
            echo -e "\n${YELLOW}Scan interrupted before finding any items.${NC}"
        else
            echo -e "\n${YELLOW}No items found matching criteria.${NC}"
            if [ $total_skipped -gt 0 ]; then
                echo -e "${GREEN}Delta scan: Skipped $total_skipped unchanged items${NC}"
            fi
        fi
        return
    fi
    
    echo -e "\n${BLUE}Processing results...${NC}"
    
    # Separate directories and files, sort each by size
    grep "^DIR|" "$temp_all" 2>/dev/null | sort -t'|' -k2 -rn > "$SCAN_RESULTS.dirs"
    grep "^FILE|" "$temp_all" 2>/dev/null | sort -t'|' -k2 -rn > "$SCAN_RESULTS.files"
    
    # Filter out nested directories - only keep leaf directories
    echo -e "${BLUE}Filtering nested directories...${NC}"
    > "$SCAN_RESULTS.dirs.filtered"
    
    if [ -s "$SCAN_RESULTS.dirs" ]; then
        while IFS='|' read -r type size human_size path; do
            # Check if any other directory in the list is a subdirectory of this one
            local is_parent=0
            while IFS='|' read -r type2 size2 human_size2 path2; do
                # If path2 starts with path/ (and is not the same), then path is a parent
                if [ "$path" != "$path2" ] && [[ "$path2" == "$path"/* ]]; then
                    is_parent=1
                    break
                fi
            done < "$SCAN_RESULTS.dirs"
            
            # Only keep if it's not a parent of another directory (i.e., it's a leaf)
            if [ $is_parent -eq 0 ]; then
                echo "$type|$size|$human_size|$path" >> "$SCAN_RESULTS.dirs.filtered"
            fi
        done < "$SCAN_RESULTS.dirs"
    fi
    
    # Combine filtered directories and files
    cat "$SCAN_RESULTS.dirs.filtered" "$SCAN_RESULTS.files" 2>/dev/null > "$SCAN_RESULTS"
    rm -f "$SCAN_RESULTS.dirs" "$SCAN_RESULTS.files" "$SCAN_RESULTS.dirs.filtered" "$temp_all"
    
    # Save the size marker
    echo "$MIN_SIZE_MB" > "$SCAN_SIZE_MARKER"
    
    local item_count=$(wc -l < "$SCAN_RESULTS" | tr -d ' ')
    local dir_count=$(grep -c "^DIR|" "$SCAN_RESULTS" 2>/dev/null || echo "0")
    local file_count=$(grep -c "^FILE|" "$SCAN_RESULTS" 2>/dev/null || echo "0")
    
    # Fix integer issues
    dir_count=${dir_count:-0}
    file_count=${file_count:-0}
    dir_count=$((10#$dir_count))
    file_count=$((10#$file_count))
    
    if [ $SCAN_INTERRUPTED -eq 1 ]; then
        echo -e "\n${RADIATION_YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RADIATION_YELLOW}║   ⚠️  Scan Interrupted - Partial Results Available  ⚠️    ║${NC}"
        echo -e "${RADIATION_YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "\n${TOXIC_GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${TOXIC_GREEN}║              ☢️  Radiation Scan Complete!  ☢️              ║${NC}"
        echo -e "${TOXIC_GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    fi
    
    echo -e "${YELLOW}Found: $dir_count directories, $file_count files (Total: $item_count items)${NC}"
    
    if [ $total_skipped -gt 0 ]; then
        echo -e "${GREEN}Delta scan: Skipped $total_skipped unchanged items (faster scan!)${NC}"
    fi
    
    echo -e "${YELLOW}Results saved to: $SCAN_RESULTS${NC}"
    
    # Show a preview
    if [ $dir_count -gt 0 ]; then
        echo -e "\n${BLUE}Top 3 largest directories:${NC}"
        grep "^DIR|" "$SCAN_RESULTS" | head -3 | while IFS='|' read -r type size human_size path; do
            echo "  $human_size - $path"
        done
    fi
    
    if [ $file_count -gt 0 ]; then
        echo -e "\n${BLUE}Top 3 largest files:${NC}"
        grep "^FILE|" "$SCAN_RESULTS" | head -3 | while IFS='|' read -r type size human_size path; do
            echo "  $human_size - $path"
        done
    fi
    
    if [ $SCAN_INTERRUPTED -eq 1 ]; then
        echo -e "\n${GREEN}Tip: You can continue working with these partial results!${NC}"
    fi
}

# Function to display results
display_results() {
    if [ ! -f "$SCAN_RESULTS" ] || [ ! -s "$SCAN_RESULTS" ]; then
        echo -e "${RADIATION_YELLOW}⚠️  No targets found or scan not performed.${NC}"
        return 1
    fi
    
    local dir_count=$(grep -c "^DIR|" "$SCAN_RESULTS" 2>/dev/null || echo "0")
    local file_count=$(grep -c "^FILE|" "$SCAN_RESULTS" 2>/dev/null || echo "0")
    
    # Ensure counts are valid integers
    dir_count=${dir_count:-0}
    file_count=${file_count:-0}
    
    # Remove leading zeros
    dir_count=$((10#$dir_count))
    file_count=$((10#$file_count))
    
    echo -e "\n${TOXIC_GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${TOXIC_GREEN}║       ☢️  RADIATION SCAN RESULTS (${MIN_SIZE_MB}MB+)  ☢️           ║${NC}"
    echo -e "${TOXIC_GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo -e "${RADIATION_YELLOW}📁 Directories: $dir_count | 📄 Files: $file_count${NC}\n"
    
    if [ $dir_count -gt 0 ]; then
        echo -e "${TOXIC_GREEN}☢️  === DIRECTORIES (sorted by contamination level) ===${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        local index=1
        grep "^DIR|" "$SCAN_RESULTS" | while IFS='|' read -r type size human_size path; do
            printf "${ORANGE}%3d)${NC} ${RADIATION_YELLOW}%-10s${NC} %s\n" "$index" "$human_size" "$path"
            ((index++))
        done
        echo ""
    fi
    
    if [ $file_count -gt 0 ]; then
        echo -e "${TOXIC_GREEN}☣️  === FILES (sorted by contamination level) ===${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        local index=1
        grep "^FILE|" "$SCAN_RESULTS" | while IFS='|' read -r type size human_size path; do
            printf "${ORANGE}%3d)${NC} ${RADIATION_YELLOW}%-10s${NC} %s\n" "$index" "$human_size" "$path"
            ((index++))
        done
        echo ""
    fi
    
    return 0
}

# Function to select items for deletion with interactive checkboxes
select_items() {
    if [ ! -f "$SCAN_RESULTS" ] || [ ! -s "$SCAN_RESULTS" ]; then
        echo -e "${YELLOW}No items found. Please run scan first.${NC}"
        return 1
    fi
    
    # Create temporary files for directories and files
    local temp_dirs="/tmp/disk_scan_dirs.txt"
    local temp_files="/tmp/disk_scan_files.txt"
    
    grep "^DIR|" "$SCAN_RESULTS" > "$temp_dirs" 2>/dev/null || true
    grep "^FILE|" "$SCAN_RESULTS" > "$temp_files" 2>/dev/null || true
    
    # Read all items into arrays
    local -a items_type
    local -a items_size
    local -a items_human
    local -a items_path
    local -a items_selected
    local -a items_section
    
    local index=0
    
    # Read directories first
    if [ -s "$temp_dirs" ]; then
        while IFS='|' read -r type size human_size path; do
            items_type[$index]="$type"
            items_size[$index]="$size"
            items_human[$index]="$human_size"
            items_path[$index]="$path"
            items_selected[$index]=0
            items_section[$index]="DIR"
            ((index++))
        done < "$temp_dirs"
    fi
    
    # Read files second
    if [ -s "$temp_files" ]; then
        while IFS='|' read -r type size human_size path; do
            items_type[$index]="$type"
            items_size[$index]="$size"
            items_human[$index]="$human_size"
            items_path[$index]="$path"
            items_selected[$index]=0
            items_section[$index]="FILE"
            ((index++))
        done < "$temp_files"
    fi
    
    # Clean up temp files
    rm -f "$temp_dirs" "$temp_files"
    
    local total_items=$index
    
    if [ $total_items -eq 0 ]; then
        echo -e "${RADIATION_YELLOW}⚠️  No items found in scan results.${NC}"
        echo -e "\n${YELLOW}Press any key to continue...${NC}"
        read -rsn1
        return 1
    fi
    
    local current_pos=0
    local total_selected_size=0
    
    # Function to calculate total selected size
    calculate_total() {
        total_selected_size=0
        for ((i=0; i<total_items; i++)); do
            if [ "${items_selected[$i]}" -eq 1 ]; then
                total_selected_size=$((total_selected_size + items_size[$i]))
            fi
        done
    }
    
    # Function to draw the screen
    draw_screen() {
        clear
        echo -e "${BRIGHT_RED}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BRIGHT_RED}║          ☠️  SELECT TARGETS FOR NUKIFICATION  ☠️          ║${NC}"
        echo -e "${BRIGHT_RED}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo -e "${RADIATION_YELLOW}↑/↓ or j/k: navigate | X: toggle | a: all | n: none | ENTER: confirm | q: cancel${NC}\n"
        
        # Calculate total selected
        calculate_total
        local total_human=$(bytes_to_human $total_selected_size)
        echo -e "${TOXIC_GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${TOXIC_GREEN}║  ☢️  CONTAMINATION TO ELIMINATE: %-27s║${NC}" "$total_human"
        echo -e "${TOXIC_GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"
        
        # Show items with scrolling window
        local start_idx=0
        local end_idx=$total_items
        local max_display=15
        
        # If more than max_display items, show window around current position
        if [ $total_items -gt $max_display ]; then
            start_idx=$((current_pos - max_display / 2))
            if [ $start_idx -lt 0 ]; then
                start_idx=0
            fi
            end_idx=$((start_idx + max_display))
            if [ $end_idx -gt $total_items ]; then
                end_idx=$total_items
                start_idx=$((end_idx - max_display))
                if [ $start_idx -lt 0 ]; then
                    start_idx=0
                fi
            fi
        fi
        
        local last_section=""
        for ((i=start_idx; i<end_idx; i++)); do
            # Print section header
            if [ "${items_section[$i]}" != "$last_section" ]; then
                if [ "${items_section[$i]}" = "DIR" ]; then
                    echo -e "${RADIATION_YELLOW}☢️  ━━━ DIRECTORIES (CONTAMINATED ZONES) ━━━━━━━━━━━━━━━━━${NC}"
                else
                    echo -e "${RADIATION_YELLOW}☣️  ━━━ FILES (RADIOACTIVE WASTE) ━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                fi
                last_section="${items_section[$i]}"
            fi
            
            local checkbox="( )"
            if [ "${items_selected[$i]}" -eq 1 ]; then
                checkbox="(${BRIGHT_RED}☢${NC})"
            fi
            
            # Highlight current position
            if [ $i -eq $current_pos ]; then
                printf "${TOXIC_GREEN}→ %b %-10s %s${NC}\n" "$checkbox" "${items_human[$i]}" "${items_path[$i]}"
            else
                printf "  %b %-10s %s\n" "$checkbox" "${items_human[$i]}" "${items_path[$i]}"
            fi
        done
        
        if [ $total_items -gt $max_display ]; then
            echo -e "\n${ORANGE}⚠️  Showing $((start_idx + 1))-$end_idx of $total_items targets${NC}"
        fi
    }
    
    # Interactive selection loop
    # Save terminal settings
    local old_tty_settings=$(stty -g)
    
    while true; do
        draw_screen
        
        # Read single character
        read -rsn1 key
        
        # Handle arrow keys (they send 3 characters: ESC [ A/B)
        if [ "$key" = $'\x1b' ]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Up arrow
                    if [ $current_pos -gt 0 ]; then
                        ((current_pos--))
                    fi
                    ;;
                '[B') # Down arrow
                    if [ $current_pos -lt $((total_items - 1)) ]; then
                        ((current_pos++))
                    fi
                    ;;
            esac
        else
            case "$key" in
                ' '|$' '|x|X) # Space or X - toggle selection
                    if [ "${items_selected[$current_pos]}" -eq 0 ]; then
                        items_selected[$current_pos]=1
                    else
                        items_selected[$current_pos]=0
                    fi
                    ;;
                'j') # j - move down (vim style)
                    if [ $current_pos -lt $((total_items - 1)) ]; then
                        ((current_pos++))
                    fi
                    ;;
                'k') # k - move up (vim style)
                    if [ $current_pos -gt 0 ]; then
                        ((current_pos--))
                    fi
                    ;;
                'a') # a - select all
                    for ((i=0; i<total_items; i++)); do
                        items_selected[$i]=1
                    done
                    ;;
                'n') # n - select none
                    for ((i=0; i<total_items; i++)); do
                        items_selected[$i]=0
                    done
                    ;;
                '') # Enter - confirm (empty string means Enter was pressed)
                    break
                    ;;
                'q'|'Q') # q - quit
                    clear
                    echo -e "\n${RADIATION_YELLOW}⚠️  Target selection cancelled - Standing down.${NC}"
                    return 1
                    ;;
                *) # Ignore other keys
                    ;;
            esac
        fi
    done
    
    # Save selected items
    > "$SELECTED_ITEMS"
    local selected_count=0
    for ((i=0; i<total_items; i++)); do
        if [ "${items_selected[$i]}" -eq 1 ]; then
            echo "${items_type[$i]}|${items_size[$i]}|${items_human[$i]}|${items_path[$i]}" >> "$SELECTED_ITEMS"
            ((selected_count++))
        fi
    done
    
    clear
    if [ $selected_count -eq 0 ]; then
        echo -e "${RADIATION_YELLOW}⚠️  No targets selected for nukification.${NC}"
        echo -e "\n${YELLOW}Press any key to continue...${NC}"
        read -rsn1
        return 1
    fi
    
    calculate_total
    local total_human=$(bytes_to_human $total_selected_size)
    echo -e "${TOXIC_GREEN}☢️  Armed $selected_count target(s) - Total payload: $total_human${NC}"
    echo -e "\n${YELLOW}Press any key to continue...${NC}"
    read -rsn1
    return 0
}

# Function to confirm and delete
delete_items() {
    if [ ! -f "$SELECTED_ITEMS" ] || [ ! -s "$SELECTED_ITEMS" ]; then
        echo -e "${RADIATION_YELLOW}⚠️  No targets selected for nukification.${NC}"
        return 1
    fi
    
    echo -e "\n${BRIGHT_RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_RED}║          ☢️  TARGETS LOCKED FOR NUKIFICATION  ☢️          ║${NC}"
    echo -e "${BRIGHT_RED}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    
    local total_size=0
    local item_count=0
    while IFS='|' read -r type size human_size path; do
        echo -e "${BRIGHT_RED}☠️  [$type]${NC} ${RADIATION_YELLOW}$human_size${NC} - $path"
        total_size=$((total_size + size))
        ((item_count++))
    done < "$SELECTED_ITEMS"
    
    local total_human=$(bytes_to_human $total_size)
    echo -e "\n${TOXIC_GREEN}☢️  Total contamination to eliminate: $total_human${NC}"
    echo -e "${TOXIC_GREEN}☢️  Total targets: $item_count${NC}"
    
    echo -e "\n${BRIGHT_RED}⚠️  ☠️  WARNING: NUCLEAR OPTION - THIS CANNOT BE UNDONE!  ☠️  ⚠️${NC}"
    echo -e "${ORANGE}Type 'NUKE' to launch the missiles:${NC} "
    read confirm
    
    if [ "$confirm" != "NUKE" ]; then
        echo -e "${RADIATION_YELLOW}⚠️  Launch sequence aborted. Standing down.${NC}"
        return 1
    fi
    
    echo -e "\n${BRIGHT_RED}☢️  ☢️  ☢️  LAUNCHING NUKES...  ☢️  ☢️  ☢️${NC}\n"
    
    local deleted_count=0
    local deleted_size=0
    
    while IFS='|' read -r type size human_size path; do
        if [ -e "$path" ]; then
            echo -e "${ORANGE}💥 Nukifying: $path${NC}"
            if rm -rf "$path" 2>/dev/null; then
                echo -e "${TOXIC_GREEN}   ☢️  OBLITERATED${NC}"
                ((deleted_count++))
                deleted_size=$((deleted_size + size))
            else
                echo -e "${BRIGHT_RED}   ✗ FAILED (target survived)${NC}"
            fi
        fi
    done < "$SELECTED_ITEMS"
    
    # Update statistics
    update_stats $deleted_size $deleted_count
    
    local freed_human=$(bytes_to_human $deleted_size)
    echo -e "\n${TOXIC_GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${TOXIC_GREEN}║          ☢️  NUKIFICATION COMPLETE!  ☢️                    ║${NC}"
    echo -e "${TOXIC_GREEN}║  Targets obliterated: %-35d║${NC}" "$deleted_count"
    echo -e "${TOXIC_GREEN}║  Contamination removed: %-33s║${NC}" "$freed_human"
    echo -e "${TOXIC_GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo -e "${RADIATION_YELLOW}⚡ Mission accomplished! The wasteland is cleaner. ⚡${NC}\n"
}

# Function to configure minimum size
configure_size() {
    # Check if changing size will clear results
    local current_saved_size=""
    if [ -f "$SCAN_SIZE_MARKER" ]; then
        current_saved_size=$(cat "$SCAN_SIZE_MARKER")
    fi
    
    echo -e "\n${BLUE}=== Configure Minimum Size ===${NC}"
    echo -e "${YELLOW}Current minimum size: ${MIN_SIZE_MB}MB${NC}"
    
    if [ -n "$current_saved_size" ] && [ "$current_saved_size" != "$MIN_SIZE_MB" ]; then
        echo -e "${RED}Warning: Saved scan results are for ${current_saved_size}MB threshold${NC}"
    fi
    
    echo ""
    echo "Common presets:"
    echo "  1) 100MB  - Find smaller files"
    echo "  2) 256MB  - Medium files"
    echo "  3) 512MB  - Large files (default)"
    echo "  4) 1GB    - Very large files"
    echo "  5) 5GB    - Huge files"
    echo "  6) Custom - Enter your own size"
    echo ""
    read -p "Choose an option: " size_choice
    
    local new_size=$MIN_SIZE_MB
    
    case $size_choice in
        1)
            new_size=100
            ;;
        2)
            new_size=256
            ;;
        3)
            new_size=512
            ;;
        4)
            new_size=1024
            ;;
        5)
            new_size=5120
            ;;
        6)
            read -p "Enter minimum size in MB: " custom_size
            if [[ "$custom_size" =~ ^[0-9]+$ ]] && [ "$custom_size" -gt 0 ]; then
                new_size=$custom_size
            else
                echo -e "${RED}Invalid size. Keeping current setting.${NC}"
                return
            fi
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            return
            ;;
    esac
    
    # Check if size changed
    if [ "$new_size" != "$current_saved_size" ] && [ -f "$SCAN_RESULTS" ]; then
        echo -e "\n${YELLOW}⚠️  Size threshold changed from ${current_saved_size}MB to ${new_size}MB${NC}"
        echo -e "${YELLOW}⚠️  Previous scan results will be cleared on next scan${NC}"
        echo -e "${YELLOW}⚠️  You'll need to run a full scan again${NC}"
    fi
    
    MIN_SIZE_MB=$new_size
    echo -e "\n${GREEN}Minimum size set to: ${MIN_SIZE_MB}MB${NC}"
}

# Function to scan custom path
scan_custom_path() {
    echo -e "\n${BLUE}=== Scan Custom Location ===${NC}"
    echo -e "${YELLOW}Enter path(s) to scan:${NC}"
    echo -e "${YELLOW}  • Single path: /Users/username/Documents${NC}"
    echo -e "${YELLOW}  • Multiple paths (comma-separated): /path1, /path2, ~/Downloads${NC}"
    echo -e "${YELLOW}  • Multiple paths (space-separated): /path1 /path2 ~/Downloads${NC}"
    echo ""
    read -p "Path(s): " custom_input
    
    if [ -z "$custom_input" ]; then
        echo -e "${RED}No path provided.${NC}"
        return
    fi
    
    # Convert input to array - handle both comma and space delimiters
    local -a paths_array
    
    # First, split by comma
    IFS=',' read -ra comma_split <<< "$custom_input"
    
    # Then process each comma-separated part for spaces
    for part in "${comma_split[@]}"; do
        # Trim leading/trailing whitespace
        part=$(echo "$part" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # If part contains spaces, split by space
        if [[ "$part" == *" "* ]]; then
            IFS=' ' read -ra space_split <<< "$part"
            for subpart in "${space_split[@]}"; do
                subpart=$(echo "$subpart" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                [ -n "$subpart" ] && paths_array+=("$subpart")
            done
        else
            [ -n "$part" ] && paths_array+=("$part")
        fi
    done
    
    # Validate paths
    local valid_paths=()
    echo ""
    for path in "${paths_array[@]}"; do
        # Expand ~ to home directory
        expanded_path="${path/#\~/$HOME}"
        
        if [ -d "$expanded_path" ]; then
            valid_paths+=("$expanded_path")
            echo -e "${GREEN}✓ Valid:${NC} $path"
        else
            echo -e "${RED}✗ Not found:${NC} $path"
        fi
    done
    
    if [ ${#valid_paths[@]} -eq 0 ]; then
        echo -e "\n${RED}No valid paths to scan.${NC}"
        return
    fi
    
    echo -e "\n${GREEN}Scanning ${#valid_paths[@]} location(s)...${NC}\n"
    scan_disk "${valid_paths[@]}"
    display_results
}

# Main menu
main_menu() {
    while true; do
        echo -e "\n${TOXIC_GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${TOXIC_GREEN}║              ☢️  NUKIFY CONTROL PANEL  ☢️                  ║${NC}"
        echo -e "${TOXIC_GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo -e "${RADIATION_YELLOW}☣️  Target Size: ${MIN_SIZE_MB}MB or larger${NC}"
        
        if [ $DELTA_SCAN_ENABLED -eq 1 ]; then
            echo -e "${TOXIC_GREEN}⚡ Radiation Scanner: ACTIVE (Delta mode)${NC}"
        fi
        
        if [ -n "$FILTER_EXTENSION" ] || [ -n "$FILTER_AGE_DAYS" ]; then
            echo -e "${RADIATION_YELLOW}🎯 Active Targeting Filters:${NC}"
            [ -n "$FILTER_EXTENSION" ] && echo -e "  • Extension: .$FILTER_EXTENSION"
            [ -n "$FILTER_AGE_DAYS" ] && echo -e "  • Age: $FILTER_AGE_DAYS+ days"
        fi
        
        echo ""
        echo -e "${TOXIC_GREEN}☢️  SCAN OPTIONS:${NC}"
        echo "  1) 🔍 Scan default locations (Home, Applications, Library)"
        echo "  2) 🎯 Scan custom location"
        echo ""
        echo -e "${RADIATION_YELLOW}📊 VIEW & ANALYZE:${NC}"
        echo "  3) 📋 Display scan results"
        echo "  4) 📈 Show disk usage graph"
        echo "  5) 🔎 Find duplicate files"
        echo "  6) 📊 View statistics dashboard"
        echo ""
        echo -e "${BRIGHT_RED}💀 CLEANUP (DANGER ZONE):${NC}"
        echo "  7) ☠️  Select items to NUKE (interactive)"
        echo "  8) ☢️  LAUNCH NUKES (delete selected)"
        echo "  9) ⚡ Quick nuke actions"
        echo ""
        echo -e "${ORANGE}⚙️  SETTINGS:${NC}"
        echo " 10) 🎚️  Configure minimum size"
        echo " 11) 🎯 Configure filters"
        echo " 12) ⚡ Scan settings (delta scan, cache)"
        echo " 13) 🚪 Exit (or press Q)"
        echo ""
        read -p "Choose an option: " choice
        
        case $choice in
            1)
                FILTER_EXTENSION=""
                FILTER_AGE_DAYS=""
                scan_disk
                display_results
                ;;
            2)
                scan_custom_path
                ;;
            3)
                display_results
                ;;
            4)
                show_disk_graph
                ;;
            5)
                find_duplicates
                ;;
            6)
                show_statistics
                ;;
            7)
                if display_results; then
                    select_items
                    # Clear any remaining input
                    read -t 0.1 -n 10000 discard 2>/dev/null || true
                fi
                ;;
            8)
                delete_items
                ;;
            9)
                quick_actions
                ;;
            10)
                configure_size
                ;;
            11)
                configure_filters
                ;;
            12)
                scan_settings
                ;;
            13|q|Q)
                echo -e "\n${TOXIC_GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
                echo -e "${TOXIC_GREEN}║          ☢️  NUKIFY REACTOR SHUTTING DOWN  ☢️             ║${NC}"
                echo -e "${TOXIC_GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
                echo -e "${RADIATION_YELLOW}Stay radioactive! ⚡${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${BRIGHT_RED}⚠️  Invalid option - Try again!${NC}"
                ;;
        esac
    done
}

# Cleanup on exit
trap 'rm -f "$SELECTED_ITEMS"' EXIT

# Splash screen with warning
show_splash_screen() {
    clear
    
    # Show title with icons
    echo -e "${BRIGHT_RED}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════╗
    ║  ☢️  ☠️  ⚠️                                    ⚠️  ☠️  ☢️  ║
    ║                                                           ║
    ║          ███╗   ██╗██╗   ██╗██╗  ██╗██╗███████╗██╗   ██╗ ║
    ║          ████╗  ██║██║   ██║██║ ██╔╝██║██╔════╝╚██╗ ██╔╝ ║
    ║          ██╔██╗ ██║██║   ██║█████╔╝ ██║█████╗   ╚████╔╝  ║
    ║          ██║╚██╗██║██║   ██║██╔═██╗ ██║██╔══╝    ╚██╔╝   ║
    ║          ██║ ╚████║╚██████╔╝██║  ██╗██║██║        ██║    ║
    ║          ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝        ╚═╝    ║
    ║                                                           ║
    ║  ☢️  ☠️  ⚠️                                    ⚠️  ☠️  ☢️  ║
    ╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${RADIATION_YELLOW}              ☢️  NUCLEAR DISK CLEANUP TOOL  ☢️${NC}"
    
    # Nuclear mushroom cloud
    echo ""
    echo -e "${ORANGE}"
    cat << 'EOF'
                          .-""""-.
                        .'        '.
                       /   O    O   \
                      :                :
                      |                |
                      :       __       :
                       \  .-"    "-.  /
                        '.          .'
                          '-......-'
                            '.  .'
                          .-'  '-.
                        .'        '.
                       /            \
                      |              |
                      |              |
                       \            /
                        '.        .'
                          '-.  .-'
                            ||
                            ||
                          .'  '.
                         /      \
                        |        |
                        |        |
                         \      /
                          '.  .'
EOF
    echo -e "${NC}"
    echo -e "${BRIGHT_RED}                      ═══════ NUKIFY ═══════${NC}"
    echo ""
    
    # Show warning text
    echo ""
    echo -e "${BRIGHT_RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_RED}║                  ☠️  LIABILITY DISCLAIMER  ☠️             ║${NC}"
    echo -e "${BRIGHT_RED}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RADIATION_YELLOW}⚠️  WARNING: NUCLEAR MATERIAL - EXTREME DANGER ⚠️${NC}"
    echo ""
    echo -e "${ORANGE}This tool is designed for TOTAL DISK ANNIHILATION.${NC}"
    echo -e "${ORANGE}Files deleted by Nukify are ${BRIGHT_RED}PERMANENTLY DESTROYED${ORANGE}.${NC}"
    echo -e "${ORANGE}There is ${BRIGHT_RED}NO UNDO${ORANGE}. There is ${BRIGHT_RED}NO RECOVERY${ORANGE}. There is ${BRIGHT_RED}NO GOING BACK${ORANGE}.${NC}"
    echo ""
    echo -e "${BRIGHT_RED}☢️  YOU ARE SOLELY RESPONSIBLE FOR WHAT YOU DELETE.${NC}"
    echo -e "${BRIGHT_RED}☢️  THE AUTHOR ACCEPTS NO LIABILITY FOR DATA LOSS.${NC}"
    echo -e "${BRIGHT_RED}☢️  USE AT YOUR OWN RISK. PROCEED WITH CAUTION.${NC}"
    echo ""
    echo -e "${YELLOW}By continuing, you acknowledge:${NC}"
    echo -e "  ${TOXIC_GREEN}•${NC} You understand the risks of this nuclear tool"
    echo -e "  ${TOXIC_GREEN}•${NC} You accept full responsibility for all deletions"
    echo -e "  ${TOXIC_GREEN}•${NC} You will not hold the author liable for data loss"
    echo ""
    echo -e "${ORANGE}Press ${BRIGHT_RED}ENTER${ORANGE} to accept and enter the reactor...${NC}"
    
    # Wait for Enter key
    read -r
    
    clear
    echo -e "${TOXIC_GREEN}✓ Disclaimer accepted. Reactor online.${NC}"
    echo -e "${RADIATION_YELLOW}☢️  Remember: With great power comes great responsibility. ☢️${NC}\n"
    sleep 1
}

# Start
show_splash_screen

main_menu
