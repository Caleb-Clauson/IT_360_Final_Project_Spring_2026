# What specific forensic artifacts will your tool collect?
1.) System Information
-OS + kernal: '/etc/os-release', 'uname -a'
-Host + time: 'hostnamectl' (if available), 'date', 'uptime'
-Storage overview: 'df -h', 'lsblk'
2.) User Activity
-Current sessions: 'who'
-Recent logons 'last -a' (last 50 entries)
-Authentication + sudo activity:
  -'/var/log/auth.log' (Ubuntu)
3.) Process/Service snapshot
-Running processes: 'ps aux' (top CPU/mem snapshots)
-Running services: 'systemctl 
4.) Network snapshot
-Interfaces + Routes 'ip a', 'ip r'
-Listening ports: 
5.) Recent file changes (key directories)
-Recent modification in '/etc' and '/var/log' 

# How will you maintain data integrity throughout collection?
We will preserve integrity and create an audit trail by:
-Using read-only commands wherever possible (triage collection, no disk imaging)
-Writing outputs to a timestamped case directory to avoid overwiriting prior runs
-Logging every command executed with a timestamp into 'collection_log.txt'
-Hashing every collected output file using SHA-256 and writing a 'hash_manifest.txt'
-Creating a SHA-256 hash of the final compressed archive ('case.tar.gz') for later verification
-Using consistent file naming and timestamps so results are repeatable

# What dependencies will your tool require on the target system?
Minimum dependcies
-'bash', 'coreutils'
-'ps', 'find'
-Networking tools: 'ip', 'ss', or 'netstat'
-'sha256sum'
-Archiving: 'tar', 'gzip'

# How will you handle errors and unexpected conditions?
We will imprement robust error handling by:
-Checking required commands at startup and reporting missing tools (while continuing with what is available)
-Wrapping each collection step so failures (eg., permission denied, missing logs, unsupported systemd) are:
  -recorded in 'collection_log.txt'
  -recorded in a "warnings.txt' section of the summary
  -do not stop the entire collection unless the output directory cannt be created/written
-Detecting common enironment differences
-Validating free disk space before running and warning if space is low

# What format will your output take for analysis and reporting?
The tool will produce both raw and structered outputs:
1.) Raw outputs (human-readable)
-Text files from each module (system, users, processes, network, recent changes)
2.) Structured outputs
-'report.json'
-'timeline.csv'
3.) Integrity + documentation
-'hash_manifest.txt'
-'collection_log.txt'
-'summary.txt'
4.) Packaging
-'case.tar.gz'

