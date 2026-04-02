// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { apiFetch, ApiError, toHumanError } from "../lib/apiFetch";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function mockResponse(status: number, body: unknown = {}): Response {
  const json = JSON.stringify(body);
  return new Response(json, {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function setupFetch(...responses: Response[]) {
  let call = 0;
  vi.stubGlobal(
    "fetch",
    vi.fn().mockImplementation(() => {
      const res = responses[call] ?? responses[responses.length - 1];
      call++;
      return Promise.resolve(res);
    }),
  );
}

function setupFetchNetworkError(afterAttempts = 0) {
  let call = 0;
  vi.stubGlobal(
    "fetch",
    vi.fn().mockImplementation(() => {
      if (call++ < afterAttempts) return Promise.resolve(mockResponse(200, {}));
      return Promise.reject(new TypeError("Failed to fetch"));
    }),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("apiFetch", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  // ── Success path ──────────────────────────────────────────────────────────

  it("resolves with parsed JSON on a 2xx response", async () => {
    setupFetch(mockResponse(200, { ok: true }));
    const result = await apiFetch("/test", { backoffMs: 0 });
    expect(result).toEqual({ ok: true });
  });

  // ── Retry behaviour ───────────────────────────────────────────────────────

  it("retries on 500 and succeeds on the 2nd attempt", async () => {
    setupFetch(mockResponse(500), mockResponse(200, { value: 42 }));
    const p = apiFetch<{ value: number }>("/test", { backoffMs: 0 });
    await vi.runAllTimersAsync();
    const result = await p;
    expect(result).toEqual({ value: 42 });
    expect(vi.mocked(fetch)).toHaveBeenCalledTimes(2);
  });

  it("retries on 502 up to 3 times then throws ApiError", async () => {
    setupFetch(mockResponse(502), mockResponse(502), mockResponse(502));
    const p = apiFetch("/test", { retries: 3, backoffMs: 0 });
    // Attach rejection handler BEFORE running timers to avoid unhandled-rejection warnings.
    const assertion = expect(p).rejects.toBeInstanceOf(ApiError);
    await vi.runAllTimersAsync();
    await assertion;
    expect(vi.mocked(fetch)).toHaveBeenCalledTimes(3);
  });

  it("retries on network error and succeeds on 2nd attempt", async () => {
    let call = 0;
    vi.stubGlobal(
      "fetch",
      vi.fn().mockImplementation(() => {
        if (call++ === 0)
          return Promise.reject(new TypeError("Failed to fetch"));
        return Promise.resolve(mockResponse(200, { recovered: true }));
      }),
    );
    const p = apiFetch("/test", { backoffMs: 0 });
    await vi.runAllTimersAsync();
    const result = await p;
    expect(result).toEqual({ recovered: true });
  });

  it("throws after all retries are exhausted on network error", async () => {
    setupFetchNetworkError(0);
    const p = apiFetch("/test", { retries: 3, backoffMs: 0 });
    const assertion = expect(p).rejects.toBeInstanceOf(ApiError);
    await vi.runAllTimersAsync();
    await assertion;
    expect(vi.mocked(fetch)).toHaveBeenCalledTimes(3);
  });

  it("does NOT retry 4xx client errors (except 429)", async () => {
    setupFetch(mockResponse(404));
    const p = apiFetch("/test", { backoffMs: 0 });
    const assertion = expect(p).rejects.toBeInstanceOf(ApiError);
    await vi.runAllTimersAsync();
    await assertion;
    expect(vi.mocked(fetch)).toHaveBeenCalledTimes(1); // no retry
  });

  it("retries on 429 (rate-limit) because it is retryable", async () => {
    setupFetch(mockResponse(429), mockResponse(200, {}));
    const p = apiFetch("/test", { backoffMs: 0 });
    await vi.runAllTimersAsync();
    await p;
    expect(vi.mocked(fetch)).toHaveBeenCalledTimes(2);
  });

  it("uses exponential backoff between retries", async () => {
    setupFetch(mockResponse(500), mockResponse(500), mockResponse(200, {}));
    const setTimeoutSpy = vi.spyOn(globalThis, "setTimeout");
    const p = apiFetch("/test", { retries: 3, backoffMs: 200 });
    await vi.runAllTimersAsync();
    await p;
    const delays = setTimeoutSpy.mock.calls.map((c) => c[1]);
    expect(delays).toContain(200); // attempt 1 → 200 ms
    expect(delays).toContain(400); // attempt 2 → 400 ms
  });

  // ── Human-readable error messages ─────────────────────────────────────────

  // Helper: attach catch handler BEFORE running timers to avoid unhandled-rejection
  // warnings.  This pattern ensures Node/Vitest never sees the rejection as unhandled
  // even though it is intentional.
  async function expectApiError(p: Promise<unknown>): Promise<ApiError> {
    const caught = p.catch((e) => e as ApiError) as Promise<ApiError>;
    await vi.runAllTimersAsync();
    return caught;
  }

  it("maps 401 to a human-readable message including the code", async () => {
    setupFetch(mockResponse(401));
    const err = await expectApiError(apiFetch("/test", { backoffMs: 0 }));
    expect(err).toBeInstanceOf(ApiError);
    expect(err.humanMessage).toContain("session has expired");
    expect(err.humanMessage).toContain("(401)");
    expect(err.code).toBe(401);
  });

  it("maps 403 to a permission-denied message", async () => {
    setupFetch(mockResponse(403));
    const err = await expectApiError(apiFetch("/test", { backoffMs: 0 }));
    expect(err.humanMessage).toContain("don't have permission");
    expect(err.humanMessage).toContain("(403)");
  });

  it("maps 404 to a not-found message", async () => {
    setupFetch(mockResponse(404));
    const err = await expectApiError(apiFetch("/test", { backoffMs: 0 }));
    expect(err.humanMessage).toContain("not found");
    expect(err.humanMessage).toContain("(404)");
  });

  it("maps 422 to an invalid-request message", async () => {
    setupFetch(mockResponse(422));
    const err = await expectApiError(apiFetch("/test", { backoffMs: 0 }));
    expect(err.humanMessage).toContain("invalid");
    expect(err.humanMessage).toContain("(422)");
  });

  it("maps 500 to a server-problem message", async () => {
    setupFetch(mockResponse(500, {}));
    const err = await expectApiError(
      apiFetch("/test", { retries: 1, backoffMs: 0 }),
    );
    expect(err.humanMessage).toContain("server ran into a problem");
    expect(err.humanMessage).toContain("(500)");
  });

  it("maps 502 to an unavailable message", async () => {
    setupFetch(mockResponse(502, {}));
    const err = await expectApiError(
      apiFetch("/test", { retries: 1, backoffMs: 0 }),
    );
    expect(err.humanMessage).toContain("temporarily unavailable");
    expect(err.humanMessage).toContain("(502)");
  });

  it("maps 503 to an unavailable message", async () => {
    setupFetch(mockResponse(503, {}));
    const err = await expectApiError(
      apiFetch("/test", { retries: 1, backoffMs: 0 }),
    );
    expect(err.humanMessage).toContain("temporarily unavailable");
    expect(err.humanMessage).toContain("(503)");
  });

  it("maps 504 to a timeout message", async () => {
    setupFetch(mockResponse(504, {}));
    const err = await expectApiError(
      apiFetch("/test", { retries: 1, backoffMs: 0 }),
    );
    expect(err.humanMessage).toContain("took too long");
    expect(err.humanMessage).toContain("(504)");
  });

  it("appends server error message to the human message when present", async () => {
    setupFetch(mockResponse(422, { error: "email already taken" }));
    const err = await expectApiError(apiFetch("/test", { backoffMs: 0 }));
    expect(err.humanMessage).toContain("email already taken");
    expect(err.humanMessage).toContain("(422)");
  });

  it("uses generic message for unknown status codes", async () => {
    setupFetch(mockResponse(418)); // I'm a teapot
    const err = await expectApiError(apiFetch("/test", { backoffMs: 0 }));
    expect(err.humanMessage).toContain("unexpected error");
    expect(err.humanMessage).toContain("(418)");
  });

  it("maps network error to a connection message", async () => {
    setupFetchNetworkError();
    const err = await expectApiError(
      apiFetch("/test", { retries: 1, backoffMs: 0 }),
    );
    expect(err).toBeInstanceOf(ApiError);
    expect(err.humanMessage).toContain("Could not reach the server");
    expect(err.code).toBe("network error");
  });

  // ── Custom retry count ────────────────────────────────────────────────────

  it("respects retries: 1 — throws immediately without retrying", async () => {
    setupFetch(mockResponse(500));
    const p = apiFetch("/test", { retries: 1, backoffMs: 0 });
    const assertion = expect(p).rejects.toBeInstanceOf(ApiError);
    await vi.runAllTimersAsync();
    await assertion;
    expect(vi.mocked(fetch)).toHaveBeenCalledTimes(1);
  });

  it("succeeds on 3rd attempt when retries: 3", async () => {
    setupFetch(
      mockResponse(503),
      mockResponse(503),
      mockResponse(200, { done: true }),
    );
    const p = apiFetch("/test", { retries: 3, backoffMs: 0 });
    await vi.runAllTimersAsync();
    const result = await p;
    expect(result).toEqual({ done: true });
    expect(vi.mocked(fetch)).toHaveBeenCalledTimes(3);
  });
});

// ---------------------------------------------------------------------------
// toHumanError helper
// ---------------------------------------------------------------------------

describe("toHumanError", () => {
  it("returns humanMessage from ApiError", () => {
    const err = new ApiError("Server error. (500)", 500);
    expect(toHumanError(err)).toBe("Server error. (500)");
  });

  it("returns .error string from legacy {error} shape", () => {
    expect(toHumanError({ error: "Network error" })).toBe("Network error");
  });

  it("returns .message from Error instances", () => {
    expect(toHumanError(new Error("oops"))).toBe("oops");
  });

  it("returns fallback for unknown shapes", () => {
    expect(toHumanError(null)).toBe("Something went wrong.");
    expect(toHumanError(42)).toBe("Something went wrong.");
  });

  it("accepts a custom fallback string", () => {
    expect(toHumanError(null, "Custom fallback")).toBe("Custom fallback");
  });
});
