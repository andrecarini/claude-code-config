@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    set "PROJECT_PATH=%CD%"
) else (
    set "PROJECT_PATH=%~f1"
)
set "CLAUDE_HOST_CONFIG=%USERPROFILE%\.claude"
set "CONTAINER_CONFIG=%CLAUDE_HOST_CONFIG%\claude-code-config\container-config"
set "LAUNCHER_DIR=%PROJECT_PATH%\.claude-data\.launcher"

for %%I in ("%PROJECT_PATH%") do set "PROJECT_NAME=%%~nI"

REM --- Auto-setup if needed ---

if not exist "%PROJECT_PATH%\.claude-data" (
    echo.
    echo ======================================================
    echo   First-time setup needed for this project.
    echo   Launching Claude to configure interactively...
    echo   Run /sandbox when Claude starts.
    echo ======================================================
    echo.
    pushd "%PROJECT_PATH%"
    claude
    popd
    if not exist "%PROJECT_PATH%\.claude-data" (
        echo Setup was not completed. Aborting.
        exit /b 1
    )
)

REM --- Ensure launcher metadata dir ---
if not exist "%LAUNCHER_DIR%" mkdir "%LAUNCHER_DIR%"

REM --- Get host Claude Code version ---
for /f "tokens=1" %%V in ('claude --version 2^>nul') do set "HOST_VERSION=%%V"

REM --- Build image if needed ---
docker image inspect claude-sandbox:latest > nul 2>&1
if errorlevel 1 (
    echo Building claude-sandbox image with Claude Code v%HOST_VERSION%...
    docker build --build-arg "CLAUDE_VERSION=%HOST_VERSION%" -t "claude-sandbox:%HOST_VERSION%" -t "claude-sandbox:latest" "%CONTAINER_CONFIG%"
)

REM --- Get or generate container name ---
if exist "%LAUNCHER_DIR%\container-name" (
    set /p CONTAINER_NAME=<"%LAUNCHER_DIR%\container-name"
) else (
    REM Use a hash of the project path for uniqueness
    for /f %%H in ('powershell -Command "[System.BitConverter]::ToString((New-Object System.Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([System.Text.Encoding]::UTF8.GetBytes('%PROJECT_PATH%'))).Replace('-','').Substring(0,8).ToLower()"') do set "PATH_HASH=%%H"
    set "CONTAINER_NAME=claude-%PROJECT_NAME%-!PATH_HASH!"
    echo !CONTAINER_NAME!>"%LAUNCHER_DIR%\container-name"
)

REM --- Staleness check ---
set "STALE=0"
set "STALE_MSG="

if exist "%LAUNCHER_DIR%\claude-version" (
    set /p CONTAINER_VERSION=<"%LAUNCHER_DIR%\claude-version"
    if not "!CONTAINER_VERSION!"=="%HOST_VERSION%" (
        set "STALE=1"
        set "STALE_MSG=!STALE_MSG!  - Claude Code version mismatch: container has v!CONTAINER_VERSION!, host has v%HOST_VERSION%"
        echo.
    )
)

if exist "%LAUNCHER_DIR%\container-created" (
    set /p CREATED=<"%LAUNCHER_DIR%\container-created"
    for /f %%D in ('powershell -Command "([datetime]::UtcNow - [datetime]::Parse('!CREATED!')).Days"') do set "AGE_DAYS=%%D"
    if !AGE_DAYS! GTR 7 (
        set "STALE=1"
        set "STALE_MSG=!STALE_MSG!  - Container is !AGE_DAYS! days old"
        echo.
    )
)

