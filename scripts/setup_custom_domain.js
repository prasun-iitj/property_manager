/**
 * One-off: register mayurproperty.duckdns.org on Firebase Hosting.
 * Uses local Firebase CLI credentials. Do not commit tokens.
 */
const fs = require("fs");
const path = require("path");

const DOMAIN = "mayurproperty.duckdns.org";
const PROJECT = "propertymanagerapp-c4961";
const SITE = "propertymanagerapp-c4961";
const DUCK_TOKEN = process.env.DUCKDNS_TOKEN;
const DUCK_DOMAIN = "mayurproperty";

function getAccessToken() {
  const configPath = path.join(
    process.env.USERPROFILE,
    ".config",
    "configstore",
    "firebase-tools.json",
  );
  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const access = config.tokens?.access_token;
  if (!access) {
    throw new Error("No Firebase CLI access token. Run: firebase login");
  }
  return access;
}

async function duckDnsUpdate(params) {
  const q = new URLSearchParams({ domains: DUCK_DOMAIN, token: DUCK_TOKEN, ...params });
  const res = await fetch(`https://www.duckdns.org/update?${q}`);
  const text = await res.text();
  if (text.trim() !== "OK") throw new Error(`DuckDNS failed: ${text}`);
}

async function main() {
  if (!DUCK_TOKEN) {
    console.error("Set DUCKDNS_TOKEN env var");
    process.exit(1);
  }

  console.log("Updating DuckDNS IP...");
  await duckDnsUpdate({ ip: "199.36.158.100" });
  console.log("DuckDNS IP OK");

  const accessToken = await getAccessToken();
  const base = "https://firebasehosting.googleapis.com/v1beta1";
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    "Content-Type": "application/json",
  };

  const listRes = await fetch(
    `${base}/projects/${PROJECT}/sites/${SITE}/customDomains`,
    { headers },
  );
  const list = await listRes.json();
  const existing = (list.customDomains || []).find(
    (d) => d.customDomain === DOMAIN || d.name?.includes(DOMAIN),
  );

  let domainResource = existing;
  if (existing) {
    const getRes = await fetch(
      `${base}/projects/${PROJECT}/sites/${SITE}/customDomains/${encodeURIComponent(DOMAIN)}`,
      { headers },
    );
    domainResource = await getRes.json();
  }
  if (!existing) {
    console.log("Creating Firebase custom domain...");
    const createRes = await fetch(
      `${base}/projects/${PROJECT}/sites/${SITE}/customDomains?customDomainId=${encodeURIComponent(DOMAIN)}`,
      { method: "POST", headers, body: "{}" },
    );
    domainResource = await createRes.json();
    if (!createRes.ok) {
      console.error("Create failed:", JSON.stringify(domainResource, null, 2));
      process.exit(1);
    }
    console.log("Custom domain created.");
  } else {
    console.log("Custom domain already exists.");
  }

  // Poll until DNS requirements are available (async provisioning).
  let required = domainResource.requiredDnsUpdates?.desired || [];
  for (let i = 0; i < 12 && required.length === 0; i++) {
    await new Promise((r) => setTimeout(r, 5000));
    const getRes = await fetch(
      `${base}/projects/${PROJECT}/sites/${SITE}/customDomains/${encodeURIComponent(DOMAIN)}`,
      { headers },
    );
    domainResource = await getRes.json();
    required = domainResource.requiredDnsUpdates?.desired || [];
    if (required.length) console.log("DNS requirements ready.");
  }

  const txtRecord = required.find((r) => r.type === "TXT");
  if (txtRecord?.records?.[0]) {
    const txt = txtRecord.records[0];
    console.log("Setting DuckDNS TXT...");
    await duckDnsUpdate({ txt });
    console.log("DuckDNS TXT OK");
  } else {
    console.log("TXT not ready yet — open Firebase Hosting and verify manually.");
    console.log("Status:", domainResource.state || domainResource.status || "pending");
  }

  // Add authorized domain for Firebase Auth (web login on custom URL).
  try {
    const authRes = await fetch(
      `https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT}/config?updateMask=authorizedDomains`,
      {
        method: "PATCH",
        headers,
        body: JSON.stringify({
          authorizedDomains: [DOMAIN, `${PROJECT}.firebaseapp.com`, `${PROJECT}.web.app`],
        }),
      },
    );
    const authBody = await authRes.json();
    if (authRes.ok) {
      console.log("Firebase Auth authorized domain added.");
    } else {
      console.log("Auth domain update (add manually if needed):", authBody.error?.message || authRes.status);
    }
  } catch (e) {
    console.log("Auth domain update skipped:", e.message);
  }

  console.log("\nDone. Wait 5–30 min for Firebase SSL, then open https://" + DOMAIN);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
