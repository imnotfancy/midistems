# Create and activate virtual environment
python -m venv venv
.\venv\Scripts\Activate.ps1

# Upgrade pip
python -m pip install --upgrade pip

# Install required packages
pip install -r python/requirements.txt

Write-Host "Virtual environment setup complete. Please run 'flutter clean; flutter pub get; flutter run' to rebuild the app."