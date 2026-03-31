const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const https = require("https");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ maxInstances: 10 });

// ── Your Arkesel API key ──────────────────────────────────────────────────────
const ARKESEL_API_KEY = "RXV4YXpMdFNxQkZpZWdkR2NaUk0";
const ARKESEL_SENDER  = "Sentinel360";
const ESCALATION_MAX_ATTEMPTS = 5;
const ESCALATION_INTERVAL_MS = 60 * 1000; // 1 min between prompts
const CONTEXT_ENRICH_MIN_INTERVAL_MS = 5 * 60 * 1000; // 5 min throttle

// ── Triggered when a new document is created in emergency_alerts 
exports.onEmergencyAlert = onDocumentCreated(
  "emergency_alerts/{alertId}",
  async (event) => {
    const alert = event.data.data();
    const { userId, tripId, location, triggerSource } = alert;

    console.log(`SOS triggered by user ${userId}, trip ${tripId ?? "none"}`);

    try {
      // 1. Get the user's display name
      const userDoc = await db.collection("users").doc(userId).get();
      const userData = userDoc.exists ? userDoc.data() : {};
      const userName =
        userData.fullName || userData.displayName || userData.name || "A Sentinel 360 user";

      // 2. Get all emergency contacts for this user
      const contactsSnap = await db
        .collection("users")
        .doc(userId)
        .collection("emergency_contacts")
        .get();

      if (contactsSnap.empty) {
        console.log(`No emergency contacts found for user ${userId}`);
        await event.data.ref.update({
          smsStatus: "no_contacts",
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      const contacts = contactsSnap.docs.map((doc) => doc.data());
      console.log(`Found ${contacts.length} emergency contact(s)`);

      // 3. Build location string
      const lat = location?.latitude  ?? 5.6037;
      const lng = location?.longitude ?? -0.1870;
      const mapsLink = `https://maps.google.com/?q=${lat},${lng}`;

      // 4. Build SMS message
      const time = new Date().toLocaleString("en-GH", {
        timeZone: "Africa/Accra",
        dateStyle: "medium",
        timeStyle: "short",
      });
      const message =
        `EMERGENCY ALERT - Sentinel 360\n\n` +
        `${userName} has triggered an SOS alert.\n\n` +
        `Last known location:\n${mapsLink}\n\n` +
        `Time: ${time}\n\n` +
        `Please check on them immediately.\n` +
        `Ghana Police: 191 | Ambulance: 193`;

      // 5. Send SMS to each contact via Arkesel v1 API
      const results = [];

      for (const contact of contacts) {
        const phone = contact.phone?.trim();
        if (!phone) {
          console.warn(`Contact ${contact.name} has no phone, skipping`);
          continue;
        }

        const normalised = normalisePhone(phone);

        try {
          await sendArkeselSMS({
            recipient: normalised,
            message,
            sender: ARKESEL_SENDER,
          });
          console.log(`SMS sent to ${contact.name} (${normalised})`);
          results.push({
            name: contact.name,
            phone: normalised,
            status: "sent",
          });
        } catch (smsErr) {
          console.error(
            `Failed to SMS ${contact.name} (${normalised}):`,
            smsErr.message
          );
          results.push({
            name: contact.name,
            phone: normalised,
            status: "failed",
            error: smsErr.message,
          });
        }
      }

      // 6. Write results back to Firestore for audit trail
      await event.data.ref.update({
        smsStatus: "processed",
        smsResults: results,
        contactsNotified: results.filter((r) => r.status === "sent").length,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(
        `SOS done. ${results.filter((r) => r.status === "sent").length}` +
        `/${contacts.length} SMS sent.`
      );
    } catch (err) {
      console.error("Error processing SOS alert:", err);
      await event.data.ref.update({
        smsStatus: "error",
        smsError: err.message,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
);

// ── Triggered when current_state/latest changes: manage escalation lifecycle ──
exports.onCurrentStateUpdated = onDocumentWritten(
  "trips/{tripId}/current_state/latest",
  async (event) => {
    if (!event.data || !event.data.after.exists) return;

    const tripId = event.params.tripId;
    const after = event.data.after.data() || {};
    const before = event.data.before.exists ? event.data.before.data() || {} : {};

    const overallUnsafe = !!after.overallUnsafe;
    const becameUnsafe = overallUnsafe && !before.overallUnsafe;

    const escalationRef = db.collection("trip_escalations").doc(tripId);
    const tripRef = db.collection("trips").doc(tripId);
    const tripSnap = await tripRef.get();
    if (!tripSnap.exists) return;
    const tripData = tripSnap.data() || {};
    const userId = tripData.userId || tripData.driver_id;
    if (!userId) return;

    if (!overallUnsafe) {
      // Close any active escalation when trip risk returns to non-unsafe.
      const escSnap = await escalationRef.get();
      if (escSnap.exists && escSnap.data().status === "active") {
        await escalationRef.update({
          status: "resolved",
          resolvedBy: "risk_recovered",
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      return;
    }

    // Start escalation only when unsafe state starts.
    if (becameUnsafe) {
      const now = Date.now();
      await escalationRef.set({
        tripId,
        userId,
        status: "active",
        attemptsSent: 1,
        maxAttempts: ESCALATION_MAX_ATTEMPTS,
        intervalMs: ESCALATION_INTERVAL_MS,
        nextCheckAt: admin.firestore.Timestamp.fromMillis(now + ESCALATION_INTERVAL_MS),
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastPromptAt: admin.firestore.FieldValue.serverTimestamp(),
        overallRiskLevel: after.overallRiskLevel || "HIGH RISK",
        policyReason: after.policy?.reason || "",
        userResponse: null, // "OK" | "NOT_OK"
        sosTriggered: false,
      }, { merge: true });

      await sendSafetyPrompt({
        userId,
        tripId,
        attempt: 1,
      });
    }
  }
);

// ── Triggered by user response updates on escalation document ─────────────────
exports.onEscalationResponse = onDocumentWritten(
  "trip_escalations/{tripId}",
  async (event) => {
    if (!event.data || !event.data.after.exists) return;
    const tripId = event.params.tripId;
    const after = event.data.after.data() || {};
    const before = event.data.before.exists ? event.data.before.data() || {} : {};

    const response = (after.userResponse || "").toUpperCase();
    const prevResponse = (before.userResponse || "").toUpperCase();
    if (!response || response === prevResponse) return;

    const escRef = db.collection("trip_escalations").doc(tripId);

    if (response === "OK") {
      await escRef.update({
        status: "resolved",
        resolvedBy: "user_ok",
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    if (response === "NOT_OK") {
      await triggerSosForEscalation({
        tripId,
        userId: after.userId,
        triggerSource: "user_confirmed_not_ok",
      });
    }
  }
);

// ── Scheduled escalation processor: retries + unresponsive auto-SOS ──────────
exports.processActiveEscalations = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Africa/Accra",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const snap = await db
      .collection("trip_escalations")
      .where("status", "==", "active")
      .where("nextCheckAt", "<=", now)
      .limit(100)
      .get();

    for (const doc of snap.docs) {
      const data = doc.data();
      const tripId = data.tripId || doc.id;
      const userId = data.userId;
      const attemptsSent = data.attemptsSent || 0;
      const responded = !!data.userResponse;
      const sosTriggered = !!data.sosTriggered;

      if (responded || sosTriggered) continue;

      if (attemptsSent >= ESCALATION_MAX_ATTEMPTS) {
        await triggerSosForEscalation({
          tripId,
          userId,
          triggerSource: "unresponsive_after_5_prompts",
        });
        continue;
      }

      const nextAttempt = attemptsSent + 1;
      await sendSafetyPrompt({
        userId,
        tripId,
        attempt: nextAttempt,
      });

      await doc.ref.update({
        attemptsSent: nextAttempt,
        lastPromptAt: admin.firestore.FieldValue.serverTimestamp(),
        nextCheckAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + ESCALATION_INTERVAL_MS
        ),
      });
    }
  }
);

// ── Triggered on sensor event: enrich weather/traffic context (throttled) ────
exports.enrichTripContext = onDocumentCreated(
  "trips/{tripId}/sensor_data/{eventId}",
  async (event) => {
    const tripId = event.params.tripId;
    const data = event.data.data() || {};

    // Handle both old batched format and new event-per-doc format.
    const gps = extractGpsFromSensorDoc(data);
    if (!gps) return;

    const tripRef = db.collection("trips").doc(tripId);
    const tripSnap = await tripRef.get();
    if (!tripSnap.exists) return;
    const tripData = tripSnap.data() || {};

    const lastEnrichedAtMs =
      tripData.context_meta?.lastEnrichedAt?.toMillis?.() ||
      tripData.context_meta?.lastEnrichedAtMs ||
      0;
    const nowMs = Date.now();
    if (nowMs - lastEnrichedAtMs < CONTEXT_ENRICH_MIN_INTERVAL_MS) return;

    let weather = null;
    try {
      weather = await getWeatherContext(gps.lat, gps.lon);
    } catch (err) {
      console.warn("Weather enrichment failed:", err.message);
    }

    const traffic = deriveTrafficContext({
      speedKmh: gps.speed || 0,
      hour: new Date().getHours(),
    });

    await db
      .collection("trips")
      .doc(tripId)
      .collection("current_state")
      .doc("latest")
      .set(
        {
          context: {
            weather,
            traffic,
            source: "backend_enrichment",
          },
          contextUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    await tripRef.set(
      {
        context_meta: {
          lastEnrichedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastEnrichedAtMs: nowMs,
          lat: gps.lat,
          lon: gps.lon,
        },
      },
      { merge: true }
    );
  }
);

// ── Arkesel SMS sender (v1 API — GET request) ─────────────────────────────────
function sendArkeselSMS({ recipient, message, sender }) {
  return new Promise((resolve, reject) => {
    const params = new URLSearchParams({
      action: "send-sms",
      api_key: ARKESEL_API_KEY,
      to: recipient,
      from: sender,
      sms: message,
    });

    const options = {
      hostname: "sms.arkesel.com",
      path: `/sms/api?${params.toString()}`,
      method: "GET",
    };

    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          const parsed = JSON.parse(data);
          console.log("Arkesel response:", JSON.stringify(parsed));
          if (parsed.code === "ok") {
            resolve(parsed);
          } else {
            reject(new Error(parsed.message || JSON.stringify(parsed)));
          }
        } catch (e) {
          reject(new Error(`Failed to parse Arkesel response: ${data}`));
        }
      });
    });

    req.on("error", reject);
    req.end();
  });
}

// ── Phone number normaliser ───────────────────────────────────────────────────
function normalisePhone(phone) {
  let cleaned = phone.replace(/[\s\-()]/g, "");
  if (cleaned.startsWith("+"))   return cleaned;
  if (cleaned.startsWith("233")) return `+${cleaned}`;
  if (cleaned.startsWith("0"))   return `+233${cleaned.slice(1)}`;
  return `+233${cleaned}`;
}

function extractGpsFromSensorDoc(data) {
  if (data?.gps?.lat != null && data?.gps?.lon != null) {
    return {
      lat: Number(data.gps.lat),
      lon: Number(data.gps.lon),
      speed: Number(data.gps.speed || 0),
    };
  }

  // Backward compatibility for old batched documents.
  if (Array.isArray(data?.batch) && data.batch.length > 0) {
    const point = data.batch[data.batch.length - 1];
    if (point?.gps?.lat != null && point?.gps?.lon != null) {
      return {
        lat: Number(point.gps.lat),
        lon: Number(point.gps.lon),
        speed: Number(point.gps.speed || 0),
      };
    }
  }
  return null;
}

async function sendSafetyPrompt({ userId, tripId, attempt }) {
  const title = "Sentinel 360 Safety Check";
  const body =
    `Risk trend is unsafe (check ${attempt}/${ESCALATION_MAX_ATTEMPTS}). ` +
    "Please confirm you are okay.";

  await db
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .add({
      type: "SAFETY_CHECK",
      tripId,
      title,
      body,
      attempt,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });

  // Optional FCM push if token(s) are available.
  try {
    const userSnap = await db.collection("users").doc(userId).get();
    const userData = userSnap.exists ? userSnap.data() : {};
    const tokens = []
      .concat(userData.fcmToken || [])
      .concat(Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [])
      .filter(Boolean);

    if (tokens.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: {
          type: "SAFETY_CHECK",
          tripId,
          attempt: String(attempt),
        },
      });
    }
  } catch (err) {
    console.warn("Push notification send failed:", err.message);
  }
}

async function triggerSosForEscalation({ tripId, userId, triggerSource }) {
  if (!tripId || !userId) return;
  const escRef = db.collection("trip_escalations").doc(tripId);

  await db.runTransaction(async (tx) => {
    const escSnap = await tx.get(escRef);
    const escData = escSnap.exists ? escSnap.data() : {};
    if (escData.sosTriggered) return;

    tx.set(
      escRef,
      {
        sosTriggered: true,
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        completedReason: triggerSource,
      },
      { merge: true }
    );

    tx.set(db.collection("emergency_alerts").doc(), {
      userId,
      tripId,
      triggerSource,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: "triggered",
    });
  });
}

function deriveTrafficContext({ speedKmh, hour }) {
  // Simple backend fallback heuristic until traffic API is wired.
  const isPeak = (hour >= 6 && hour <= 9) || (hour >= 16 && hour <= 20);
  let level = "LOW";
  if (speedKmh < 12) level = "HIGH";
  else if (speedKmh < 25) level = "MEDIUM";
  if (isPeak && level === "LOW") level = "MEDIUM";

  return {
    level,
    source: "heuristic",
    speedKmh,
    isPeakHour: isPeak,
  };
}

function getWeatherContext(lat, lon) {
  return new Promise((resolve, reject) => {
    const path =
      "/v1/forecast" +
      `?latitude=${encodeURIComponent(lat)}` +
      `&longitude=${encodeURIComponent(lon)}` +
      "&current=temperature_2m,precipitation,weather_code,wind_speed_10m";

    const req = https.request(
      {
        hostname: "api.open-meteo.com",
        path,
        method: "GET",
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            const parsed = JSON.parse(data);
            const cur = parsed.current || {};
            resolve({
              temperatureC: cur.temperature_2m ?? null,
              precipitation: cur.precipitation ?? null,
              weatherCode: cur.weather_code ?? null,
              windSpeed: cur.wind_speed_10m ?? null,
              source: "open-meteo",
            });
          } catch (e) {
            reject(new Error("Failed to parse weather response"));
          }
        });
      }
    );
    req.on("error", reject);
    req.end();
  });
}