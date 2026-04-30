# Architecture

ForensiCollect is organized into:
- `forensicollect.sh` as the main runner
- `src/modules/` for forensic collection modules
- `src/ai/` for optional AI explanation
- `src/output/` for generated case output (not stored in GitHub)

Each run creates a timestamped case directory containing:
- raw evidence
- logs
- hash manifest
- summaries
- structured reports
