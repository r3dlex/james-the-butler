export type RiskLevel = "read_only" | "additive" | "destructive";
export type TaskStatus =
  | "pending"
  | "running"
  | "completed"
  | "blocked"
  | "failed";

export interface Task {
  id: string;
  sessionId: string;
  description: string;
  riskLevel: RiskLevel;
  status: TaskStatus;
  hostId: string;
  agentId: string | null;
  createdAt: string;
  startedAt: string | null;
  completedAt: string | null;
}
