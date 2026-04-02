import { describe, it, expect } from "vitest";
import { generateSessionName } from "../utils/sessionNames";

describe("generateSessionName", () => {
  it("returns a non-empty string", () => {
    expect(generateSessionName()).toBeTruthy();
  });

  it("returns a name with exactly two words separated by a space", () => {
    const name = generateSessionName();
    const parts = name.split(" ");
    expect(parts).toHaveLength(2);
    expect(parts[0].length).toBeGreaterThan(0);
    expect(parts[1].length).toBeGreaterThan(0);
  });

  it("starts with a capital letter", () => {
    for (let i = 0; i < 20; i++) {
      const name = generateSessionName();
      expect(name[0]).toMatch(/[A-Z]/);
    }
  });

  it("both words start with capital letters", () => {
    for (let i = 0; i < 20; i++) {
      const [adj, noun] = generateSessionName().split(" ");
      expect(adj[0]).toMatch(/[A-Z]/);
      expect(noun[0]).toMatch(/[A-Z]/);
    }
  });

  it("returns different names on repeated calls", () => {
    const names = new Set(
      Array.from({ length: 30 }, () => generateSessionName()),
    );
    // With 38 adjectives × 44 nouns = 1672 combinations, 30 random picks
    // should yield at least 5 distinct names with overwhelming probability.
    expect(names.size).toBeGreaterThan(5);
  });
});
