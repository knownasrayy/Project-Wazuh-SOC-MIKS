#!/usr/bin/env python3
# =============================================================
# Script  : ai_verdict.py
# Role    : A6 — AI Engineer (Integration ke Wazuh)
# Lokasi  : /var/ossec/active-response/bin/ai_verdict.py (di VM1)
# Deskripsi: Wazuh Active Response script yang:
#            1. Menerima alert dari Wazuh via stdin (JSON)
#            2. Forward alert ke Flask AI server (/predict)
#            3. Log hasilnya ke /var/ossec/logs/ai_verdicts.log
#
# Install di VM1:
#   sudo cp ai_verdict.py /var/ossec/active-response/bin/
#   sudo chmod 750 /var/ossec/active-response/bin/ai_verdict.py
#   sudo chown root:wazuh /var/ossec/active-response/bin/ai_verdict.py
#
# Catatan:
#   Script ini dipanggil otomatis oleh Wazuh Engine saat
#   alert memenuhi rule yang didefinisikan di ossec.conf.
#   JANGAN jalankan manual kecuali untuk testing.
# =============================================================

import sys
import os
import json
import datetime
import urllib.request
import urllib.error

# ═══════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════

# Flask AI Server endpoint (running on VM1 localhost)
AI_SERVER_URL = os.environ.get(
    "SOC_AI_SERVER_URL",
    "http://127.0.0.1:5000/predict"
)

# Log file for AI verdicts
VERDICT_LOG = os.environ.get(
    "SOC_VERDICT_LOG",
    "/var/ossec/logs/active-responses.log"
)

# Timeout for HTTP request to AI server (seconds)
REQUEST_TIMEOUT = int(os.environ.get("SOC_REQUEST_TIMEOUT", "5"))

# Wazuh ossec log path (for writing custom alerts)
OSSEC_LOG_DIR = "/var/ossec/logs"

# Dedicated AI verdict log
AI_VERDICT_LOG = os.environ.get(
    "SOC_AI_VERDICT_LOG",
    "/var/ossec/logs/ai_verdicts.log"
)


# ═══════════════════════════════════════════════════════════════
# LOGGING UTILITY
# ═══════════════════════════════════════════════════════════════

def log_message(message, level="INFO"):
    """Write a timestamped message to the AI verdict log."""
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%S.%fZ"
    )
    log_line = f"{timestamp} [{level}] ai_verdict: {message}\n"

    try:
        with open(AI_VERDICT_LOG, "a", encoding="utf-8") as f:
            f.write(log_line)
    except Exception:
        # Fallback to stderr if log file is not writable
        sys.stderr.write(log_line)


