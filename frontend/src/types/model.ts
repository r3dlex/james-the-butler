export interface ModelConfig {
  id: string;
  hostId: string;
  provider: string;
  model: string;
  apiKey: string;
  isLocal: boolean;
  baseUrl: string | null;
  useOAuth: boolean;
  createdAt: string;
}

export interface ModelProvider {
  name: string;
  models: string[];
  supportsOAuth: boolean;
}
