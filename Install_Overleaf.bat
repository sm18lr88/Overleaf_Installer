@echo off
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

:: Color codes for better visibility
set "infoColor=0A"  :: Green for informational messages
set "errorColor=0C" :: Red for error messages

:: Initial setup and welcome
color %infoColor%
echo Welcome to the Overleaf installation script!

:: Define functions to check system requirements and setup Overleaf
call :CheckDiskSpace
call :SetupRepository
call :InstallAndSetupWSL
call :InstallAndSetupDocker
call :EnsureDockerRunning
call :ConfigureOverleaf
call :FinalInstructions
ENDLOCAL
GOTO :EOF

:: Function to check disk space on all partitions
:CheckDiskSpace
echo Checking available disk space on all partitions...
set "adequateSpace=false"
for /f "tokens=1,3" %%i in ('wmic logicaldisk get size^,freespace^,name') do (
    set /a size=%%j / 1024 / 1024 / 1024
    if !size! gtr 2 (
        echo %%i has !size! GB free.
        set "adequateSpace=true"
    )
)
if not "%adequateSpace%"=="true" (
    color %errorColor%
    echo Not enough disk space available on any drive. At least 2.5 GB is required.
    exit /b
)
GOTO :EOF

:: Function to setup repository
:SetupRepository
echo Do you need to download the Overleaf repository or will you use an existing directory?
echo [1] Download Overleaf
echo [2] Use existing directory
set /p repoChoice="Enter your choice (1 or 2): "
if "%repoChoice%"=="1" (
    echo Please enter the full path where you want to install Overleaf:
    set /p repoPath="Enter the path (e.g., C:\Users\YourName\Overleaf): "
    if not exist "%repoPath%" (
        echo Creating directory...
        mkdir "%repoPath%"
    ) else (
        echo Directory already exists. Using existing directory...
    )
    cd /d "%repoPath%"
    echo Downloading and preparing Overleaf repository...
    start "Downloading Overleaf" powershell -command "Invoke-WebRequest -Uri https://github.com/overleaf/overleaf/archive/refs/heads/master.zip -OutFile overleaf.zip; Expand-Archive -Path overleaf.zip -DestinationPath .; Remove-Item overleaf.zip"
) else (
    echo Enter the path to your existing Overleaf directory:
    set /p repoPath="Enter the path: "
    if not exist "%repoPath%" (
        color %errorColor%
        echo The specified path does not exist. Please check the path and try again.
        exit /b
    )
    cd /d "%repoPath%"
    echo Using existing directory...
)
GOTO :EOF

:: Function to install and set up WSL
:InstallAndSetupWSL
echo Checking for Windows Subsystem for Linux (WSL)...
wsl --list --quiet >nul 2>&1
if errorlevel 1 (
    color %infoColor%
    echo WSL is not installed or no Linux distributions are detected.
    set /p installWSL="Would you like to install WSL and a Linux distribution now? (Y/N): "
    if /i "%installWSL%"=="Y" (
        start "Installing WSL" dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        wsl --install
        echo WSL installation initiated. Please restart your computer to complete the installation and rerun this script.
        exit /b
    ) else (
        color %errorColor%
        echo Please install WSL and a Linux distribution to continue.
        exit /b
    )
)
GOTO :EOF

:: Function to check and install Docker
:InstallAndSetupDocker
echo Checking if Docker is installed...
where docker >nul 2>&1
if errorlevel 1 (
    color %infoColor%
    echo Docker is not installed.
    set /p installDocker="Would you like to install Docker now? (Y/N): "
    if /i "%installDocker%"=="Y" (
        start "Installing Docker" powershell -command "Invoke-WebRequest -Uri https://download.docker.com/win/stable/Docker%20Desktop%20Installer.exe -OutFile DockerInstaller.exe; Start-Process -FilePath DockerInstaller.exe -Args 'install --quiet' -Wait; Remove-Item DockerInstaller.exe"
        echo Docker installation completed.
    ) else (
        color %errorColor%
        echo Please install Docker to continue.
        exit /b
    )
)
GOTO :EOF