def write_active_response_log(alert_data, verdict, confidence):
    """
    Write verdict to active-responses.log in a format that
    Wazuh can parse with a custom decoder + rule.
    Format: ai_verdict:<VERDICT>|confidence:<SCORE>|rule_id:<ID>|src_ip:<IP>|agent:<NAME>
    """
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y/%m/%d %H:%M:%S"
    )

    rule_id = alert_data.get("rule", {}).get("id", "0")
    src_ip = alert_data.get("data", {}).get("srcip", "N/A")
    agent_name = alert_data.get("agent", {}).get("name", "N/A")
    rule_desc = alert_data.get("rule", {}).get("description", "N/A")

    log_entry = (
        f"{timestamp} ai_verdict: "
        f"verdict:{verdict}|"
        f"confidence:{confidence:.4f}|"
        f"rule_id:{rule_id}|"
        f"src_ip:{src_ip}|"
        f"agent:{agent_name}|"
        f"description:{rule_desc}"
    )

    try:
        with open(VERDICT_LOG, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")
    except Exception as e:
        log_message(f"Failed to write to active-responses.log: {e}", "ERROR")


# ═══════════════════════════════════════════════════════════════
# WAZUH ACTIVE RESPONSE PROTOCOL
# ═══════════════════════════════════════════════════════════════

def read_alert_from_stdin():
    """
    Read the alert from stdin as per Wazuh Active Response protocol.

    Wazuh sends the alert JSON as a single line to stdin.
    The format is a JSON object containing the alert data
    under different possible keys depending on the Wazuh version.

    Returns:
        dict — the parsed alert data, or None on failure
    """
    try:
        input_data = sys.stdin.read()
        if not input_data.strip():
            log_message("Empty input received from stdin", "WARNING")
            return None

        alert_wrapper = json.loads(input_data)

        # Wazuh 4.x active response format:
        # The alert is nested under "parameters" -> "alert"
        if "parameters" in alert_wrapper:
            alert = alert_wrapper.get("parameters", {}).get("alert", {})
            if alert:
                return alert

        # Fallback: the input might be the raw alert itself
        if "rule" in alert_wrapper:
            return alert_wrapper

        # Another fallback: check for "data" wrapper
        if "data" in alert_wrapper and isinstance(alert_wrapper["data"], dict):
            return alert_wrapper["data"]

        log_message(f"Unrecognized alert format. Keys: {list(alert_wrapper.keys())}", "WARNING")
        return alert_wrapper

    except json.JSONDecodeError as e:
        log_message(f"Failed to parse stdin JSON: {e}", "ERROR")
        log_message(f"Raw input (first 500 chars): {input_data[:500]}", "DEBUG")
        return None
    except Exception as e:
        log_message(f"Error reading stdin: {e}", "ERROR")
        return None


# ═══════════════════════════════════════════════════════════════
# AI PREDICTION
# ═══════════════════════════════════════════════════════════════

def get_ai_prediction(alert_data):
    """
    Send the alert to the Flask AI server and get the prediction.

    Args:
        alert_data: dict — raw Wazuh alert JSON

    Returns:
        tuple (verdict: str, confidence: float) or (None, None) on failure
    """
    try:
        payload = json.dumps(alert_data).encode("utf-8")

        req = urllib.request.Request(
            AI_SERVER_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as response:
            result = json.loads(response.read().decode("utf-8"))

        verdict = result.get("ai_verdict", "UNKNOWN")
        confidence = float(result.get("ai_confidence", 0.0))

        return verdict, confidence

    except urllib.error.URLError as e:
        log_message(
            f"Cannot reach AI server at {AI_SERVER_URL}: {e}",
            "ERROR"
        )
        return None, None

    except urllib.error.HTTPError as e:
        log_message(
            f"AI server returned HTTP {e.code}: {e.read().decode('utf-8', errors='replace')[:200]}",
            "ERROR"
        )
        return None, None

    except Exception as e:
        log_message(f"Unexpected error calling AI server: {e}", "ERROR")
        return None, None


# ═══════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════

def main():
    """
    Main entry point for the Wazuh Active Response script.

    Flow:
    1. Read alert from stdin (Wazuh protocol)
    2. Forward to Flask AI server
    3. Log the verdict
    4. Exit cleanly (Wazuh expects exit code 0)
    """
    log_message("Active response script triggered")

    # Step 1: Read alert from stdin
    alert_data = read_alert_from_stdin()
    if alert_data is None:
        log_message("No valid alert data received. Exiting.", "ERROR")
        sys.exit(0)  # Exit 0 to prevent Wazuh from flagging an error

    rule_id = alert_data.get("rule", {}).get("id", "?")
    agent_name = alert_data.get("agent", {}).get("name", "?")
    log_message(f"Processing alert: rule_id={rule_id}, agent={agent_name}")

    # Step 2: Get AI prediction
    verdict, confidence = get_ai_prediction(alert_data)

    if verdict is None:
        log_message(
            f"AI server unavailable. Alert rule_id={rule_id} passed through without verdict.",
            "WARNING"
        )
        # Write a fallback entry so A7 SOAR can still see it
        write_active_response_log(alert_data, "UNKNOWN", 0.0)
        sys.exit(0)

    # Step 3: Log the verdict
    log_message(
        f"RESULT: verdict={verdict} confidence={confidence:.4f} "
        f"rule_id={rule_id} agent={agent_name}"
    )

    # Write to active-responses.log for Wazuh to parse
    write_active_response_log(alert_data, verdict, confidence)

    # Step 4: Additional action based on verdict
    if verdict == "TP":
        log_message(
            f"⚠ TRUE POSITIVE detected! rule_id={rule_id} "
            f"confidence={confidence:.4f} — forwarding to SOAR (A7)"
        )
    elif verdict == "FP":
        log_message(
            f"✓ FALSE POSITIVE suppressed: rule_id={rule_id} "
            f"confidence={confidence:.4f}"
        )

    # Exit cleanly
    sys.exit(0)


if __name__ == "__main__":
    main()
