export type AgentType =
  | "chat"
  | "code"
  | "research"
  | "desktop_control"
  | "browser_control";
export type SessionStatus =
  | "active"
  | "idle"
  | "completed"
  | "error"
  | "suspended"
  | "terminated";
export type ExecutionMode = "direct" | "confirmed";

export interface Session {
  id: string;
  name: string;
  nameSetByUser: boolean;
  agentType: AgentType;
  hostId: string;
  projectId: string | null;
  status: SessionStatus;
  executionMode: ExecutionMode;
  personalityId: string | null;
  workingDirectories: string[];
  mcpServers: string[];
  keepIntermediates: boolean;
  tokenCount: number;
  tokenCost: number;
  createdAt: string;
  updatedAt: string;
}

export interface CreateSessionPayload {
  name?: string;
  agentType: AgentType;
  hostId: string;
  projectId?: string;
  workingDirectories?: string[];
  mcpServers?: string[];
  personalityId?: string;
  executionMode?: ExecutionMode;
  keepIntermediates?: boolean;
}
