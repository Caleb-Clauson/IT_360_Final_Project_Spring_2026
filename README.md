# IT_360_Final_Project_Spring_2026
Our final project for IT 360 will be to create a forensic collector, specifically a Linux DFIR Triage and mini timeline report tool.

## Team Members
- Caleb Clauson
- Eric Anderson

## Team Name
 - Securists

## Project Idea
Our project will be: ForensiCollect - Linux DFIR Triage & Mini Timeline Report Tool
1. Linux focused
2. User Focused
3. Shell Scripting (Bash)
4. Structured output (JSON/CSV)

## What the Tool will do
1. Evidence collection
   - System info
   - User activity
   - Process/service snapshot
   - Network snapshot
   - Recent file changes in key directories
2. Integrity and documentation
   - SHA-256 hash manifest
   - Collection log (audit trail of actions/commands)
3. Artifical Intelligence Explainer
   - A Large Language Model analyzes and converts logs into readable summaries for the report.
4. Output packaging
   - Compressed case archive for storage/transfer

## Tech Stack
1. Bash for collection/orchestration
2. Uses standard Linux utilities

## How we will demo it
1. Run tool on a Linux VM
2. Walk through the case folder outputs (raw artifacts, hash manifest, report)
3. Show a sample of "findings" section (failed login spikes, unusual listening ports, recent changes in /etc or new users) that flags at least a few indicators
   
## Project Timeline
The project timeline is as follows:
- February 5, 2026: Project Proposal Submission.
- Week of March 16: Completion of First Script (Core collection features working).
- Week of April 13: Testing & Validation (Verify hashing and evidence integrity).
- Week of May 11: Documentation Phase (Drafting the report and presentation).
- May 30, 2026: Final Project Submission.
