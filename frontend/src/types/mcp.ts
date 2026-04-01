export type McpTransport = "stdio" | "sse" | "streamable_http";
export type McpStatus = "connected" | "disconnected" | "error";

export interface McpServer {
  id: string;
  name: string;
  transport: McpTransport;
  status: McpStatus;
  isPreConfigured: boolean;
  params: Record<string, string>;
}
