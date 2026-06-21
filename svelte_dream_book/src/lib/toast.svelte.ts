/**
 * Tiny toast/snackbar store — the web stand-in for Flutter's ScaffoldMessenger
 * snackbars. Error toasts offer a "Copy" action like the Flutter ones do.
 */
export interface Toast {
  id: number;
  message: string;
  isError: boolean;
}

class ToastStore {
  items = $state<Toast[]>([]);
  private nextId = 1;

  show(message: string, isError = false): void {
    const id = this.nextId++;
    this.items = [...this.items, { id, message, isError }];
    setTimeout(() => this.dismiss(id), isError ? 6000 : 3000);
  }

  error(message: string): void {
    this.show(message, true);
  }

  dismiss(id: number): void {
    this.items = this.items.filter((t) => t.id !== id);
  }
}

export const toasts = new ToastStore();
