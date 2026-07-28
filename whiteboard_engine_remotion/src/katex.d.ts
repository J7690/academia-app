// KaTeX ne fournit pas de types TypeScript et `@types/katex` n'est pas installé sur le
// serveur de rendu. On déclare le module a minima, avec la seule fonction utilisée
// (`renderToString`), plutôt que d'ajouter une dépendance de développement au VPS.
declare module "katex" {
  interface KatexOptions {
    displayMode?: boolean;
    throwOnError?: boolean;
    strict?: boolean | string;
    trust?: boolean;
    macros?: Record<string, string>;
    output?: "html" | "mathml" | "htmlAndMathml";
  }
  export function renderToString(expression: string, options?: KatexOptions): string;
  const katex: { renderToString: typeof renderToString };
  export default katex;
}