if "!STALE!"=="1" (
    echo.
    echo WARNING: Container may be stale:
    echo !STALE_MSG!
    echo.
    echo Options:
    echo   [r] Rebuild - fresh container with Claude Code v%HOST_VERSION%
    echo   [c] Continue as-is
    echo.
    set /p CHOICE="Choice [r/c]: "
    if /i "!CHOICE!"=="r" (
        docker rm -f "!CONTAINER_NAME!" > nul 2>&1
        echo Building claude-sandbox image with Claude Code v%HOST_VERSION%...
        docker build --build-arg "CLAUDE_VERSION=%HOST_VERSION%" -t "claude-sandbox:%HOST_VERSION%" -t "claude-sandbox:latest" "%CONTAINER_CONFIG%"
        for /f %%H in ('powershell -Command "[System.BitConverter]::ToString((New-Object System.Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([System.Text.Encoding]::UTF8.GetBytes('%PROJECT_PATH%'))).Replace('-','').Substring(0,8).ToLower()"') do set "PATH_HASH=%%H"
        set "CONTAINER_NAME=claude-%PROJECT_NAME%-!PATH_HASH!"
        echo !CONTAINER_NAME!>"%LAUNCHER_DIR%\container-name"
    )
)

REM --- Build skill mounts (filter out host-only) ---
set "SKILL_MOUNTS="
for /d %%S in ("%CLAUDE_HOST_CONFIG%\claude-code-config\skills\*") do (
    findstr /c:"host-only: true" "%%S\SKILL.md" > nul 2>&1
    if errorlevel 1 (
        set "SKILL_MOUNTS=!SKILL_MOUNTS! -v "%%S:/home/claude/.claude/skills/%%~nxS:ro""
    )
)

REM --- Extra env for deploy key ---
set "EXTRA_ENV="
if exist "%PROJECT_PATH%\deploy_key" (
    set "EXTRA_ENV=-e GIT_SSH_COMMAND=ssh -i /project/deploy_key -o StrictHostKeyChecking=no"
)

REM --- PAT auth support ---
set "EXTRA_MOUNTS="
if exist "%PROJECT_PATH%\.claude-data\git-askpass.sh" (
    set "EXTRA_MOUNTS=-v "%PROJECT_PATH%\.claude-data\git-askpass.sh:/home/claude/.claude/git-askpass.sh:ro" -v "%PROJECT_PATH%\.claude-data\git-pat:/home/claude/.claude/git-pat:ro""
    set "EXTRA_ENV=!EXTRA_ENV! -e GIT_ASKPASS=/home/claude/.claude/git-askpass.sh"
)

REM --- Launch or reattach ---
docker inspect "!CONTAINER_NAME!" > nul 2>&1
if not errorlevel 1 (
    echo Reattaching to existing container: !CONTAINER_NAME!
    docker start -ai "!CONTAINER_NAME!"
) else (
    echo Creating new container: !CONTAINER_NAME!

    REM Save metadata
    echo %HOST_VERSION%>"%LAUNCHER_DIR%\claude-version"
    for /f %%T in ('powershell -Command "Get-Date -Format 'yyyy-MM-ddTHH:mm:ss' -AsUTC"') do echo %%T>"%LAUNCHER_DIR%\container-created"

    docker create -it ^
      --name "!CONTAINER_NAME!" ^
      --hostname "claude-sandbox" ^
      %EXTRA_ENV% ^
      -v "%PROJECT_PATH%:/project" ^
      -v "%PROJECT_PATH%\.claude-data:/home/claude/.claude" ^
      -v "%LAUNCHER_DIR%:/home/claude/.claude/.launcher:ro" ^
      -v "%CLAUDE_HOST_CONFIG%\.credentials.json:/home/claude/.claude/.credentials.json:ro" ^
      -v "%CONTAINER_CONFIG%\CLAUDE.md:/home/claude/.claude/CLAUDE.md:ro" ^
      -v "%CONTAINER_CONFIG%\settings.json:/home/claude/.claude/settings.json:ro" ^
      -v "%CLAUDE_HOST_CONFIG%\claude-code-config\scripts\statusline.pl:/home/claude/.claude/statusline.pl:ro" ^
      %SKILL_MOUNTS% ^
      %EXTRA_MOUNTS% ^
      claude-sandbox:latest

    docker start -ai "!CONTAINER_NAME!"
)

endlocal
