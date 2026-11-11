import http from "k6/http";
import { check, sleep } from "k6";

const baseURL = __ENV.BASE_URL || "http://localhost";

export const options = {
  stages: [
    { duration: "30s", target: 3 },
    { duration: "1m", target: 5 },
    { duration: "30s", target: 0 },
  ],
  thresholds: {
    http_req_failed: ["rate<0.02"],
    http_req_duration: ["p(95)<1500"],
  },
};

export default function () {
  const response = http.get(`${baseURL}/work?delay_ms=100`);
  check(response, { "work returns 200": (result) => result.status === 200 });
  sleep(1);
}
