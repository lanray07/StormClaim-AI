import { createHash, sign } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";

// Configures the StormClaim AI auto-renewable subscriptions in App Store Connect.
// Expects App Store Connect credentials through environment variables; never
// store API keys or private key material in this repository.
const API_ROOT = "https://api.appstoreconnect.apple.com";

const config = {
  issuerId: requiredEnv("ASC_ISSUER_ID"),
  keyId: requiredEnv("ASC_KEY_ID"),
  privateKeyPath: requiredEnv("ASC_PRIVATE_KEY_PATH"),
  appId: requiredEnv("ASC_APP_ID"),
  locale: process.env.ASC_LOCALE || "en-GB",
  territory: process.env.ASC_TERRITORY || "GBR",
  allTerritories: process.env.ASC_ALL_TERRITORIES !== "0",
  reviewScreenshotPath: process.env.ASC_SUBSCRIPTION_REVIEW_SCREENSHOT || "",
};

const group = {
  referenceName: "StormClaim AI Subscriptions",
  displayName: "StormClaim AI Plans",
};

const plans = [
  {
    name: "StormClaim AI Pro Monthly",
    productId: "stormclaim.pro.monthly",
    displayName: "Pro Monthly",
    description: "Cases, AI scans, pro PDFs, logo and templates.",
    period: "ONE_MONTH",
    groupLevel: 2,
    gbpPrice: "29.99",
  },
  {
    name: "StormClaim AI Pro Yearly",
    productId: "stormclaim.pro.yearly",
    displayName: "Pro Yearly",
    description: "Annual Pro with scans, PDFs, logo and templates.",
    period: "ONE_YEAR",
    groupLevel: 2,
    gbpPrice: "249.99",
  },
  {
    name: "StormClaim AI Business Monthly",
    productId: "stormclaim.business.monthly",
    displayName: "Business Monthly",
    description: "Branding, claim-support reports and action lists.",
    period: "ONE_MONTH",
    groupLevel: 1,
    gbpPrice: "89.99",
  },
];

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
  let json = null;
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      json = { raw: text };
    }
  }
  if (!response.ok) {
    const message =
      json?.errors
        ?.map((error) => `${error.status} ${error.code}: ${error.title} ${error.detail || ""}`)
        .join("\n") || text;
    throw new Error(`${method} ${route} failed (${response.status})\n${message}`);
  }
  return json;
}

async function apiMaybe(method, route, body) {
  try {
    return await api(method, route, body);
  } catch (error) {
    return { error };
  }
}

async function getOrCreateGroup() {
  const existing = await api("GET", `/v1/apps/${config.appId}/subscriptionGroups?limit=50`);
  const found = existing.data.find((item) => item.attributes?.referenceName === group.referenceName);
  if (found) {
    console.log(`Using subscription group ${found.id}`);
    return found;
  }

  const created = await api("POST", "/v1/subscriptionGroups", {
    data: {
      type: "subscriptionGroups",
      attributes: { referenceName: group.referenceName },
      relationships: {
        app: { data: { type: "apps", id: config.appId } },
      },
    },
  });
  console.log(`Created subscription group ${created.data.id}`);
  return created.data;
}

async function ensureGroupLocalization(groupId) {
  const existing = await api("GET", `/v1/subscriptionGroups/${groupId}/subscriptionGroupLocalizations?limit=50`);
  const found = existing.data.find((item) => item.attributes?.locale === config.locale);
  const body = {
    data: {
      type: "subscriptionGroupLocalizations",
      attributes: {
        locale: config.locale,
        name: group.displayName,
      },
      relationships: {
        subscriptionGroup: { data: { type: "subscriptionGroups", id: groupId } },
      },
    },
  };

  if (found) {
    await api("PATCH", `/v1/subscriptionGroupLocalizations/${found.id}`, {
      data: {
        type: "subscriptionGroupLocalizations",
        id: found.id,
        attributes: { name: group.displayName },
      },
    });
    console.log(`Updated group localization ${config.locale}`);
    return;
  }

  await api("POST", "/v1/subscriptionGroupLocalizations", body);
  console.log(`Created group localization ${config.locale}`);
}

async function getSubscriptions(groupId) {
  const response = await api("GET", `/v1/subscriptionGroups/${groupId}/subscriptions?limit=50`);
  return response.data || [];
}

