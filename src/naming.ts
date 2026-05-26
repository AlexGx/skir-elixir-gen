import { type RecordLocation, convertCase } from "skir-internal";

// Elixir reserved words that cannot be used as bare atoms/identifiers without
// quoting. Field names colliding with these get a trailing underscore.
const ELIXIR_RESERVED = new Set([
  "after",
  "and",
  "catch",
  "do",
  "else",
  "end",
  "false",
  "fn",
  "in",
  "nil",
  "not",
  "or",
  "rescue",
  "true",
  "when",
]);

// The default top-level Elixir namespace for all generated modules.
// Overridable via the generator config's `namespace` option.
export const DEFAULT_NAMESPACE = "SkirOut";

/**
 * Returns the fully-qualified Elixir module name for a record.
 *
 * Joins the namespace with each ancestor name converted to UpperCamel.
 *   namespace "SkirOut", record User → "SkirOut.User"
 *   namespace "SkirOut", record User.Address → "SkirOut.User.Address"
 *   namespace "MyApp.Schema", record Pet → "MyApp.Schema.Pet"
 */
export function getModuleName(
  record: RecordLocation,
  namespace: string,
): string {
  const parts = record.recordAncestors.map((a) =>
    convertCase(a.name.text, "UpperCamel"),
  );
  return [namespace, ...parts].join(".");
}

/**
 * Converts a Skir field/variant/method name to a safe Elixir atom name.
 */
export function toFieldName(skirName: string): string {
  const snake = convertCase(skirName, "lower_underscore");
  return ELIXIR_RESERVED.has(snake) ? `${snake}_` : snake;
}

/**
 * Formats an integer as an Elixir numeric literal with underscore separators
 * every three digits from the right.
 */
export function formatIntWithSeparators(n: number): string {
  // Leverage groupDigits directly to eliminate code duplication entirely
  return groupDigits(n.toString());
}

/**
 * Groups a raw integer digit string with underscore separators every three
 * digits from the right, without converting to a Number (safe for values
 * beyond Number.MAX_SAFE_INTEGER, e.g. int64/hash64).
 *   "9223372036854775807" → "9_223_372_036_854_775_807"
 *   "-1000"               → "-1_000"
 */
/**
 * Groups a raw integer digit string with underscore separators every three
 * digits from the right, without converting to a Number (safe for values
 * beyond Number.MAX_SAFE_INTEGER, e.g. int64/hash64).
 * "9223372036854775807" → "9_223_372_036_854_775_807"
 * "-1000"               → "-1_000"
 */
export function groupDigits(text: string): string {
  const isNegative = text.startsWith("-");
  const digits = isNegative ? text.slice(1) : text;

  // Strict check for plain integer literal
  if (!/^\d+$/.test(digits)) {
    return text;
  }

  // Matches a position where followed by multiples of 3 digits
  const grouped = digits.replace(/\B(?=(\d{3})+(?!\d))/g, "_");

  return isNegative ? `-${grouped}` : grouped;
}

/**
 * Returns the output .ex file path for a Skir module path.
 * Strips "@", converts "-" to "_", replaces ".skir" with ".ex".
 *   "foo/bar.skir"                       → "foo/bar.ex"
 *   "@gepheum/skir-tests/goldens.skir"   → "gepheum/skir_tests/goldens.ex"
 */
export function getOutputPath(modulePath: string): string {
  return modulePath
    .replace(/^@/, "")
    .replace(/-/g, "_")
    .replace(/\.skir$/, ".ex");
}
