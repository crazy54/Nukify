# ☢️ NUKIFY - Nuclear Disk Cleanup Tool ☢️

```
    ███╗   ██╗██╗   ██╗██╗  ██╗██╗███████╗██╗   ██╗
    ████╗  ██║██║   ██║██║ ██╔╝██║██╔════╝╚██╗ ██╔╝
    ██╔██╗ ██║██║   ██║█████╔╝ ██║█████╗   ╚████╔╝ 
    ██║╚██╗██║██║   ██║██╔═██╗ ██║██╔══╝    ╚██╔╝  
    ██║ ╚████║╚██████╔╝██║  ██╗██║██║        ██║   
    ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   
```

**⚠️ HANDLE WITH EXTREME CAUTION ⚠️**

A powerful, radiation-themed disk cleanup utility for macOS that finds and **NUKES** large files and directories from orbit. When you need to obliterate disk space hogs, accept no substitutes.

## ☢️ Features

### Core Functionality
- **☢️ Radiation Scanner** - Detect contaminated files and directories above a configurable size threshold (default: 512MB)
- **☠️ Interactive Targeting** - Checkbox-based UI with spacebar toggle and live contamination counter
- **⚠️ Nuclear Safety** - Requires explicit "NUKE" confirmation before obliterating targets
- **⚡ Automatic Sudo** - Automatically requests elevated privileges for maximum destruction

### Advanced Features

#### 🔍 Radiation Detection
- **⚡ Delta Scanning** - Caches file metadata and skips unchanged files on subsequent scans (5-10x faster!)
- **🎯 Custom Targeting** - Scan specific contamination zones with comma or space-delimited paths
- **⚠️ Interrupt Support** - Press Ctrl+C during scan to view partial results
- **☢️ Progress Indicators** - Animated spinner shows radiation scanner is active

#### 📊 Analysis Tools
- **📈 Visual Contamination Graph** - ASCII bar chart showing top 15 most contaminated items
- **🔎 Duplicate Detector** - MD5-based duplicate file detection with space savings calculation
- **📊 Mission Statistics** - Track total contamination removed, targets obliterated, and cleanup history
- **☣️ File Type Breakdown** - See which file types are spreading the most contamination

#### 🎯 Smart Targeting Filters
- **Extension Filter** - Target only specific file types (e.g., .log, .tmp, .dmg)
- **Age Filter** - Find radioactive files older than X days
- **Apply/Clear Filters** - Easily refine targeting parameters

#### ⚡ Quick Nuke Actions
Pre-configured nukification profiles:
1. 💥 Nuke Downloads (files 30+ days old)
2. 💥 Nuke system logs (*.log files)
3. 💥 Nuke cache directories
4. 💥 Nuke disk images (*.dmg, *.iso)
5. 💥 Nuke development artifacts (node_modules, .git)

## 📋 Requirements

- macOS (tested on Tahoe 26.1)
- Bash shell
- Sudo privileges

## 🎮 Usage

### Basic Usage
```bash
# Launch Nukify (sudo is automatic)
./nukify.sh

# Or
bash nukify.sh
```

### Control Panel Options

```
☢️  SCAN OPTIONS:
  1) 🔍 Scan default locations (Home, Applications, Library)
  2) 🎯 Scan custom location
  
📊 VIEW & ANALYZE:
  3) 📋 Display scan results
  4) 📈 Show disk usage graph
  5) 🔎 Find duplicate files
  6) 📊 View statistics dashboard
  
💀 CLEANUP (DANGER ZONE):
  7) ☠️  Select items to NUKE (interactive)
  8) ☢️  LAUNCH NUKES (delete selected)
  9) ⚡ Quick nuke actions
  
⚙️  SETTINGS:
 10) 🎚️  Configure minimum size
 11) 🎯 Configure filters
 12) ⚡ Scan settings (delta scan, cache)
 13) 🚪 Exit (or press Q)
```

### Interactive Targeting

When selecting targets to nuke (option 7):
- **↑/↓ or j/k** - Navigate through targets
- **SPACE** - Toggle selection (shows red ☢️)
- **a** - Arm all targets
- **n** - Disarm all targets
- **ENTER** - Lock targets and proceed
- **q** - Abort mission

**☢️ Live Contamination Counter**: Shows total contamination to be eliminated as you select targets!

### Custom Zone Targeting

Scan specific contamination zones with flexible input:

```bash
# Single zone
/Users/username/Documents

# Comma-delimited zones
/path1, /path2, ~/Downloads

# Space-delimited zones
/path1 /path2 ~/Downloads

# Mixed format
/path1, /path2 /path3, ~/Downloads
```

## ⚙️ Configuration

### Contamination Threshold Presets
- 100MB - Detect minor contamination
- 256MB - Medium contamination
- 512MB - Heavy contamination (default)
- 1GB - Severe contamination
- 5GB - Critical contamination
- Custom - Enter any threshold in MB

### ⚡ Delta Scan (Radiation Fast Mode)
When enabled, the radiation scanner caches file metadata (modification time + size) and skips unchanged files on subsequent scans.

