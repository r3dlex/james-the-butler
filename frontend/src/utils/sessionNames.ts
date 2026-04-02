/**
 * Generates interesting two-word names for new sessions.
 * Format: "<Adjective> <Noun>" — e.g. "Amber Falcon", "Silent Cascade".
 */

const ADJECTIVES = [
  "Amber",
  "Azure",
  "Cobalt",
  "Crimson",
  "Crystal",
  "Dark",
  "Dawn",
  "Dusk",
  "Emerald",
  "Ember",
  "Frost",
  "Ghost",
  "Golden",
  "Hollow",
  "Iron",
  "Jade",
  "Lunar",
  "Midnight",
  "Neon",
  "Obsidian",
  "Onyx",
  "Prism",
  "Raven",
  "Ruby",
  "Sage",
  "Shadow",
  "Silent",
  "Silver",
  "Solar",
  "Storm",
  "Swift",
  "Thunder",
  "Twilight",
  "Void",
  "Wandering",
  "Wild",
  "Winter",
  "Zenith",
];

const NOUNS = [
  "Arrow",
  "Cascade",
  "Circuit",
  "Comet",
  "Compass",
  "Crown",
  "Drift",
  "Echo",
  "Falcon",
  "Fern",
  "Flame",
  "Fleet",
  "Forge",
  "Gate",
  "Glyph",
  "Harbor",
  "Hollow",
  "Horizon",
  "Lantern",
  "Lark",
  "Lynx",
  "Mist",
  "Moth",
  "Nova",
  "Orbit",
  "Otter",
  "Peak",
  "Phoenix",
  "Pulse",
  "Quest",
  "Rook",
  "Shard",
  "Shroud",
  "Spark",
  "Tide",
  "Torch",
  "Vale",
  "Veil",
  "Venture",
  "Vortex",
  "Wave",
  "Wind",
  "Wolf",
  "Wraith",
];

/**
 * Returns a random two-word session name such as "Amber Falcon" or "Silent Cascade".
 * Every call picks independently at random so repeated calls yield different names.
 */
export function generateSessionName(): string {
  const adj = ADJECTIVES[Math.floor(Math.random() * ADJECTIVES.length)];
  const noun = NOUNS[Math.floor(Math.random() * NOUNS.length)];
  return `${adj} ${noun}`;
}
