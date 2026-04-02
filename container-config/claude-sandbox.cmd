@echo off
if "%~1"=="" (
    set "PROJECT_PATH=%CD%"
) else (
    set "PROJECT_PATH=%~1"
)
set "CLAUDE_HOST_CONFIG=%USERPROFILE%\.claude"
set "CONTAINER_CONFIG=%CLAUDE_HOST_CONFIG%\container-config"

for %%I in ("%PROJECT_PATH%") do set "PROJECT_NAME=%%~nI"

REM --- Auto-setup if needed ---

set "NEEDS_SETUP=0"

docker image inspect claude-sandbox > nul 2>&1
if errorlevel 1 set "NEEDS_SETUP=1"

if not exist "%PROJECT_PATH%\.claude-data" set "NEEDS_SETUP=1"

if "%NEEDS_SETUP%"=="1" (
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

REM --- Launch container ---

set "EXTRA_ENV="
if exist "%PROJECT_PATH%\deploy_key" (
    set "EXTRA_ENV=-e GIT_SSH_COMMAND=ssh -i /project/deploy_key -o StrictHostKeyChecking=no"
)

docker run --rm -it ^
  --name "claude-%PROJECT_NAME%" ^
  --hostname "claude-sandbox" ^
  %EXTRA_ENV% ^
  -v "%PROJECT_PATH%:/project" ^
  -v "%PROJECT_PATH%\.claude-data:/home/claude/.claude" ^
  -v "%CLAUDE_HOST_CONFIG%\.credentials.json:/home/claude/.claude/.credentials.json:ro" ^
  -v "%CONTAINER_CONFIG%\CLAUDE.md:/home/claude/.claude/CLAUDE.md:ro" ^
  -v "%CONTAINER_CONFIG%\settings.json:/home/claude/.claude/settings.json:ro" ^
  -v "%CLAUDE_HOST_CONFIG%\statusline.pl:/home/claude/.claude/statusline.pl:ro" ^
  -v "%CLAUDE_HOST_CONFIG%\skills\refresh:/home/claude/.claude/skills/refresh:ro" ^
  -v "claude-npm-cache:/home/claude/.npm" ^
  -v "claude-pip-cache:/home/claude/.cache/pip" ^
  claude-sandbox
