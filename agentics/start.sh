#!/usr/bin/env bash

echo "Initializing Agentic Layer"

function uv_deps() {
  # Ensure uv is installed
  if ! command -v uv &>/dev/null; then
    echo "[uv_deps] uv not found. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Source the env so uv is available in this session
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v uv &>/dev/null; then
      echo "[uv_deps] ERROR: uv installation failed" >&2
      return 1
    fi
    echo "[uv_deps] uv installed: $(uv --version)"
  else
    echo "[uv_deps] uv found: $(uv --version)"
  fi

  # Collect unique dependencies from generated Python scripts
  local agentics_dir="./agentics"
  local -A seen
  local deps=()

  while IFS= read -r line; do
    # Strip comment prefix and quotes: '#   "pkg",' -> 'pkg'
    local pkg
    pkg=$(echo "$line" | sed -n 's/^#[[:space:]]*"\([^"]*\)".*/\1/p')
    if [[ -n "$pkg" && -z "${seen[$pkg]+x}" ]]; then
      seen["$pkg"]=1
      deps+=("$pkg")
    fi
  done < <(grep -h '#   "' "$agentics_dir"/*.py 2>/dev/null)

  if [[ ${#deps[@]} -eq 0 ]]; then
    echo "[uv_deps] No dependencies found in scripts."
    return 0
  fi

  echo "[uv_deps] Resolved dependencies: ${deps[*]}"

  # Pre-cache dependencies so first script run is fast
  uv pip install --system "${deps[@]}" 2>/dev/null \
    || uv pip install --break-system-packages "${deps[@]}" 2>/dev/null \
    || {
      # Fallback: create a temp venv and install there to warm the cache
      local tmp_venv
      tmp_venv=$(mktemp -d)/venv
      uv venv "$tmp_venv" --quiet
      VIRTUAL_ENV="$tmp_venv" uv pip install "${deps[@]}" --quiet
      rm -rf "$(dirname "$tmp_venv")"
      echo "[uv_deps] Dependencies cached via temp venv."
    }

  echo "[uv_deps] Dependency injection complete."
}

function claude_loop() {
  local claude_dir="./.claude"
  local dir=(
    hooks
    commands
  )
  for i in "${dir[@]}"; do
    mkdir -p "${claude_dir}/${i}"
  done
}

function agentics() {
  local agentics_dir="./agentics"
  local modules="./agentics/agentic_modules"

  local files=(
    README.md
    adw_chore_implement.py
    adw_prompt.py
    adw_sdk_prompt.py
    adw_slash_command.py
    agentic_instructions.md
  )

  local module_files=(
    agent.py
    agent_sdk.py
    agentic_instructions.md
  )

  mkdir -p "${agentics_dir}" "${modules}"

  for i in "${files[@]}"; do
    touch "${agentics_dir}/${i}"
  done

  for i in "${module_files[@]}"; do
    touch "${modules}/${i}"
  done

}

function agentic_instructions() {
  cat <<'EOF' > ./agentics/agentic_instructions.md
# agentic_instructions.md -- tac8_app1/agentics

## Purpose
Minimal ADW scripts demonstrating agent layer primitives. Shows the simplest forms of programmatic Claude Code invocation.

## Technology
Python 3.12+, uv single-file scripts.

## Contents
- `adw_chore_implement.py` -- Chore workflow: generate plan + implement via Claude
- `adw_prompt.py` -- Direct prompt execution via Claude CLI
- `adw_sdk_prompt.py` -- Prompt execution via Claude Code SDK
- `adw_slash_command.py` -- Slash command execution
- `agentic_modules/` -- Shared modules
- `README.md` -- Documentation

## Key Functions
See individual script descriptions.

## CRUD Entry Points
- `uv run adw_chore_implement.py`
- `uv run adw_prompt.py`

## Style Guide
uv single-file scripts with inline dependencies.
EOF
}

function chore() {
  cat <<'PYEOF' > ./agentics/adw_chore_implement.py
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "pydantic",
#   "click",
#   "rich",
# ]
# ///
"""
Run chore planning and implementation workflow.

This script runs two slash commands in sequence:
1. /chore - Creates a plan based on the prompt
2. /implement - Implements the plan created by /chore

Usage:
    # Method 1: Direct execution (requires uv)
    ./agentics/adw_chore_implement.py "Add error handling to all API endpoints"

    # Method 2: Using uv run
    uv run agentics/adw_chore_implement.py "Refactor database connection logic"

Examples:
    # Run with specific model
    ./agentics/adw_chore_implement.py "Add logging to agent.py" --model opus

    # Run from a different working directory
    ./agentics/adw_chore_implement.py "Update documentation" --working-dir /path/to/project

    # Run with verbose output
    ./agentics/adw_chore_implement.py "Add tests" --verbose
"""

import os
import sys
import json
import re
from pathlib import Path
import click
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.rule import Rule

# Add the agentic_modules directory to the path so we can import agent
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "agentic_modules"))

from agent import (
    AgentTemplateRequest,
    AgentPromptResponse,
    execute_template,
    generate_short_id,
)

# Output file name constants
OUTPUT_JSONL = "cc_raw_output.jsonl"
OUTPUT_JSON = "cc_raw_output.json"
FINAL_OBJECT_JSON = "cc_final_object.json"
SUMMARY_JSON = "custom_summary_output.json"


def extract_plan_path(output: str) -> str:
    """Extract the plan file path from the chore command output.

    Looks for patterns like:
    - specs/chore-12345678-update-readme.md
    - Created plan at: specs/chore-...
    - Plan file: specs/chore-...
    """
    # Try multiple patterns to find the plan path
    patterns = [
        r"specs/chore-[a-zA-Z0-9\-]+\.md",
        r"Created plan at:\s*(specs/chore-[a-zA-Z0-9\-]+\.md)",
        r"Plan file:\s*(specs/chore-[a-zA-Z0-9\-]+\.md)",
        r"path.*?:\s*(specs/chore-[a-zA-Z0-9\-]+\.md)",
    ]

    for pattern in patterns:
        match = re.search(pattern, output, re.IGNORECASE | re.MULTILINE)
        if match:
            return match.group(1) if match.groups() else match.group(0)

    # If no match found, raise an error
    raise ValueError("Could not find plan file path in chore output")


@click.command()
@click.argument("prompt", required=True)
@click.option(
    "--model",
    type=click.Choice(["sonnet", "opus"]),
    default="sonnet",
    help="Claude model to use",
)
@click.option(
    "--working-dir",
    type=click.Path(exists=True, file_okay=False, dir_okay=True, resolve_path=True),
    help="Working directory for command execution (default: current directory)",
)
def main(
    prompt: str,
    model: str,
    working_dir: str,
):
    """Run chore planning and implementation workflow."""
    console = Console()

    # Generate a unique ID for this workflow
    adw_id = generate_short_id()

    # Use current directory if no working directory specified
    if not working_dir:
        working_dir = os.getcwd()

    # Set default agent names
    planner_name = "planner"
    builder_name = "builder"

    console.print(
        Panel(
            f"[bold blue]ADW Chore & Implement Workflow[/bold blue]\n\n"
            f"[cyan]ADW ID:[/cyan] {adw_id}\n"
            f"[cyan]Model:[/cyan] {model}\n"
            f"[cyan]Working Dir:[/cyan] {working_dir}",
            title="[bold blue]🚀 Workflow Configuration[/bold blue]",
            border_style="blue",
        )
    )
    console.print()

    # Phase 1: Run /chore command
    console.print(Rule("[bold yellow]Phase 1: Planning (/chore)[/bold yellow]"))
    console.print()

    # Create the chore request
    chore_request = AgentTemplateRequest(
        agent_name=planner_name,
        slash_command="/chore",
        args=[adw_id, prompt],
        adw_id=adw_id,
        model=model,
        working_dir=working_dir,
    )

    # Display chore execution info
    chore_info_table = Table(show_header=False, box=None, padding=(0, 1))
    chore_info_table.add_column(style="bold cyan")
    chore_info_table.add_column()

    chore_info_table.add_row("ADW ID", adw_id)
    chore_info_table.add_row("ADW Name", "adw_chore_implement (planning)")
    chore_info_table.add_row("Command", "/chore")
    chore_info_table.add_row("Args", f'{adw_id} "{prompt}"')
    chore_info_table.add_row("Model", model)
    chore_info_table.add_row("Agent", planner_name)

    console.print(
        Panel(
            chore_info_table,
            title="[bold blue]🚀 Chore Inputs[/bold blue]",
            border_style="blue",
        )
    )
    console.print()

    plan_path = None

    try:
        # Execute the chore command
        with console.status("[bold yellow]Creating plan...[/bold yellow]"):
            chore_response = execute_template(chore_request)

        # Display the chore result
        if chore_response.success:
            # Success panel
            console.print(
                Panel(
                    chore_response.output,
                    title="[bold green]✅ Planning Success[/bold green]",
                    border_style="green",
                    padding=(1, 2),
                )
            )

            # Extract the plan path from the output
            try:
                plan_path = extract_plan_path(chore_response.output)
                console.print(f"\n[bold cyan]Plan created at:[/bold cyan] {plan_path}")
            except ValueError as e:
                console.print(
                    Panel(
                        f"[bold red]Could not extract plan path: {str(e)}[/bold red]\n\n"
                        "The chore command succeeded but the plan file path could not be found in the output.",
                        title="[bold red]❌ Parse Error[/bold red]",
                        border_style="red",
                    )
                )
                sys.exit(3)

        else:
            # Error panel
            console.print(
                Panel(
                    chore_response.output,
                    title="[bold red]❌ Planning Failed[/bold red]",
                    border_style="red",
                    padding=(1, 2),
                )
            )
            console.print(
                "\n[bold red]Workflow aborted: Planning phase failed[/bold red]"
            )
            sys.exit(1)

        # Save chore phase summary
        chore_output_dir = f"./agents/{adw_id}/{planner_name}"
        chore_summary_path = f"{chore_output_dir}/{SUMMARY_JSON}"

        with open(chore_summary_path, "w") as f:
            json.dump(
                {
                    "phase": "planning",
                    "adw_id": adw_id,
                    "slash_command": "/chore",
                    "args": [adw_id, prompt],
                    "path_to_slash_command_prompt": ".claude/commands/chore.md",
                    "model": model,
                    "working_dir": working_dir,
                    "success": chore_response.success,
                    "session_id": chore_response.session_id,
                    "retry_code": chore_response.retry_code,
                    "output": chore_response.output,
                    "plan_path": plan_path,
                },
                f,
                indent=2,
            )

        # Show chore output files
        console.print()

        # Files saved panel for chore phase
        chore_files_table = Table(show_header=True, box=None)
        chore_files_table.add_column("File Type", style="bold cyan")
        chore_files_table.add_column("Path", style="dim")
        chore_files_table.add_column("Description", style="italic")

        chore_files_table.add_row(
            "JSONL Stream",
            f"{chore_output_dir}/{OUTPUT_JSONL}",
            "Raw streaming output from Claude Code",
        )
        chore_files_table.add_row(
            "JSON Array",
            f"{chore_output_dir}/{OUTPUT_JSON}",
            "All messages as a JSON array",
        )
        chore_files_table.add_row(
            "Final Object",
            f"{chore_output_dir}/{FINAL_OBJECT_JSON}",
            "Last message entry (final result)",
        )
        chore_files_table.add_row(
            "Summary",
            chore_summary_path,
            "High-level execution summary with metadata",
        )

        console.print(
            Panel(
                chore_files_table,
                title="[bold blue]📄 Planning Output Files[/bold blue]",
                border_style="blue",
            )
        )

        console.print()

        # Phase 2: Run /implement command
        console.print(
            Rule("[bold yellow]Phase 2: Implementation (/implement)[/bold yellow]")
        )
        console.print()

        # Create the implement request
        implement_request = AgentTemplateRequest(
            agent_name=builder_name,
            slash_command="/implement",
            args=[plan_path],
            adw_id=adw_id,
            model=model,
            working_dir=working_dir,
        )

        # Display implement execution info
        implement_info_table = Table(show_header=False, box=None, padding=(0, 1))
        implement_info_table.add_column(style="bold cyan")
        implement_info_table.add_column()

        implement_info_table.add_row("ADW ID", adw_id)
        implement_info_table.add_row("ADW Name", "adw_chore_implement (building)")
        implement_info_table.add_row("Command", "/implement")
        implement_info_table.add_row("Args", plan_path)
        implement_info_table.add_row("Model", model)
        implement_info_table.add_row("Agent", builder_name)

        console.print(
            Panel(
                implement_info_table,
                title="[bold blue]🚀 Implement Inputs[/bold blue]",
                border_style="blue",
            )
        )
        console.print()

        # Execute the implement command
        with console.status("[bold yellow]Implementing plan...[/bold yellow]"):
            implement_response = execute_template(implement_request)

        # Display the implement result
        if implement_response.success:
            # Success panel
            console.print(
                Panel(
                    implement_response.output,
                    title="[bold green]✅ Implementation Success[/bold green]",
                    border_style="green",
                    padding=(1, 2),
                )
            )

            if implement_response.session_id:
                console.print(
                    f"\n[bold cyan]Session ID:[/bold cyan] {implement_response.session_id}"
                )
        else:
            # Error panel
            console.print(
                Panel(
                    implement_response.output,
                    title="[bold red]❌ Implementation Failed[/bold red]",
                    border_style="red",
                    padding=(1, 2),
                )
            )

        # Save implement phase summary
        implement_output_dir = f"./agents/{adw_id}/{builder_name}"
        implement_summary_path = f"{implement_output_dir}/{SUMMARY_JSON}"

        with open(implement_summary_path, "w") as f:
            json.dump(
                {
                    "phase": "implementation",
                    "adw_id": adw_id,
                    "slash_command": "/implement",
                    "args": [plan_path],
                    "path_to_slash_command_prompt": ".claude/commands/implement.md",
                    "model": model,
                    "working_dir": working_dir,
                    "success": implement_response.success,
                    "session_id": implement_response.session_id,
                    "retry_code": implement_response.retry_code,
                    "output": implement_response.output,
                },
                f,
                indent=2,
            )

        # Show implement output files
        console.print()

        # Files saved panel for implement phase
        implement_files_table = Table(show_header=True, box=None)
        implement_files_table.add_column("File Type", style="bold cyan")
        implement_files_table.add_column("Path", style="dim")
        implement_files_table.add_column("Description", style="italic")

        implement_files_table.add_row(
            "JSONL Stream",
            f"{implement_output_dir}/{OUTPUT_JSONL}",
            "Raw streaming output from Claude Code",
        )
        implement_files_table.add_row(
            "JSON Array",
            f"{implement_output_dir}/{OUTPUT_JSON}",
            "All messages as a JSON array",
        )
        implement_files_table.add_row(
            "Final Object",
            f"{implement_output_dir}/{FINAL_OBJECT_JSON}",
            "Last message entry (final result)",
        )
        implement_files_table.add_row(
            "Summary",
            implement_summary_path,
            "High-level execution summary with metadata",
        )

        console.print(
            Panel(
                implement_files_table,
                title="[bold blue]📄 Implementation Output Files[/bold blue]",
                border_style="blue",
            )
        )

        # Show workflow summary
        console.print()
        console.print(Rule("[bold blue]Workflow Summary[/bold blue]"))
        console.print()

        summary_table = Table(show_header=True, box=None)
        summary_table.add_column("Phase", style="bold cyan")
        summary_table.add_column("Status", style="bold")
        summary_table.add_column("Output Directory", style="dim")

        # Planning phase row
        planning_status = "✅ Success" if chore_response.success else "❌ Failed"
        summary_table.add_row(
            "Planning (/chore)",
            planning_status,
            f"./agents/{adw_id}/{planner_name}/",
        )

        # Implementation phase row
        implement_status = "✅ Success" if implement_response.success else "❌ Failed"
        summary_table.add_row(
            "Implementation (/implement)",
            implement_status,
            f"./agents/{adw_id}/{builder_name}/",
        )

        console.print(summary_table)

        # Create overall workflow summary
        workflow_summary_path = f"./agents/{adw_id}/workflow_summary.json"
        os.makedirs(f"./agents/{adw_id}", exist_ok=True)

        with open(workflow_summary_path, "w") as f:
            json.dump(
                {
                    "workflow": "chore_implement",
                    "adw_id": adw_id,
                    "prompt": prompt,
                    "model": model,
                    "working_dir": working_dir,
                    "plan_path": plan_path,
                    "phases": {
                        "planning": {
                            "success": chore_response.success,
                            "session_id": chore_response.session_id,
                            "agent": planner_name,
                            "output_dir": f"./agents/{adw_id}/{planner_name}/",
                        },
                        "implementation": {
                            "success": implement_response.success,
                            "session_id": implement_response.session_id,
                            "agent": builder_name,
                            "output_dir": f"./agents/{adw_id}/{builder_name}/",
                        },
                    },
                    "overall_success": chore_response.success
                    and implement_response.success,
                },
                f,
                indent=2,
            )

        console.print(
            f"\n[bold cyan]Workflow summary:[/bold cyan] {workflow_summary_path}"
        )
        console.print()

        # Exit with appropriate code
        if chore_response.success and implement_response.success:
            console.print(
                "[bold green]✅ Workflow completed successfully![/bold green]"
            )
            sys.exit(0)
        else:
            console.print(
                "[bold yellow]⚠️  Workflow completed with errors[/bold yellow]"
            )
            sys.exit(1)

    except Exception as e:
        console.print(
            Panel(
                f"[bold red]{str(e)}[/bold red]",
                title="[bold red]❌ Unexpected Error[/bold red]",
                border_style="red",
            )
        )
        sys.exit(2)


if __name__ == "__main__":
    main()
PYEOF
  chmod +x ./agentics/adw_chore_implement.py
}

function agentic_modules_agentic_instructions() {
  cat <<'EOF' > ./agentics/agentic_modules/agentic_instructions.md
# agentic_instructions.md -- tac8_app1/agentics/agentic_modules

## Purpose
Core agent execution modules for the minimal ADW layer.

## Technology
Python 3.12+, pydantic.

## Contents
- `agent.py` -- Claude Code CLI agent execution (AgentPromptRequest/Response, retries, timeout)
- `agent_sdk.py` -- Claude Code SDK-based agent execution (alternative to CLI)

## Key Functions
- `run_agent(request: AgentPromptRequest) -> AgentPromptResponse` -- Execute Claude via CLI subprocess
- SDK variant: Execute Claude via Python SDK

## Data Types
- `AgentPromptRequest` -- `{prompt, adw_id, agent_name, model, output_file, working_dir}`
- `AgentPromptResponse` -- `{output, success, session_id, retry_code}`
- `RetryCode` -- Error classification enum

## Style Guide
Same as tac-6/agentics/agentic_modules.

### Representative Snippet
```python
class AgentPromptRequest(BaseModel):
    prompt: str
    adw_id: str
    agent_name: str = "ops"
    model: Literal["sonnet", "opus"] = "sonnet"
    dangerously_skip_permissions: bool = False
    output_file: str
    working_dir: Optional[str] = None

class AgentPromptResponse(BaseModel):
    output: str
    success: bool
    session_id: Optional[str] = None
    retry_code: RetryCode = RetryCode.NONE
```
EOF
}

function agent_module() {
  cat <<'PYEOF' > ./agentics/agentic_modules/agent.py
"""Claude Code agent module for executing prompts programmatically."""

import subprocess
import sys
import os
import json
import re
import logging
import time
import uuid
from typing import Optional, List, Dict, Any, Tuple, Final, Literal
from enum import Enum
from pydantic import BaseModel


# Retry codes for Claude Code execution errors
class RetryCode(str, Enum):
    """Codes indicating different types of errors that may be retryable."""
    CLAUDE_CODE_ERROR = "claude_code_error"  # General Claude Code CLI error
    TIMEOUT_ERROR = "timeout_error"  # Command timed out
    EXECUTION_ERROR = "execution_error"  # Error during execution
    ERROR_DURING_EXECUTION = "error_during_execution"  # Agent encountered an error
    NONE = "none"  # No retry needed




class AgentPromptRequest(BaseModel):
    """Claude Code agent prompt configuration."""
    prompt: str
    adw_id: str
    agent_name: str = "ops"
    model: Literal["sonnet", "opus"] = "sonnet"
    dangerously_skip_permissions: bool = False
    output_file: str
    working_dir: Optional[str] = None


class AgentPromptResponse(BaseModel):
    """Claude Code agent response."""
    output: str
    success: bool
    session_id: Optional[str] = None
    retry_code: RetryCode = RetryCode.NONE


class AgentTemplateRequest(BaseModel):
    """Claude Code agent template execution request."""
    agent_name: str
    slash_command: str
    args: List[str]
    adw_id: str
    model: Literal["sonnet", "opus"] = "sonnet"
    working_dir: Optional[str] = None


class ClaudeCodeResultMessage(BaseModel):
    """Claude Code JSONL result message (last line)."""
    type: str
    subtype: str
    is_error: bool
    duration_ms: int
    duration_api_ms: int
    num_turns: int
    result: str
    session_id: str
    total_cost_usd: float


def get_safe_subprocess_env() -> Dict[str, str]:
    """Get filtered environment variables safe for subprocess execution.

    Returns only the environment variables needed for subprocess execution.
    Authentication is handled by the claude CLI via subscription login.

    Returns:
        Dictionary containing only required environment variables
    """
    safe_env_vars = {
        # Claude Code Configuration (uses subscription auth via 'claude login')
        # No API key needed - claude CLI reads OAuth token from ~/.claude/.credentials.json
        "CLAUDE_CODE_PATH": os.getenv("CLAUDE_CODE_PATH", "claude"),
        "CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR": os.getenv(
            "CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR", "true"
        ),

        # Essential system environment variables
        "HOME": os.getenv("HOME"),
        "USER": os.getenv("USER"),
        "PATH": os.getenv("PATH"),
        "SHELL": os.getenv("SHELL"),
        "TERM": os.getenv("TERM"),
        "LANG": os.getenv("LANG"),
        "LC_ALL": os.getenv("LC_ALL"),

        # Python-specific variables that subprocesses might need
        "PYTHONPATH": os.getenv("PYTHONPATH"),
        "PYTHONUNBUFFERED": "1",  # Useful for subprocess output

        # Working directory tracking
        "PWD": os.getcwd(),
    }

    # Filter out None values
    return {k: v for k, v in safe_env_vars.items() if v is not None}


# Get Claude Code CLI path from environment
CLAUDE_PATH = os.getenv("CLAUDE_CODE_PATH", "claude")

# Output file name constants (matching adw_prompt.py and adw_slash_command.py)
OUTPUT_JSONL = "cc_raw_output.jsonl"
OUTPUT_JSON = "cc_raw_output.json"
FINAL_OBJECT_JSON = "cc_final_object.json"
SUMMARY_JSON = "custom_summary_output.json"


def generate_short_id() -> str:
    """Generate a short 8-character UUID for tracking."""
    return str(uuid.uuid4())[:8]




def truncate_output(
    output: str, max_length: int = 500, suffix: str = "... (truncated)"
) -> str:
    """Truncate output to a reasonable length for display.

    Special handling for JSONL data - if the output appears to be JSONL,
    try to extract just the meaningful part.

    Args:
        output: The output string to truncate
        max_length: Maximum length before truncation (default: 500)
        suffix: Suffix to add when truncated (default: "... (truncated)")

    Returns:
        Truncated string if needed, original if shorter than max_length
    """
    # Check if this looks like JSONL data
    if output.startswith('{"type":') and '\n{"type":' in output:
        # This is likely JSONL output - try to extract the last meaningful message
        lines = output.strip().split("\n")
        for line in reversed(lines):
            try:
                data = json.loads(line)
                # Look for result message
                if data.get("type") == "result":
                    result = data.get("result", "")
                    if result:
                        return truncate_output(result, max_length, suffix)
                # Look for assistant message
                elif data.get("type") == "assistant" and data.get("message"):
                    content = data["message"].get("content", [])
                    if isinstance(content, list) and content:
                        text = content[0].get("text", "")
                        if text:
                            return truncate_output(text, max_length, suffix)
            except:
                pass
        # If we couldn't extract anything meaningful, just show that it's JSONL
        return f"[JSONL output with {len(lines)} messages]{suffix}"

    # Regular truncation logic
    if len(output) <= max_length:
        return output

    # Try to find a good break point (newline or space)
    truncate_at = max_length - len(suffix)

    # Look for newline near the truncation point
    newline_pos = output.rfind("\n", truncate_at - 50, truncate_at)
    if newline_pos > 0:
        return output[:newline_pos] + suffix

    # Look for space near the truncation point
    space_pos = output.rfind(" ", truncate_at - 20, truncate_at)
    if space_pos > 0:
        return output[:space_pos] + suffix

    # Just truncate at the limit
    return output[:truncate_at] + suffix


def check_claude_installed() -> Optional[str]:
    """Check if Claude Code CLI is installed. Return error message if not."""
    try:
        result = subprocess.run(
            [CLAUDE_PATH, "--version"], capture_output=True, text=True
        )
        if result.returncode != 0:
            return (
                f"Error: Claude Code CLI is not installed. Expected at: {CLAUDE_PATH}"
            )
    except FileNotFoundError:
        return f"Error: Claude Code CLI is not installed. Expected at: {CLAUDE_PATH}"
    return None


def check_claude_auth() -> Optional[str]:
    """Check if user is authenticated via claude login (subscription auth).

    The claude CLI uses OAuth tokens from ~/.claude/.credentials.json
    obtained via 'claude login'. This function verifies the user is logged in.

    Returns error message if not authenticated, None if OK.
    """
    try:
        result = subprocess.run(
            [CLAUDE_PATH, "auth", "status"],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            return (
                "Error: Not authenticated. Run 'claude login' to authenticate "
                "with your Anthropic subscription account."
            )
        # Parse the JSON output to check login status
        try:
            status = json.loads(result.stdout)
            if not status.get("loggedIn", False):
                return (
                    "Error: Not logged in. Run 'claude login' to authenticate "
                    "with your Anthropic subscription account."
                )
        except (json.JSONDecodeError, KeyError):
            pass  # If we can't parse, the CLI is installed and returned 0, assume OK
    except FileNotFoundError:
        return f"Error: Claude Code CLI not found at: {CLAUDE_PATH}"
    return None


def parse_jsonl_output(
    output_file: str,
) -> Tuple[List[Dict[str, Any]], Optional[Dict[str, Any]]]:
    """Parse JSONL output file and return all messages and the result message.

    Returns:
        Tuple of (all_messages, result_message) where result_message is None if not found
    """
    try:
        with open(output_file, "r") as f:
            # Read all lines and parse each as JSON
            messages = [json.loads(line) for line in f if line.strip()]

            # Find the result message (should be the last one)
            result_message = None
            for message in reversed(messages):
                if message.get("type") == "result":
                    result_message = message
                    break

            return messages, result_message
    except Exception as e:
        return [], None


def convert_jsonl_to_json(jsonl_file: str) -> str:
    """Convert JSONL file to JSON array file.

    Creates a cc_raw_output.json file in the same directory as the JSONL file,
    containing all messages as a JSON array.

    Returns:
        Path to the created JSON file
    """
    # Create JSON filename in the same directory
    output_dir = os.path.dirname(jsonl_file)
    json_file = os.path.join(output_dir, OUTPUT_JSON)

    # Parse the JSONL file
    messages, _ = parse_jsonl_output(jsonl_file)

    # Write as JSON array
    with open(json_file, "w") as f:
        json.dump(messages, f, indent=2)

    return json_file


def save_last_entry_as_raw_result(json_file: str) -> Optional[str]:
    """Save the last entry from a JSON array file as cc_final_object.json.

    Args:
        json_file: Path to the JSON array file

    Returns:
        Path to the created cc_final_object.json file, or None if error
    """
    try:
        # Read the JSON array
        with open(json_file, "r") as f:
            messages = json.load(f)

        if not messages:
            return None

        # Get the last entry
        last_entry = messages[-1]

        # Create cc_final_object.json in the same directory
        output_dir = os.path.dirname(json_file)
        final_object_file = os.path.join(output_dir, FINAL_OBJECT_JSON)

        # Write the last entry
        with open(final_object_file, "w") as f:
            json.dump(last_entry, f, indent=2)

        return final_object_file
    except Exception:
        # Silently fail - this is a nice-to-have feature
        return None


def get_claude_env() -> Dict[str, str]:
    """Get only the required environment variables for Claude Code execution.

    This is a wrapper around get_safe_subprocess_env() for
    backward compatibility. New code should use get_safe_subprocess_env() directly.

    Returns a dictionary containing only the necessary environment variables
    for subprocess execution. Auth is handled via subscription login.
    """
    # Use the function defined above
    return get_safe_subprocess_env()


def save_prompt(prompt: str, adw_id: str, agent_name: str = "ops") -> None:
    """Save a prompt to the appropriate logging directory."""
    # Extract slash command from prompt
    match = re.match(r"^(/\w+)", prompt)
    if not match:
        return

    slash_command = match.group(1)
    # Remove leading slash for filename
    command_name = slash_command[1:]

    # Create directory structure at project root (parent of agentics)
    # __file__ is in agentics/agentic_modules/, so we need to go up 3 levels to get to project root
    project_root = os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    )
    prompt_dir = os.path.join(project_root, "agents", adw_id, agent_name, "prompts")
    os.makedirs(prompt_dir, exist_ok=True)

    # Save prompt to file
    prompt_file = os.path.join(prompt_dir, f"{command_name}.txt")
    with open(prompt_file, "w") as f:
        f.write(prompt)


def prompt_claude_code_with_retry(
    request: AgentPromptRequest,
    max_retries: int = 3,
    retry_delays: List[int] = None,
) -> AgentPromptResponse:
    """Execute Claude Code with retry logic for certain error types.

    Args:
        request: The prompt request configuration
        max_retries: Maximum number of retry attempts (default: 3)
        retry_delays: List of delays in seconds between retries (default: [1, 3, 5])

    Returns:
        AgentPromptResponse with output and retry code
    """
    if retry_delays is None:
        retry_delays = [1, 3, 5]

    # Ensure we have enough delays for max_retries
    while len(retry_delays) < max_retries:
        retry_delays.append(retry_delays[-1] + 2)  # Add incrementing delays

    last_response = None

    for attempt in range(max_retries + 1):  # +1 for initial attempt
        if attempt > 0:
            # This is a retry
            delay = retry_delays[attempt - 1]
            time.sleep(delay)

        response = prompt_claude_code(request)
        last_response = response

        # Check if we should retry based on the retry code
        if response.success or response.retry_code == RetryCode.NONE:
            # Success or non-retryable error
            return response

        # Check if this is a retryable error
        if response.retry_code in [
            RetryCode.CLAUDE_CODE_ERROR,
            RetryCode.TIMEOUT_ERROR,
            RetryCode.EXECUTION_ERROR,
            RetryCode.ERROR_DURING_EXECUTION,
        ]:
            if attempt < max_retries:
                continue
            else:
                return response

    # Should not reach here, but return last response just in case
    return last_response


def prompt_claude_code(request: AgentPromptRequest) -> AgentPromptResponse:
    """Execute Claude Code with the given prompt configuration."""

    # Check if Claude Code CLI is installed
    error_msg = check_claude_installed()
    if error_msg:
        return AgentPromptResponse(
            output=error_msg,
            success=False,
            session_id=None,
            retry_code=RetryCode.NONE,  # Installation error is not retryable
        )

    # Check if user is authenticated via subscription
    auth_msg = check_claude_auth()
    if auth_msg:
        return AgentPromptResponse(
            output=auth_msg,
            success=False,
            session_id=None,
            retry_code=RetryCode.NONE,  # Auth error is not retryable
        )

    # Save prompt before execution
    save_prompt(request.prompt, request.adw_id, request.agent_name)

    # Create output directory if needed
    output_dir = os.path.dirname(request.output_file)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    # Build command - always use stream-json format and verbose
    cmd = [CLAUDE_PATH, "-p", request.prompt]
    cmd.extend(["--model", request.model])
    cmd.extend(["--output-format", "stream-json"])
    cmd.append("--verbose")

    # Check for MCP config in working directory
    if request.working_dir:
        mcp_config_path = os.path.join(request.working_dir, ".mcp.json")
        if os.path.exists(mcp_config_path):
            cmd.extend(["--mcp-config", mcp_config_path])

    # Add dangerous skip permissions flag if enabled
    if request.dangerously_skip_permissions:
        cmd.append("--dangerously-skip-permissions")

    # Set up environment with only required variables
    env = get_claude_env()

    try:
        # Open output file for streaming
        with open(request.output_file, "w") as output_f:
            # Execute Claude Code and stream output to file
            result = subprocess.run(
                cmd,
                stdout=output_f,  # Stream directly to file
                stderr=subprocess.PIPE,
                text=True,
                env=env,
                cwd=request.working_dir,  # Use working_dir if provided
            )

        if result.returncode == 0:

            # Parse the JSONL file
            messages, result_message = parse_jsonl_output(request.output_file)

            # Convert JSONL to JSON array file
            json_file = convert_jsonl_to_json(request.output_file)

            # Save the last entry as raw_result.json
            save_last_entry_as_raw_result(json_file)

            if result_message:
                # Extract session_id from result message
                session_id = result_message.get("session_id")

                # Check if there was an error in the result
                is_error = result_message.get("is_error", False)
                subtype = result_message.get("subtype", "")

                # Handle error_during_execution case where there's no result field
                if subtype == "error_during_execution":
                    error_msg = "Error during execution: Agent encountered an error and did not return a result"
                    return AgentPromptResponse(
                        output=error_msg,
                        success=False,
                        session_id=session_id,
                        retry_code=RetryCode.ERROR_DURING_EXECUTION,
                    )

                result_text = result_message.get("result", "")

                # For error cases, truncate the output to prevent JSONL blobs
                if is_error and len(result_text) > 1000:
                    result_text = truncate_output(result_text, max_length=800)

                return AgentPromptResponse(
                    output=result_text,
                    success=not is_error,
                    session_id=session_id,
                    retry_code=RetryCode.NONE,  # No retry needed for successful or non-retryable errors
                )
            else:
                # No result message found, try to extract meaningful error
                error_msg = "No result message found in Claude Code output"

                # Try to get the last few lines of output for context
                try:
                    with open(request.output_file, "r") as f:
                        lines = f.readlines()
                        if lines:
                            # Get last 5 lines or less
                            last_lines = lines[-5:] if len(lines) > 5 else lines
                            # Try to parse each as JSON to find any error messages
                            for line in reversed(last_lines):
                                try:
                                    data = json.loads(line.strip())
                                    if data.get("type") == "assistant" and data.get(
                                        "message"
                                    ):
                                        # Extract text from assistant message
                                        content = data["message"].get("content", [])
                                        if isinstance(content, list) and content:
                                            text = content[0].get("text", "")
                                            if text:
                                                error_msg = f"Claude Code output: {text[:500]}"  # Truncate
                                                break
                                except:
                                    pass
                except:
                    pass

                return AgentPromptResponse(
                    output=truncate_output(error_msg, max_length=800),
                    success=False,
                    session_id=None,
                    retry_code=RetryCode.NONE,
                )
        else:
            # Error occurred - stderr is captured, stdout went to file
            stderr_msg = result.stderr.strip() if result.stderr else ""

            # Try to read the output file to check for errors in stdout
            stdout_msg = ""
            error_from_jsonl = None
            try:
                if os.path.exists(request.output_file):
                    # Parse JSONL to find error message
                    messages, result_message = parse_jsonl_output(request.output_file)

                    if result_message and result_message.get("is_error"):
                        # Found error in result message
                        error_from_jsonl = result_message.get("result", "Unknown error")
                    elif messages:
                        # Look for error in last few messages
                        for msg in reversed(messages[-5:]):
                            if msg.get("type") == "assistant" and msg.get(
                                "message", {}
                            ).get("content"):
                                content = msg["message"]["content"]
                                if isinstance(content, list) and content:
                                    text = content[0].get("text", "")
                                    if text and (
                                        "error" in text.lower()
                                        or "failed" in text.lower()
                                    ):
                                        error_from_jsonl = text[:500]  # Truncate
                                        break

                    # If no structured error found, get last line only
                    if not error_from_jsonl:
                        with open(request.output_file, "r") as f:
                            lines = f.readlines()
                            if lines:
                                # Just get the last line instead of entire file
                                stdout_msg = lines[-1].strip()[
                                    :200
                                ]  # Truncate to 200 chars
            except:
                pass

            if error_from_jsonl:
                error_msg = f"Claude Code error: {error_from_jsonl}"
            elif stdout_msg and not stderr_msg:
                error_msg = f"Claude Code error: {stdout_msg}"
            elif stderr_msg and not stdout_msg:
                error_msg = f"Claude Code error: {stderr_msg}"
            elif stdout_msg and stderr_msg:
                error_msg = f"Claude Code error: {stderr_msg}\nStdout: {stdout_msg}"
            else:
                error_msg = f"Claude Code error: Command failed with exit code {result.returncode}"

            # Always truncate error messages to prevent huge outputs
            return AgentPromptResponse(
                output=truncate_output(error_msg, max_length=800),
                success=False,
                session_id=None,
                retry_code=RetryCode.CLAUDE_CODE_ERROR,
            )

    except subprocess.TimeoutExpired:
        error_msg = "Error: Claude Code command timed out after 5 minutes"
        return AgentPromptResponse(
            output=error_msg,
            success=False,
            session_id=None,
            retry_code=RetryCode.TIMEOUT_ERROR,
        )
    except Exception as e:
        error_msg = f"Error executing Claude Code: {e}"
        return AgentPromptResponse(
            output=error_msg,
            success=False,
            session_id=None,
            retry_code=RetryCode.EXECUTION_ERROR,
        )


def execute_template(request: AgentTemplateRequest) -> AgentPromptResponse:
    """Execute a Claude Code template with slash command and arguments.

    Example:
        request = AgentTemplateRequest(
            agent_name="planner",
            slash_command="/implement",
            args=["plan.md"],
            adw_id="abc12345",
            model="sonnet"  # Explicitly set model
        )
        response = execute_template(request)
    """

    # Construct prompt from slash command and args
    prompt = f"{request.slash_command} {' '.join(request.args)}"

    # Create output directory with adw_id at project root
    # __file__ is in agentics/agentic_modules/, so we need to go up 3 levels to get to project root
    project_root = os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    )
    output_dir = os.path.join(
        project_root, "agents", request.adw_id, request.agent_name
    )
    os.makedirs(output_dir, exist_ok=True)

    # Build output file path
    output_file = os.path.join(output_dir, OUTPUT_JSONL)

    # Create prompt request with specific parameters
    prompt_request = AgentPromptRequest(
        prompt=prompt,
        adw_id=request.adw_id,
        agent_name=request.agent_name,
        model=request.model,
        dangerously_skip_permissions=True,
        output_file=output_file,
        working_dir=request.working_dir,  # Pass through working_dir
    )

    # Execute with retry logic and return response (prompt_claude_code now handles all parsing)
    return prompt_claude_code_with_retry(prompt_request)
PYEOF
}

function agent_sdk_module() {
  cat <<'PYEOF' > ./agentics/agentic_modules/agent_sdk.py
"""
Claude Code SDK - The SDK Way

This module demonstrates the idiomatic way to use the Claude Code Python SDK
for programmatic agent interactions. It focuses on clean, type-safe patterns
using the SDK's native abstractions.

Key Concepts:
- Use `query()` for one-shot operations
- Use `ClaudeSDKClient` for interactive sessions
- Work directly with SDK message types
- Leverage async/await for clean concurrency
- Configure options for your use case

Example Usage:
    # Simple query
    async for message in query(prompt="What is 2 + 2?"):
        if isinstance(message, AssistantMessage):
            print(extract_text(message))

    # With options
    options = ClaudeCodeOptions(
        model="claude-sonnet-4-20250514",
        allowed_tools=["Read", "Write"],
        permission_mode="bypassPermissions"
    )
    async for message in query(prompt="Create hello.py", options=options):
        process_message(message)

    # Interactive session
    async with create_session() as client:
        await client.query("Debug this error")
        async for msg in client.receive_response():
            handle_message(msg)
"""

import logging
from pathlib import Path
from typing import AsyncIterator, Optional, List
from contextlib import asynccontextmanager

# Import all SDK components we'll use
from claude_code_sdk import (
    # Main functions
    query,
    ClaudeSDKClient,

    # Configuration
    ClaudeCodeOptions,
    PermissionMode,

    # Message types
    Message,
    AssistantMessage,
    UserMessage,
    SystemMessage,
    ResultMessage,

    # Content blocks
    ContentBlock,
    TextBlock,
    ToolUseBlock,
    ToolResultBlock,

    # Errors
    ClaudeSDKError,
    CLIConnectionError,
    CLINotFoundError,
    ProcessError,
)

# Set up logging
logger = logging.getLogger(__name__)


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def extract_text(message: AssistantMessage) -> str:
    """Extract all text content from an assistant message.

    The SDK way: Work directly with typed message objects.

    Args:
        message: AssistantMessage with content blocks

    Returns:
        Concatenated text from all text blocks
    """
    texts = []
    for block in message.content:
        if isinstance(block, TextBlock):
            texts.append(block.text)
    return "\n".join(texts)


def extract_tool_uses(message: AssistantMessage) -> List[ToolUseBlock]:
    """Extract all tool use blocks from an assistant message.

    Args:
        message: AssistantMessage with content blocks

    Returns:
        List of ToolUseBlock objects
    """
    return [
        block for block in message.content
        if isinstance(block, ToolUseBlock)
    ]


def get_result_text(messages: List[Message]) -> str:
    """Extract final result text from a list of messages.

    Args:
        messages: List of messages from a query

    Returns:
        Result text or assistant responses
    """
    # First check for ResultMessage
    for msg in reversed(messages):
        if isinstance(msg, ResultMessage) and msg.result:
            return msg.result

    # Otherwise collect assistant text
    texts = []
    for msg in messages:
        if isinstance(msg, AssistantMessage):
            text = extract_text(msg)
            if text:
                texts.append(text)

    return "\n".join(texts)


# ============================================================================
# ONE-SHOT QUERIES (The Simple SDK Way)
# ============================================================================

async def simple_query(prompt: str, model: str = "claude-sonnet-4-20250514") -> str:
    """Simple one-shot query with text response.

    The SDK way: Direct use of query() with minimal setup.

    Args:
        prompt: What to ask Claude
        model: Which model to use

    Returns:
        Text response from Claude

    Example:
        response = await simple_query("What is 2 + 2?")
        print(response)  # "4" or "2 + 2 equals 4"
    """
    options = ClaudeCodeOptions(model=model)

    texts = []
    async for message in query(prompt=prompt, options=options):
        if isinstance(message, AssistantMessage):
            text = extract_text(message)
            if text:
                texts.append(text)

    return "\n".join(texts) if texts else "No response"


async def query_with_tools(
    prompt: str,
    allowed_tools: List[str],
    working_dir: Optional[Path] = None
) -> AsyncIterator[Message]:
    """Query with specific tools enabled.

    The SDK way: Configure options for your use case.

    Args:
        prompt: What to ask Claude
        allowed_tools: List of tool names to allow
        working_dir: Optional working directory

    Yields:
        SDK message objects

    Example:
        async for msg in query_with_tools(
            "Create a Python script",
            allowed_tools=["Write", "Read"]
        ):
            if isinstance(msg, AssistantMessage):
                for block in msg.content:
                    if isinstance(block, ToolUseBlock):
                        print(f"Using tool: {block.name}")
    """
    options = ClaudeCodeOptions(
        allowed_tools=allowed_tools,
        cwd=str(working_dir) if working_dir else None,
        permission_mode="bypassPermissions"  # For automated workflows
    )

    async for message in query(prompt=prompt, options=options):
        yield message


async def collect_query_response(
    prompt: str,
    options: Optional[ClaudeCodeOptions] = None
) -> tuple[List[Message], Optional[ResultMessage]]:
    """Collect all messages from a query.

    The SDK way: Async iteration with type checking.

    Args:
        prompt: What to ask Claude
        options: Optional configuration

    Returns:
        Tuple of (all_messages, result_message)

    Example:
        messages, result = await collect_query_response("List files")
        if result and not result.is_error:
            print("Success!")
        for msg in messages:
            process_message(msg)
    """
    if options is None:
        options = ClaudeCodeOptions()

    messages = []
    result = None

    async for message in query(prompt=prompt, options=options):
        messages.append(message)
        if isinstance(message, ResultMessage):
            result = message

    return messages, result


# ============================================================================
# INTERACTIVE SESSIONS (The SDK Client Way)
# ============================================================================

@asynccontextmanager
async def create_session(
    model: str = "claude-sonnet-4-20250514",
    working_dir: Optional[Path] = None
):
    """Create an interactive session with Claude.

    The SDK way: Use context managers for resource management.

    Args:
        model: Which model to use
        working_dir: Optional working directory

    Yields:
        Connected ClaudeSDKClient

    Example:
        async with create_session() as client:
            await client.query("Hello")
            async for msg in client.receive_response():
                print(msg)
    """
    options = ClaudeCodeOptions(
        model=model,
        cwd=str(working_dir) if working_dir else None,
        permission_mode="bypassPermissions"
    )

    client = ClaudeSDKClient(options=options)
    await client.connect()

    try:
        yield client
    finally:
        await client.disconnect()


async def interactive_conversation(prompts: List[str]) -> List[Message]:
    """Have an interactive conversation with Claude.

    The SDK way: Bidirectional communication with the client.

    Args:
        prompts: List of prompts to send in sequence

    Returns:
        All messages from the conversation

    Example:
        messages = await interactive_conversation([
            "What's the weather like?",
            "Tell me more about clouds",
            "How do they form?"
        ])
    """
    all_messages = []

    async with create_session() as client:
        for prompt in prompts:
            # Send prompt
            await client.query(prompt)

            # Collect response
            async for msg in client.receive_response():
                all_messages.append(msg)
                if isinstance(msg, ResultMessage):
                    break

    return all_messages


# ============================================================================
# ERROR HANDLING (The SDK Way)
# ============================================================================

async def safe_query(prompt: str) -> tuple[Optional[str], Optional[str]]:
    """Query with comprehensive error handling.

    The SDK way: Handle specific SDK exceptions.

    Args:
        prompt: What to ask Claude

    Returns:
        Tuple of (response_text, error_message)

    Example:
        response, error = await safe_query("Help me debug this")
        if error:
            print(f"Error: {error}")
        else:
            print(f"Response: {response}")
    """
    try:
        response = await simple_query(prompt)
        return response, None

    except CLINotFoundError:
        return None, "Claude Code CLI not found. Install with: npm install -g @anthropic-ai/claude-code"

    except CLIConnectionError as e:
        return None, f"Connection error: {str(e)}"

    except ProcessError as e:
        return None, f"Process error (exit code {e.exit_code}): {str(e)}"

    except ClaudeSDKError as e:
        return None, f"SDK error: {str(e)}"

    except Exception as e:
        return None, f"Unexpected error: {str(e)}"


# ============================================================================
# ADVANCED PATTERNS (The SDK Way)
# ============================================================================

async def stream_with_progress(
    prompt: str,
    on_text: Optional[callable] = None,
    on_tool: Optional[callable] = None
) -> ResultMessage:
    """Stream query with progress callbacks.

    The SDK way: Process messages as they arrive.

    Args:
        prompt: What to ask Claude
        on_text: Callback for text blocks (optional)
        on_tool: Callback for tool use blocks (optional)

    Returns:
        Final ResultMessage

    Example:
        result = await stream_with_progress(
            "Analyze this codebase",
            on_text=lambda text: print(f"Claude: {text}"),
            on_tool=lambda tool: print(f"Using: {tool.name}")
        )
        print(f"Cost: ${result.total_cost_usd:.4f}")
    """
    result = None

    async for message in query(prompt=prompt):
        if isinstance(message, AssistantMessage):
            for block in message.content:
                if isinstance(block, TextBlock) and on_text:
                    on_text(block.text)
                elif isinstance(block, ToolUseBlock) and on_tool:
                    on_tool(block)

        elif isinstance(message, ResultMessage):
            result = message

    return result


async def query_with_timeout(prompt: str, timeout_seconds: float = 30) -> Optional[str]:
    """Query with timeout protection.

    The SDK way: Use asyncio for timeout control.

    Args:
        prompt: What to ask Claude
        timeout_seconds: Maximum time to wait

    Returns:
        Response text or None if timeout

    Example:
        response = await query_with_timeout("Complex analysis", timeout_seconds=60)
        if response is None:
            print("Query timed out")
    """
    import asyncio

    try:
        # Create the query task
        async def _query():
            return await simple_query(prompt)

        # Run with timeout
        response = await asyncio.wait_for(_query(), timeout=timeout_seconds)
        return response

    except asyncio.TimeoutError:
        logger.warning(f"Query timed out after {timeout_seconds} seconds")
        return None
PYEOF
}

function adw_prompt() {
  cat <<'PYEOF' > ./agentics/adw_prompt.py
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "pydantic",
#   "click",
#   "rich",
# ]
# ///
"""
Run an adhoc Claude Code prompt from the command line.

Usage:
    # Method 1: Direct execution (requires uv)
    ./adw_prompt.py "Write a hello world Python script"

    # Method 2: Using uv run
    uv run adw_prompt.py "Write a hello world Python script"

    # Method 3: Using Python directly (requires dependencies installed)
    python adw_prompt.py "Write a hello world Python script"

Examples:
    # Run with specific model
    ./adw_prompt.py "Explain this code" --model opus

    # Run with custom output file
    ./adw_prompt.py "Create a FastAPI app" --output my_result.jsonl

    # Run from a different working directory
    ./adw_prompt.py "List files here" --working-dir /path/to/project

    # Disable retry on failure
    ./adw_prompt.py "Quick test" --no-retry

    # Use custom agent name
    ./adw_prompt.py "Debug this" --agent-name debugger
"""

import os
import sys
import json
from pathlib import Path
import click
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.syntax import Syntax
from rich.text import Text

# Add the agentic_modules directory to the path so we can import agent
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "agentic_modules"))

from agent import (
    prompt_claude_code,
    AgentPromptRequest,
    AgentPromptResponse,
    prompt_claude_code_with_retry,
    generate_short_id,
)

# Output file name constants
OUTPUT_JSONL = "cc_raw_output.jsonl"
OUTPUT_JSON = "cc_raw_output.json"
FINAL_OBJECT_JSON = "cc_final_object.json"
SUMMARY_JSON = "custom_summary_output.json"


@click.command()
@click.argument("prompt", required=True)
@click.option(
    "--model",
    type=click.Choice(["sonnet", "opus"]),
    default="sonnet",
    help="Claude model to use",
)
@click.option(
    "--output",
    type=click.Path(),
    help="Output file path (default: ./output/oneoff_<id>_output.jsonl)",
)
@click.option(
    "--working-dir",
    type=click.Path(exists=True, file_okay=False, dir_okay=True, resolve_path=True),
    help="Working directory for the prompt execution (default: current directory)",
)
@click.option("--no-retry", is_flag=True, help="Disable automatic retry on failure")
@click.option(
    "--agent-name", default="oneoff", help="Agent name for tracking (default: oneoff)"
)
def main(
    prompt: str,
    model: str,
    output: str,
    working_dir: str,
    no_retry: bool,
    agent_name: str,
):
    """Run an adhoc Claude Code prompt from the command line."""
    console = Console()

    # Generate a unique ID for this execution
    adw_id = generate_short_id()

    # Set up output file path
    if not output:
        # Default: write to agents/<adw_id>/<agent_name>/
        output_dir = Path(f"./agents/{adw_id}/{agent_name}")
        output_dir.mkdir(parents=True, exist_ok=True)
        output = str(output_dir / OUTPUT_JSONL)

    # Use current directory if no working directory specified
    if not working_dir:
        working_dir = os.getcwd()

    # Create the prompt request
    request = AgentPromptRequest(
        prompt=prompt,
        adw_id=adw_id,
        agent_name=agent_name,
        model=model,
        dangerously_skip_permissions=True,
        output_file=output,
        working_dir=working_dir,
    )

    # Create execution info table
    info_table = Table(show_header=False, box=None, padding=(0, 1))
    info_table.add_column(style="bold cyan")
    info_table.add_column()

    info_table.add_row("ADW ID", adw_id)
    info_table.add_row("ADW Name", "adw_prompt")
    info_table.add_row("Prompt", prompt)
    info_table.add_row("Model", model)
    info_table.add_row("Working Dir", working_dir)
    info_table.add_row("Output", output)

    console.print(
        Panel(
            info_table,
            title="[bold blue]Inputs[/bold blue]",
            border_style="blue",
        )
    )
    console.print()

    response: AgentPromptResponse | None = None

    try:
        # Execute the prompt
        with console.status("[bold yellow]Executing prompt...[/bold yellow]"):
            if no_retry:
                # Direct execution without retry

                response = prompt_claude_code(request)
            else:
                # Execute with retry logic
                response = prompt_claude_code_with_retry(request)

        # Display the result
        if response.success:
            # Success panel
            result_panel = Panel(
                response.output,
                title="[bold green]Success[/bold green]",
                border_style="green",
                padding=(1, 2),
            )
            console.print(result_panel)

            if response.session_id:
                console.print(
                    f"\n[bold cyan]Session ID:[/bold cyan] {response.session_id}"
                )
        else:
            # Error panel
            error_panel = Panel(
                response.output,
                title="[bold red]Failed[/bold red]",
                border_style="red",
                padding=(1, 2),
            )
            console.print(error_panel)

            if response.retry_code != "none":
                console.print(
                    f"\n[bold yellow]Retry code:[/bold yellow] {response.retry_code}"
                )

        # Show output file info
        console.print()

        # Also create a JSON summary file
        if output.endswith(f"/{OUTPUT_JSONL}"):
            # Default path: save as custom_summary_output.json in same directory
            simple_json_output = output.replace(f"/{OUTPUT_JSONL}", f"/{SUMMARY_JSON}")
        else:
            # Custom path: replace .jsonl with _summary.json
            simple_json_output = output.replace(".jsonl", "_summary.json")

        with open(simple_json_output, "w") as f:
            json.dump(
                {
                    "adw_id": adw_id,
                    "prompt": prompt,
                    "model": model,
                    "working_dir": working_dir,
                    "success": response.success,
                    "session_id": response.session_id,
                    "retry_code": response.retry_code,
                    "output": response.output,
                },
                f,
                indent=2,
            )

        # Files saved panel with descriptions
        files_table = Table(show_header=True, box=None)
        files_table.add_column("File Type", style="bold cyan")
        files_table.add_column("Path", style="dim")
        files_table.add_column("Description", style="italic")

        # Determine paths for all files
        output_dir = os.path.dirname(output)
        json_array_path = os.path.join(output_dir, OUTPUT_JSON)
        final_object_path = os.path.join(output_dir, FINAL_OBJECT_JSON)

        files_table.add_row(
            "JSONL Stream", output, "Raw streaming output from Claude Code"
        )
        files_table.add_row(
            "JSON Array", json_array_path, "All messages as a JSON array"
        )
        files_table.add_row(
            "Final Object", final_object_path, "Last message entry (final result)"
        )
        files_table.add_row(
            "Summary", simple_json_output, "High-level execution summary with metadata"
        )

        console.print(
            Panel(
                files_table,
                title="[bold blue]Output Files[/bold blue]",
                border_style="blue",
            )
        )

        # Exit with appropriate code
        sys.exit(0 if response.success else 1)

    except Exception as e:
        console.print(
            Panel(
                f"[bold red]{str(e)}[/bold red]",
                title="[bold red]Unexpected Error[/bold red]",
                border_style="red",
            )
        )
        sys.exit(2)


if __name__ == "__main__":
    main()
PYEOF
  chmod +x ./agentics/adw_prompt.py
}

function adw_sdk_prompt() {
  cat <<'PYEOF' > ./agentics/adw_sdk_prompt.py
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "pydantic",
#   "click",
#   "rich",
#   "claude-code-sdk",
#   "anyio",
# ]
# ///
"""
Run Claude Code prompts using the official Python SDK.

This ADW demonstrates using the Claude Code Python SDK for both one-shot
and interactive sessions. The SDK provides better type safety, error handling,
and a more Pythonic interface compared to subprocess-based implementations.

Usage:
    # One-shot query (default)
    ./agentics/adw_sdk_prompt.py "Hello Claude Code"

    # Interactive session
    ./agentics/adw_sdk_prompt.py --interactive

    # Resume a previous session
    ./agentics/adw_sdk_prompt.py --interactive --session-id abc123

    # With specific model
    ./agentics/adw_sdk_prompt.py "Create a FastAPI app" --model opus

    # From different directory
    ./agentics/adw_sdk_prompt.py "List files here" --working-dir /path/to/project

Examples:
    # Simple query
    ./agentics/adw_sdk_prompt.py "Explain async/await in Python"

    # Interactive debugging session
    ./agentics/adw_sdk_prompt.py --interactive --context "Debugging a memory leak"

    # Resume session with context
    ./agentics/adw_sdk_prompt.py --interactive --session-id abc123 --context "Continue debugging"

    # Query with tools
    ./agentics/adw_sdk_prompt.py "Create a Python web server" --tools Read,Write,Bash

Key Features:
    - Uses official Claude Code Python SDK
    - Supports both one-shot and interactive modes
    - Better error handling with typed exceptions
    - Native async/await support
    - Clean message type handling
"""

import os
import sys
import json
import asyncio
from pathlib import Path
from typing import Optional, List
import click
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.live import Live
from rich.spinner import Spinner
from rich.text import Text
from rich.prompt import Prompt

# Add the agentic_modules directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "agentic_modules"))

# Import SDK functions from our clean module
from agent_sdk import (
    simple_query,
    query_with_tools,
    collect_query_response,
    create_session,
    safe_query,
    stream_with_progress,
    extract_text,
    extract_tool_uses,
)

# Import SDK types
from claude_code_sdk import (
    ClaudeCodeOptions,
    AssistantMessage,
    ResultMessage,
    TextBlock,
    ToolUseBlock,
)


def generate_short_id() -> str:
    """Generate a short ID for tracking."""
    import uuid

    return str(uuid.uuid4())[:8]


async def run_one_shot_query(
    prompt: str,
    model: str,
    working_dir: str,
    allowed_tools: Optional[List[str]] = None,
    session_id: Optional[str] = None,
) -> None:
    """Run a one-shot query using the SDK."""
    console = Console()
    adw_id = generate_short_id()

    # Display execution info
    info_table = Table(show_header=False, box=None, padding=(0, 1))
    info_table.add_column(style="bold cyan")
    info_table.add_column()

    info_table.add_row("ADW ID", adw_id)
    info_table.add_row("Mode", "One-shot Query")
    info_table.add_row("Prompt", prompt)
    info_table.add_row("Model", model)
    info_table.add_row("Working Dir", working_dir)
    if allowed_tools:
        info_table.add_row("Tools", ", ".join(allowed_tools))
    if session_id:
        info_table.add_row("Session ID", session_id)
    info_table.add_row("[bold green]SDK[/bold green]", "Claude Code Python SDK")

    console.print(
        Panel(
            info_table,
            title="[bold blue]SDK Query Execution[/bold blue]",
            border_style="blue",
        )
    )
    console.print()

    try:
        # Execute query based on whether tools are needed
        with console.status("[bold yellow]Executing via SDK...[/bold yellow]"):
            if allowed_tools:
                # Query with tools
                options = ClaudeCodeOptions(
                    model=model,
                    allowed_tools=allowed_tools,
                    cwd=working_dir,
                    permission_mode="bypassPermissions",
                )
                if session_id:
                    options.resume = session_id
                messages, result = await collect_query_response(prompt, options=options)

                # Extract response text
                response_text = ""
                tool_uses = []

                for msg in messages:
                    if isinstance(msg, AssistantMessage):
                        text = extract_text(msg)
                        if text:
                            response_text += text + "\n"
                        for tool in extract_tool_uses(msg):
                            tool_uses.append(f"{tool.name} ({tool.id[:8]}...)")

                success = result and not result.is_error if result else False

            else:
                # Simple query
                response_text, error = await safe_query(prompt)
                success = error is None
                tool_uses = []

                if error:
                    response_text = error

        # Display result
        if success:
            console.print(
                Panel(
                    response_text.strip(),
                    title="[bold green]SDK Success[/bold green]",
                    border_style="green",
                    padding=(1, 2),
                )
            )

            if tool_uses:
                console.print(
                    f"\n[bold cyan]Tools used:[/bold cyan] {', '.join(tool_uses)}"
                )
        else:
            console.print(
                Panel(
                    response_text,
                    title="[bold red]SDK Error[/bold red]",
                    border_style="red",
                    padding=(1, 2),
                )
            )

        # Show cost and session info if available
        if "result" in locals() and result:
            if result.total_cost_usd:
                console.print(
                    f"\n[bold cyan]Cost:[/bold cyan] ${result.total_cost_usd:.4f}"
                )
            if hasattr(result, 'session_id') and result.session_id:
                console.print(
                    f"[bold cyan]Session ID:[/bold cyan] {result.session_id}"
                )
                console.print(
                    f"[dim]Resume with: --session-id {result.session_id}[/dim]"
                )

    except Exception as e:
        console.print(
            Panel(
                f"[bold red]{str(e)}[/bold red]",
                title="[bold red]Unexpected Error[/bold red]",
                border_style="red",
            )
        )


async def run_interactive_session(
    model: str,
    working_dir: str,
    context: Optional[str] = None,
    session_id: Optional[str] = None,
) -> None:
    """Run an interactive session using the SDK."""
    console = Console()
    adw_id = generate_short_id()

    # Display session info
    info_table = Table(show_header=False, box=None, padding=(0, 1))
    info_table.add_column(style="bold cyan")
    info_table.add_column()

    info_table.add_row("ADW ID", adw_id)
    info_table.add_row("Mode", "Interactive Session")
    info_table.add_row("Model", model)
    info_table.add_row("Working Dir", working_dir)
    if context:
        info_table.add_row("Context", context)
    if session_id:
        info_table.add_row("Session ID", session_id)
    info_table.add_row("[bold green]SDK[/bold green]", "Claude Code Python SDK")

    console.print(
        Panel(
            info_table,
            title="[bold blue]SDK Interactive Session[/bold blue]",
            border_style="blue",
        )
    )
    console.print()

    # Instructions
    console.print("[bold yellow]Interactive Mode[/bold yellow]")
    console.print("Commands: 'exit' or 'quit' to end session")
    console.print("Just type your questions or requests\n")

    # Start session
    options = ClaudeCodeOptions(
        model=model,
        cwd=working_dir,
        permission_mode="bypassPermissions",
    )
    if session_id:
        options.resume = session_id

    from claude_code_sdk import ClaudeSDKClient
    client = ClaudeSDKClient(options=options)
    await client.connect()

    # Track session ID from results throughout the session
    session_id_from_result = None

    try:
        # Send initial context if provided
        if context:
            console.print(f"[dim]Setting context: {context}[/dim]\n")
            await client.query(f"Context: {context}")

            # Consume the context response
            async for msg in client.receive_response():
                if isinstance(msg, AssistantMessage):
                    text = extract_text(msg)
                    if text:
                        console.print(f"[dim]Claude: {text}[/dim]\n")

        # Interactive loop
        while True:
            # Get user input
            try:
                user_input = Prompt.ask("[bold cyan]You[/bold cyan]")
            except (EOFError, KeyboardInterrupt):
                console.print("\n[yellow]Session interrupted[/yellow]")
                break

            if user_input.lower() in ["exit", "quit"]:
                break

            # Send to Claude
            await client.query(user_input)

            # Show response with progress
            console.print()
            response_parts = []
            tool_uses = []
            cost = None
            session_id_from_result = None

            with Live(
                Spinner("dots", text="Thinking..."),
                console=console,
                refresh_per_second=4,
            ):
                async for msg in client.receive_response():
                    if isinstance(msg, AssistantMessage):
                        text = extract_text(msg)
                        if text:
                            response_parts.append(text)

                        for tool in extract_tool_uses(msg):
                            tool_uses.append(f"{tool.name}")

                    elif isinstance(msg, ResultMessage):
                        if msg.total_cost_usd:
                            cost = msg.total_cost_usd
                        if hasattr(msg, 'session_id') and msg.session_id:
                            session_id_from_result = msg.session_id

            # Display response
            if response_parts:
                console.print("[bold green]Claude:[/bold green]")
                for part in response_parts:
                    console.print(part)

            if tool_uses:
                console.print(f"\n[dim]Tools used: {', '.join(tool_uses)}[/dim]")

            if cost:
                console.print(f"[dim]Cost: ${cost:.4f}[/dim]")

            if session_id_from_result:
                console.print(f"[dim]Session ID: {session_id_from_result}[/dim]")

            console.print()

    finally:
        await client.disconnect()

    console.print("\n[bold green]Session ended[/bold green]")
    console.print(f"[dim]ADW ID: {adw_id}[/dim]")
    if 'session_id_from_result' in locals() and session_id_from_result:
        console.print(f"[bold cyan]Session ID:[/bold cyan] {session_id_from_result}")
        console.print(f"[dim]Resume with: ./agentics/adw_sdk_prompt.py --interactive --session-id {session_id_from_result}[/dim]")


@click.command()
@click.argument("prompt", required=False)
@click.option(
    "--interactive",
    "-i",
    is_flag=True,
    help="Start an interactive session instead of one-shot query",
)
@click.option(
    "--model",
    type=click.Choice(["sonnet", "opus"]),
    default="sonnet",
    help="Claude model to use",
)
@click.option(
    "--working-dir",
    type=click.Path(exists=True, file_okay=False, dir_okay=True, resolve_path=True),
    help="Working directory (default: current directory)",
)
@click.option(
    "--tools",
    help="Comma-separated list of allowed tools (e.g., Read,Write,Bash)",
)
@click.option(
    "--context",
    help="Context for interactive session (e.g., 'Debugging a memory leak')",
)
@click.option(
    "--session-id",
    help="Resume a previous session by its ID",
)
def main(
    prompt: Optional[str],
    interactive: bool,
    model: str,
    working_dir: Optional[str],
    tools: Optional[str],
    context: Optional[str],
    session_id: Optional[str],
):
    """Run Claude Code prompts using the Python SDK.

    Examples:
        # One-shot query
        adw_sdk_prompt.py "What is 2 + 2?"

        # Interactive session
        adw_sdk_prompt.py --interactive

        # Resume session
        adw_sdk_prompt.py --interactive --session-id abc123

        # Query with tools
        adw_sdk_prompt.py "Create hello.py" --tools Write,Read
    """
    if not working_dir:
        working_dir = os.getcwd()

    # Convert model names
    model_map = {"sonnet": "claude-sonnet-4-20250514", "opus": "claude-opus-4-20250514"}
    full_model = model_map.get(model, model)

    # Parse tools if provided
    allowed_tools = None
    if tools:
        allowed_tools = [t.strip() for t in tools.split(",")]

    # Run appropriate mode
    if interactive:
        if prompt:
            console = Console()
            console.print(
                "[yellow]Warning: Prompt ignored in interactive mode[/yellow]\n"
            )

        asyncio.run(
            run_interactive_session(
                model=full_model,
                working_dir=working_dir,
                context=context,
                session_id=session_id,
            )
        )
    else:
        if not prompt:
            console = Console()
            console.print("[red]Error: Prompt required for one-shot mode[/red]")
            console.print("Use --interactive for interactive session")
            sys.exit(1)

        asyncio.run(
            run_one_shot_query(
                prompt=prompt,
                model=full_model,
                working_dir=working_dir,
                allowed_tools=allowed_tools,
                session_id=session_id,
            )
        )


if __name__ == "__main__":
    main()
PYEOF
  chmod +x ./agentics/adw_sdk_prompt.py
}

function adw_slash_command() {
  cat <<'PYEOF' > ./agentics/adw_slash_command.py
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "pydantic",
#   "click",
#   "rich",
# ]
# ///
"""
Run Claude Code slash commands from the command line.

Usage:
    # Method 1: Direct execution (requires uv)
    ./agentics/adw_slash_command.py /chore "Update documentation"

    # Method 2: Using uv run
    uv run agentics/adw_slash_command.py /implement specs/<name-of-spec>.md

    uv run agentics/adw_slash_command.py /start


Examples:
    # Run a slash command
    ./agentics/adw_slash_command.py /chore "Add logging to agent.py"

    # Run with specific model
    ./agentics/adw_slash_command.py /implement plan.md --model opus

    # Run from a different working directory
    ./agentics/adw_slash_command.py /test --working-dir /path/to/project

    # Use custom agent name
    ./agentics/adw_slash_command.py /review --agent-name reviewer
"""

import os
import sys
import json
from pathlib import Path
import click
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

# Add the agentic_modules directory to the path so we can import agent
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "agentic_modules"))

from agent import (
    AgentTemplateRequest,
    AgentPromptResponse,
    execute_template,
    generate_short_id,
)

# Output file name constants
OUTPUT_JSONL = "cc_raw_output.jsonl"
OUTPUT_JSON = "cc_raw_output.json"
FINAL_OBJECT_JSON = "cc_final_object.json"
SUMMARY_JSON = "custom_summary_output.json"


@click.command()
@click.argument("slash_command", required=True)
@click.argument("args", nargs=-1)  # Accept multiple optional arguments
@click.option(
    "--model",
    type=click.Choice(["sonnet", "opus"]),
    default="sonnet",
    help="Claude model to use",
)
@click.option(
    "--working-dir",
    type=click.Path(exists=True, file_okay=False, dir_okay=True, resolve_path=True),
    help="Working directory for command execution (default: current directory)",
)
@click.option(
    "--agent-name",
    default="executor",
    help="Agent name for tracking (default: executor)",
)
def main(
    slash_command: str,
    args: tuple,
    model: str,
    working_dir: str,
    agent_name: str,
):
    """Run Claude Code slash commands from the command line."""
    console = Console()

    # Generate a unique ID for this execution
    adw_id = generate_short_id()

    # Use current directory if no working directory specified
    if not working_dir:
        working_dir = os.getcwd()

    # Create the template request
    request = AgentTemplateRequest(
        agent_name=agent_name,
        slash_command=slash_command,
        args=list(args),  # Convert tuple to list
        adw_id=adw_id,
        model=model,
        working_dir=working_dir,
    )

    # Create execution info table
    info_table = Table(show_header=False, box=None, padding=(0, 1))
    info_table.add_column(style="bold cyan")
    info_table.add_column()

    info_table.add_row("ADW ID", adw_id)
    info_table.add_row("ADW Name", "adw_slash_command")
    info_table.add_row("Command", slash_command)
    info_table.add_row("Args", " ".join(args) if args else "(none)")
    info_table.add_row("Model", model)
    info_table.add_row("Working Dir", working_dir)

    console.print(
        Panel(
            info_table,
            title="[bold blue]Inputs[/bold blue]",
            border_style="blue",
        )
    )
    console.print()

    try:
        # Execute the slash command
        with console.status("[bold yellow]Executing command...[/bold yellow]"):
            response = execute_template(request)

        # Display the result
        if response.success:
            # Success panel
            result_panel = Panel(
                response.output,
                title="[bold green]Success[/bold green]",
                border_style="green",
                padding=(1, 2),
            )
            console.print(result_panel)

            if response.session_id:
                console.print(
                    f"\n[bold cyan]Session ID:[/bold cyan] {response.session_id}"
                )
        else:
            # Error panel
            error_panel = Panel(
                response.output,
                title="[bold red]Failed[/bold red]",
                border_style="red",
                padding=(1, 2),
            )
            console.print(error_panel)

            if response.retry_code != "none":
                console.print(
                    f"\n[bold yellow]Retry code:[/bold yellow] {response.retry_code}"
                )

        # Show output file info
        console.print()

        # Output files are in agents/<adw_id>/<agent_name>/
        output_dir = f"./agents/{adw_id}/{agent_name}"

        # Create the simple JSON summary file
        simple_json_output = f"{output_dir}/{SUMMARY_JSON}"

        # Determine the template file path
        command_name = slash_command.lstrip("/")  # Remove leading slash
        path_to_slash_command_prompt = f".claude/commands/{command_name}.md"

        with open(simple_json_output, "w") as f:
            json.dump(
                {
                    "adw_id": adw_id,
                    "slash_command": slash_command,
                    "args": list(args),
                    "path_to_slash_command_prompt": path_to_slash_command_prompt,
                    "model": model,
                    "working_dir": working_dir,
                    "success": response.success,
                    "session_id": response.session_id,
                    "retry_code": response.retry_code,
                    "output": response.output,
                },
                f,
                indent=2,
            )

        # Files saved panel
        files_table = Table(show_header=True, box=None)
        files_table.add_column("File Type", style="bold cyan")
        files_table.add_column("Path", style="dim")
        files_table.add_column("Description", style="italic")

        files_table.add_row(
            "JSONL Stream",
            f"{output_dir}/{OUTPUT_JSONL}",
            "Raw streaming output from Claude Code",
        )
        files_table.add_row(
            "JSON Array",
            f"{output_dir}/{OUTPUT_JSON}",
            "All messages as a JSON array",
        )
        files_table.add_row(
            "Final Object",
            f"{output_dir}/{FINAL_OBJECT_JSON}",
            "Last message entry (final result)",
        )
        files_table.add_row(
            "Summary",
            simple_json_output,
            "High-level execution summary with metadata",
        )

        console.print(
            Panel(
                files_table,
                title="[bold blue]Output Files[/bold blue]",
                border_style="blue",
            )
        )

        # Exit with appropriate code
        sys.exit(0 if response.success else 1)

    except Exception as e:
        console.print(
            Panel(
                f"[bold red]{str(e)}[/bold red]",
                title="[bold red]Unexpected Error[/bold red]",
                border_style="red",
            )
        )
        sys.exit(2)


if __name__ == "__main__":
    main()
PYEOF
  chmod +x ./agentics/adw_slash_command.py
}

function readme() {
  cat <<'EOF' > ./agentics/README.md
# AI Developer Workflows (ADWs)

## Overview

The `agentics/` directory contains the **AI Developer Workflows** - the highest compositional level of the agentic layer. These are executable Python scripts that combine deterministic code with non-deterministic, compute-scalable agents to perform complex development tasks on your application layer.

ADWs represent a paradigm shift: instead of directly modifying code ourselves, we template our engineering patterns and teach agents how to operate our codebases. This allows us to scale compute to scale our impact.

## Core Philosophy

- **Template Engineering**: Capture and reuse engineering patterns
- **Agent Orchestration**: Combine multiple agents for complex workflows
- **Compute Scalability**: Scale development effort through parallel agent execution
- **Observability**: Track and debug agent actions through structured outputs

## Architecture Evolution

### Minimum Viable ADW Structure

```
agentics/
   agentic_modules/
       agent.py                # Core agent execution module
   adw_*.py                    # Single-file workflow scripts (uv astral)
```

The minimum viable structure focuses on:
- **Core execution** (`agent.py`): Essential agent interaction logic
- **Simple workflows** (`adw_*.py`): Standalone scripts using uv for dependency management

### Scaled ADW Structure

```
agentics/
   agentic_modules/                # Core reusable modules
       agent.py                # Agent execution
       agent_sdk.py            # SDK-based execution
       data_types.py           # Type definitions
       git_ops.py              # Git operations
       github.py               # GitHub integration
       state.py                # State management
       workflow_ops.py         # Workflow orchestration
       worktree_ops.py         # Worktree management

   adw_triggers/               # Invocation patterns
       trigger_webhook.py      # Webhook-based triggers
       trigger_cron.py         # Scheduled execution
       adw_trigger_*.py        # Custom triggers

   adw_tests/                  # Testing infrastructure
       test_agents.py          # Agent behavior tests
       test_*.py               # Component tests

   adw_data/                   # Persistent storage
       agents.db               # Agent database
       backups/                # Database backups

   # Individual workflows
   adw_plan_iso.py             # Planning workflow
   adw_build_iso.py            # Build workflow
   adw_test_iso.py             # Testing workflow
   adw_review_iso.py           # Review workflow
   adw_document_iso.py         # Documentation workflow
   adw_patch_iso.py            # Patching workflow

   # Composed workflows
   adw_plan_build_iso.py       # Plan + Build
   adw_plan_build_test_iso.py  # Plan + Build + Test
   adw_sdlc_iso.py             # Full SDLC workflow
   adw_sdlc_zte_iso.py         # Zero-touch engineering
   adw_ship_iso.py             # Ship to production
```

## Key Components

### 1. Core Module: `agent.py`

The foundation module that provides:
- **AgentPromptRequest/Response**: Data models for prompt execution
- **AgentTemplateRequest**: Data model for slash command execution
- **prompt_claude_code()**: Direct Claude Code CLI execution
- **prompt_claude_code_with_retry()**: Execution with automatic retry logic
- **execute_template()**: Slash command template execution
- **Environment management**: Safe subprocess environment handling
- **Output parsing**: JSONL to JSON conversion and result extraction

### 2. Direct Prompt Execution: `adw_prompt.py`

Execute adhoc Claude Code prompts from the command line.

**Usage:**
```bash
# Direct execution (requires uv)
./agentics/adw_prompt.py "Write a hello world Python script"

# With specific model
./agentics/adw_prompt.py "Explain this code" --model opus

# From different directory
./agentics/adw_prompt.py "List files here" --working-dir /path/to/project
```

**Features:**
- Direct prompt execution without templates
- Configurable models (sonnet/opus)
- Custom output paths
- Automatic retry on failure
- Rich console output with progress indicators

### 3. Slash Command Execution: `adw_slash_command.py`

Execute predefined slash commands from `.claude/commands/*.md` templates.

**Usage:**
```bash
# Run a slash command
./agentics/adw_slash_command.py /chore "Add logging to agent.py"

# With arguments
./agentics/adw_slash_command.py /implement specs/feature.md

# Start a new session
./agentics/adw_slash_command.py /start
```

**Available Commands:**
- `/chore` - Create implementation plans
- `/implement` - Execute implementation plans
- `/prime` - Prime the agent with context
- `/start` - Start a new agent session

### 4. Compound Workflow: `adw_chore_implement.py`

Orchestrates a two-phase workflow: planning (/chore) followed by implementation (/implement).

**Usage:**
```bash
# Plan and implement a feature
./agentics/adw_chore_implement.py "Add error handling to all API endpoints"

# With specific model
./agentics/adw_chore_implement.py "Refactor database logic" --model opus
```

**Workflow Phases:**
1. **Planning Phase**: Executes `/chore` to create a detailed plan
2. **Implementation Phase**: Automatically executes `/implement` with the generated plan

## SDK-Based ADWs

In addition to subprocess-based execution, ADWs now support the Claude Code Python SDK for better type safety and native async/await patterns.

### SDK Module: `agent_sdk.py`

The SDK module provides idiomatic patterns for using the Claude Code Python SDK:
- **Simple queries** - `simple_query()` for basic text responses
- **Tool-enabled queries** - `query_with_tools()` for operations requiring tools
- **Interactive sessions** - `create_session()` context manager for conversations
- **Error handling** - `safe_query()` with SDK-specific exception handling

### SDK Execution: `adw_sdk_prompt.py`

Execute Claude Code using the Python SDK instead of subprocess.

**Usage:**
```bash
# One-shot query
./agentics/adw_sdk_prompt.py "Write a hello world Python script"

# Interactive session
./agentics/adw_sdk_prompt.py --interactive

# With tools
./agentics/adw_sdk_prompt.py "Create hello.py" --tools Write,Read

# Interactive with context
./agentics/adw_sdk_prompt.py --interactive --context "Debugging a memory leak"
```

### SDK vs Subprocess

| Feature | Subprocess (agent.py) | SDK (agent_sdk.py) |
|---------|----------------------|-------------------|
| Type Safety | Basic dictionaries | Typed message objects |
| Error Handling | Generic exceptions | SDK-specific exceptions |
| Async Support | Subprocess management | Native async/await |
| Interactive Sessions | Not supported | ClaudeSDKClient |

## Output Structure & Observability

### Minimum Viable Output

```
agents/
   {adw_id}/                   # Unique 8-character ID per execution
       {agent_name}/            # Agent-specific outputs
          cc_raw_output.jsonl  # Raw streaming output
          cc_final_object.json # Final result object
```

### Scaled Output Structure

```
agents/                         # Comprehensive observability
   {adw_id}/                   # Unique workflow execution
       adw_state.json          # Workflow state tracking

       # Per-agent outputs
       {agent_name}/
          cc_raw_output.jsonl  # Raw streaming output
          cc_raw_output.json   # Parsed JSON array
          cc_final_object.json # Final result object
          custom_summary_output.json # High-level summary

       # Specialized agent outputs
       branch_generator/       # Branch naming
       issue_classifier/       # Issue categorization
       sdlc_planner/          # SDLC planning
       sdlc_implementor/      # Implementation
       reviewer/              # Code review
       documenter/            # Documentation

       # Workflow metadata
       workflow_summary.json   # Overall summary
       workflow_metrics.json   # Performance metrics
```

This structure provides:
- **Debugging**: Raw outputs for troubleshooting
- **Analysis**: Structured JSON for programmatic processing
- **Metrics**: Performance and success tracking
- **Audit Trail**: Complete history of agent actions

## Data Flow

1. **Input**: User provides prompt/command + arguments
2. **Template Composition**: ADW loads slash command template from `.claude/commands/`
3. **Execution**: Claude Code CLI processes the prompt
4. **Output Parsing**: JSONL stream parsed into structured JSON
5. **Result Storage**: Multiple output formats saved for analysis

## Key Features

### Retry Logic
- Automatic retry for transient failures
- Configurable retry attempts and delays
- Different retry codes for various error types

### Environment Safety
- Filtered environment variables for subprocess execution
- Only passes required variables (API keys, paths, etc.)
- Prevents environment variable leakage

### Rich Console UI
- Progress indicators during execution
- Colored output panels for success/failure
- Structured tables showing inputs and outputs
- File path listings for generated outputs

### Session Tracking
- Unique ADW IDs for each execution
- Session IDs from Claude Code for debugging
- Comprehensive logging and output capture

## Best Practices

1. **Use the Right Tool**:
   - `adw_prompt.py` for one-off tasks
   - `adw_slash_command.py` for templated operations
   - `adw_chore_implement.py` for complex features
   - `adw_sdk_prompt.py` for type-safe SDK operations or interactive sessions

2. **Model Selection**:
   - Use `sonnet` (default) for most tasks
   - Use `opus` for complex reasoning or large codebases

3. **Working Directory**:
   - Always specify `--working-dir` when operating on different projects
   - ADWs respect `.mcp.json` configuration in working directories

4. **Output Analysis**:
   - Check `custom_summary_output.json` for high-level results
   - Use `cc_final_object.json` for the final agent response
   - Review `cc_raw_output.jsonl` for debugging

## Integration Points

### Core Integrations

- **Slash Commands** (`.claude/commands/*.md`): Templated agent prompts
- **Application Layer** (`apps/*`): Target codebase for modifications
- **Specifications** (`specs/*`): Implementation plans and requirements
- **AI Documentation** (`ai_docs/*`): Context and reference materials

### Extended Integrations (Scaled)

- **Worktrees** (`trees/*`): Isolated environments for agent operations
- **MCP Configuration** (`.mcp.json`): Model Context Protocol settings
- **Hooks** (`.claude/hooks/*`): Event-driven automation
- **Deep Specs** (`deep_specs/*`): Complex architectural specifications
- **App Documentation** (`app_docs/*`): Generated feature documentation
- **GitHub Integration**: Issue tracking, PR creation, and automation
- **External Services**: Webhooks, CI/CD, monitoring systems

## Error Handling

ADWs implement robust error handling:
- Installation checks for Claude Code CLI
- Timeout protection (5-minute default)
- Graceful failure with informative error messages
- Retry codes for different failure types
- Output truncation to prevent console flooding

## Flexibility & Customization

The ADW structure is intentionally flexible. This is just *one way* to organize your agentic layer. Key principles to maintain:

1. **Separation of Concerns**: Keep agent logic separate from application code
2. **Composability**: Build complex workflows from simple components
3. **Observability**: Maintain clear audit trails of agent actions
4. **Scalability**: Design for parallel execution and compute scaling
5. **Testability**: Ensure agent behavior can be validated

Adapt the structure to your team's needs, development patterns, and scale requirements.

## Getting Started

### Minimum Viable Setup

1. Create basic ADW structure:
   ```bash
   mkdir -p agentics/agentic_modules
   mkdir -p specs
   mkdir -p .claude/commands
   ```

2. Add core agent module (`agentic_modules/agent.py`)
3. Create your first workflow script (`adw_prompt.py`)
4. Define slash commands (`.claude/commands/chore.md`)

### Scaling Up

As your needs grow, incrementally add:
- Type definitions for better IDE support
- Triggers for automation
- Tests for reliability
- State management for complex workflows
- Worktrees for isolation
- Metrics for performance tracking

---

The ADW layer represents the pinnacle of abstraction in agentic coding, turning high-level developer intentions into executed code changes through intelligent agent orchestration. It's where we scale our impact by scaling compute, not just effort.
EOF
}

# --- Execute all functions in order ---
claude_loop
agentics
agentic_instructions
agentic_modules_agentic_instructions
agent_module
agent_sdk_module
adw_prompt
adw_sdk_prompt
adw_slash_command
chore
readme
uv_deps

echo "Finalized Agentic Layer"
