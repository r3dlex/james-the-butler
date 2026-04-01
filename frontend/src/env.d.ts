/// <reference types="vite/client" />

declare module "phoenix" {
  export class Socket {
    constructor(endPoint: string, opts?: Record<string, unknown>);
    connect(): void;
    disconnect(): void;
    isConnected(): boolean;
    channel(topic: string, params?: Record<string, unknown>): Channel;
    onOpen(callback: () => void): void;
    onClose(callback: () => void): void;
    onError(callback: (error: unknown) => void): void;
  }

  export class Channel {
    join(): Push;
    leave(): Push;
    on(event: string, callback: (payload: unknown) => void): void;
    off(event: string): void;
    push(event: string, payload?: unknown): Push;
  }

  export class Push {
    receive(status: string, callback: (response: unknown) => void): Push;
  }
}
