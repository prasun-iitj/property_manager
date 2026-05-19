const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

setGlobalOptions({ region: "asia-south1" });

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();
const bucket = admin.storage().bucket();

const SYSTEM_CONFIG = "config/system";
const OTP_COLLECTION = "systemOtp";
const BACKUP_HISTORY = "backupHistory";

const OTP_TTL_MS = 10 * 60 * 1000;

function hashOtp(code) {
  return crypto.createHash("sha256").update(code).digest("hex");
}

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

async function assertAdmin(context) {
  if (!context.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const uid = context.auth.uid;
  const doc = await db.collection("users").doc(uid).get();
  if (!doc.exists || doc.data().role !== "admin") {
    throw new HttpsError("permission-denied", "Admin access required.");
  }
  return { uid, profile: doc.data() };
}

async function getSystemConfig() {
  const snap = await db.doc(SYSTEM_CONFIG).get();
  return snap.exists ? snap.data() : {};
}

function maskEmail(email) {
  const parts = email.split("@");
  if (parts.length !== 2) return "***";
  const local = parts[0];
  const visible = local.length <= 2 ? local.slice(0, 1) : local.slice(0, 2);
  return `${visible}***@${parts[1]}`;
}

function getMailConfig() {
  const host = process.env.SMTP_HOST || "smtp.gmail.com";
  const port = Number(process.env.SMTP_PORT || "587");
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const from = process.env.SMTP_FROM || user;

  if (!user || !pass) {
    throw new HttpsError(
      "failed-precondition",
      "Email OTP is not configured. Set SMTP_USER and SMTP_PASS (Gmail app password) on Cloud Functions. See INSTRUCTIONS.md.",
    );
  }

  return {
    transporter: nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
    }),
    from,
  };
}

async function sendOtpEmail(toEmail, subject, textBody) {
  const { transporter, from } = getMailConfig();
  await transporter.sendMail({
    from,
    to: toEmail,
    subject,
    text: textBody,
    html: `<div style="font-family:sans-serif;max-width:480px">
      <h2 style="color:#1E3A8A">Property Manager</h2>
      <p>${textBody.replace(/\n/g, "<br>")}</p>
      <p style="color:#64748B;font-size:12px">If you did not request this, ignore this email.</p>
    </div>`,
  });
}

async function resolveSuperAdminOtpEmail(config) {
  const stored =
    config.superAdminOtpEmail || config.superAdminEmail || null;
  if (stored && stored.includes("@")) return stored.toLowerCase();

  if (config.superAdminUid) {
    try {
      const user = await auth.getUser(config.superAdminUid);
      if (user.email) return user.email.toLowerCase();
    } catch (_) {
      /* ignore */
    }
  }
  return null;
}

async function exportDocRef(docRef) {
  const snap = await docRef.get();
  if (!snap.exists) return null;

  const node = { _data: snap.data() };
  const subcols = await docRef.listCollections();
  if (subcols.length > 0) {
    node._sub = {};
    for (const sub of subcols) {
      node._sub[sub.id] = await exportCollection(sub);
    }
  }
  return node;
}

async function exportCollection(colRef) {
  const snap = await colRef.get();
  const out = {};
  for (const doc of snap.docs) {
    out[doc.id] = await exportDocRef(doc.ref);
  }
  return out;
}

async function runFirestoreBackup(triggeredBy) {
  const started = Date.now();
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const path = `backups/${stamp}/firestore-export.json`;

  const rootCollections = ["users", "sites", "customers", "ledger"];
  const payload = {
    exportedAt: new Date().toISOString(),
    triggeredBy,
    collections: {},
  };

  for (const name of rootCollections) {
    payload.collections[name] = await exportCollection(db.collection(name));
  }

  const json = JSON.stringify(payload);
  const file = bucket.file(path);
  await file.save(json, {
    contentType: "application/json",
    metadata: { cacheControl: "private, max-age=0" },
  });

  const [metadata] = await file.getMetadata();
  const sizeBytes = Number(metadata.size || json.length);

  const historyRef = db.collection(BACKUP_HISTORY).doc();
  await historyRef.set({
    path,
    sizeBytes,
    triggeredBy,
    status: "completed",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    durationMs: Date.now() - started,
  });

  await db.doc(SYSTEM_CONFIG).set(
    {
      lastBackupAt: admin.firestore.FieldValue.serverTimestamp(),
      lastBackupPath: path,
      lastBackupSizeBytes: sizeBytes,
    },
    { merge: true },
  );

  return { path, sizeBytes, historyId: historyRef.id };
}

