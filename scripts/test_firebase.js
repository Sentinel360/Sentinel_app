/**
 * Layer 2 — Sentinel360 Firebase escalation chain tests.
 * Tests the full backend: Cloud Functions + Firestore, no phone needed.
 *
 * Setup:
 *   1. Download serviceAccountKey.json from Firebase Console →
 *      Project Settings → Service Accounts → Generate new private key
 *   2. Place it at scripts/serviceAccountKey.json (gitignored)
 *   3. npm install firebase-admin (or: cd functions && node ../scripts/test_firebase.js)
 *
 * Usage:
 *   node scripts/test_firebase.js
 */

const admin = require("firebase-admin");
const path = require("path");

const KEY_PATH = path.join(__dirname, "serviceAccountKey.json");
try { require(KEY_PATH); } catch {
  console.error("✗ serviceAccountKey.json not found at scripts/serviceAccountKey.json");
  console.error("  Download it from: Firebase Console → Project Settings → Service Accounts");
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(KEY_PATH)) });
const db = admin.firestore();

// ── Config — fill in your real test user UID ──────────────────────────────────
const TEST_USER_ID = "REPLACE_WITH_YOUR_UID"; // Firebase Auth UID of your test account
const TEST_TRIP_ID = `test_trip_${Date.now()}`;

const PASS = "\x1b[32m✓\x1b[0m";
const FAIL = "\x1b[31m✗\x1b[0m";
const INFO = "\x1b[36m·\x1b[0m";

const errors = [];

function check(label, condition, actual) {
  if (condition) {
    console.log(`  ${PASS} ${label}`);
  } else {
    const suffix = actual !== undefined ? `  →  got: ${JSON.stringify(actual)}` : "";
    console.log(`  ${FAIL} ${label}${suffix}`);
    errors.push(label);
  }
}

const wait = (ms) => new Promise((res) => setTimeout(res, ms));

async function getEscalation() {
  // trip_escalations is a TOP-LEVEL collection, not under trips/
  const snap = await db.collection("trip_escalations").doc(TEST_TRIP_ID).get();
  return snap.exists ? snap.data() : null;
}

async function getLatestEmergencyAlert() {
  // emergency_alerts uses 'timestamp' field (not 'createdAt')
  const snap = await db
    .collection("emergency_alerts")
    .where("tripId", "==", TEST_TRIP_ID)
    .orderBy("timestamp", "desc")
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0].data();
}

