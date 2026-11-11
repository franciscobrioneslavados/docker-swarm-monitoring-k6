import http from "k6/http";
import { check } from "k6";

const baseURL = __ENV.BASE_URL || "http://localhost";

export const options = {
  vus: 1,
  iterations: 5,
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<1000"],
  },
};

export default function () {
  const health = http.get(`${baseURL}/health`);
  check(health, { "health returns 200": (response) => response.status === 200 });

  const work = http.get(`${baseURL}/work?delay_ms=50`);
  check(work, { "work returns 200": (response) => response.status === 200 });
}
