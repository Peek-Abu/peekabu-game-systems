--!strict
-- Type-only contracts. Runtime behavior is covered by the registry/rules/system specs.
export type Family = "building" | "furniture" | "cargo" | "props" | "equipment"
export type FitMode = "Uniform" | "Stretch"
-- `fallback`: the kit a key this kit lacks is looked up in next (ArtKitRegistry.chain), before the default kit.
export type Kit = { id: string, name: string, fallback: string? }
return {}