async function injectCurrentState(fields) {
  await db
    .collection("trips").doc(TEST_TRIP_ID)
    .collection("current_state").doc("latest")
    .set({ ...fields, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
}

// ── Setup ─────────────────────────────────────────────────────────────────────
async function setup() {
  console.log("\n── Setup ──");
  await db.collection("trips").doc(TEST_TRIP_ID).set({
    userId: TEST_USER_ID,
    driver_id: TEST_USER_ID,
    status: "active",
    origin: { lat: 5.6037, lon: -0.1870 },
    destination: { lat: 5.5913, lon: -0.1969 },
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await db
    .collection("trips").doc(TEST_TRIP_ID)
    .collection("current_state").doc("latest")
    .set({
      overallUnsafe: false,
      riskScore: 0.0,
      riskLevel: "SAFE",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  console.log(`  ${INFO} Trip created: ${TEST_TRIP_ID}`);
  console.log(`  ${INFO} User: ${TEST_USER_ID}`);
}

// ── Test 1: Escalation document created on unsafe injection ───────────────────
async function test1_escalation_created() {
  console.log("\n── Test 1: Escalation created on overallUnsafe: true ──");
  await injectCurrentState({ overallUnsafe: true, overallRiskLevel: "HIGH RISK", riskScore: 0.85 });
  console.log(`  ${INFO} Injected overallUnsafe: true — waiting 6s for Cloud Function...`);
  await wait(6000);

  const esc = await getEscalation();
  check("trip_escalations/{tripId} document created", esc !== null);
  if (!esc) return;
  check("status is 'active'", esc.status === "active", esc.status);
  check("attemptsSent is 1", esc.attemptsSent === 1, esc.attemptsSent);
  check("sosTriggered is false", esc.sosTriggered === false, esc.sosTriggered);
  check("userId matches", esc.userId === TEST_USER_ID, esc.userId);
  console.log(`  ${INFO} Full doc: status=${esc.status} attempts=${esc.attemptsSent} sosTriggered=${esc.sosTriggered}`);
}

// ── Test 2: Policy latch — safe prediction must NOT clear escalation ───────────
async function test2_policy_latch() {
  console.log("\n── Test 2: Policy latch — safe prediction must not clear escalation ──");
  await injectCurrentState({ overallUnsafe: false, riskScore: 0.10, riskLevel: "SAFE" });
  console.log(`  ${INFO} Injected overallUnsafe: false — waiting 6s...`);
  await wait(6000);

  const esc = await getEscalation();
  check("Escalation document still exists", esc !== null);
  if (!esc) return;
  check("status is still 'active' (NOT resolved by safe prediction)", esc.status === "active", esc.status);
  if (esc.status === "resolved" && esc.resolvedBy === "risk_recovered") {
    console.log(`  ${FAIL} Bug 1 is still active — escalation was cleared by safe prediction!`);
    console.log(`       Verify the Cloud Functions deploy included the Bug 1 fix.`);
  }
}

// ── Test 3: Path B — user responds NOT_OK → emergency alert fires ─────────────
async function test3_path_b() {
  console.log("\n── Test 3: Path B — user responds NOT_OK → emergency alert ──");

  // Re-inject unsafe in case Test 2 left it safe
  await injectCurrentState({ overallUnsafe: true, riskScore: 0.85 });
  await wait(4000);

  // Simulate user tapping "I need help"
  await db.collection("trip_escalations").doc(TEST_TRIP_ID).set(
    { userResponse: "NOT_OK", respondedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
  console.log(`  ${INFO} Set userResponse: NOT_OK — waiting 8s for onEscalationResponse...`);
  await wait(8000);

  const esc = await getEscalation();
  check("Escalation status is 'completed'", esc?.status === "completed", esc?.status);
  check("sosTriggered is true", esc?.sosTriggered === true, esc?.sosTriggered);

  console.log(`  ${INFO} Checking emergency_alerts collection...`);
  await wait(3000);
  const alert = await getLatestEmergencyAlert();
  check("emergency_alerts document created", alert !== null);
  if (alert) {
    check("triggerSource is user_confirmed_not_ok", alert.triggerSource === "user_confirmed_not_ok", alert.triggerSource);
    check("location field present", alert.location !== undefined);
    console.log(`  ${INFO} Alert status: ${alert.status}  smsStatus: ${alert.smsStatus ?? "pending"}`);
  }

  // Give onEmergencyAlert time to run and update smsStatus
  console.log(`  ${INFO} Waiting 15s for onEmergencyAlert (SMS send)...`);
  await wait(15000);
  const alertFinal = await getLatestEmergencyAlert();
  if (alertFinal) {
    const sms = alertFinal.smsStatus;
    check(
      `smsStatus is 'processed' or 'no_contacts' (got: ${sms})`,
      sms === "processed" || sms === "no_contacts",
      sms
    );
    if (sms === "processed") {
      console.log(`  ${INFO} Contacts notified: ${alertFinal.contactsNotified}`);
      console.log(`  ${INFO} SMS results: ${JSON.stringify(alertFinal.smsResults)}`);
    }
    if (sms === "no_contacts") {
      console.log(`  ${INFO} No emergency contacts found for ${TEST_USER_ID} — add one in Firestore to test SMS`);
    }
  }
}

// ── Test 4: Path C — no response → scheduler auto-SOS after 3 prompts ─────────
async function test4_path_c() {
  const PATH_C_TRIP_ID = `test_trip_pathc_${Date.now()}`;
  console.log(`\n── Test 4: Path C — auto-SOS after 3 unresponsive prompts ──`);
  console.log(`  ${INFO} Using separate trip: ${PATH_C_TRIP_ID}`);
  console.log(`  ${INFO} Intervals: 10s → 20s → 10s + scheduler tick (~60s). Total wait: ~2min`);

  // Create a fresh trip for Path C
  await db.collection("trips").doc(PATH_C_TRIP_ID).set({
    userId: TEST_USER_ID,
    driver_id: TEST_USER_ID,
    status: "active",
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await db.collection("trips").doc(PATH_C_TRIP_ID)
    .collection("current_state").doc("latest")
    .set({
      overallUnsafe: true,
      overallRiskLevel: "HIGH RISK",
      riskScore: 0.85,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  console.log(`  ${INFO} Injected overallUnsafe: true — starting watch loop...`);

  const getEscC = async () => {
    const snap = await db.collection("trip_escalations").doc(PATH_C_TRIP_ID).get();
    return snap.exists ? snap.data() : null;
  };

  // Poll every 15 seconds, up to 150 seconds
  let sosFired = false;
  for (let i = 1; i <= 10; i++) {
    await wait(15000);
    const esc = await getEscC();
    if (!esc) {
      console.log(`  ${INFO} t+${i * 15}s: no escalation doc yet`);
      continue;
    }
    console.log(`  ${INFO} t+${i * 15}s: status=${esc.status} attempts=${esc.attemptsSent} sosTriggered=${esc.sosTriggered}`);
    if (esc.sosTriggered) {
      sosFired = true;
      check("Path C: sosTriggered = true after 3 unresponsive prompts", true);
      check("Path C: status is 'completed'", esc.status === "completed", esc.status);
      check("Path C: completedReason is unresponsive_after_3_prompts",
        esc.completedReason === "unresponsive_after_3_prompts", esc.completedReason);
      break;
    }
  }
  if (!sosFired) {
    check("Path C: SOS fired within 150s", false, "sosTriggered never became true");
    console.log(`  Possible causes:`);
    console.log(`    • processActiveEscalations scheduler is not enabled in Firebase Console`);
    console.log(`    • nextCheckAt intervals are set longer than expected`);
    console.log(`    • Cloud Function deploy did not complete`);
  }

  // Cleanup Path C trip
  await db.collection("trips").doc(PATH_C_TRIP_ID).update({ status: "completed" });
}

// ── Cleanup ───────────────────────────────────────────────────────────────────
async function cleanup() {
  await db.collection("trips").doc(TEST_TRIP_ID).update({ status: "completed" });
  console.log(`\n  ${INFO} Test trip marked completed.`);
}

// ── Run ───────────────────────────────────────────────────────────────────────
(async () => {
  if (TEST_USER_ID === "REPLACE_WITH_YOUR_UID") {
    console.error("✗ Set TEST_USER_ID to your actual Firebase Auth UID in scripts/test_firebase.js line 28");
    process.exit(1);
  }

  console.log("Sentinel360 Firebase Escalation Tests");
  console.log(`Trip: ${TEST_TRIP_ID}`);

  try {
    await setup();
    await test1_escalation_created();
    await test2_policy_latch();
    await test3_path_b();
    await test4_path_c();
    await cleanup();
  } catch (err) {
    console.error("\n✗ Unexpected error:", err.message);
    errors.push(err.message);
  }

  console.log("\n" + "─".repeat(50));
  if (errors.length) {
    console.log(`\x1b[31m${errors.length} test(s) failed:\x1b[0m`);
    errors.forEach((e) => console.log(`  • ${e}`));
    process.exit(1);
  } else {
    console.log("\x1b[32mAll Firebase tests passed.\x1b[0m");
  }
  process.exit(0);
})();