**Benefits:**
- First scan: Normal speed (builds radiation cache)
- Subsequent scans: 5-10x faster! ⚡

**Manage via Option 12:**
- Toggle radiation scanner mode
- Clear cache (force full rescan)
- View cache statistics

## 📊 Mission Statistics

Nukify tracks your cleanup missions:
- Total contamination removed (lifetime)
- Total targets obliterated
- Total nukification missions
- Average contamination removed per mission
- File type breakdown

View your destruction stats anytime with **Option 6**

## 🎨 Visual Features

### Contamination Graph
ASCII bar chart with:
- Radiation-themed color coding (Toxic Green=directories, Radiation Yellow=files)
- Proportional contamination levels
- Top 15 most contaminated items

### Live Radiation Scanner
During scans:
- Animated spinner (radiation detector active)
- Real-time contamination counts
- Skipped items counter (delta scan mode)

### Radiation-Themed Color Coding
- ☢️ Toxic Green - Success/Active systems
- ⚠️ Radiation Yellow - Warnings/Caution
- 💀 Bright Red - Danger/Deletion zone
- 🔥 Orange - Important information

## 🔒 Nuclear Safety Features

1. **☢️ Sudo Confirmation** - Prompts for elevated privileges
2. **⚠️ Explicit Launch Code** - Must type "NUKE" to launch missiles
3. **📋 Target Preview** - Shows all targets and total contamination before launch
4. **🛑 Emergency Stop** - Ctrl+C aborts scan safely
5. **🔐 No Accidental Launches** - Multiple confirmation steps prevent accidents

## 📁 Radiation Cache Locations

Temporary files (auto-managed):
- `/tmp/disk_scan_results.txt` - Radiation scan results
- `/tmp/disk_scan_cache.txt` - Delta scan radiation cache
- `/tmp/disk_cleanup_stats.txt` - Mission statistics
- `/tmp/disk_selected_items.txt` - Armed targets

## 🐛 Troubleshooting

### "local: can only be used in a function"
- This was a bug in earlier versions, should be fixed now
- Try running: `bash -n nukify.sh` to check for syntax errors

### Radiation counters show 0
- Fixed in latest version
- Counters now properly track contamination outside subshells

### Radiation scanner is slow
- Enable delta scan mode (Option 12 → Toggle radiation scanner)
- Reduce contamination threshold
- Target specific zones instead of entire system

### Permission denied
- Nukify automatically requests sudo privileges
- Ensure you have admin/root access for maximum destruction

## 🎯 Nukification Tips & Tricks

1. **☢️ Start with high contamination threshold** (1GB+) to find the biggest targets first
2. **⚡ Use delta scan mode** for repeated scans of the same contamination zones
3. **💥 Try Quick Nuke Actions** (Option 9) for pre-configured nukification missions
4. **🔎 Check duplicates** (Option 5) before launching to avoid removing needed files
5. **🎯 Use targeting filters** to focus on specific file types or old radioactive files
6. **🛑 Press Ctrl+C** if a scan is taking too long - you can work with partial results

## 📈 Performance

- **⚡ Radiation Scanner (Delta Mode)**: 5-10x faster on subsequent scans
- **☢️ Optimized Detection**: Single radiation sweep per directory tree
- **🔄 Parallel Processing**: Background scans with live progress indicators
- **💾 Smart Caching**: Metadata-based contamination change detection

## 🔮 Future Enhancements

Potential features for future nukification missions:
- Export/import target lists
- Scheduled radiation sweeps
- Backup before nukification
- Comparison mode (before/after contamination levels)
- Web-based launch control panel

## 📝 Version History

### v2.0 - Nukify Edition (Nuclear Rebranding)
- ☢️ Complete radiation/biohazard theme overhaul
- 💀 Nuclear-themed UI with biohazard icons
- ⚡ Renamed to "Nukify" - the nuclear disk cleanup tool
- 🎨 Toxic green, radiation yellow, and bright red color scheme
- ☠️ "NUKE" confirmation instead of "DELETE"
- 📊 Contamination-themed terminology throughout

### v1.5 - Elite Edition
- Added delta scanning with caching
- Interactive checkbox selection
- Live space counter
- Visual disk usage graph
- Duplicate file finder
- Statistics dashboard
- Smart filters (extension, age)
- Quick cleanup actions
- Animated progress indicators
- Interrupt support (Ctrl+C)
- Auto-sudo
- Multiple path input formats

### v1.0 - Initial Release
- Basic scanning
- Simple deletion
- Size threshold configuration

## 👨‍💻 Author

Created with ☢️ for maximum disk obliteration

## 📄 License

Free to use and modify. Handle with extreme caution.

---

**☢️ Happy Nukifying! Stay Radioactive! ⚡**

```
⚠️  WARNING: NUCLEAR MATERIAL ⚠️
This tool is designed for total disk annihilation.
Use responsibly. We are not liable for any data vaporized.
```
