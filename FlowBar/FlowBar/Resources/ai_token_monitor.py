#!/usr/bin/env python3
"""
FlowBar - AI Token Monitor
===========================
Monitors Claude (Anthropic) and OpenAI token/cost usage.
- Logs current usage to stdout
- Sends macOS notification when approaching budget
- Creates a 5-minute "AI Token Budget Reset" event in Apple Calendar (weekly)

Environment variables (or set in FlowBar workflow env vars):
  ANTHROPIC_API_KEY   - Your Anthropic API key
  OPENAI_API_KEY      - Your OpenAI API key
  BUDGET_USD          - Monthly $ budget threshold (default: 50)
  CALENDAR_NAME       - Target Apple Calendar name (default: AI)

Usage:
  python3 ai_token_monitor.py
"""

import os
import sys
import json
import subprocess
from datetime import datetime, timedelta
from urllib.request import urlopen, Request
from urllib.error import URLError

# ── Config ──────────────────────────────────────────────────────────────────
ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")
OPENAI_API_KEY    = os.environ.get("OPENAI_API_KEY", "")
BUDGET_USD        = float(os.environ.get("BUDGET_USD", "50"))
CALENDAR_NAME     = os.environ.get("CALENDAR_NAME", "AI")
BUDGET_HOURS      = float(os.environ.get("BUDGET_HOURS", "5"))  # token "hours" budget

# ── Helpers ──────────────────────────────────────────────────────────────────

def notify(title: str, body: str) -> None:
    """Send a macOS notification via osascript."""
    script = f'display notification "{body}" with title "{title}"'
    subprocess.run(["osascript", "-e", script], capture_output=True)


def fetch_json(url: str, headers: dict) -> dict | None:
    req = Request(url, headers=headers)
    try:
        with urlopen(req, timeout=10) as resp:
            return json.loads(resp.read())
    except URLError as e:
        print(f"  [warn] HTTP error: {e}", file=sys.stderr)
        return None


# ── Anthropic Usage ─────────────────────────────────────────────────────────

def check_anthropic() -> dict:
    if not ANTHROPIC_API_KEY:
        print("  [skip] ANTHROPIC_API_KEY not set")
        return {}

    # Anthropic doesn't have a public usage API yet; approximate from billing
    # Replace this with the real endpoint when available
    print("  [anthropic] Checking usage (placeholder - add real API call)")
    return {"provider": "Anthropic", "status": "ok", "note": "Configure real API endpoint"}


# ── OpenAI Usage ─────────────────────────────────────────────────────────────

def check_openai() -> dict:
    if not OPENAI_API_KEY:
        print("  [skip] OPENAI_API_KEY not set")
        return {}

    today    = datetime.utcnow()
    month_start = today.replace(day=1).strftime("%Y-%m-%d")
    url = f"https://api.openai.com/v1/usage?date={month_start}"
    headers = {"Authorization": f"Bearer {OPENAI_API_KEY}"}

    data = fetch_json(url, headers)
    if not data:
        return {"provider": "OpenAI", "status": "error"}

    total_tokens = sum(
        item.get("n_context_tokens_total", 0) + item.get("n_generated_tokens_total", 0)
        for item in data.get("data", [])
    )
    print(f"  [openai] Total tokens this month: {total_tokens:,}")
    return {"provider": "OpenAI", "tokens": total_tokens, "status": "ok"}


# ── Apple Calendar ────────────────────────────────────────────────────────────

def create_weekly_reset_meeting() -> None:
    """
    Creates a 5-minute 'AI Token Budget Reset' event in Apple Calendar
    every Monday at 09:00 (or the next Monday from now).
    """
    # Find next Monday
    today   = datetime.now()
    days_ahead = (0 - today.weekday()) % 7  # 0 = Monday
    if days_ahead == 0:
        days_ahead = 7
    next_monday = today + timedelta(days=days_ahead)
    event_date  = next_monday.replace(hour=9, minute=0, second=0, microsecond=0)

    # Format for AppleScript
    def fmt(d: datetime) -> str:
        return d.strftime("%A, %B %d, %Y at %I:%M:%S %p")

    start_str = fmt(event_date)
    end_str   = fmt(event_date + timedelta(minutes=5))

    applescript = f"""
tell application "Calendar"
    set calName to "{CALENDAR_NAME}"
    set targetCal to missing value
    repeat with c in (every calendar)
        if name of c is calName then
            set targetCal to c
            exit repeat
        end if
    end repeat
    if targetCal is missing value then
        set targetCal to make new calendar with properties {{name:calName}}
    end if
    set startDate to date "{start_str}"
    set endDate to date "{end_str}"
    make new event at end of events of targetCal with properties {{\\
        summary:"AI Token Budget Reset (Weekly)", \\
        start date:startDate, \\
        end date:endDate, \\
        description:"Weekly AI token budget resets. Review usage and adjust limits."}}
end tell
"""
    result = subprocess.run(["osascript", "-e", applescript], capture_output=True, text=True)
    if result.returncode == 0:
        print(f"  [calendar] Meeting created: {CALENDAR_NAME} / AI Token Budget Reset on {event_date.strftime('%Y-%m-%d')}")
    else:
        print(f"  [calendar] Error: {result.stderr.strip()}", file=sys.stderr)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print(f"[{datetime.now().isoformat()}] FlowBar AI Token Monitor starting...")

    results = []

    print("\n→ Anthropic (Claude)")
    anthropic = check_anthropic()
    results.append(anthropic)

    print("\n→ OpenAI")
    openai = check_openai()
    results.append(openai)

    # Check if it's a weekly reset day (Monday)
    if datetime.now().weekday() == 0:  # Monday
        print("\n→ Creating weekly reset calendar event…")
        create_weekly_reset_meeting()

    # Budget alert
    total_usd = sum(r.get("cost_usd", 0) for r in results)
    if total_usd >= BUDGET_USD * 0.8:
        notify(
            "⚠️ AI Budget Alert",
            f"${total_usd:.2f} of ${BUDGET_USD:.2f} monthly budget used."
        )

    print("\n✅ Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
