import { PLACE_CODES } from "./places.js";
import { buildPath, fetchSeoul, normalize } from "./seoul.js";

const CRON_CHUNKS = ["*/10 * * * *", "2-59/10 * * * *", "4-59/10 * * * *"];
const CHUNK_COUNT = CRON_CHUNKS.length;
const PLACE_TTL_SECONDS = 300;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({ ok: true });
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

    if (url.pathname === "/v1/admin/refresh") {
      const chunk = Number(url.searchParams.get("chunk") ?? 0);
      const result = await refreshChunk(chunk, env);
      return json(result);
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

async function refreshChunk(chunk, env) {
  const codes = chunkCodes(chunk);
  const places = {};
  const failures = [];
  const results = await Promise.allSettled(
    codes.map((code) => fetchSeoul(buildPath(env.SEOUL_API_KEY, code), env.SEOUL_FETCH_MODE).then(normalize))
  );
  results.forEach((result, index) => {
    if (result.status === "fulfilled") {
      places[codes[index]] = result.value;
    } else {
      failures.push({ code: codes[index], reason: String(result.reason?.message || result.reason) });
    }
  });
  const record = { updatedAt: new Date().toISOString(), places };
  if (Object.keys(places).length > 0) {
    await env.SNAPSHOT.put(`chunk:${chunk}`, JSON.stringify(record));
  }
  return { chunk, requested: codes.length, stored: Object.keys(places).length, failures };
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
