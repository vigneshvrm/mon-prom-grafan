@echo off
REM Start the Node Exporter Installation Web UI (Windows)

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python is not installed
    pause
    exit /b 1
)

REM Check if required packages are installed
python -c "import flask" >nul 2>&1
if errorlevel 1 (
    echo Installing required Python packages...
    pip install -r requirements.txt
)

REM Get the directory where this script is located
cd /d "%~dp0"

REM Create necessary directories
if not exist certs mkdir certs
if not exist web-ui\uploads mkdir web-ui\uploads
if not exist tmp mkdir tmp

REM Start the Flask application
echo Starting Node Exporter Installation Web UI...
echo Access the application at http://localhost:5000
echo Press Ctrl+C to stop
echo.

cd web-ui
python app.py