async function getOrCreateSubscription(groupId, plan, existingSubscriptions) {
  const found = existingSubscriptions.find((item) => item.attributes?.productId === plan.productId);
  const attributes = {
    name: plan.name,
    productId: plan.productId,
    subscriptionPeriod: plan.period,
    groupLevel: plan.groupLevel,
    familySharable: false,
    reviewNote: "StoreKit 2 subscription for StormClaim AI paywall features. Mock AI mode is enabled by default.",
  };

  if (found) {
    await api("PATCH", `/v1/subscriptions/${found.id}`, {
      data: {
        type: "subscriptions",
        id: found.id,
        attributes: {
          name: plan.name,
          groupLevel: plan.groupLevel,
          familySharable: false,
          reviewNote: "StoreKit 2 subscription for StormClaim AI paywall features. Mock AI mode is enabled by default.",
        },
      },
    });
    console.log(`Updated subscription ${plan.productId} (${found.id})`);
    return found;
  }

  const created = await api("POST", "/v1/subscriptions", {
    data: {
      type: "subscriptions",
      attributes,
      relationships: {
        group: { data: { type: "subscriptionGroups", id: groupId } },
      },
    },
  });
  console.log(`Created subscription ${plan.productId} (${created.data.id})`);
  return created.data;
}

async function ensureSubscriptionLocalization(subscriptionId, plan) {
  const existing = await api("GET", `/v1/subscriptions/${subscriptionId}/subscriptionLocalizations?limit=50`);
  const found = existing.data.find((item) => item.attributes?.locale === config.locale);
  const attributes = {
    locale: config.locale,
    name: plan.displayName,
    description: plan.description,
  };

  if (found) {
    await api("PATCH", `/v1/subscriptionLocalizations/${found.id}`, {
      data: {
        type: "subscriptionLocalizations",
        id: found.id,
        attributes: {
          name: plan.displayName,
          description: plan.description,
        },
      },
    });
    console.log(`Updated localization for ${plan.productId}`);
    return;
  }

  await api("POST", "/v1/subscriptionLocalizations", {
    data: {
      type: "subscriptionLocalizations",
      attributes,
      relationships: {
        subscription: { data: { type: "subscriptions", id: subscriptionId } },
      },
    },
  });
  console.log(`Created localization for ${plan.productId}`);
}

async function findPricePoint(subscriptionId, targetPrice) {
  const response = await api(
    "GET",
    `/v1/subscriptions/${subscriptionId}/pricePoints?filter[territory]=${encodeURIComponent(config.territory)}&include=territory&limit=8000`,
  );
  const found = response.data.find((item) => item.attributes?.customerPrice === targetPrice);
  if (!found) {
    const sample = response.data
      .slice(0, 10)
      .map((item) => item.attributes?.customerPrice)
      .join(", ");
    throw new Error(`No ${config.territory} price point found for ${targetPrice}. Sample prices: ${sample}`);
  }
  return found;
}

async function getAllTerritories() {
  const response = await api("GET", "/v1/territories?limit=200");
  return response.data || [];
}

async function getTargetTerritoryIds() {
  if (!config.allTerritories) return [config.territory];
  const territories = await getAllTerritories();
  return territories.map((territory) => territory.id);
}

async function existingPrices(subscriptionId) {
  const response = await api(
    "GET",
    `/v1/subscriptions/${subscriptionId}/prices?include=subscriptionPricePoint,territory&limit=200`,
  );
  return response.data || [];
}

async function equalizedPricePoints(basePricePointId) {
  const response = await api(
    "GET",
    `/v1/subscriptionPricePoints/${encodeURIComponent(basePricePointId)}/equalizations?include=territory&limit=200`,
  );
  return response.data || [];
}

async function createSubscriptionPrice(subscriptionId, pricePointId) {
  await api("POST", "/v1/subscriptionPrices", {
    data: {
      type: "subscriptionPrices",
      attributes: {
        preserveCurrentPrice: true,
      },
      relationships: {
        subscription: { data: { type: "subscriptions", id: subscriptionId } },
        subscriptionPricePoint: { data: { type: "subscriptionPricePoints", id: pricePointId } },
      },
    },
  });
}

async function ensurePrice(subscriptionId, plan) {
  const basePricePoint = await findPricePoint(subscriptionId, plan.gbpPrice);

  if (!config.allTerritories) {
    const existing = (await existingPrices(subscriptionId)).find(
      (price) => price.relationships?.territory?.data?.id === config.territory,
    );
    if (existing) {
      console.log(`Price already exists for ${plan.productId} in ${config.territory}`);
      return;
    }

    await createSubscriptionPrice(subscriptionId, basePricePoint.id);
    console.log(`Set ${config.territory} price ${plan.gbpPrice} for ${plan.productId}`);
    return;
  }

  const targetTerritoryIds = await getTargetTerritoryIds();
  const existingTerritoryIds = new Set(
    (await existingPrices(subscriptionId)).map((price) => price.relationships?.territory?.data?.id).filter(Boolean),
  );
  const equalized = await equalizedPricePoints(basePricePoint.id);
  const pricePointByTerritory = new Map([
    [config.territory, basePricePoint.id],
    ...equalized.map((pricePoint) => [pricePoint.relationships?.territory?.data?.id, pricePoint.id]),
  ]);

  let created = 0;
  for (const territoryId of targetTerritoryIds) {
    if (existingTerritoryIds.has(territoryId)) continue;

    const pricePointId = pricePointByTerritory.get(territoryId);
    if (!pricePointId) {
      console.warn(`No equalized price point for ${plan.productId} in ${territoryId}`);
      continue;
    }

    await createSubscriptionPrice(subscriptionId, pricePointId);
    created += 1;
  }

  console.log(`Ensured ${targetTerritoryIds.length} territory prices for ${plan.productId} (${created} created)`);
}

