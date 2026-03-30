# IT_360_Final_Project_Spring_2026

## Project Overview
Our final project for IT 360 is to create a forensic collection tool, specifically a **Linux DFIR Triage and Mini Timeline Report Tool**.

---

## Team Members
- Caleb Clauson  
- Eric Anderson  

## Team Name
**Securists**

---

## Project Idea
**ForensiCollect** – A Linux-based DFIR (Digital Forensics and Incident Response) triage tool designed to collect, organize, and summarize key system artifacts for rapid analysis.

### Key Features
1. Linux-focused forensic triage  
2. User-focused and easy to interpret  
3. Implemented using Bash scripting  
4. Structured outputs (JSON and CSV)  
5. Modular and extensible design  

---

## What the Tool Does

### 1. Evidence Collection
The tool collects key forensic artifacts from the system, including:
- System information (OS, kernel, uptime, storage)
- User activity (logins, sessions, authentication logs)
- Process and service snapshots
- Network configuration and listening ports
- Recent file changes in critical directories (`/etc`, `/var/log`)
- Higher-value Linux artifacts such as authentication activity and system changes

---

### 2. Integrity and Documentation
To ensure forensic soundness, the tool:
- Uses read-only commands for triage collection  
- Creates a timestamped case directory  
- Logs all executed commands in `collection_log.txt`  
- Records warnings and errors in `warnings.txt`  
- Generates a SHA-256 hash manifest (`hash_manifest.txt`)  
- Hashes the final archive for verification  

---

### 3. Artificial Intelligence Explainer
An optional AI component is used for **post-collection analysis only**:
- Converts complex logs into readable summaries  
- Improves investigator efficiency  
- Does NOT modify or collect evidence  

---

### 4. Output Packaging
- Generates a structured case folder  
- Compresses results into a `.tar.gz` archive  
- Produces a hash of the archive for integrity validation  

---

## Tech Stack
- **Bash scripting** for orchestration and automation  
- **Standard Linux utilities** (`ps`, `ip`, `ss`, `find`, etc.)  

---

## Output Structure
Each run generates a case directory containing:

- `raw/` → collected forensic artifacts  
- `report/` → summaries and AI outputs  
- `collection_log.txt` → command audit trail  
- `warnings.txt` → errors and missing data  
- `hash_manifest.txt` → SHA-256 file hashes  
- `summary.txt` → human-readable overview  
- `report.json` → structured summary  
- `timeline.csv` → event timeline  

---

## How We Will Demonstrate It
1. Run the tool on a Linux VM  
2. Walk through the generated case folder  
3. Highlight key findings such as:
   - Failed login attempts  
   - Suspicious listening ports  
   - Recent changes in `/etc`  
   - Newly created users  

---

## Project Timeline
- **February 5, 2026**: Project Proposal Submission  
- **Week of March 16**: Core collection features completed  
- **Week of April 13**: Testing and validation  
- **Week of May 11**: Documentation and presentation prep  
- **May 30, 2026**: Final project submission  
