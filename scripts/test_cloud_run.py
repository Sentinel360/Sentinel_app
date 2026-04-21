"""
Layer 1 — Sentinel360 Cloud Run ML endpoint tests.
Run before anything else to confirm the ML backend is alive and returning correct fields.

Usage:
    pip install requests
    python scripts/test_cloud_run.py
"""

import requests
import json
import sys

BASE_URL = "https://sentinel360-ml-687324217816.us-central1.run.app"

PASS = "\033[92m✓\033[0m"
FAIL = "\033[91m✗\033[0m"

errors = []

def check(label, condition, actual=None):
    if condition:
        print(f"  {PASS} {label}")
    else:
        msg = f"  {FAIL} {label}" + (f"  →  got: {actual}" if actual is not None else "")
        print(msg)
        errors.append(label)

def post(path, payload):
    try:
        r = requests.post(f"{BASE_URL}{path}", json=payload, timeout=30)
        return r
    except requests.exceptions.ConnectionError:
        print(f"\n{FAIL} Cannot reach {BASE_URL}")
        print("   Check: is the Cloud Run service deployed and not scaled to zero?")
        sys.exit(1)
    except requests.exceptions.Timeout:
        print(f"\n{FAIL} Request to {path} timed out after 30s (cold start?). Re-run.")
        sys.exit(1)

# ── Sensor payload matching SensorService format ──────────────────────────────
def sensor_payload(trip_id, lat, lon, speed_kmh, accel_x, accel_y, accel_z,
                   gyro_x=0.0, gyro_y=0.0, gyro_z=0.0, timestamp=1000):
    return {
        "trip_id": trip_id,
        "userId": "test_user",
        "timestamp": timestamp,
        "gps": {
            "lat": lat,
            "lon": lon,
            "speed": speed_kmh,
            "accuracy": 5.0,
            "speed_accuracy": 1.0,
            "heading": 0.0,
            "bearing": 0.0,
            "altitude": 50.0,
            "vertical_speed": 0.0,
        },
        "acceleration": {"x": accel_x, "y": accel_y, "z": accel_z},
        "gyro": {"x": gyro_x, "y": gyro_y, "z": gyro_z},
        "is_moving": speed_kmh > 2.0,
        "activity": "in_vehicle" if speed_kmh > 2.0 else "still",
        "source": "PHONE",
    }


# ── Test 1: Health check ───────────────────────────────────────────────────────
def test_health():
    print("\n── Test 1: Health check ──")
    r = requests.get(f"{BASE_URL}/health", timeout=15)
    check("GET /health returns 200", r.status_code == 200, r.status_code)
    if r.status_code == 200:
        print(f"     response: {r.text[:120]}")


# ── Test 2: Safe driving prediction ───────────────────────────────────────────
def test_predict_safe():
    print("\n── Test 2: Safe driving prediction ──")
    payload = sensor_payload(
        trip_id="test_001",
        lat=5.6037, lon=-0.1870,
        speed_kmh=35,
        accel_x=0.1, accel_y=0.05, accel_z=9.8,
        timestamp=1000,
    )
    r = post("/predict", payload)
    check("/predict returns 200", r.status_code == 200, r.status_code)
    if r.status_code != 200:
        print(f"     body: {r.text[:300]}")
        return

    data = r.json()
    print(f"     response: {json.dumps(data, indent=2)[:400]}")
    check("riskScore present", "riskScore" in data or "risk_score" in data)
    check("riskLevel present", "riskLevel" in data or "risk_level" in data)
    check("overallUnsafe present", "overallUnsafe" in data or "overall_unsafe" in data)
    level = data.get("riskLevel") or data.get("risk_level", "")
    check(f"riskLevel is SAFE or MEDIUM for safe input (got {level!r})",
          level in ["SAFE", "MEDIUM"])


# ── Test 3: Dangerous driving — must set overallUnsafe = true ─────────────────
def test_predict_dangerous():
    print("\n── Test 3: Dangerous driving → overallUnsafe: true ──")
    payload = sensor_payload(
        trip_id="test_002",
        lat=5.6037, lon=-0.1870,
        speed_kmh=145,
        accel_x=3.5, accel_y=2.8, accel_z=9.8,
        gyro_x=2.5, gyro_y=1.8, gyro_z=0.5,
        timestamp=2000,
    )
    r = post("/predict", payload)
    check("/predict returns 200", r.status_code == 200, r.status_code)
    if r.status_code != 200:
        print(f"     body: {r.text[:300]}")
        return

    data = r.json()
    print(f"     response: {json.dumps(data, indent=2)[:400]}")
    unsafe = data.get("overallUnsafe") or data.get("overall_unsafe")
    score = data.get("riskScore") or data.get("risk_score", 0)
    check("overallUnsafe is True for extreme input", unsafe is True, unsafe)
    check("riskScore > 0.5 for extreme input", float(score) > 0.5, score)


# ── Test 4: Route deviation ────────────────────────────────────────────────────
def test_predict_deviation():
    print("\n── Test 4: Route deviation ──")
    payload = sensor_payload(
        trip_id="test_003",
        lat=5.7200, lon=-0.2500,   # clearly off any Accra route
        speed_kmh=40,
        accel_x=0.1, accel_y=0.05, accel_z=9.8,
        timestamp=3000,
    )
    r = post("/predict", payload)
    check("/predict returns 200", r.status_code == 200, r.status_code)
    if r.status_code != 200:
        return

    data = r.json()
    print(f"     response: {json.dumps(data, indent=2)[:400]}")
    route_status = data.get("routeStatus") or data.get("route_status", "unknown")
    check("routeStatus field present", route_status != "unknown", route_status)
    print(f"     routeStatus: {route_status!r}  riskScore: {data.get('riskScore') or data.get('risk_score')}")


# ── Test 5: Policy latch — safe prediction after dangerous must not reset ──────
def test_policy_latch():
    print("\n── Test 5: Policy latch (safe after dangerous must not reset overallUnsafe) ──")
    # First send dangerous
    post("/predict", sensor_payload(
        trip_id="test_004",
        lat=5.6037, lon=-0.1870,
        speed_kmh=145, accel_x=3.5, accel_y=2.8, accel_z=9.8,
        timestamp=4000,
    ))
    # Then send safe — overallUnsafe must remain True
    r = post("/predict", sensor_payload(
        trip_id="test_004",
        lat=5.6037, lon=-0.1870,
        speed_kmh=30, accel_x=0.1, accel_y=0.05, accel_z=9.8,
        timestamp=5000,
    ))
    check("/predict returns 200", r.status_code == 200, r.status_code)
    if r.status_code != 200:
        return

    data = r.json()
    print(f"     response: {json.dumps(data, indent=2)[:400]}")
    unsafe = data.get("overallUnsafe") or data.get("overall_unsafe")
    check("overallUnsafe stays True after safe prediction (policy latch)", unsafe is True, unsafe)


# ── Run all ────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print(f"Sentinel360 Cloud Run Tests")
    print(f"Target: {BASE_URL}\n")

    test_health()
    test_predict_safe()
    test_predict_dangerous()
    test_predict_deviation()
    test_policy_latch()

    print("\n" + "─" * 50)
    if errors:
        print(f"\033[91m{len(errors)} test(s) failed:\033[0m")
        for e in errors:
            print(f"  • {e}")
        sys.exit(1)
    else:
        print("\033[92mAll Cloud Run tests passed.\033[0m")
