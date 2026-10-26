import { connect } from "cloudflare:sockets";

const HOST = "openapi.seoul.go.kr";
const PORT = 8088;

export function buildPath(key, code) {
  return `/${encodeURIComponent(key)}/json/citydata_ppltn/1/5/${encodeURIComponent(code)}`;
}

export async function fetchSeoul(path, mode) {
  if (mode === "socket") {
    return fetchViaSocket(path);
  }
  const response = await fetch(`http://${HOST}:${PORT}${path}`, {
    headers: { Accept: "application/json" },
  });
  if (!response.ok) {
    throw new Error(`seoul http ${response.status}`);
  }
  return response.json();
}

async function fetchViaSocket(path) {
  const socket = connect({ hostname: HOST, port: PORT });
  const writer = socket.writable.getWriter();
  const request =
    `GET ${path} HTTP/1.1\r\n` +
    `Host: ${HOST}:${PORT}\r\n` +
    `Accept: application/json\r\n` +
    `Connection: close\r\n\r\n`;
  await writer.write(new TextEncoder().encode(request));
  writer.releaseLock();

  const chunks = [];
  const reader = socket.readable.getReader();
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    chunks.push(value);
  }
  await socket.close();

  const raw = concat(chunks);
  const headerEnd = indexOfCRLFCRLF(raw);
  if (headerEnd < 0) {
    throw new Error("seoul socket malformed response");
  }
  const head = new TextDecoder().decode(raw.slice(0, headerEnd));
  const status = Number(head.split(" ")[1]);
  if (status !== 200) {
    throw new Error(`seoul socket ${status}`);
  }
  let body = raw.slice(headerEnd + 4);
  if (/transfer-encoding:\s*chunked/i.test(head)) {
    body = dechunk(body);
  }
  return JSON.parse(new TextDecoder().decode(body));
}

function concat(chunks) {
  const total = chunks.reduce((sum, c) => sum + c.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const c of chunks) {
    out.set(c, offset);
    offset += c.length;
  }
  return out;
}

function indexOfCRLFCRLF(bytes) {
  for (let i = 0; i + 3 < bytes.length; i++) {
    if (bytes[i] === 13 && bytes[i + 1] === 10 && bytes[i + 2] === 13 && bytes[i + 3] === 10) {
      return i;
    }
  }
  return -1;
}

function dechunk(bytes) {
  const parts = [];
  let i = 0;
  const decoder = new TextDecoder();
  while (i < bytes.length) {
    let lineEnd = i;
    while (lineEnd + 1 < bytes.length && !(bytes[lineEnd] === 13 && bytes[lineEnd + 1] === 10)) {
      lineEnd++;
    }
    const size = parseInt(decoder.decode(bytes.slice(i, lineEnd)).trim(), 16);
    if (!size) break;
    const start = lineEnd + 2;
    parts.push(bytes.slice(start, start + size));
    i = start + size + 2;
  }
  return concat(parts);
}

export function normalize(json) {
  const list = json["SeoulRtd.citydata_ppltn"];
  if (!Array.isArray(list) || list.length === 0) {
    const result = json.RESULT || {};
    throw new Error(`seoul result ${result["RESULT.CODE"] || "unknown"}`);
  }
  const p = list[0];
  return {
    code: p.AREA_CD,
    name: p.AREA_NM,
    level: p.AREA_CONGEST_LVL,
    message: p.AREA_CONGEST_MSG,
    populationMin: Number(p.AREA_PPLTN_MIN),
    populationMax: Number(p.AREA_PPLTN_MAX),
    observedAt: p.PPLTN_TIME,
    forecast: (p.FCST_PPLTN || []).map((f) => ({
      time: f.FCST_TIME,
      level: f.FCST_CONGEST_LVL,
      populationMin: Number(f.FCST_PPLTN_MIN),
      populationMax: Number(f.FCST_PPLTN_MAX),
    })),
  };
}
