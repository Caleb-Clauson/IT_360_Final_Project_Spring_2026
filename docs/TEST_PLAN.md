# Test Plan

We will test the tool on a Linux VM by validating:
- case folder creation
- raw artifact generation
- logging
- hash manifest generation
- archive creation
- detection of sample indicators such as:
  - failed logins
  - unusual listening ports
  - recent changes in /etc
