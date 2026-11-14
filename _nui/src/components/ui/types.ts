export type Tab<V extends string> = { value: V; label: string; count?: number };

export type Option<V> = { value: V; label: string; dot?: string };

export type PickOption<V> = { key: string; label: string; detail?: string; value: V };
