// GET {LOCATION_SERVICE_URL}/api/v1/catalog/snapshot?providers=ghn with the API key; one retry on a 5xx or a network error.
const TIMEOUT_MS = 60_000;

const attempt = async (url, key) => {
  const response = await fetch(url, { headers: { Authorization: `Bearer ${key}`, Accept: "application/x-ndjson" }, signal: AbortSignal.timeout(TIMEOUT_MS) });
  if (response.status >= 500) throw Object.assign(new Error(`the service answered ${response.status}`), { retry: true });
  if (!response.ok) throw Object.assign(new Error(`the service answered ${response.status}`), { retry: false });
  return response.text();
};

export const fetchSnapshot = async (env) => {
  const base = env.LOCATION_SERVICE_URL;
  const key = env.LOCATION_SERVICE_KEY;
  if (!base || !key) throw new Error("LOCATION_SERVICE_URL and LOCATION_SERVICE_KEY must be set");
  const url = `${base.replace(/\/$/, "")}/api/v1/catalog/snapshot?providers=ghn`;
  try {
    return await attempt(url, key);
  } catch (error) {
    if (error.retry === false) throw error;
    return attempt(url, key);
  }
};
