export type HostStatus = "online" | "offline" | "degraded";

export interface Host {
  id: string;
  name: string;
  status: HostStatus;
  sessionCount: number;
  isPrimary: boolean;
  models: HostModel[];
  workingDirectories: string[];
  resourceUsage: ResourceUsage | null;
}

export interface HostModel {
  id: string;
  provider: string;
  model: string;
  isLocal: boolean;
  baseUrl: string | null;
}

export interface ResourceUsage {
  cpuPercent: number;
  memoryPercent: number;
  diskPercent: number;
}
