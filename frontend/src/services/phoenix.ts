import { Socket } from "phoenix";

const SOCKET_URL = import.meta.env.VITE_WS_URL || "ws://localhost:4000/socket";

let socket: Socket | null = null;

export function getSocket(): Socket {
  if (!socket) {
    socket = new Socket(SOCKET_URL, {
      params: () => {
        const token = localStorage.getItem("auth_token");
        return token ? { token } : {};
      },
      reconnectAfterMs: (tries: number) =>
        Math.min(1000 * Math.pow(2, tries), 30000),
    });
  }
  return socket;
}

export function connectSocket(): void {
  const s = getSocket();
  if (!s.isConnected()) {
    s.connect();
  }
}

export function disconnectSocket(): void {
  if (socket) {
    socket.disconnect();
    socket = null;
  }
}
