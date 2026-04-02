export type ProviderType =
  | "anthropic"
  | "openai"
  | "openai_codex"
  | "gemini"
  | "minimax"
  | "ollama"
  | "lm_studio"
  | "openai_compatible";

export type AuthMethod = "api_key" | "oauth";
export type ProviderStatus = "untested" | "connected" | "failed";

export interface ProviderConfig {
  id: string;
  providerType: ProviderType;
  displayName: string;
  authMethod: AuthMethod;
  status: ProviderStatus;
  baseUrl: string | null;
  apiKeyMasked: string | null;
  lastTestedAt: string | null;
  models: string[];
}
