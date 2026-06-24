#!/usr/bin/env python3
# =============================================================
# Script  : ai_server.py
# Role    : A6 — AI Engineer (Integration ke Wazuh)
# Deskripsi: Flask REST API server untuk inferensi model ML
#            terhadap alert Wazuh secara real-time.
#
# Endpoint:
#   POST /predict   — Terima alert JSON Wazuh, return AI verdict
#   GET  /health    — Health check
#   GET  /stats     — Statistik prediksi sejak server start
#
# Cara Jalankan (di VM1 — Wazuh Manager):
#   pip install flask joblib scikit-learn pandas
#   python3 ai_server.py
#
# Server akan listen di http://0.0.0.0:5000
# =============================================================

import os
import sys
import json
import logging
import warnings
from datetime import datetime, timezone
from collections import deque
from threading import Lock

from flask import Flask, request, jsonify

# Suppress sklearn version warnings (A5 trained on 1.8, server may use 1.9)
warnings.filterwarnings("ignore", category=UserWarning)

try:
    import joblib
    import pandas as pd
    import numpy as np
except ImportError as e:
    print(f"[!] Missing dependency: {e}")
    print("    Install with: pip install joblib scikit-learn pandas numpy")
    sys.exit(1)


# ═══════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════

# Paths — sesuaikan dengan lokasi deployment di VM1
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.environ.get(
    "SOC_MODEL_PATH",
    os.path.join(BASE_DIR, "..", "soc_model_random_forest.pkl")
)
FEATURES_PATH = os.environ.get(
    "SOC_FEATURES_PATH",
    os.path.join(BASE_DIR, "..", "feature_names.pkl")
)

# Server config
HOST = os.environ.get("SOC_HOST", "0.0.0.0")
PORT = int(os.environ.get("SOC_PORT", "5000"))

# Sliding window for hit_count_60s computation
HIT_WINDOW_SECONDS = 60

# Infrastructure IPs (from A1 setup)
ATTACKER_IP = "10.0.0.6"   # VM3 (agent-vm3)
TARGET_IP = "10.0.0.5"     # VM2 (agent-vm2)


