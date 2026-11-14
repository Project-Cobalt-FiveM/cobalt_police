type Locales = Record<string, string>;

let dict: Locales = $state.raw({});

export function t(key: string, ...args: (string | number)[]): string {
  const template = dict[key];
  if (template == null) return key;
  let index = 0;
  return template.replace(/%[sd]/g, (placeholder) => {
    const value = args[index++];
    return value == null ? placeholder : String(value);
  });
}

function flatten(tree: unknown, prefix = '', into: Locales = {}): Locales {
  if (typeof tree === 'string') into[prefix] = tree;
  else if (typeof tree === 'object' && tree !== null)
    for (const [key, value] of Object.entries(tree)) flatten(value, prefix === '' ? key : `${prefix}.${key}`, into);
  return into;
}

async function loadDevLocales(): Promise<void> {
  const files = import.meta.glob<unknown>('../../../locales/en.json', { import: 'default' });
  const load = Object.values(files)[0];
  if (load) dict = flatten(await load());
}

export function setLocales(locales: Locales | undefined): void {
  if (locales && Object.keys(locales).length > 0) dict = locales;
  else if (import.meta.env.DEV) void loadDevLocales();
}
