export interface MemoryEntry {
  id: string;
  content: string;
  sourceSessionId: string | null;
  sourceSessionName: string | null;
  createdAt: string;
  updatedAt: string;
}
