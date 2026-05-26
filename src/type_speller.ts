import { type RecordKey, type RecordLocation, type ResolvedType } from "skir-internal";

export class TypeSpeller {
  constructor(
    private readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    private readonly baseNamespace: string,
  ) {}

  public spell(type: ResolvedType): string {
    switch (type.kind) {
      case "primitive":
        return `:${type.primitive}`;
      
      case "optional":
        return `{:optional, ${this.spell(type.other)}}`;
      
      case "array":
        return `{:array, ${this.spell(type.item)}}`;
      
      case "record": {
        const loc = this.recordMap.get(type.key);
        if (!loc) {
          return ":unknown";
        }

        // 1. Trace the destination path from the targeted record location
        const pathPrefix = this.derivePathPrefix(loc.modulePath);
        let targetNamespace = pathPrefix 
          ? `${this.baseNamespace}.${pathPrefix}` 
          : this.baseNamespace;

        // 2. Strip base utility filename suffix segments if present
        if (targetNamespace.endsWith(".Structs")) {
          targetNamespace = targetNamespace.slice(0, -8);
        } else if (targetNamespace.endsWith(".Enums")) {
          targetNamespace = targetNamespace.slice(0, -6);
        }

        // 3. Map the nested structural ancestors chain 
        const recordParts = loc.recordAncestors.map((r) => r.name.text);
        if (!recordParts.includes(loc.record.name.text)) {
          recordParts.push(loc.record.name.text);
        }
        
        // 4. Combine into the absolute Elixir module identifier path
        return `${targetNamespace}.${recordParts.join(".")}`;
      }
      
      default:
        return ":unknown";
    }
  }

  /**
   * Identical path sanitization logic to keep module targets aligned
   */
  private derivePathPrefix(modulePath: string): string {
    let cleanPath = modulePath;
    if (cleanPath.endsWith(".skir")) {
      cleanPath = cleanPath.slice(0, -5);
    } else if (cleanPath.endsWith(".ex")) {
      cleanPath = cleanPath.slice(0, -3);
    }

    cleanPath = cleanPath.replace(/^[\./]+/, "");
    const segments = cleanPath.split("/").filter(Boolean);

    return segments
      .map((segment) => {
        let sanitized = segment.replace(/[^a-zA-Z0-9_\-]/g, "");

        if (/^\d/.test(sanitized)) {
          sanitized = "Mod" + sanitized;
        }

        const words = sanitized.split(/[_\-]/).filter(Boolean);
        return words
          .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
          .join("");
      })
      .join(".");
  }
}