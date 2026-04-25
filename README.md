# 🔐 ForensiCollect – Linux DFIR Triage Tool

## 📌 Project Overview
ForensiCollect is a Linux-based Digital Forensics and Incident Response (DFIR) triage tool designed to automate the collection and analysis of critical system artifacts.

It enables cybersecurity analysts to quickly move from raw system data to actionable insights by combining automated evidence collection with AI-assisted reporting.

---

## 👥 Team
Team Name: Securists  
- Caleb Clauson  
- Eric Anderson  

---

## 🎯 Purpose
Digital forensic investigations are often time-consuming and require manually collecting and analyzing system data.

ForensiCollect solves this by:
- Automating artifact collection  
- Structuring outputs for easy review  
- Generating a concise security summary  

---

## 🚀 Key Features

### Evidence Collection
Collects critical Linux forensic artifacts:
- System info (OS, uptime, hostname)
- Authentication logs (/var/log/auth.log)
- Running processes (ps aux)
- Network activity (ss -tulpen, ss -antp)
- Listening ports
- Recent file changes (/etc, /var/log)
- User accounts (/etc/passwd)
- Sudo activity
- Cron jobs (persistence detection)
- Kernel modules (lsmod)
- Recently modified user files

---

### AI Analysis
- Converts raw logs into human-readable findings  
- Identifies suspicious ports, authentication anomalies, and persistence techniques  

Output file:
report/ai_summary.txt

---

### Integrity & Logging
- collection_log.txt (command audit trail)
- warnings.txt (errors and missing data)
- hash_manifest.txt (SHA-256 file hashes)
- Timestamped case directory

---

### Output Packaging
Each run creates:
output/case_<timestamp>/

Contents:
- raw/ → collected artifacts  
- report/ → summaries and AI output  
- timeline.csv → event timeline  
- report.json → structured data  
- summary.txt → overview  
- hash_manifest.txt → integrity verification  

---

## 🛠️ Tech Stack
- Bash scripting  
- Linux CLI tools (ps, ss, find, grep, lsmod)  
- AI API (via curl)  

---

## ⚙️ Setup Instructions

### 1. Clone Repository
git clone https://github.com/Caleb-Clauson/IT_360_Final_Project_Spring_2026.git  
cd IT_360_Final_Project_Spring_2026/src  

---

### 2. Create Environment File
cp ../.env.example .env  
nano .env  

Add your API key:
AI_API_KEY=your_real_key_here  
AI_MODEL=llama3.2-vision:latest  

---

### 3. Set Permissions
chmod +x forensicollect.sh  
chmod +x modules/*.sh  
chmod +x ai/*.sh  

---

### 4. Install Dependencies
sudo apt update  
sudo apt install netcat-openbsd -y  

---

## ▶️ How to Run
./forensicollect.sh  

---

## 🧪 Demo / Testing Scenario (Recommended)

Simulate suspicious activity:

sudo useradd demo_user  
nc -l -p 4444 &  

Run the tool:
./forensicollect.sh  

---

## 📊 Viewing Results
cd ../output  
cd $(ls -dt case_* | head -1)  

View AI report:
cat report/ai_summary.txt  

View logs:
tail -n 40 collection_log.txt  

---

## 🧠 Example Findings
The tool can detect:
- Suspicious port 4444 (netcat listener)
- Normal vs abnormal services
- Authentication activity
- Recent system changes

---

## 📁 Repository Structure
/src  
 ├── forensicollect.sh  
 ├── setup.sh  
 ├── modules/  
 ├── ai/  

/docs  
 ├── AI_SETUP_GUIDE.md  
 ├── ARCHITECTURE.md  
 ├── TEST_PLAN.md  
 ├── final_report.pdf  

---

## ⚠️ Security Note
- .env is NOT stored in GitHub  
- API keys must remain local  
- .env.example is provided for setup  

---

## 📽️ Demo Video
(Add your video link here)

---

## 📄 Final Report
docs/final_report.pdf  

---

## 📌 Conclusion
ForensiCollect demonstrates how automation and AI can enhance digital forensics by:
- Reducing investigation time  
- Improving clarity of findings  
- Providing structured, repeatable analysis  