async function ensureAvailability(subscriptionId, plan) {
  const response = await apiMaybe("GET", `/v1/subscriptions/${subscriptionId}/subscriptionAvailability`);
  const territoryIds = await getTargetTerritoryIds();

  const created = await apiMaybe("POST", "/v1/subscriptionAvailabilities", {
    data: {
      type: "subscriptionAvailabilities",
      attributes: {
        availableInNewTerritories: config.allTerritories,
      },
      relationships: {
        subscription: { data: { type: "subscriptions", id: subscriptionId } },
        availableTerritories: {
          data: territoryIds.map((territoryId) => ({ type: "territories", id: territoryId })),
        },
      },
    },
  });

  if (created.error) {
    console.warn(`Skipped availability for ${plan.productId}: ${created.error.message.split("\n")[0]}`);
    return;
  }

  const changed = response.error || response.data?.attributes?.availableInNewTerritories !== config.allTerritories;
  const verb = changed ? "Set" : "Ensured";
  console.log(`${verb} ${territoryIds.length} territory availability for ${plan.productId}`);
}

async function existingReviewScreenshot(subscriptionId) {
  const response = await apiMaybe("GET", `/v1/subscriptions/${subscriptionId}/appStoreReviewScreenshot`);
  return response.error ? null : response.data;
}

async function uploadReviewScreenshot(subscriptionId, plan) {
  if (!config.reviewScreenshotPath) return;
  const existing = await existingReviewScreenshot(subscriptionId);
  if (existing) {
    console.log(`Review screenshot already exists for ${plan.productId}`);
    return;
  }

  const fileStat = await stat(config.reviewScreenshotPath);
  const reservation = await api("POST", "/v1/subscriptionAppStoreReviewScreenshots", {
    data: {
      type: "subscriptionAppStoreReviewScreenshots",
      attributes: {
        fileName: path.basename(config.reviewScreenshotPath),
        fileSize: fileStat.size,
      },
      relationships: {
        subscription: { data: { type: "subscriptions", id: subscriptionId } },
      },
    },
  });

  const bytes = await readFile(config.reviewScreenshotPath);
  for (const operation of reservation.data.attributes.uploadOperations || []) {
    const headers = {};
    for (const header of operation.requestHeaders || []) headers[header.name] = header.value;
    const chunk = bytes.subarray(operation.offset, operation.offset + operation.length);
    const response = await fetch(operation.url, {
      method: operation.method,
      headers,
      body: chunk,
    });
    if (!response.ok) {
      throw new Error(`Review screenshot upload failed for ${plan.productId}: ${response.status} ${response.statusText}`);
    }
  }

  await api("PATCH", `/v1/subscriptionAppStoreReviewScreenshots/${reservation.data.id}`, {
    data: {
      type: "subscriptionAppStoreReviewScreenshots",
      id: reservation.data.id,
      attributes: {
        uploaded: true,
        sourceFileChecksum: createHash("md5").update(bytes).digest("hex"),
      },
    },
  });
  console.log(`Uploaded review screenshot for ${plan.productId}`);
}

async function summarize(groupId) {
  const subscriptions = await getSubscriptions(groupId);
  console.log("\nConfigured subscriptions:");
  for (const subscription of subscriptions) {
    console.log(
      `- ${subscription.attributes.productId}: ${subscription.attributes.name} (${subscription.attributes.state || "state pending"})`,
    );
  }
}

async function main() {
  const subscriptionGroup = await getOrCreateGroup();
  await ensureGroupLocalization(subscriptionGroup.id);

  let existingSubscriptions = await getSubscriptions(subscriptionGroup.id);
  for (const plan of plans) {
    const subscription = await getOrCreateSubscription(subscriptionGroup.id, plan, existingSubscriptions);
    await ensureSubscriptionLocalization(subscription.id, plan);
    await ensureAvailability(subscription.id, plan);
    await ensurePrice(subscription.id, plan);
    await uploadReviewScreenshot(subscription.id, plan);
    existingSubscriptions = await getSubscriptions(subscriptionGroup.id);
  }

  await summarize(subscriptionGroup.id);
}

try {
  await main();
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
