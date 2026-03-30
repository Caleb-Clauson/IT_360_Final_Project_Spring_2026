# Project Requirements – ForensiCollect

## 1. Forensic Artifacts Collected

### System Information
- OS and kernel:
  - `/etc/os-release`
  - `uname -a`
- Host and time:
  - `hostnamectl` (if available) or `hostname`
  - `date`
  - `uptime`
- Storage overview:
  - `df -h`
  - `lsblk`

---

### User Activity
- Current sessions:
  - `who`
- Recent logins:
  - `last -a` (last 50 entries)
- Authentication and sudo activity:
  - `/var/log/auth.log` (Ubuntu)
  - `/var/log/secure` (RHEL-based systems)
  - `journalctl` (fallback if needed)
- User accounts:
  - `/etc/passwd`

---

### Process / Service Snapshot
- Running processes:
  - `ps aux`
- System resource snapshot:
  - `top -b -n 1`
- Running services:
  - `systemctl list-units --type=service`
  - fallback: `service --status-all`

---

### Network Snapshot
- Interfaces and routes:
  - `ip a`
  - `ip r`
- Listening ports:
  - `ss -tulpen` (preferred)
  - fallback: `netstat -plant`
- ARP / neighbor table:
  - `arp -a`
  - fallback: `ip neigh`

---

### Recent File Changes
- Modified files in key directories:
  - `/etc`
  - `/var/log`
- Using:
  - `find` with `-mtime`

---

### Higher-Value Linux Artifacts
- Authentication logs
- Service activity
- Recent system configuration changes
- Indicators of persistence or abnormal behavior

---

## 2. Data Integrity

We ensure forensic integrity by:
- Using read-only commands for triage collection  
- Writing output to a timestamped case directory  
- Logging all executed commands (`collection_log.txt`)  
- Recording warnings (`warnings.txt`)  
- Hashing all collected files using SHA-256  
- Creating a hash of the final archive (`case.tar.gz`)  
- Using consistent naming and timestamps  

---

## 3. Dependencies

### Required
- `bash`
- `coreutils`
- `find`
- `sha256sum`
- `tar`
- `gzip`

### Optional (with fallbacks)
- `ip`
- `ss` or `netstat`
- `ps`
- `systemctl`
- `last`
- `who`
- `lsblk`
- `df`

---

## 4. Error Handling

The tool is designed to be resilient:

- Checks for required commands at startup  
- Logs missing tools but continues execution  
- Wraps each module to prevent full failure  
- Records issues in:
  - `collection_log.txt`
  - `warnings.txt`
- Handles:
  - permission issues  
  - missing logs  
  - unsupported system features  
- Validates disk space before execution  

---

## 5. Output Format

### Raw Outputs
- Text files from each module stored in `raw/`

### Structured Outputs
- `report.json`
- `timeline.csv`

### Documentation and Integrity
- `collection_log.txt`
- `warnings.txt`
- `summary.txt`
- `hash_manifest.txt`

### Packaging
- Compressed archive:
  - `case_TIMESTAMP.tar.gz`
- Archive hash:
  - `.sha256`

