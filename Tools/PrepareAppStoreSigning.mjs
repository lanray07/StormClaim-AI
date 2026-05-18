import { sign } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

// Creates or downloads the App Store provisioning profile for StormClaim AI.
// The generated files are written to SigningAssets/, which is gitignored.
const API_ROOT = "https://api.appstoreconnect.apple.com";

const config = {
  issuerId: requiredEnv("ASC_ISSUER_ID"),
  keyId: requiredEnv("ASC_KEY_ID"),
  privateKeyPath: requiredEnv("ASC_PRIVATE_KEY_PATH"),
  appId: process.env.ASC_APP_ID || "6770429445",
  bundleIdentifier: process.env.ASC_BUNDLE_IDENTIFIER || "com.stormclaim.ai",
  profileName: process.env.ASC_PROFILE_NAME || "StormClaim_AI_App_Store",
  outputDir: process.env.ASC_SIGNING_OUTPUT_DIR || "SigningAssets",
};

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function base64url(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

async function createJwt() {
  const privateKey = await readFile(config.privateKeyPath, "utf8");
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: config.keyId, typ: "JWT" };
  const payload = { iss: config.issuerId, exp: now + 20 * 60, aud: "appstoreconnect-v1" };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = sign("sha256", Buffer.from(signingInput), {
    key: privateKey,
    dsaEncoding: "ieee-p1363",
  });
  return `${signingInput}.${base64url(signature)}`;
}

const token = await createJwt();

async function api(method, route, body) {
  const response = await fetch(`${API_ROOT}${route}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const message =
      json?.errors
        ?.map((error) => `${error.status} ${error.code}: ${error.title} ${error.detail || ""}`)
        .join("\n") || text;
    throw new Error(`${method} ${route} failed (${response.status})\n${message}`);
  }
  return json;
}

async function getBundleId() {
  const response = await api(
    "GET",
    `/v1/bundleIds?filter[identifier]=${encodeURIComponent(config.bundleIdentifier)}&limit=10`,
  );
  const bundleId = response.data?.[0];
  if (!bundleId) {
    throw new Error(`No bundle ID exists for ${config.bundleIdentifier}`);
  }
  return bundleId;
}

async function getExistingProfile(bundleId) {
  const response = await api("GET", `/v1/bundleIds/${bundleId}/profiles?limit=200`);
  return response.data.find(
    (profile) =>
      profile.attributes?.name === config.profileName &&
      profile.attributes?.profileType === "IOS_APP_STORE" &&
      profile.attributes?.profileState === "ACTIVE",
  );
}

async function getDistributionCertificates() {
  const response = await api("GET", "/v1/certificates?limit=200");
  const now = Date.now();
  return response.data.filter((certificate) => {
    const type = certificate.attributes?.certificateType;
    const expiresAt = Date.parse(certificate.attributes?.expirationDate || "");
    return ["IOS_DISTRIBUTION", "DISTRIBUTION"].includes(type) && expiresAt > now;
  });
}

async function createProfile(bundleId, certificates) {
  const response = await api("POST", "/v1/profiles", {
    data: {
      type: "profiles",
      attributes: {
        name: config.profileName,
        profileType: "IOS_APP_STORE",
      },
      relationships: {
        bundleId: { data: { type: "bundleIds", id: bundleId } },
        certificates: {
          data: certificates.map((certificate) => ({ type: "certificates", id: certificate.id })),
        },
      },
    },
  });
  return response.data;
}

async function writeProfileFiles(profile) {
  await mkdir(config.outputDir, { recursive: true });

  const mobileprovisionPath = path.join(config.outputDir, `${config.profileName}.mobileprovision`);
  const base64Path = path.join(config.outputDir, "BUILD_PROVISION_PROFILE_BASE64.txt");

  await writeFile(mobileprovisionPath, Buffer.from(profile.attributes.profileContent, "base64"));
  await writeFile(base64Path, `${profile.attributes.profileContent}\n`, "utf8");

  console.log(`Wrote ${mobileprovisionPath}`);
  console.log(`Wrote ${base64Path}`);
  console.log("Use BUILD_PROVISION_PROFILE_BASE64.txt as the BUILD_PROVISION_PROFILE_BASE64 GitHub secret.");
}

async function main() {
  const app = await api("GET", `/v1/apps/${config.appId}`);
  if (app.data.attributes?.bundleId !== config.bundleIdentifier) {
    throw new Error(`App ${config.appId} is not using ${config.bundleIdentifier}`);
  }

  const bundleId = await getBundleId();
  let profile = await getExistingProfile(bundleId.id);
  if (profile) {
    console.log(`Using existing profile ${profile.id} (${config.profileName})`);
  } else {
    const certificates = await getDistributionCertificates();
    if (certificates.length === 0) {
      throw new Error("No active Apple Distribution certificates found in App Store Connect.");
    }
    profile = await createProfile(bundleId.id, certificates);
    console.log(`Created profile ${profile.id} (${config.profileName})`);
  }

  await writeProfileFiles(profile);
}

try {
  await main();
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
