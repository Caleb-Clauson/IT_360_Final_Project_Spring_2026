# PowerShell Script
# Get current date and time
$currentDate = Get-Date
Write-Host "Current Date and Time: $currentDate"

# List files in current directory
$files = Get-ChildItem
Write-Host "Files in current directory:"
$files | ForEach-Object { Write-Host $_.Name }

# Create a simple variable and display it
$message = "Hello from PowerShell!"
Write-Host $message