/** Register super-admin email for admin OTP. First admin can set once. */
exports.registerSuperAdminEmail = onCall(async (request) => {
  const { uid } = await assertAdmin(request);
  let email = (request.data.email || "").trim().toLowerCase();

  if (request.data.useMyLoginEmail === true) {
    email = (request.auth.token.email || "").trim().toLowerCase();
  }

  if (!email.includes("@") || email.length < 5) {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }

  const config = await getSystemConfig();
  if (config.superAdminUid && config.superAdminUid !== uid) {
    throw new HttpsError(
      "permission-denied",
      "Only the super admin can change this email.",
    );
  }

  await db.doc(SYSTEM_CONFIG).set(
    {
      superAdminUid: uid,
      superAdminOtpEmail: email,
      superAdminEmail: email,
      otpChannel: "email",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await db.collection("users").doc(uid).set(
    { isSuperAdmin: true },
    { merge: true },
  );

  return { success: true, emailMasked: maskEmail(email) };
});

/** @deprecated Use registerSuperAdminEmail */
exports.registerSuperAdminPhone = onCall(async (request) => {
  throw new HttpsError(
    "failed-precondition",
    "Admin OTP now uses email. Open Manage team and set super admin email instead.",
  );
});

/** Send OTP to super-admin email before creating/promoting an admin. */
exports.requestAdminOtp = onCall(async (request) => {
  await assertAdmin(request);
  const purpose = request.data.purpose || "promote_admin";
  const targetEmail = (request.data.targetEmail || "").trim().toLowerCase();

  const config = await getSystemConfig();
  const otpEmail = await resolveSuperAdminOtpEmail(config);
  if (!otpEmail) {
    throw new HttpsError(
      "failed-precondition",
      "Super admin email is not set. Open Manage team and register the OTP email first.",
    );
  }

  const code = generateOtp();
  const requestId = db.collection(OTP_COLLECTION).doc().id;
  const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + OTP_TTL_MS);

  await db.collection(OTP_COLLECTION).doc(requestId).set({
    hashedOtp: hashOtp(code),
    purpose,
    targetEmail,
    requestedBy: request.auth.uid,
    expiresAt,
    used: false,
    channel: "email",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const textBody =
    `Your Property Manager admin verification code is: ${code}\n\n` +
    `Valid for 10 minutes.\n` +
    `Purpose: ${purpose}\n` +
    (targetEmail ? `For account: ${targetEmail}\n` : "") +
    `\nDo not share this code with anyone.`;

  await sendOtpEmail(
    otpEmail,
    `Property Manager admin code: ${code}`,
    textBody,
  );

  return {
    requestId,
    expiresInSeconds: OTP_TTL_MS / 1000,
    sentTo: maskEmail(otpEmail),
    channel: "email",
  };
});

async function verifyOtp(requestId, otp) {
  const ref = db.collection(OTP_COLLECTION).doc(requestId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "OTP request not found or expired.");
  }
  const data = snap.data();
  if (data.used) {
    throw new HttpsError("failed-precondition", "OTP already used.");
  }
  if (data.expiresAt.toMillis() < Date.now()) {
    throw new HttpsError("deadline-exceeded", "OTP expired. Request a new code.");
  }
  if (hashOtp(String(otp).trim()) !== data.hashedOtp) {
    throw new HttpsError("permission-denied", "Incorrect OTP.");
  }
  await ref.update({ used: true, usedAt: admin.firestore.FieldValue.serverTimestamp() });
  return data;
}

/** Create staff member (no OTP). */
exports.createTeamMember = onCall(async (request) => {
  await assertAdmin(request);
  const email = (request.data.email || "").trim().toLowerCase();
  const password = request.data.password || "";
  const name = (request.data.name || "").trim();
  const role = request.data.role === "admin" ? "admin" : "staff";

  if (!email || !password || password.length < 6) {
    throw new HttpsError("invalid-argument", "Email and password (min 6 chars) required.");
  }

  if (role === "admin") {
    throw new HttpsError(
      "invalid-argument",
      "Use createAdminTeamMember with OTP to add an admin.",
    );
  }

  const userRecord = await auth.createUser({ email, password, displayName: name });
  await db.collection("users").doc(userRecord.uid).set({
    email,
    name,
    role: "staff",
    disabled: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: request.auth.uid,
  });

  return { uid: userRecord.uid, email, role: "staff" };
});

/** Create admin — requires OTP sent to super admin. */
exports.createAdminTeamMember = onCall(async (request) => {
  await assertAdmin(request);
  const email = (request.data.email || "").trim().toLowerCase();
  const password = request.data.password || "";
  const name = (request.data.name || "").trim();
  const otpRequestId = request.data.otpRequestId;
  const otp = request.data.otp;

  if (!email || !password || password.length < 6) {
    throw new HttpsError("invalid-argument", "Email and password (min 6 chars) required.");
  }
  if (!otpRequestId || !otp) {
    throw new HttpsError("invalid-argument", "OTP verification required.");
  }

  await verifyOtp(otpRequestId, otp);

  const userRecord = await auth.createUser({ email, password, displayName: name });
  await db.collection("users").doc(userRecord.uid).set({
    email,
    name,
    role: "admin",
    disabled: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: request.auth.uid,
  });

  return { uid: userRecord.uid, email, role: "admin" };
});

/** Update role. Promoting to admin requires OTP. */
exports.updateTeamMemberRole = onCall(async (request) => {
  const { uid: adminUid } = await assertAdmin(request);
  const targetUid = request.data.uid;
  const newRole = request.data.role === "admin" ? "admin" : "staff";
  const otpRequestId = request.data.otpRequestId;
  const otp = request.data.otp;

  if (!targetUid) {
    throw new HttpsError("invalid-argument", "User id required.");
  }
  if (targetUid === adminUid) {
    throw new HttpsError("invalid-argument", "You cannot change your own role here.");
  }

  const targetDoc = await db.collection("users").doc(targetUid).get();
  if (!targetDoc.exists) {
    throw new HttpsError("not-found", "User not found.");
  }

  const currentRole = targetDoc.data().role || "staff";
  if (newRole === "admin" && currentRole !== "admin") {
    if (!otpRequestId || !otp) {
      throw new HttpsError("invalid-argument", "OTP required to grant admin access.");
    }
    await verifyOtp(otpRequestId, otp);
  }

  await db.collection("users").doc(targetUid).update({
    role: newRole,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: adminUid,
  });

  return { uid: targetUid, role: newRole };
});

/** Disable user login (keeps data). */
exports.disableTeamMember = onCall(async (request) => {
  const { uid: adminUid } = await assertAdmin(request);
  const targetUid = request.data.uid;
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "User id required.");
  }
  if (targetUid === adminUid) {
    throw new HttpsError("invalid-argument", "You cannot disable your own account.");
  }

  await auth.updateUser(targetUid, { disabled: true });
  await db.collection("users").doc(targetUid).update({
    disabled: true,
    disabledAt: admin.firestore.FieldValue.serverTimestamp(),
    disabledBy: adminUid,
  });

  return { success: true };
});

