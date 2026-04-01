export type MessageRole = "user" | "assistant" | "system";
export type ContentBlockType =
  | "text"
  | "thinking"
  | "tool_call"
  | "tool_result"
  | "command_log"
  | "file_diff"
  | "report_block";

export interface ContentBlock {
  type: ContentBlockType;
  text?: string;
  command?: string;
  output?: string;
  filePath?: string;
  diff?: string;
  title?: string;
  citations?: string[];
  toolName?: string;
  toolInput?: Record<string, unknown>;
  toolResult?: unknown;
}

export interface FileAttachment {
  id: string;
  name: string;
  size: number;
  mimeType: string;
  url: string;
}

export interface Message {
  id: string;
  sessionId: string;
  role: MessageRole;
  content: ContentBlock[];
  attachments: FileAttachment[];
  tokenCount: number;
  createdAt: string;
}

export interface PlannerStep {
  id: string;
  description: string;
  riskLevel: "read_only" | "additive" | "destructive";
  targetHost: string;
  status: "pending" | "running" | "completed" | "blocked" | "failed";
}
