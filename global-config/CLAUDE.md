# Global Instructions

## Response Style
- Every message must start with 🤖

## ⚠️⚠️⚠️ NEVER RUN DEV TOOLING ON THE HOST ⚠️⚠️⚠️

🚨🚨🚨 **CRITICAL SECURITY RULE** 🚨🚨🚨

**NEVER install or run development tooling, SDKs, package managers, or dependencies directly on the host machine.**

This includes but is not limited to:
- ❌ `npm install`, `npm ci`, `npx`
- ❌ `dart`, `flutter`, `pub get`
- ❌ `pip install`, `python`, `cargo`, `go build`
- ❌ `firebase`, `gcloud`, `terraform`
- ❌ ANY build tool, linter, formatter, or compiler

⚠️ **Supply chain attacks in development dependencies are rampant.** Malicious packages can execute arbitrary code during install (npm postinstall hooks, pip setup.py, etc.) and compromise the entire host machine — steal credentials, SSH keys, browser sessions, cryptocurrency wallets, and more.

⚠️ If the user asks you to run a dev tool directly, **warn them about the risks** (supply chain attacks, arbitrary code execution during install) and **ask for explicit confirmation** before proceeding. Do not silently comply, but do not hard-block either — the user has the final say.

🐳 If a project needs dev tooling, **offer to run `/sandbox`** to set up an isolated Docker container for the project. Do not run it automatically — let the user decide.
