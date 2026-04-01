export type ArtifactType = "document" | "code" | "report" | "image" | "data";

export interface Artifact {
  id: string;
  sessionId: string;
  name: string;
  type: ArtifactType;
  mimeType: string;
  url: string;
  isDeliverable: boolean;
  createdAt: string;
}
