// controller/src/hooks/useStoreSubscription.ts
// React hook for subscribing to store updates

import { useEffect, useState, useCallback } from "react";

/**
 * Generic store interface with subscribe pattern
 */
interface Store<T> {
  getState(): T;
  subscribe(listener: () => void): () => void;
}

/**
 * Hook to subscribe to a store and get reactive updates
 * @param store - The store to subscribe to
 * @returns The current state of the store
 */
export function useStoreSubscription<T>(store: Store<T>): T {
  const [state, setState] = useState<T>(() => store.getState());

  useEffect(() => {
    // Update state when store changes
    const unsubscribe = store.subscribe(() => {
      setState(store.getState());
    });

    // Initial sync in case state changed between render and effect
    setState(store.getState());

    return unsubscribe;
  }, [store]);

  return state;
}

/**
 * Hook to subscribe to a store with a selector for derived state
 * @param store - The store to subscribe to
 * @param selector - Function to derive state
 * @returns The derived state
 */
export function useStoreSelector<T, R>(
  store: Store<T>,
  selector: (state: T) => R
): R {
  const [derived, setDerived] = useState<R>(() => selector(store.getState()));

  useEffect(() => {
    const unsubscribe = store.subscribe(() => {
      const newDerived = selector(store.getState());
      setDerived(newDerived);
    });

    // Initial sync
    setDerived(selector(store.getState()));

    return unsubscribe;
  }, [store, selector]);

  return derived;
}

/**
 * Hook to force re-render on store updates without tracking state
 * Useful when you only need to trigger re-renders
 */
export function useStoreRerender(store: Store<unknown>): void {
  const [, forceUpdate] = useState({});

  useEffect(() => {
    const unsubscribe = store.subscribe(() => {
      forceUpdate({});
    });

    return unsubscribe;
  }, [store]);
}