# ═══════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(
            os.environ.get("SOC_LOG_PATH", "/var/ossec/logs/ai_server.log"),
            mode="a",
            encoding="utf-8",
        )
    ] if os.path.isdir("/var/ossec/logs") else [logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("ai_server")


# ═══════════════════════════════════════════════════════════════
# AGENT NAME ENCODING
# Exact mapping from A5's LabelEncoder (sklearn alphabetical)
# Verified from A5_SOC_ML_Model.ipynb Cell 9:
#   le_agent.fit_transform(['agent-vm2','agent-vm3','vm1-manager'])
#   → agent-vm2=0, agent-vm3=1, vm1-manager=2
# ═══════════════════════════════════════════════════════════════

AGENT_NAME_ENCODING = {
    "agent-vm2": 0,
    "agent-vm3": 1,
    "vm1-manager": 2,
}


# ═══════════════════════════════════════════════════════════════
# HIT COUNTER (sliding window for hit_count_60s)
# ═══════════════════════════════════════════════════════════════

class HitCounter:
    """
    Thread-safe sliding window counter that tracks how many alerts
    from the same src_ip were seen in the last 60 seconds.
    Replicates A4's hit_count_60s feature engineering.
    """

    def __init__(self, window_seconds=60):
        self.window = window_seconds
        self.events = deque()  # (timestamp, src_ip)
        self.lock = Lock()

    def add_and_count(self, src_ip, timestamp=None):
        """Add an event and return the count for this src_ip in the window."""
        if timestamp is None:
            timestamp = datetime.now(timezone.utc)

        with self.lock:
            # Add new event
            self.events.append((timestamp, src_ip))

            # Prune expired events
            cutoff = timestamp.replace(tzinfo=timezone.utc) if timestamp.tzinfo is None else timestamp
            cutoff_time = cutoff.timestamp() - self.window
            while self.events and self.events[0][0].timestamp() < cutoff_time:
                self.events.popleft()

            # Count occurrences of this src_ip
            if not src_ip:
                return 0
            count = sum(1 for _, ip in self.events if ip == src_ip)
            return count


# ═══════════════════════════════════════════════════════════════
# FEATURE ENGINEERING
# Exact replication of A5's preprocessing (A5_SOC_ML_Model.ipynb Cell 9)
# ═══════════════════════════════════════════════════════════════

def extract_features(alert_json, hit_count):
    """
    Transform a raw Wazuh alert JSON into the 16-feature vector
    expected by the Random Forest model.

    Args:
        alert_json: dict — raw Wazuh alert (as stored in alerts.json)
        hit_count: int — pre-computed hit_count_60s from HitCounter

    Returns:
        dict with exactly the 16 features in the model's expected order
    """
    # ── Extract raw fields from Wazuh alert JSON ──
    rule = alert_json.get("rule", {})
    agent = alert_json.get("agent", {})
    data = alert_json.get("data", {})

    rule_id = int(rule.get("id", 0))
    rule_level = int(rule.get("level", 0))
    rule_description = str(rule.get("description", ""))
    rule_groups = rule.get("groups", [])
    if isinstance(rule_groups, str):
        rule_groups = rule_groups.split("|")

    agent_name = str(agent.get("name", ""))
    src_ip = str(data.get("srcip", ""))
    dst_ip = data.get("dstip", "")  # May be missing
    dst_port = data.get("dstport", 0)

    # Parse timestamp
    ts_str = alert_json.get("timestamp", "")
    try:
        ts = pd.to_datetime(ts_str, utc=True)
    except Exception:
        ts = datetime.now(timezone.utc)

    # ── Feature Engineering (matching A5 exactly) ──

    # 1. rule_id — direct
    feat_rule_id = rule_id

    # 2. rule_level — direct
    feat_rule_level = rule_level

    # 3. agent_name — label encoded (A5: LabelEncoder alphabetical)
    feat_agent_name = AGENT_NAME_ENCODING.get(agent_name, 0)

    # 4. dst_port — direct, default 0
    try:
        feat_dst_port = float(dst_port) if dst_port else 0.0
    except (ValueError, TypeError):
        feat_dst_port = 0.0

    # 5. hit_count_60s — from HitCounter
    feat_hit_count = hit_count

    # 6. hour_of_day — from timestamp
    feat_hour = ts.hour if hasattr(ts, 'hour') else 0

    # 7. day_of_week — from timestamp (0=Monday)
    feat_day = ts.dayofweek if hasattr(ts, 'dayofweek') else 0

    # 8. minute_of_hour — from timestamp
    feat_minute = ts.minute if hasattr(ts, 'minute') else 0

    # 9. src_ip_is_internal — A5 used startswith('10.'), -1 if missing
    if not src_ip or src_ip == "nan" or src_ip == "":
        feat_src_internal = -1
    elif src_ip.startswith("10."):
        feat_src_internal = 1
    else:
        feat_src_internal = 0

    # 10. src_ip_is_attacker — A5: src_ip == '10.0.0.6'
    feat_src_attacker = 1 if src_ip == ATTACKER_IP else 0

    # 11. dst_ip_is_target — A5 compared dst_ip == 10.0 (float artifact from CSV)
    #     In live alerts, dst_ip is a string like "10.0.0.5"
    #     The 10.0 comparison was a bug in A5's CSV processing (dst_ip column
    #     had NaN/float issues). For live inference, we compare to the actual IP.
    if isinstance(dst_ip, str) and dst_ip == TARGET_IP:
        feat_dst_target = 1
    else:
        # Also handle the float case from A5's training data
        try:
            feat_dst_target = 1 if float(dst_ip) == 10.0 else 0
        except (ValueError, TypeError):
            feat_dst_target = 0

    # 12. rule_groups_count — len(groups)
    feat_groups_count = len(rule_groups) if rule_groups else 0

    # 13. is_ddos_group — A5 regex: 'ddos|attack' (case insensitive)
    groups_str = "|".join(rule_groups).lower() if rule_groups else ""
    feat_is_ddos = 1 if ("ddos" in groups_str or "attack" in groups_str) else 0

    # 14. desc_is_syn — A5 regex: 'SYN|Flood|DDoS' (case insensitive)
    desc_lower = rule_description.lower()
    feat_desc_syn = 1 if any(k in desc_lower for k in ["syn", "flood", "ddos"]) else 0

    # 15. desc_is_ssh — A5 regex: 'ssh|login|password' (case insensitive)
    feat_desc_ssh = 1 if any(k in desc_lower for k in ["ssh", "login", "password"]) else 0

    # 16. desc_is_fim — A5 regex: 'file|integrity|checksum' (case insensitive)
    feat_desc_fim = 1 if any(k in desc_lower for k in ["file", "integrity", "checksum"]) else 0

    return {
        "rule_id": feat_rule_id,
        "rule_level": feat_rule_level,
        "agent_name": feat_agent_name,
        "dst_port": feat_dst_port,
        "hit_count_60s": feat_hit_count,
        "hour_of_day": feat_hour,
        "day_of_week": feat_day,
        "minute_of_hour": feat_minute,
        "src_ip_is_internal": feat_src_internal,
        "src_ip_is_attacker": feat_src_attacker,
        "dst_ip_is_target": feat_dst_target,
        "rule_groups_count": feat_groups_count,
        "is_ddos_group": feat_is_ddos,
        "desc_is_syn": feat_desc_syn,
        "desc_is_ssh": feat_desc_ssh,
        "desc_is_fim": feat_desc_fim,
    }


# ═══════════════════════════════════════════════════════════════
# FLASK APPLICATION
# ═══════════════════════════════════════════════════════════════

app = Flask(__name__)

# Global state
model = None
feature_names = None
hit_counter = HitCounter(window_seconds=HIT_WINDOW_SECONDS)

# Stats tracking
stats = {
    "total_predictions": 0,
    "tp_count": 0,
    "fp_count": 0,
    "errors": 0,
    "server_start": datetime.now(timezone.utc).isoformat(),
}
stats_lock = Lock()


def load_model():
    """Load the trained model and feature names at startup."""
    global model, feature_names

    model_path = os.path.normpath(MODEL_PATH)
    features_path = os.path.normpath(FEATURES_PATH)

    logger.info(f"Loading model from: {model_path}")
    logger.info(f"Loading features from: {features_path}")

    if not os.path.exists(model_path):
        logger.error(f"Model file not found: {model_path}")
        logger.error("Please ensure soc_model_random_forest.pkl is in the correct location.")
        logger.error("You can set SOC_MODEL_PATH environment variable to specify the path.")
        return False

    if not os.path.exists(features_path):
        logger.error(f"Feature names file not found: {features_path}")
        logger.error("Please ensure feature_names.pkl is in the correct location.")
        logger.error("You can set SOC_FEATURES_PATH environment variable to specify the path.")
        return False

    try:
        model = joblib.load(model_path)
        feature_names = joblib.load(features_path)
        logger.info(f"Model loaded successfully: {type(model).__name__}")
        logger.info(f"Feature count: {len(feature_names)}")
        logger.info(f"Features: {list(feature_names)}")
        return True
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        return False


# ── POST /predict ─────────────────────────────────────────────

@app.route("/predict", methods=["POST"])
def predict():
    """
    Receive a raw Wazuh alert JSON and return AI classification.

    Request body: Wazuh alert JSON (as found in alerts.json)
    Response:
    {
        "ai_verdict": "TP" or "FP",
        "ai_confidence": 0.0-1.0,
        "rule_id": <int>,
        "agent_name": <str>,
        "timestamp": <str>
    }
    """
    global stats

    # Validate model is loaded
    if model is None or feature_names is None:
        return jsonify({
            "error": "Model not loaded",
            "ai_verdict": "UNKNOWN",
            "ai_confidence": 0.0,
        }), 503

    # Parse request
    try:
        alert_json = request.get_json(force=True)
    except Exception as e:
        with stats_lock:
            stats["errors"] += 1
        return jsonify({"error": f"Invalid JSON: {str(e)}"}), 400

    if not alert_json:
        with stats_lock:
            stats["errors"] += 1
        return jsonify({"error": "Empty request body"}), 400

    try:
        # Compute hit_count_60s via sliding window
        src_ip = alert_json.get("data", {}).get("srcip", "")
        ts_str = alert_json.get("timestamp", "")
        try:
            ts = pd.to_datetime(ts_str, utc=True).to_pydatetime()
        except Exception:
            ts = datetime.now(timezone.utc)

        hit_count = hit_counter.add_and_count(src_ip, ts)

        # Extract features (replicating A5's exact preprocessing)
        features = extract_features(alert_json, hit_count)

        # Create DataFrame with correct column order
        df_input = pd.DataFrame([features])[feature_names]

        # Run prediction
        prediction = model.predict(df_input)[0]
        confidence = model.predict_proba(df_input)[0]

        # Format response
        verdict = "TP" if prediction == 1 else "FP"
        # confidence[1] = probability of class 1 (TP)
        conf_score = float(confidence[1])

        # Update stats
        with stats_lock:
            stats["total_predictions"] += 1
            if verdict == "TP":
                stats["tp_count"] += 1
            else:
                stats["fp_count"] += 1

        # Log the verdict
        rule_id = alert_json.get("rule", {}).get("id", "?")
        agent_name = alert_json.get("agent", {}).get("name", "?")
        logger.info(
            f"VERDICT: {verdict} | confidence={conf_score:.4f} | "
            f"rule_id={rule_id} | agent={agent_name} | src_ip={src_ip} | "
            f"hit_count_60s={hit_count}"
        )

        return jsonify({
            "ai_verdict": verdict,
            "ai_confidence": round(conf_score, 4),
            "rule_id": rule_id,
            "agent_name": agent_name,
            "timestamp": ts_str,
            "features_used": features,
        })

    except Exception as e:
        with stats_lock:
            stats["errors"] += 1
        logger.error(f"Prediction error: {e}", exc_info=True)
        return jsonify({
            "error": str(e),
            "ai_verdict": "UNKNOWN",
            "ai_confidence": 0.0,
        }), 500


# ── GET /health ───────────────────────────────────────────────

@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({
        "status": "healthy" if model is not None else "degraded",
        "model_loaded": model is not None,
        "model_type": type(model).__name__ if model else None,
        "feature_count": len(feature_names) if feature_names else 0,
        "server_uptime_since": stats["server_start"],
    })


# ── GET /stats ────────────────────────────────────────────────

@app.route("/stats", methods=["GET"])
def get_stats():
    """Return prediction statistics since server start."""
    with stats_lock:
        return jsonify({
            **stats,
            "fp_rate": (
                round(stats["fp_count"] / stats["total_predictions"], 4)
                if stats["total_predictions"] > 0 else 0
            ),
            "tp_rate": (
                round(stats["tp_count"] / stats["total_predictions"], 4)
                if stats["total_predictions"] > 0 else 0
            ),
        })


# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("=" * 60)
    print("  SOC AI Inference Server — A6 Integration")
    print("  Project: Wazuh SOC MIKS 2026")
    print("=" * 60)
    print()

    if not load_model():
        print("[!] WARNING: Model not loaded. Server will start in degraded mode.")
        print("    Predictions will return 'UNKNOWN' until model is available.")
        print()

    print(f"[*] Starting Flask server on {HOST}:{PORT}")
    print(f"[*] Endpoints:")
    print(f"    POST http://{HOST}:{PORT}/predict")
    print(f"    GET  http://{HOST}:{PORT}/health")
    print(f"    GET  http://{HOST}:{PORT}/stats")
    print()

    app.run(host=HOST, port=PORT, debug=False)
