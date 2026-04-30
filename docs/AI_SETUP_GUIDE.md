# AI Configuration Guide

## Overview
ForensiCollect now integrates with AI API keys to provide intelligent forensic analysis. This guide explains how to set up and use the AI features securely.

---

## Security Architecture

### Why We Use Environment Variables
- **Never hardcode secrets** in scripts or git repositories
- Credentials are loaded at runtime from `.env` file
- Each developer/deployment can have different credentials

### Directory Structure
```
IT_360_Final_Project_Spring_2026/
│
├── docs/
│   ├── AI_SETUP_GUIDE.md
│   ├── ARCHITECTURE.md
│   ├── TEST_PLAN.md
│   └── IT 360 Final Project Report.pdf
│
├── src/
│   ├── ai/
│   │   └── ai_explainer.sh
│   │
│   ├── modules/
│   │   ├── network.sh
│   │   ├── process_service.sh
│   │   ├── recent_changes.sh
│   │   ├── system_info.sh
│   │   └── user_activity.sh
│   │
│   ├── forensicollect.sh
│   └── setup.sh
│
├── .env.example
├── .gitignore
├── LICENSE
├── ProjectRequirements.md
└── README.md
```

---

## Setup Instructions

### 1. Get an API Key

1. Visit [Sushi Server](http://sushi.it.ilstu.edu:8080/)
2. Sign in or create an account
3. Click "Create new secret key"
4. Copy the key

### 2. Create Your Local `.env` File

```bash
# Edit .env with your API key
nano .env  # or use your preferred editor
```

### 3. Update `.env` with Your Key

```bash
AI_API_KEY=sk-your-actual-api-key-here
AI_MODEL=-
```
---

## Configuration Options

### `.env` Variables

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `AI_API_KEY` | (empty) | Yes* | Your API key from Sushi Server |
| `AI_MODEL` | `llama3.2-vision:latest` | Yes* | Model to use for analysis |

*Required only if AI analysis is desired. Tool works without these (raw data only).

### Available Models
Visit [Sushi Server](http://sushi.it.ilstu.edu:8080/) to see available models. Common options:
- `llama3.2-vision:latest` - Recommended model

Check your account to see which models you have access to.

---

## How It Works

### 1. Main Script Loads Credentials
```bash
# forensicollect.sh does this automatically:
source .env
export AI_API_KEY
```

### 2. AI Script Validates Credentials
```bash
# ai_explainer.sh checks:
if [[ -z "${AI_API_KEY:-}" ]]; then
    echo "ERROR: API key not set"
    exit 1
fi
```

### 3. API Calls Use Variables
```bash
# Never exposes the actual key in logs/output
curl -H "Authorization: Bearer $AI_API_KEY" ...
```

---

## Usage

Run the forensic collection tool normally:

```bash
./forensicollect.sh
```

The AI analysis will run automatically and analyze:
- Authentication logs for suspicious patterns
- Listening ports for unusual activity
- Running processes for anomalies

Output is saved to: `output/case_YYYY-MM-DD_HHMMSS/report/ai_summary.txt`

---

## Troubleshooting

### "AI_API_KEY not set" or "AI API Error"
**Symptoms:** Tool runs but skips AI analysis, or shows error messages

**Solutions:**
1. Verify `.env` file exists in `src/` directory:
   ```bash
   ls -la .env
   ```

2. Check file contains correct key:
   ```bash
   cat .env | grep AI_API_KEY
   ```

3. Verify format is correct (no extra spaces):
   ```bash
   # Correct:
   AI_API_KEY="sk-abc123xyz789"
   
   # Wrong:
   AI_API_KEY = sk-abc123xyz789  # Extra spaces
   ```

4. Test API key is valid by visiting http://sushi.it.ilstu.edu:8080/

### "Connection refused" or "Network error"
**Symptoms:** Tool fails when trying to reach API

**Solutions:**
- Check internet connectivity:
  ```bash
  curl http://sushi.it.ilstu.edu:8080/
  ```
- Verify API endpoint is accessible (may be down for maintenance)
- If behind a proxy, configure curl accordingly
- Check firewall rules if running in restricted environment

### "Invalid API key" or "Authentication failed"
**Symptoms:** Error mentions authentication or 401 status

**Solutions:**
1. Verify key is not expired (keys may have TTL)
2. Generate a new key at http://sushi.it.ilstu.edu:8080/
3. Update `.env` with the new key
4. Try again: `./forensicollect.sh`

### "Quota exceeded" or "Rate limit exceeded"
**Symptoms:** API returns 429 status or quota error

### No AI Analysis in Output
**Symptoms:** Tool completes but `report/ai_summary.txt` is empty or missing

**Solutions:**
1. Check if AI analysis was skipped:
   ```bash
   tail -20 collection_log.txt | grep -i "ai\|analysis"
   ```

2. Look for error details:
   ```bash
   cat warnings.txt
   ```

3. Verify API key is set:
   ```bash
   echo $AI_API_KEY
   ```

4. Run with verbose output:
   ```bash
   export AI_API_KEY=your_key
   bash -x ./forensicollect.sh 2>&1 | grep -i "ai\|curl"
   ```

---

## Error Handling During Collection

### What Happens if AI Fails?
- **Raw data:** Still successfully collected ✅
- **AI summary:** Skipped or shows error ❌
- **Exit code:** Still `0` (tool completes)
- **Warnings:** Error logged in `warnings.txt`

**Recommendation:** Check `warnings.txt` and retry if needed:
```bash
cd output/case_*/
cat warnings.txt
# Fix issue if possible, then:
AI_API_KEY=your_key /path/to/ai_explainer.sh < raw/user_activity.txt
```

### Fallback Behavior
- If AI fails: Raw data is preserved
- If network fails: Collection continues (AI optional)
- If API key invalid: Raw data still collected
- If rate limited: Raw data still collected

---

## Security Best Practices

### When Setting Up
- ✅ **Never share your API key** (it grants access to your account)
- ✅ **Never hardcode keys** in scripts, config files, or environment setup
- ✅ **Use `.env` file** (which is git-ignored automatically)
  ```
- ✅ **Use strong API keys** (use the generated keys, don't create predictable ones)

### When Using
- ✅ **Don't copy `.env` to other machines** (each system should have its own key)
- ✅ **Don't print API key** in logs or output
- ✅ **Use API key only from trusted networks** (consider VPN if untrusted)
- ✅ **Check `.gitignore`** includes `.env`:
  ```bash
  cat .gitignore | grep "\.env"
  ```

### Environment Variable Safety
- ✅ API key loaded at startup, then cleared from shell history
- ✅ Not visible in `ps aux` or `echo $AI_API_KEY` (if not exported)
- ✅ Not written to system logs
- ✅ Only sent over HTTPS to API server

---

## Safety Checklist

- ✅ Never commit the local updated `.env` to git
- ✅ `.env.example` shows template (safe to commit)
- ✅ API key loaded at runtime, not in source code
- ✅ No logging of actual API keys in output
- ✅ Each environment has own credentials

---

## Rotating/Revoking Credentials

### Routine Rotation (Recommended Quarterly)
1. Generate new API key at http://sushi.it.ilstu.edu:8080/
2. Update `.env` with new key: `AI_API_KEY=sk-new-key`
3. Test with `./forensicollect.sh` to verify it works
4. Delete old key

### Emergency Revocation (Suspected Compromise)
1. **Immediately** delete the compromised key at http://sushi.it.ilstu.edu:8080/
2. Generate new key
3. Update `.env` with new key
4. Consider running fresh forensic collection if data was collected during compromise

---

## Questions & Support

### For API/Key Issues
- Visit http://sushi.it.ilstu.edu:8080/ (API dashboard)
- Check your account settings

### For Tool Integration
- See main `README.md` for overall usage
- Check `ARCHITECTURE.md` for module details
- Review `forensicollect.sh` and `ai/ai_explainer.sh` for implementation

### For Security Concerns
- Never share this guide with API keys included
- Report key compromises immediately
- Document any unusual API activity

````
