export class ApiError extends Error {
  constructor(
    public readonly humanMessage: string,
    public readonly code: string | number,
    public readonly raw?: Response,
  ) {
    super(humanMessage);
    this.name = "ApiError";
  }
}

const STATUS_MESSAGES: Record<number, string> = {
  400: "The request was malformed. Please try again.",
  401: "Your session has expired. Please log in again.",
  403: "You don't have permission to do that.",
  404: "The requested resource was not found.",
  409: "This action conflicts with existing data.",
  422: "The request was invalid. Please check your input.",
  429: "You've sent too many requests. Please wait a moment.",
  500: "The server ran into a problem. Please try again shortly.",
  502: "The server is temporarily unavailable. Please try again in a moment.",
  503: "The server is temporarily unavailable. Please try again in a moment.",
  504: "The server took too long to respond. Please try again.",
};

function humanise(status: number, serverMessage?: string): string {
  const base = STATUS_MESSAGES[status] ?? "An unexpected error occurred.";
  const suffix = serverMessage ? ` — ${serverMessage}` : "";
  return `${base} (${status})${suffix}`;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export interface ApiFetchOptions extends RequestInit {
  /** Number of attempts before surfacing an error. Default: 3. */
  retries?: number;
  /** Base delay (ms) between retries — doubles each attempt. Default: 500. */
  backoffMs?: number;
}

/**
 * Fetch wrapper with automatic retry (exponential back-off) and human-readable
 * error messages.
 *
 * - Retries up to `retries` times (default 3) before throwing.
 * - 4xx errors (except 429) are NOT retried — they are surfaced immediately.
 * - Throws `ApiError` with a plain-English `humanMessage` and the HTTP `code`.
 */
export async function apiFetch<T = unknown>(
  url: string,
  options: ApiFetchOptions = {},
): Promise<T> {
  const { retries = 3, backoffMs = 500, ...fetchOptions } = options;
  let lastError: ApiError | null = null;

  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const res = await fetch(url, fetchOptions);

      if (res.ok) {
        return (await res.json()) as T;
      }

      // Try to extract a message from the response body
      let serverMessage: string | undefined;
      try {
        const body = await res.clone().json();
        serverMessage =
          body?.error ?? body?.message ?? body?.errors?.[0] ?? undefined;
      } catch {
        // ignore body parse failures
      }

      lastError = new ApiError(
        humanise(res.status, serverMessage),
        res.status,
        res,
      );

      // Don't retry client errors that won't change (4xx, except 429 rate-limit)
      const isRetryable = res.status === 429 || res.status >= 500;
      if (!isRetryable) break;
    } catch (networkErr) {
      // fetch() itself threw — likely a network/DNS failure
      if (networkErr instanceof ApiError) {
        lastError = networkErr;
      } else {
        lastError = new ApiError(
          "Could not reach the server. Check your connection. (network error)",
          "network error",
        );
      }
    }

    if (attempt < retries) {
      await sleep(backoffMs * attempt); // 500 ms, 1 000 ms, …
    }
  }

  throw lastError;
}

/**
 * Normalise any caught value into a human-readable string.
 * Works with ApiError, legacy `{ error: string }` shapes, and plain Error objects.
 */
export function toHumanError(
  e: unknown,
  fallback = "Something went wrong.",
): string {
  if (e instanceof ApiError) return e.humanMessage;
  if (e && typeof e === "object") {
    if ("error" in e) return String((e as { error: unknown }).error);
    if ("message" in e) return String((e as { message: unknown }).message);
  }
  if (e instanceof Error) return e.message;
  return fallback;
}
