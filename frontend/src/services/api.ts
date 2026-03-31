import type { ApiError } from "@/types/api";

const BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:4000";

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
    const res = await fetch(`${BASE_URL}${path}`, { headers: this.headers() });
    if (!res.ok) throw await this.toError(res);
    return res.json();
  }

  async post<T>(path: string, body?: unknown): Promise<T> {
    const res = await fetch(`${BASE_URL}${path}`, {
      method: "POST",
      headers: this.headers(),
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!res.ok) throw await this.toError(res);
    return res.json();
  }

  async put<T>(path: string, body?: unknown): Promise<T> {
    const res = await fetch(`${BASE_URL}${path}`, {
      method: "PUT",
      headers: this.headers(),
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!res.ok) throw await this.toError(res);
    return res.json();
  }

  async delete(path: string): Promise<void> {
    const res = await fetch(`${BASE_URL}${path}`, {
      method: "DELETE",
      headers: this.headers(),
    });
    if (!res.ok) throw await this.toError(res);
  }

  private async toError(res: Response): Promise<ApiError> {
    try {
      return await res.json();
    } catch {
      return { error: `HTTP ${res.status}`, detail: res.statusText };
    }
  }
}

export const api = new ApiClient();
