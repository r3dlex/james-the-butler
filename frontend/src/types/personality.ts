export type PersonalityPreset =
  | "butler"
  | "collaborator"
  | "analyst"
  | "coach"
  | "editor"
  | "silent";

export interface Personality {
  id: string;
  name: string;
  preset: PersonalityPreset | null;
  systemPrompt: string;
  isCustom: boolean;
}
