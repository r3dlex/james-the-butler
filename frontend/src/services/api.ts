import { apiFetch } from "@/lib/apiFetch";

const BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:4000";

// Recursively convert camelCase keys to snake_case for outgoing requests
function snakify(obj: unknown): unknown {
  if (Array.isArray(obj)) return obj.map(snakify);
  if (obj !== null && typeof obj === "object") {
    return Object.fromEntries(
      Object.entries(obj as Record<string, unknown>).map(([k, v]) => [
        k.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`),
        snakify(v),
      ]),
    );
  }
  return obj;
}

// Recursively convert snake_case keys to camelCase
function camelize(obj: unknown): unknown {
  if (Array.isArray(obj)) return obj.map(camelize);
  if (obj !== null && typeof obj === "object") {
    return Object.fromEntries(
      Object.entries(obj as Record<string, unknown>).map(([k, v]) => [
        k.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase()),
        camelize(v),
      ]),
    );
  }
  return obj;
}

class ApiClient {
  private token: string | null = null;

  setToken(token: string | null) {
    this.token = token;
  }

  private headers(): Record<string, string> {
    const h: Record<string, string> = { "Content-Type": "application/json" };
    if (this.token) h["Authorization"] = `Bearer ${this.token}`;
    return h;
  }

  async get<T>(path: string): Promise<T> {
    const raw = await apiFetch<unknown>(`${BASE_URL}${path}`, {
      headers: this.headers(),
    });
    return camelize(raw) as T;
  }

  async post<T>(path: string, body?: unknown): Promise<T> {
    const raw = await apiFetch<unknown>(`${BASE_URL}${path}`, {
      method: "POST",
      headers: this.headers(),
      body: body ? JSON.stringify(snakify(body)) : undefined,
    });
    return camelize(raw) as T;
  }

  async put<T>(path: string, body?: unknown): Promise<T> {
    const raw = await apiFetch<unknown>(`${BASE_URL}${path}`, {
      method: "PUT",
      headers: this.headers(),
      body: body ? JSON.stringify(snakify(body)) : undefined,
    });
    return camelize(raw) as T;
  }

  async delete(path: string): Promise<void> {
    await apiFetch<unknown>(`${BASE_URL}${path}`, {
      method: "DELETE",
      headers: this.headers(),
    });
  }
}

export const api = new ApiClient();
