import { createHash, sign } from "node:crypto";
import { readFile, readdir, stat } from "node:fs/promises";
import path from "node:path";

const API_ROOT = "https://api.appstoreconnect.apple.com";

const config = {
  issuerId: requiredEnv("ASC_ISSUER_ID"),
  keyId: requiredEnv("ASC_KEY_ID"),
  privateKeyPath: requiredEnv("ASC_PRIVATE_KEY_PATH"),
  appId: requiredEnv("ASC_APP_ID"),
  versionString: process.env.ASC_VERSION_STRING || "1.0",
  locale: process.env.ASC_LOCALE || "en-GB",
  displayType: process.env.ASC_SCREENSHOT_DISPLAY_TYPE || "APP_IPHONE_65",
  screenshotDir: requiredEnv("ASC_SCREENSHOT_DIR"),
  replaceExisting: process.env.ASC_REPLACE_EXISTING === "1",
};

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required`);
  }
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
  const payload = {
    iss: config.issuerId,
    exp: now + 20 * 60,
    aud: "appstoreconnect-v1",
  };
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
  let json = null;
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      json = { raw: text };
    }
  }
  if (!response.ok) {
    const message = json?.errors?.map((error) => `${error.status} ${error.code}: ${error.title} ${error.detail || ""}`).join("\n") || text;
    throw new Error(`${method} ${route} failed (${response.status})\n${message}`);
  }
  return json;
}

async function deleteResource(type, id) {
  const route = type === "appScreenshotSets" ? `/v1/appScreenshotSets/${id}` : `/v1/appScreenshots/${id}`;
  await api("DELETE", route);
}

async function getAppStoreVersion() {
  const route = `/v1/apps/${config.appId}/appStoreVersions?filter[platform]=IOS&filter[versionString]=${encodeURIComponent(config.versionString)}&limit=10`;
  const response = await api("GET", route);
  if (!response.data?.length) {
    throw new Error(`No iOS App Store version ${config.versionString} found for app ${config.appId}`);
  }
  return response.data[0];
}

async function getLocalization(versionId) {
  const route = `/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations?filter[locale]=${encodeURIComponent(config.locale)}&limit=10`;
  const response = await api("GET", route);
  if (!response.data?.length) {
    throw new Error(`No ${config.locale} localization found for version ${versionId}`);
  }
  return response.data[0];
}

async function getScreenshotSet(localizationId) {
  const route = `/v1/appStoreVersionLocalizations/${localizationId}/appScreenshotSets?filter[screenshotDisplayType]=${encodeURIComponent(config.displayType)}&include=appScreenshots&limit[appScreenshots]=50`;
  const response = await api("GET", route);
  const set = response.data?.[0] || null;
  const screenshots = (response.included || []).filter((item) => item.type === "appScreenshots");
  return { set, screenshots };
}

async function createScreenshotSet(localizationId) {
  const body = {
    data: {
      type: "appScreenshotSets",
      attributes: {
        screenshotDisplayType: config.displayType,
      },
      relationships: {
        appStoreVersionLocalization: {
          data: {
            type: "appStoreVersionLocalizations",
            id: localizationId,
          },
        },
      },
    },
  };
  return (await api("POST", "/v1/appScreenshotSets", body)).data;
}

async function listScreenshots() {
  const names = (await readdir(config.screenshotDir))
    .filter((name) => /\.(png|jpe?g)$/i.test(name))
    .sort();
  if (!names.length) {
    throw new Error(`No screenshots found in ${config.screenshotDir}`);
  }
  return names.map((name) => path.join(config.screenshotDir, name));
}

async function reserveScreenshot(setId, filePath) {
  const fileStat = await stat(filePath);
  const body = {
    data: {
      type: "appScreenshots",
      attributes: {
        fileSize: fileStat.size,
        fileName: path.basename(filePath),
      },
      relationships: {
        appScreenshotSet: {
          data: {
            type: "appScreenshotSets",
            id: setId,
          },
        },
      },
    },
  };
  return (await api("POST", "/v1/appScreenshots", body)).data;
}

async function uploadScreenshot(reservation, filePath) {
  const bytes = await readFile(filePath);
  const operations = reservation.attributes.uploadOperations || [];
  for (const operation of operations) {
    const headers = {};
    for (const header of operation.requestHeaders || []) {
      headers[header.name] = header.value;
    }
    const chunk = bytes.subarray(operation.offset, operation.offset + operation.length);
    const response = await fetch(operation.url, {
      method: operation.method,
      headers,
      body: chunk,
    });
    if (!response.ok) {
      throw new Error(`Asset upload failed for ${path.basename(filePath)} (${response.status} ${response.statusText})`);
    }
  }

  const checksum = createHash("md5").update(bytes).digest("hex");
  const body = {
    data: {
      type: "appScreenshots",
      id: reservation.id,
      attributes: {
        uploaded: true,
        sourceFileChecksum: checksum,
      },
    },
  };
  return (await api("PATCH", `/v1/appScreenshots/${reservation.id}`, body)).data;
}

async function orderScreenshots(setId, screenshotIds) {
  const body = {
    data: screenshotIds.map((id) => ({ type: "appScreenshots", id })),
  };
  await api("PATCH", `/v1/appScreenshotSets/${setId}/relationships/appScreenshots`, body);
}

async function main() {
  const version = await getAppStoreVersion();
  console.log(`Using App Store version ${version.attributes?.versionString || config.versionString} (${version.id})`);

  const localization = await getLocalization(version.id);
  console.log(`Using localization ${localization.attributes?.locale || config.locale} (${localization.id})`);

  let { set, screenshots } = await getScreenshotSet(localization.id);
  if (set && config.replaceExisting) {
    console.log(`Replacing existing ${config.displayType} screenshot set (${set.id}) with ${screenshots.length} existing screenshot reservation(s).`);
    await deleteResource("appScreenshotSets", set.id);
    set = null;
  }
  if (!set) {
    set = await createScreenshotSet(localization.id);
    console.log(`Created screenshot set ${set.id} for ${config.displayType}`);
  } else {
    console.log(`Using existing screenshot set ${set.id} for ${config.displayType}`);
  }

  const files = await listScreenshots();
  const uploadedIds = [];
  for (const file of files) {
    console.log(`Uploading ${path.basename(file)}...`);
    const reservation = await reserveScreenshot(set.id, file);
    const uploaded = await uploadScreenshot(reservation, file);
    uploadedIds.push(uploaded.id);
    console.log(`Committed ${path.basename(file)} (${uploaded.id})`);
  }

  await orderScreenshots(set.id, uploadedIds);
  console.log(`Uploaded and ordered ${uploadedIds.length} screenshot(s) for ${config.displayType}.`);
}

try {
  await main();
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
