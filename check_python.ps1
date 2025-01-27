# Check Python version
$pythonVersion = python --version
Write-Host "Current Python version: $pythonVersion"

# Check if Python 3.11 is installed
$python311Path = "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python311\python.exe"
if (Test-Path $python311Path) {
    Write-Host "Python 3.11 is installed at: $python311Path"
} else {
    Write-Host "Python 3.11 is not installed. Please install it from python.org"
    Write-Host "Download URL: https://www.python.org/downloads/release/python-3116/"
}