/** Re-enable user. */
exports.enableTeamMember = onCall(async (request) => {
  await assertAdmin(request);
  const targetUid = request.data.uid;
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "User id required.");
  }

  await auth.updateUser(targetUid, { disabled: false });
  await db.collection("users").doc(targetUid).update({
    disabled: false,
    enabledAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

/** Manual backup trigger from app. */
exports.runBackupNow = onCall(async (request) => {
  await assertAdmin(request);
  const result = await runFirestoreBackup(request.auth.uid);
  return result;
});

/** Update backup schedule settings. */
exports.updateBackupSettings = onCall(async (request) => {
  await assertAdmin(request);
  const enabled = request.data.enabled !== false;
  const schedule = request.data.schedule || "0 2 * * *";
  const timeZone = request.data.timeZone || "Asia/Kolkata";

  await db.doc(SYSTEM_CONFIG).set(
    {
      backupEnabled: enabled,
      backupSchedule: schedule,
      backupTimeZone: timeZone,
      backupSettingsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { success: true, enabled, schedule, timeZone };
});

/** Daily scheduled backup (2:00 AM Asia/Kolkata). */
exports.scheduledFirestoreBackup = onSchedule(
  {
    schedule: "0 2 * * *",
    timeZone: "Asia/Kolkata",
  },
  async () => {
    const config = await getSystemConfig();
    if (config.backupEnabled === false) {
      console.log("Scheduled backup skipped (disabled in config).");
      return;
    }
    try {
      await runFirestoreBackup("scheduler");
      console.log("Scheduled backup completed.");
    } catch (err) {
      console.error("Scheduled backup failed", err);
      await db.collection(BACKUP_HISTORY).add({
        status: "failed",
        error: String(err.message || err),
        triggeredBy: "scheduler",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  },
);
