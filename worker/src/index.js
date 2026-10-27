import { PLACE_CODES } from "./places.js";
import { PRIVACY_HTML } from "./privacy.js";
import { buildPath, fetchSeoul, normalize } from "./seoul.js";

const CRON_CHUNKS = ["*/10 * * * *", "2-59/10 * * * *", "4-59/10 * * * *"];
const CHUNK_COUNT = CRON_CHUNKS.length;
const PLACE_TTL_SECONDS = 300;
const SUBREQUEST_LIMIT = 50;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({ ok: true });
    }

    if (url.pathname === "/privacy") {
      return new Response(PRIVACY_HTML, {
        headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=3600" },
      });
    }

    if (url.pathname === "/v1/admin/refresh") {
      if (!env.ADMIN_TOKEN || request.headers.get("X-Admin-Token") !== env.ADMIN_TOKEN) {
        return json({ error: "unauthorized" }, 401);
      }
      const chunk = Number(url.searchParams.get("chunk") ?? 0);
      if (!Number.isInteger(chunk) || chunk < 0 || chunk >= CHUNK_COUNT) {
        return json({ error: "invalid_chunk" }, 400);
      }
      return json(await refreshChunk(chunk, env));
    }

    if (request.headers.get("X-App-Token") !== env.APP_TOKEN) {
      return json({ error: "unauthorized" }, 401);
    }

    if (url.pathname === "/v1/snapshot") {
      return json(await readSnapshot(env));
    }

    const match = url.pathname.match(/^\/v1\/places\/(POI\d{3})$/);
    if (match) {
      return placeResponse(match[1], env, ctx);
    }

    return json({ error: "not_found" }, 404);
  },

  async scheduled(event, env, ctx) {
    const chunk = CRON_CHUNKS.indexOf(event.cron);
    if (chunk < 0) return;
    ctx.waitUntil(refreshChunk(chunk, env));
  },
};

async function placeResponse(code, env, ctx) {
  if (!PLACE_CODES.includes(code)) {
    return json({ error: "unknown_place" }, 404);
  }
  const cache = caches.default;
  const cacheKey = new Request(`https://cache.calmmap/places/${code}`);
  const cached = await cache.match(cacheKey);
  if (cached) {
    return cached;
  }
  try {
    const place = normalize(await fetchSeoul(buildPath(env.SEOUL_API_KEY, code), env.SEOUL_FETCH_MODE));
    const response = json(place, 200, { "Cache-Control": `public, max-age=${PLACE_TTL_SECONDS}` });
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  } catch (error) {
    return json({ error: "upstream_failed", detail: String(error.message || error) }, 502);
  }
}

function chunkCodes(chunk) {
  const size = Math.ceil(PLACE_CODES.length / CHUNK_COUNT);
  return PLACE_CODES.slice(chunk * size, (chunk + 1) * size);
}

async function fetchPlace(code, env) {
  return normalize(await fetchSeoul(buildPath(env.SEOUL_API_KEY, code), env.SEOUL_FETCH_MODE));
}

async function refreshChunk(chunk, env) {
  const codes = chunkCodes(chunk);
  const places = {};
  const results = await Promise.allSettled(codes.map((code) => fetchPlace(code, env)));
  const retry = [];
  results.forEach((result, index) => {
    if (result.status === "fulfilled") {
      places[codes[index]] = result.value;
    } else {
      retry.push(codes[index]);
    }
  });

  const failures = [];
  const retryBudget = Math.max(SUBREQUEST_LIMIT - codes.length - 1, 0);
  for (const code of retry.slice(retryBudget)) {
    failures.push({ code, reason: "retry_budget_exhausted" });
  }
  for (const code of retry.slice(0, retryBudget)) {
    try {
      places[code] = await fetchPlace(code, env);
    } catch (error) {
      failures.push({ code, reason: String(error?.message || error) });
    }
  }

  const previous = await env.SNAPSHOT.get(`chunk:${chunk}`, "json");
  let kept = 0;
  for (const { code } of failures) {
    if (previous?.places?.[code]) {
      places[code] = previous.places[code];
      kept += 1;
    }
  }

  const fresh = codes.length - failures.length;
  if (fresh > 0) {
    const record = { updatedAt: new Date().toISOString(), places, failures };
    await env.SNAPSHOT.put(`chunk:${chunk}`, JSON.stringify(record));
  }
  return { chunk, requested: codes.length, fresh, retried: retry.length, kept, failures };
}

async function readSnapshot(env) {
  const records = await Promise.all(
    Array.from({ length: CHUNK_COUNT }, (_, i) => env.SNAPSHOT.get(`chunk:${i}`, "json"))
  );
  const places = {};
  const updatedAt = [];
  for (const record of records) {
    if (!record) continue;
    Object.assign(places, record.places);
    updatedAt.push(record.updatedAt);
  }
  return { updatedAt: updatedAt.sort()[0] ?? null, places };
}

function json(body, status = 200, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...headers },
  });
}
