import {
  type RecordKey,
  type RecordLocation,
  type ResolvedType,
} from "skir-internal";
import { getModuleName, toFieldName } from "./naming.js";

/**
 * Translates a resolved Skir type into the Elixir DSL type expression used by
 * `field`, `variant wraps:`, `method request:/response:`, and `defconst`.
 */
export class TypeSpeller {
  constructor(
    private readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    private readonly namespace: string,
  ) {}

  /** Returns the Elixir DSL type expression for a resolved type. */
  spell(type: ResolvedType): string {
    switch (type.kind) {
      case "primitive":
        return `:${type.primitive}`;

      case "record": {
        const loc = this.recordMap.get(type.key);
        if (!loc) {
          throw new Error(
            `Skir Compilation Error: Record definition not found for key '${String(type.key)}'. Ensure it is imported or registered.`,
          );
        }
        return getModuleName(loc, this.namespace);
      }

      case "array": {
        const itemExpr = this.spell(type.item);
        if (type.key?.path) {
          const keyExpr = this.spellKeyPath(type.key.path);
          return `{:array, ${itemExpr}, key: ${keyExpr}}`;
        }
        return `{:array, ${itemExpr}}`;
      }

      case "optional": {
        // Semantic renaming via destructuring for clarity
        const { other: innerType } = type;
        return `{:optional, ${this.spell(innerType)}}`;
      }

      default: {
        // Runtime exhaustiveness guarantee
        const unknownType: never = type;
        throw new Error(
          `Unsupported Skir type kind: ${JSON.stringify(unknownType)}`,
        );
      }
    }
  }

  /**
   * Renders the key path of a keyed array.
   */
  private spellKeyPath(
    path: ReadonlyArray<{ readonly name: { readonly text: string } }>,
  ): string {
    const len = path.length;

    if (len === 0) return "[]";

    // Avoid mapping an array if there's only one segment
    if (len === 1) {
      return `:${toFieldName(path[0]!.name.text)}`;
    }

    const atoms = path.map((item) => `:${toFieldName(item.name.text)}`);
    return `[${atoms.join(", ")}]`;
  }
}
