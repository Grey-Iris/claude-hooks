#!/usr/bin/env python3
"""
Claude Code hook to check package versions on install commands.
Detects major version differences and auto-spawns research.

Supports: npm, yarn, pnpm, bun, pip
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

# Cache file for research results (persists across hook invocations)
CACHE_FILE = Path.home() / ".cache" / "claude-hooks" / "version-research.json"

# Package manager command patterns
PACKAGE_MANAGERS = {
    "npm": r"\bnpm\s+(install|i|add)\b",
    "yarn": r"\byarn\s+add\b",
    "pnpm": r"\bpnpm\s+(add|install)\b",
    "bun": r"\bbun\s+(add|install)\b",
    "pip": r"\bpip\s+install\b",
}


def log(msg: str, icon: str = ""):
    """Print progress to stderr (visible to user, not captured as output)."""
    prefix = f"{icon} " if icon else ""
    print(f"{prefix}{msg}", file=sys.stderr)


def load_cache() -> dict:
    """Load research cache from disk."""
    try:
        if CACHE_FILE.exists():
            with open(CACHE_FILE) as f:
                return json.load(f)
    except Exception:
        pass
    return {}


def save_cache(cache: dict):
    """Save research cache to disk."""
    try:
        CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(CACHE_FILE, "w") as f:
            json.dump(cache, f, indent=2)
    except Exception:
        pass


def cache_key(pkg: str, old_major: int, new_major: int) -> str:
    """Generate cache key for a version diff."""
    return f"{pkg}:{old_major}->{new_major}"


def get_npm_latest(package_name: str) -> str | None:
    """Fetch latest version from npm registry."""
    try:
        url = f"https://registry.npmjs.org/{package_name}"
        with urllib.request.urlopen(url, timeout=5) as response:
            data = json.loads(response.read().decode())
            return data.get("dist-tags", {}).get("latest")
    except Exception:
        return None


def get_pypi_latest(package_name: str) -> str | None:
    """Fetch latest version from PyPI."""
    try:
        url = f"https://pypi.org/pypi/{package_name}/json"
        with urllib.request.urlopen(url, timeout=5) as response:
            data = json.loads(response.read().decode())
            return data.get("info", {}).get("version")
    except Exception:
        return None


def get_major_version(version_str: str) -> int | None:
    """Extract major version from version string."""
    if not version_str:
        return None
    # Handle semver constraints: ^14.0.0, ~14.0.0, >=14.0.0, 14.0.0
    match = re.search(r"(\d+)", version_str)
    return int(match.group(1)) if match else None


def parse_package_json(cwd: str) -> dict[str, str]:
    """Parse package.json for dependencies with versions."""
    packages = {}
    pkg_path = Path(cwd) / "package.json"

    if not pkg_path.exists():
        return packages

    try:
        with open(pkg_path) as f:
            data = json.load(f)

        for dep_type in ["dependencies", "devDependencies"]:
            deps = data.get(dep_type, {})
            for name, version in deps.items():
                # Skip workspace/file/git references
                if not version.startswith(("workspace:", "file:", "git:", "github:")):
                    packages[name] = version
    except Exception:
        pass

    return packages


def parse_requirements_txt(cwd: str) -> dict[str, str]:
    """Parse requirements.txt for packages with versions."""
    packages = {}
    req_path = Path(cwd) / "requirements.txt"

    if not req_path.exists():
        return packages

    try:
        with open(req_path) as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if not line or line.startswith("#"):
                    continue
                # Skip -r, -e, etc.
                if line.startswith("-"):
                    continue

                # Parse: package==1.0.0, package>=1.0.0, package~=1.0.0
                match = re.match(r"([a-zA-Z0-9_-]+)\s*([=<>~!]+)\s*([\d.]+)", line)
                if match:
                    packages[match.group(1)] = match.group(3)
    except Exception:
        pass

    return packages


def parse_command_packages(command: str, manager: str) -> list[str]:
    """Extract package names from install command."""
    # Remove the install command prefix (with optional trailing space)
    patterns = {
        "npm": r"^npm\s+(install|i|add)\s*",
        "yarn": r"^yarn\s+add\s*",
        "pnpm": r"^pnpm\s+(add|install)\s*",
        "bun": r"^bun\s+(add|install)\s*",
        "pip": r"^pip\s+install\s*",
    }

    cmd = re.sub(patterns.get(manager, ""), "", command)
    # Remove flags
    cmd = re.sub(r"\s+--?\w+(\s+\S+)?", " ", cmd)
    # Split and clean
    packages = []
    for pkg in cmd.split():
        if pkg and not pkg.startswith("-"):
            # Remove version specifier for lookup
            name = re.sub(r"[@=<>~!]+.*$", "", pkg)
            if name:
                packages.append(name)

    return packages


def check_version_diff(pkg: str, installed_version: str, registry: str) -> dict | None:
    """Check if major version differs from latest."""
    installed_major = get_major_version(installed_version)
    if installed_major is None:
        return None

    # Get latest version
    if registry == "npm":
        latest = get_npm_latest(pkg)
    else:
        latest = get_pypi_latest(pkg)

    if not latest:
        return None

    latest_major = get_major_version(latest)
    if latest_major is None:
        return None

    # Only flag if major version differs
    if installed_major != latest_major:
        return {
            "package": pkg,
            "installed_version": installed_version,
            "installed_major": installed_major,
            "latest_version": latest,
            "latest_major": latest_major,
        }

    return None


def spawn_research(pkg: str, old_major: int, new_major: int) -> str:
    """Spawn Claude to research breaking changes."""
    prompt = f"""Breaking changes: {pkg} v{old_major} → v{new_major}

