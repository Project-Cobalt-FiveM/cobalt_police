import type { TransitionConfig } from 'svelte/transition';

const reduced = typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;

function bezier(x1: number, y1: number, x2: number, y2: number): (t: number) => number {
  const curve = (a: number, b: number, t: number) => 3 * a * t * (1 - t) ** 2 + 3 * b * t ** 2 * (1 - t) + t ** 3;
  const slope = (a: number, b: number, t: number) =>
    3 * a * (1 - t) ** 2 + 6 * (b - a) * t * (1 - t) + 3 * (1 - b) * t ** 2;

  return (x) => {
    let t = x;

    for (let i = 0; i < 6; i++) {
      const gradient = slope(x1, x2, t);
      if (gradient === 0) break;
      t -= (curve(x1, x2, t) - x) / gradient;
    }

    return curve(y1, y2, Math.min(1, Math.max(0, t)));
  };
}

export const ease = bezier(0.2, 0, 0, 1);

type Rise = { y?: number; duration?: number };

export function rise(_node: Element, { y = 4, duration = 200 }: Rise = {}): TransitionConfig {
  return {
    duration: reduced ? 0 : duration,
    easing: ease,
    css: (t) => `opacity: ${t}; transform: translateY(${(1 - t) * y}px)`,
  };
}

export function pop(_node: Element, { duration = 200 }: { duration?: number } = {}): TransitionConfig {
  return {
    duration: reduced ? 0 : duration,
    easing: ease,
    css: (t) => `opacity: ${t}; transform: scale(${0.98 + t * 0.02})`,
  };
}

export function crossfade(_node: Element, { duration = 150 }: { duration?: number } = {}): TransitionConfig {
  return {
    duration: reduced ? 0 : duration,
    easing: ease,
    css: (t) => `opacity: ${t}`,
  };
}
