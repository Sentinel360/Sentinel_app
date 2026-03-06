const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const https = require("https");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ maxInstances: 10 });

// ── Your Arkesel API key ──────────────────────────────────────────────────────
const ARKESEL_API_KEY = "RXV4YXpMdFNxQkZpZWdkR2NaUk0";
const ARKESEL_SENDER  = "Sentinel360";

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