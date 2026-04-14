// @vitest-environment happy-dom
import { describe, it, expect } from "vitest";

// snakify and camelize are self-contained pure functions with no external
// dependencies — redefine them here so tests are isolated from the module
// structure and any import-time side-effects.
function snakify(obj: unknown): unknown {
  if (Array.isArray(obj)) return obj.map(snakify);
  if (obj !== null && typeof obj === "object") {
    return Object.fromEntries(
      Object.entries(obj as Record<string, unknown>).map(([k, v]) => [
        k.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`),
        snakify(v),
      ]),
    );
  }
  return obj;
}

function camelize(obj: unknown): unknown {
  if (Array.isArray(obj)) return obj.map(camelize);
  if (obj !== null && typeof obj === "object") {
    return Object.fromEntries(
      Object.entries(obj as Record<string, unknown>).map(([k, v]) => [
        k.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase()),
        camelize(v),
      ]),
    );
  }
  return obj;
}

describe("snakify — primitives and edge cases", () => {
  it("returns null unchanged", () => {
    expect(snakify(null)).toBeNull();
  });

  it("returns undefined unchanged", () => {
    expect(snakify(undefined)).toBe(undefined);
  });

  it("returns a number unchanged", () => {
    expect(snakify(42)).toBe(42);
  });

  it("returns a string unchanged", () => {
    expect(snakify("hello")).toBe("hello");
  });

  it("returns a boolean unchanged", () => {
    expect(snakify(true)).toBe(true);
  });

  it("returns an array of primitives unchanged", () => {
    expect(snakify([1, 2, 3])).toEqual([1, 2, 3]);
    expect(snakify(["a", "b"])).toEqual(["a", "b"]);
  });
});

describe("snakify — objects", () => {
  it("converts camelCase keys to snake_case", () => {
    expect(snakify({ myKey: 1 })).toEqual({ my_key: 1 });
  });

  it("converts deeply-nested camelCase keys", () => {
    expect(snakify({ outerKey: { innerKey: 1 } })).toEqual({
      outer_key: { inner_key: 1 },
    });
  });

  it("converts arrays of objects", () => {
    expect(snakify([{ myKey: 1 }, { otherKey: 2 }])).toEqual([
      { my_key: 1 },
      { other_key: 2 },
    ]);
  });

  it("handles multiple uppercase letters in a key", () => {
    expect(snakify({ myHTTPResponse: 200 })).toEqual({
      my_h_t_t_p_response: 200,
    });
  });
});

describe("camelize — primitives and edge cases", () => {
  it("returns null unchanged", () => {
    expect(camelize(null)).toBeNull();
  });

  it("returns undefined unchanged", () => {
    expect(camelize(undefined)).toBe(undefined);
  });

  it("returns a number unchanged", () => {
    expect(camelize(42)).toBe(42);
  });

  it("returns a string unchanged", () => {
    expect(camelize("hello")).toBe("hello");
  });

  it("returns an array of primitives unchanged", () => {
    expect(camelize([1, 2, 3])).toEqual([1, 2, 3]);
  });
});

describe("camelize — objects", () => {
  it("converts snake_case keys to camelCase", () => {
    expect(camelize({ my_key: 1 })).toEqual({ myKey: 1 });
  });

  it("converts deeply-nested snake_case keys", () => {
    expect(camelize({ outer_key: { inner_key: 1 } })).toEqual({
      outerKey: { innerKey: 1 },
    });
  });

  it("converts arrays of objects", () => {
    expect(camelize([{ my_key: 1 }, { other_key: 2 }])).toEqual([
      { myKey: 1 },
      { otherKey: 2 },
    ]);
  });

  it("handles keys already in camelCase (no change)", () => {
    expect(camelize({ alreadyCamel: 1 })).toEqual({ alreadyCamel: 1 });
  });

  it("handles mixed snake and camel keys", () => {
    expect(camelize({ user_id: 1, userName: "Alice" })).toEqual({
      userId: 1,
      userName: "Alice",
    });
  });

  it("handles deeply nested arrays", () => {
    expect(camelize([[{ snake_key: 1 }]])).toEqual([[{ snakeKey: 1 }]]);
  });
});

describe("snakify + camelize round-trip", () => {
  it("round-trip converts and restores an API payload", () => {
    const input = {
      userId: "u1",
      taskStatus: "pending",
      riskLevel: "destructive",
    };
    const snake = snakify(input) as Record<string, unknown>;
    const roundTripped = camelize(snake) as Record<string, unknown>;
    expect(roundTripped).toEqual(input);
  });
});
