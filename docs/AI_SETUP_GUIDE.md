# AI Configuration Guide

## Overview
ForensiCollect now integrates with OpenAI's API to provide intelligent forensic analysis. This guide explains how to set up and use the AI features securely.

---

## Security Architecture

### Why We Use Environment Variables
- **Never hardcode secrets** in scripts or git repositories
- Credentials are loaded at runtime from `.env` file
- `.env` is in `.gitignore` and never committed
- Each developer/deployment can have different credentials

### Directory Structure
```
project/
├── .env                 # Local credentials (NOT in git) ⚠️
├── .env.example         # Template showing what's needed (IN git) ✓
├── .gitignore          # Prevents .env from being committed
├── forensicollect.sh   # Main script (loads .env)
└── ai/
    └── ai_explainer.sh # AI analysis script
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
# Copy the example file
cp .env.example .env

# Edit .env with your API key
nano .env  # or use your preferred editor
```

### 3. Update `.env` with Your Key

```bash
API_KEY=sk-your-actual-api-key-here
AI_MODEL=-
```

### 4. Verify `.env` is Ignored

```bash
cat .gitignore | grep "\.env"
# Should show: .env
```

---

## Configuration Options

### `.env` Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `API_KEY` | (required) | Your OpenAI API key |
| `AI_MODEL` | (required) | Model to use |

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

### "OPENAI_API_KEY not set"
- Ensure `.env` file exists in the project root
- Verify the file contains `AI_API_KEY=sk-...`
- Check file permissions: `ls -la .env`

### API Errors
- Verify your API key is valid at http://sushi.it.ilstu.edu:8080/
- Ensure internet connectivity

### No AI Analysis in Output
- Check `report/ai_summary.txt` for error messages
- Verify API key is correct

---

## Safety Checklist

- ✅ `.env` is in `.gitignore`
- ✅ Never commit `.env` to git
- ✅ `.env.example` shows template (safe to commit)
- ✅ API key loaded at runtime, not in source
- ✅ No logging of actual API keys
- ✅ Each environment has own credentials

---

## Rotating/Revoking Credentials

If you suspect your API key is compromised:

1. Go to http://sushi.it.ilstu.edu:8080/
2. Delete the compromised key
3. Create a new key
4. Update `.env` with the new key
5. Delete/regenerate in any other places it might be used

---

## Questions?

See `.env.example` for all available options, or check the main script and AI script for implementation details.