You're providing context to an AI coding assistant. The codebase has v{old_major} pinned but v{new_major} is latest.

Return ONLY:
- 3-5 bullet points: breaking changes that affect code written today
- For API changes, show: `old way` → `new way`

Be terse. No migration guides, no installation steps, no sources, no headers.
This gets injected into context - every word costs attention."""

    try:
        result = subprocess.run(
            [
                "claude", "-p", prompt,
                "--output-format", "text",
                "--dangerously-skip-permissions",
            ],
            capture_output=True,
            text=True,
            timeout=300,
        )
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        return f"(Research timed out for {pkg})"
    except Exception as e:
        return f"(Research failed for {pkg}: {e})"


def filter_redundant_types(diffs: list[dict]) -> list[dict]:
    """Remove @types/* packages when base package is also in diffs."""
    base_packages = {d["package"] for d in diffs if not d["package"].startswith("@types/")}

    filtered = []
    for diff in diffs:
        pkg = diff["package"]
        # Skip @types/X if X is already in the list
        if pkg.startswith("@types/"):
            base_name = pkg.replace("@types/", "")
            if base_name in base_packages:
                log(f"Skipping {pkg} (redundant with {base_name})", "↩️")
                continue
        filtered.append(diff)

    return filtered


def main():
    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})

    # Only check Bash commands
    if tool_name != "Bash":
        sys.exit(0)

    command = tool_input.get("command", "")
    cwd = os.getcwd()

    # Extract directory from "cd X && ..." pattern
    cd_match = re.match(r'^cd\s+([^\s&]+)\s*&&\s*', command)
    if cd_match:
        cd_path = cd_match.group(1)
        # Handle absolute and relative paths
        if os.path.isabs(cd_path):
            cwd = cd_path
        else:
            cwd = os.path.join(cwd, cd_path)
        cwd = os.path.normpath(cwd)
        # Strip the cd prefix from command for further parsing
        command = command[cd_match.end():]

    # Detect package manager
    detected_manager = None
    for manager, pattern in PACKAGE_MANAGERS.items():
        if re.search(pattern, command):
            detected_manager = manager
            break

    if not detected_manager:
        sys.exit(0)

    log(f"Detected {detected_manager} install command", "📦")

    # Determine registry type
    registry = "npm" if detected_manager in ["npm", "yarn", "pnpm", "bun"] else "pypi"

    # Get packages to check
    packages_to_check = {}

    # Check for pip -r flag (read from requirements file)
    pip_requirements_file = None
    if detected_manager == "pip":
        req_match = re.search(r'-r\s+(\S+)', command)
        if req_match:
            pip_requirements_file = req_match.group(1)
            # Resolve relative to cwd
            if not os.path.isabs(pip_requirements_file):
                pip_requirements_file = os.path.join(cwd, pip_requirements_file)

    # First, check if command has explicit packages
    explicit_packages = [] if pip_requirements_file else parse_command_packages(command, detected_manager)

    if explicit_packages:
        log(f"Checking: {', '.join(explicit_packages)}", "🔍")
        # Get installed versions from package file
        if registry == "npm":
            installed = parse_package_json(cwd)
        else:
            installed = parse_requirements_txt(cwd)
        for pkg in explicit_packages:
            if pkg in installed:
                packages_to_check[pkg] = installed[pkg]
    else:
        if registry == "npm":
            log(f"Parsing package file in {cwd}", "📄")
            packages_to_check = parse_package_json(cwd)
        else:
            # For pip, use specified requirements file or look in cwd
            req_file = pip_requirements_file or os.path.join(cwd, "requirements.txt")
            log(f"Parsing {req_file}", "📄")
            packages_to_check = parse_requirements_txt(os.path.dirname(req_file))
            # Override the parse function to use the specific file
            if pip_requirements_file:
                packages_to_check = {}
                try:
                    with open(pip_requirements_file) as f:
                        for line in f:
                            line = line.strip()
                            if not line or line.startswith("#") or line.startswith("-"):
                                continue
                            match = re.match(r"([a-zA-Z0-9_-]+)\s*([=<>~!]+)\s*([\d.]+)", line)
                            if match:
                                packages_to_check[match.group(1)] = match.group(3)
                except Exception:
                    pass

    if not packages_to_check:
        log("No packages to check", "✓")
        sys.exit(0)

    log(f"Checking {len(packages_to_check)} packages for version diffs...", "🔍")

    # Check for major version differences
    diffs = []
    for pkg, version in packages_to_check.items():
        diff = check_version_diff(pkg, version, registry)
        if diff:
            diffs.append(diff)

    if not diffs:
        log("All packages up to date", "✅")
        sys.exit(0)

    # Filter out redundant @types/* packages
    diffs = filter_redundant_types(diffs)

    log(f"Found {len(diffs)} packages with major version diffs", "⚠️")

    # Load cache
    cache = load_cache()

    # Separate cached vs uncached diffs
    cached_results = []
    uncached_diffs = []

    for diff in diffs:
        key = cache_key(diff["package"], diff["installed_major"], diff["latest_major"])
        if key in cache:
            log(f"Cache hit: {diff['package']}", "⚡")
            cached_results.append({**diff, "research": cache[key]})
        else:
            uncached_diffs.append(diff)

    # Spawn research for uncached diffs in parallel
    research_results = list(cached_results)

    if uncached_diffs:
        # Build a compact list of what we're researching
        research_list = ", ".join(
            f"{d['package']} ({d['installed_major']}→{d['latest_major']})"
            for d in uncached_diffs
        )
        log(f"Researching: {research_list}", "⏳")

        def research_worker(diff):
            """Worker function for parallel research."""
            research = spawn_research(
                diff["package"],
                diff["installed_major"],
                diff["latest_major"],
            )
            return {**diff, "research": research}

        # Run all research in parallel (max 10 concurrent)
        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = {executor.submit(research_worker, diff): diff for diff in uncached_diffs}
            for future in as_completed(futures):
                try:
                    result = future.result()
                    research_results.append(result)
                    # Cache the result (but not failures)
                    if not result["research"].startswith("("):
                        key = cache_key(result["package"], result["installed_major"], result["latest_major"])
                        cache[key] = result["research"]
                        log(f"Completed: {result['package']}", "✅")
                    else:
                        log(f"Failed: {result['package']} (not cached)", "❌")
                except Exception as e:
                    diff = futures[future]
                    research_results.append({
                        **diff,
                        "research": f"(Research failed: {e})"
                    })

        # Save updated cache
        save_cache(cache)
        log("Research cached for future use", "💾")

    # Build output with summary table
    table_rows = []
    for r in research_results:
        table_rows.append(
            f"| {r['package']} | {r['installed_major']} | {r['latest_major']} | Breaking changes |"
        )

    summary_table = f"""| Package | Installed | Latest | Status |
|---------|-----------|--------|--------|
{chr(10).join(table_rows)}"""

    # Build detailed sections
    sections = []
    for r in research_results:
        sections.append(f"""
### {r['package']}: {r['installed_major']} → {r['latest_major']}

{r['research']}
""")

    context = f"""## Package Version Check

{summary_table}

---
{"".join(sections)}
"""

    # Build user-visible summary
    cached_count = len([r for r in research_results if r in cached_results])
    researched_count = len(research_results) - cached_count

    if researched_count > 0:
        summary = f"📦 Checked {len(packages_to_check)} packages → {len(research_results)} major version diffs (researched {researched_count}, cached {cached_count})"
    else:
        summary = f"📦 Checked {len(packages_to_check)} packages → {len(research_results)} major version diffs (all cached ⚡)"

    result = {
        "systemMessage": summary,
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": context
        }
    }

    print(json.dumps(result))
    # Exit code 2 shows stderr to model and user
    sys.exit(2)


if __name__ == "__main__":
    main()