:: Function to ensure Docker is running
:EnsureDockerRunning
echo Verifying Docker is running...
docker info >nul 2>&1
if errorlevel 1 (
    color %errorColor%
    echo Docker is not running. Attempting to start Docker...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    :: Wait for Docker to start and become ready
    set /a "count=0"
    :waitForDocker
    timeout /t 5 /nobreak >nul
    docker info >nul 2>&1
    if errorlevel 1 (
        set /a "count+=1"
        if !count! lss 24 (  :: Wait a few mins for Docker to start
            echo Waiting for Docker to start...
            goto waitForDocker
        )
        color %errorColor%
        echo Failed to start Docker. Please start Docker manually and rerun this script.
        exit /b
    )
)
color %infoColor%
echo Docker is running.
GOTO :EOF

:: Function to configure Overleaf
:ConfigureOverleaf
set /p dataPath="Enter the path for persistent data (e.g., E:\OverleafData): "
if not exist "%dataPath%" (
    echo The specified path does not exist. Creating it...
    mkdir "%dataPath%"
)
set /p port="Enter the desired port number [default: 8080]: "
if "%port%"=="" set port=8080

:: Check if the port is available
netstat -an | findstr ":%port% " >nul
if not errorlevel 1 (
    color %errorColor%
    echo Port %port% is already in use. Please choose a different port.
    pause
    exit /b
)

:: Choose TeX Live Scheme
echo Please choose a TeX Live scheme to install:
echo [1] Medium Scheme - Approx. 2 GB, covers essential and widely used packages.
echo [2] Full Scheme - Approx. 6 GB, includes virtually all available packages. Best choice for novices, as installing packages is a bit difficult.
set /p schemeChoice="Enter your choice (1 or 2): "
if "%schemeChoice%"=="2" (
    echo You have chosen the Full Scheme. This will take more disk space and time to install.
    set scheme=scheme-full
) else (
    echo You have chosen the Medium Scheme. This is sufficient for most users.
    set scheme=scheme-medium
)

:: Modify docker-compose.yml
echo Configuring docker-compose.yml...
powershell -command "(Get-Content docker-compose.yml) -replace 'ports:.*', 'ports: - '%port%':80' -replace 'volumes:.*', 'volumes: - '%dataPath%:/var/lib/overleaf' | Set-Content docker-compose.yml"

:: Start Docker containers
echo Starting Docker containers...
start "Starting Containers" docker-compose up -d
echo Setting up MongoDB replica set...
start "Configuring MongoDB" docker exec -it mongo mongo --eval "rs.initiate()"
timeout /t 10
docker exec -it mongo mongo --eval "rs.status()"

:: Install TeX Live packages
echo Installing TeX Live packages...
start "Installing TeX Live" docker exec -it sharelatex /bin/bash -c "tlmgr install %scheme% && tlmgr update --all"

:: Create admin user and capture the activation link
set /p adminEmail="Enter admin email (default: joe@example.com): "
if "%adminEmail%"=="" set adminEmail=joe@example.com
for /f "tokens=*" %%i in ('docker exec -it sharelatex /bin/bash -c "cd /overleaf/services/web && node modules/server-ce-scripts/scripts/create-user --admin --email=%adminEmail%"') do (
    set "adminOutput=%%i"
    echo !adminOutput! | findstr /C:"Please visit the following URL" > nul
    if not errorlevel 1 set "adminLink=!adminOutput!"
)

:: Create or modify Start_Overleaf.bat
echo Creating Start_Overleaf.bat in the Overleaf root directory...
(
    echo @echo off
    echo REM Check if Docker is running
    echo docker version --format {{.Server.Version}} ^>nul 2^>^&1
    echo IF NOT "%%ERRORLEVEL%%" == "0" (
    echo    echo Docker is not running. Please start Docker and try again.
    echo    exit /b
    echo )
    echo REM Check if Overleaf container is running
    echo docker ps ^| findstr "sharelatex" ^>nul 2^>^&1
    echo IF NOT "%%ERRORLEVEL%%" == "0" (
    echo    echo Starting Overleaf container...
    echo    docker-compose -f "%repoPath%\docker-compose.yml" up -d
    echo )
    echo REM Open Overleaf in the browser
    echo start http://localhost:%port%
    echo echo Overleaf is now running on http://localhost:%port%
    echo pause
) > "%repoPath%\Start_Overleaf.bat"

:: Final Instructions
:FinalInstructions
color %infoColor%
echo Installation complete! 
echo Your username is %adminEmail%
echo Click on this link to set the password: %adminLink%
echo You can then open your browser and go to http://localhost:%port% to start using Overleaf.
echo You can also click on Start_Overleaf.bat to start the program anytime.
pause

GOTO :EOF