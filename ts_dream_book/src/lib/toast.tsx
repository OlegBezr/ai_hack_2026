import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';

/**
 * Lightweight snackbar/toast system — the React analogue of Flutter's
 * `ScaffoldMessenger.showSnackBar`. Floating pill, bottom-center, auto-dismiss.
 * Error toasts expose a "Copy" action like the Flutter app does.
 */
interface Toast {
  id: number;
  message: string;
  isError: boolean;
}

interface ToastApi {
  show: (message: string) => void;
  error: (message: string) => void;
}

const ToastContext = createContext<ToastApi | null>(null);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const idRef = useRef(0);

  const remove = useCallback((id: number) => {
    setToasts((t) => t.filter((x) => x.id !== id));
  }, []);

  const push = useCallback(
    (message: string, isError: boolean) => {
      const id = ++idRef.current;
      setToasts((t) => [...t, { id, message, isError }]);
      window.setTimeout(() => remove(id), isError ? 6000 : 3500);
    },
    [remove],
  );

  const api = useMemo<ToastApi>(
    () => ({
      show: (m) => push(m, false),
      error: (m) => push(m, true),
    }),
    [push],
  );

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div className="pointer-events-none fixed inset-x-0 bottom-6 z-50 flex flex-col items-center gap-2 px-4">
        {toasts.map((t) => (
          <div
            key={t.id}
            className="glass pointer-events-auto flex max-w-md items-center gap-3 rounded-2xl px-4 py-3 text-sm shadow-lg"
            style={{
              background: 'color-mix(in srgb, var(--color-night-top) 88%, transparent)',
              borderColor: t.isError
                ? 'color-mix(in srgb, var(--color-danger) 50%, transparent)'
                : undefined,
            }}
          >
            <span className={t.isError ? 'text-danger' : 'text-ink'}>{t.message}</span>
            {t.isError && (
              <button
                type="button"
                onClick={() => navigator.clipboard?.writeText(t.message)}
                className="shrink-0 font-semibold text-gold hover:underline"
              >
                Copy
              </button>
            )}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useToast(): ToastApi {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used within a ToastProvider');
  return ctx;
}
