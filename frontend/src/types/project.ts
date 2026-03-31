export interface Project {
  id: string;
  name: string;
  personalityId: string | null;
  executionMode: "direct" | "confirmed" | null;
  repos: ProjectRepo[];
  sessionCount: number;
  tokenCost: number;
  createdAt: string;
}

export interface ProjectRepo {
  id: string;
  name: string;
  hostId: string;
  openPrs: number;
  testPassRate: number | null;
  securityFindings: number;
  lastActivity: string | null;
}
