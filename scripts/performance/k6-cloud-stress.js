import http from "k6/http";
import { check, sleep } from "k6";

const baseUrl = (__ENV.BASE_URL || "https://api.ankangxai.cn").replace(/\/+$/, "");
const password = __ENV.PERF_PASSWORD;
const targetVus = Number(__ENV.TARGET_VUS || 100);
const initialRampDuration = __ENV.INITIAL_RAMP_DURATION || "30s";
const targetRampDuration = __ENV.TARGET_RAMP_DURATION || "1m";
const holdDuration = __ENV.HOLD_DURATION || "5m";
const rampDownDuration = __ENV.RAMP_DOWN_DURATION || "30s";
const usernames = JSON.parse(open("./perf-usernames.json").replace(/^\uFEFF/, ""));

export const options = {
  setupTimeout: "2m",
  scenarios: {
    cloud_api: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: initialRampDuration, target: Math.min(20, targetVus) },
        { duration: targetRampDuration, target: targetVus },
        { duration: holdDuration, target: targetVus },
        { duration: rampDownDuration, target: 0 },
      ],
      gracefulRampDown: "10s",
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<3000", "p(99)<3000"],
    checks: ["rate>0.99"],
  },
};

export function setup() {
  if (!password) {
    throw new Error("必须通过 PERF_PASSWORD 提供专用压测密码");
  }
  if (!Array.isArray(usernames) || usernames.length < targetVus) {
    throw new Error(
      `账号数量不足：需要 ${targetVus} 个，当前只有 ${usernames.length} 个`,
    );
  }

  const tokens = [];
  for (const username of usernames.slice(0, targetVus)) {
    const response = http.post(
      `${baseUrl}/api/auth/login`,
      JSON.stringify({
        username,
        password,
        keepSignedIn: false,
      }),
      {
        headers: { "Content-Type": "application/json" },
        tags: { endpoint: "login" },
        timeout: "10s",
      },
    );

    const token = response.status === 200 ? response.json("data.token") : null;
    const loginPassed = check(response, {
      "登录返回 HTTP 200": (result) => result.status === 200,
      "登录返回 access token": () => Boolean(token),
    });
    if (!loginPassed) {
      throw new Error(`压测账号 ${username} 登录失败：HTTP ${response.status}`);
    }
    tokens.push(token);
  }

  return { tokens };
}

export default function (data) {
  const tokenIndex = (__VU - 1) % data.tokens.length;
  const headers = { Authorization: `Bearer ${data.tokens[tokenIndex]}` };
  const selector = Math.random();
  let path;
  let endpoint;

  if (selector < 0.50) {
    path = "/api/health/records?page=1&size=20";
    endpoint = "records";
  } else if (selector < 0.70) {
    path = "/api/health/summary";
    endpoint = "summary";
  } else if (selector < 0.90) {
    path = "/api/health/trend?type=heart_rate&days=30";
    endpoint = "trend";
  } else {
    path = "/api/reminders";
    endpoint = "reminders";
  }

  const response = http.get(`${baseUrl}${path}`, {
    headers,
    tags: { endpoint },
    timeout: "10s",
  });

  check(response, {
    [`${endpoint} 返回 HTTP 200`]: (result) => result.status === 200,
    [`${endpoint} 响应小于 3 秒`]: (result) => result.timings.duration < 3000,
  });

  sleep(0.2);
}
