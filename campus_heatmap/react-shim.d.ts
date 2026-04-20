/**
 * Minimal React + JSX type shim.
 *
 * This file lets VS Code type-check the heatmap files without a local
 * node_modules. Once you run `npm install` in this folder, @types/react
 * will provide the full declarations and this shim is ignored (skipLibCheck).
 */

// ── JSX intrinsic elements ────────────────────────────────────────────────────
// Tells TypeScript that <div>, <canvas>, <button> etc. are valid JSX.
// eslint-disable-next-line @typescript-eslint/no-namespace
declare namespace JSX {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  interface IntrinsicElements { [elem: string]: any }
  interface Element { type: unknown; props: unknown; key: unknown }
  interface ElementChildrenAttribute { children: object }
}

// ── React module ──────────────────────────────────────────────────────────────
declare module "react" {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  type AnyProps = Record<string, any>;

  export interface ReactElement { type: unknown; props: unknown; key: unknown }
  export type ReactNode = ReactElement | string | number | boolean | null | undefined;

  // Component type
  export type FC<P = AnyProps> = (props: P & { children?: ReactNode }) => ReactElement | null;

  // CSSProperties — accepts any string key so inline styles always compile
  export type CSSProperties = Partial<CSSStyleDeclaration> & { [key: string]: unknown };

  // Synthetic event wrappers — thin extensions of the DOM events
  export interface SyntheticEvent<T = Element> extends Event {
    currentTarget: EventTarget & T;
    preventDefault(): void;
    stopPropagation(): void;
    nativeEvent: Event;
  }
  export interface MouseEvent<T = Element> extends SyntheticEvent<T> {
    clientX: number;
    clientY: number;
    button: number;
  }
  export interface KeyboardEvent<T = Element> extends SyntheticEvent<T> {
    key: string;
    code: string;
    shiftKey: boolean;
    ctrlKey: boolean;
    metaKey: boolean;
  }

  // Refs
  export interface RefObject<T> { readonly current: T | null }
  export interface MutableRefObject<T> { current: T }

  // State / dispatch
  export type Dispatch<A> = (action: A) => void;
  export type SetStateAction<S> = S | ((prevState: S) => S);

  // Hooks
  export function useState<S>(init: S | (() => S)): [S, Dispatch<SetStateAction<S>>];
  export function useState<S = undefined>(): [S | undefined, Dispatch<SetStateAction<S | undefined>>];
  export function useEffect(fn: () => void | (() => void), deps?: readonly unknown[]): void;
  export function useRef<T>(init: T): MutableRefObject<T>;
  export function useRef<T>(init: T | null): RefObject<T>;
  export function useRef<T = undefined>(): MutableRefObject<T | undefined>;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export function useCallback<T extends (...args: any[]) => any>(fn: T, deps: readonly unknown[]): T;
  export function useMemo<T>(factory: () => T, deps: readonly unknown[]): T;

  // createElement (needed for classic JSX transform)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export function createElement(type: unknown, props?: unknown, ...children: unknown[]): any;

  // Default export shape used by `import React from "react"`
  const _default: {
    createElement: typeof createElement;
    FC: FC;
  };
  export default _default;
}
