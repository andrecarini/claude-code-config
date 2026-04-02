# Global Instructions

## Response Style
- Every message must start with 🤖

## ✅ YOU ARE INSIDE A SANDBOXED CONTAINER — FULL AUTONOMY

You are running inside an isolated Docker container. The project folder is at `/project`.
You have full autonomy. No permission prompts. Go fast.

**You CAN and SHOULD install and run dev tooling directly:**
- ✅ `npm install`, `npm ci`, `npx`
- ✅ `dart`, `flutter`, `pub get`
- ✅ `pip install`, `python`, `cargo`, `go build`
- ✅ `firebase`, `gcloud`, `terraform`
- ✅ ANY build tool, linter, formatter, or compiler
- ✅ `apt-get install` for additional system packages

There is no host machine to protect — this container IS the sandbox.
Worst case, the container gets trashed. Project files are git-recoverable.

## ⚠️ SUPPLY CHAIN SECURITY (still applies inside the container)

Even inside a container, supply chain attacks can exfiltrate project source code and credentials. Minimize the attack surface:

- **npm `ignore-scripts=true` is set globally** in this container. Do NOT override it with `--ignore-scripts=false` unless explicitly told to by the user. If a package requires postinstall scripts to function, inform the user and let them decide.
- **Never pull packages published < 7 days ago** — applies to fresh installs from a lockfile AND when upgrading/adding dependencies to a lockfile. If you notice a dependency was published very recently, flag it.
- **Prefer well-established packages** with many downloads, known maintainers, and active maintenance over obscure alternatives.
- Same caution applies to `pip install`, `cargo install`, `pub get`, etc.

## Git

- Local git operations (add, commit, diff, log, status, branch, etc.) work normally
- For push/pull to private repos: if a deploy key exists in the project folder, use:
  `GIT_SSH_COMMAND="ssh -i /project/deploy_key -o StrictHostKeyChecking=no" git push`
- If `$GIT_SSH_COMMAND` is already set in the environment, git push/pull should just work

## Persistence

- File changes in `/project` persist (bind-mounted to host)
- Your memories, conversation history, and plans persist in `/project/.claude-data/`
- Auth tokens are read-only from the host — do not try to modify them
- Installed packages (apt, npm global, pip global) do NOT persist between sessions
  - npm/pip caches DO persist (Docker volumes), so reinstalls are fast
