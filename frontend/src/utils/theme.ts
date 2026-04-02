export type ThemeMode = "dark" | "light" | "system";

const STORAGE_KEY = "james_general_settings";

const darkVars: Record<string, string> = {
  "--color-navy": "#1a1a2e",
  "--color-navy-deep": "#0d0d1a",
  "--color-gold": "#d4a574",
  "--color-gold-dim": "rgba(212, 165, 116, 0.5)",
  "--color-surface": "#12121f",
  "--color-border": "#2a2a3e",
  "--color-text": "#e0e0e0",
  "--color-text-dim": "#888",
  "--color-accent-blue": "#7a9ec2",
  "--color-risk-green": "#4ade80",
  "--color-risk-blue": "#60a5fa",
  "--color-risk-red": "#f87171",
};

const lightVars: Record<string, string> = {
  "--color-navy": "#f5f5f0",
  "--color-navy-deep": "#ebebea",
  "--color-gold": "#b8762d",
  "--color-gold-dim": "rgba(184, 118, 45, 0.5)",
  "--color-surface": "#ffffff",
  "--color-border": "#d0d0c8",
  "--color-text": "#1a1a1a",
  "--color-text-dim": "#666",
  "--color-accent-blue": "#3b6f9e",
  "--color-risk-green": "#16a34a",
  "--color-risk-blue": "#2563eb",
  "--color-risk-red": "#dc2626",
};

function applyVars(vars: Record<string, string>) {
  const root = document.documentElement;
  for (const [key, value] of Object.entries(vars)) {
    root.style.setProperty(key, value);
  }
}

export function applyTheme(mode: ThemeMode) {
  const prefersDark =
    window.matchMedia?.("(prefers-color-scheme: dark)").matches ?? true;
  const effective = mode === "system" ? (prefersDark ? "dark" : "light") : mode;
  applyVars(effective === "light" ? lightVars : darkVars);
  document.documentElement.setAttribute("data-theme", effective);
}

/** Read saved theme from localStorage and apply it immediately. */
export function applyPersistedTheme() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as { theme?: ThemeMode };
      if (parsed.theme) {
        applyTheme(parsed.theme);
        return;
      }
    }
  } catch {
    // ignore
  }
  // Default: dark
  applyTheme("dark");
}
