// IPC Bridge - Manages communication with Swift helper subprocess

import type { Subprocess } from "bun";
import { nanoid } from "nanoid";
import type {
  IPCRequest,
  IPCRequestBody,
  IPCResponse,
  IPCEvent,
} from "../types/index.ts";

// Event callback types
type EventCallback<T = unknown> = (data: T) => void;
type EventMap = {
  overlayIconClicked: EventCallback<IPCEvent & { event: "overlayIconClicked" }>;
  mouseClicked: EventCallback<IPCEvent & { event: "mouseClicked" }>;
  keyPressed: EventCallback<IPCEvent & { event: "keyPressed" }>;
  zoneSelected: EventCallback<IPCEvent & { event: "zoneSelected" }>;
  pixelSelected: EventCallback<IPCEvent & { event: "pixelSelected" }>;
  overlayMoved: EventCallback<IPCEvent & { event: "overlayMoved" }>;
  overlayClosed: EventCallback<IPCEvent & { event: "overlayClosed" }>;
  timeInputCompleted: EventCallback<IPCEvent & { event: "timeInputCompleted" }>;
  error: EventCallback<Error>;
  exit: EventCallback<number | null>;
};

// Pending request with timeout
interface PendingRequest<T = unknown> {
  resolve: (value: T) => void;
  reject: (error: Error) => void;
  timeout: ReturnType<typeof setTimeout>;
}

// Default timeout for IPC requests (10 seconds)
const DEFAULT_TIMEOUT_MS = 10000;

export class SwiftBridge {
  private process: Subprocess<"pipe", "pipe", "pipe"> | null = null;
  private pendingRequests = new Map<string, PendingRequest>();
  private eventListeners = new Map<string, Set<EventCallback>>();
  private readBuffer = "";
  private isRunning = false;

  // Path to Swift helper binary
  private readonly helperPath: string;

  constructor(helperPath?: string) {
    // Default to release build in swift-helper directory
    this.helperPath =
      helperPath ??
      new URL(
        "../../../swift-helper/.build/release/SequencerHelper",
        import.meta.url
      ).pathname;
  }

  /**
   * Start the Swift helper subprocess
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      throw new Error("SwiftBridge is already running");
    }

    // Spawn the Swift helper
    this.process = Bun.spawn([this.helperPath], {
      stdin: "pipe",
      stdout: "pipe",
      stderr: "pipe",
    });

    this.isRunning = true;

    // Start reading stdout in background
    this.readLoop();

    // Handle stderr (log errors)
    this.readStderr();

    // Handle process exit
    this.process.exited.then((exitCode) => {
      this.isRunning = false;
      this.emit("exit", exitCode);

      // Reject all pending requests
      for (const [id, pending] of this.pendingRequests) {
        clearTimeout(pending.timeout);
        pending.reject(new Error(`Swift helper exited with code ${exitCode}`));
        this.pendingRequests.delete(id);
      }
    });
  }

  /**
   * Stop the Swift helper subprocess
   */
  stop(): void {
    if (this.process) {
      this.process.stdin.end();
      this.process.kill();
      this.process = null;
      this.isRunning = false;
    }
  }

  /**
   * Send a request to the Swift helper and wait for response
   */
  async request<T>(
    body: IPCRequestBody,
    timeoutMs: number = DEFAULT_TIMEOUT_MS
  ): Promise<T> {
    if (!this.isRunning || !this.process) {
      throw new Error("SwiftBridge is not running");
    }

    const id = nanoid();
    const request: IPCRequest = { id, ...body };

    return new Promise<T>((resolve, reject) => {
      // Set up timeout
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(id);
        reject(new Error(`Request ${body.method} timed out after ${timeoutMs}ms`));
      }, timeoutMs);

      // Store pending request
      this.pendingRequests.set(id, {
        resolve: resolve as (value: unknown) => void,
        reject,
        timeout,
      });

      // Send request
      const json = JSON.stringify(request) + "\n";
      this.process!.stdin.write(json);
    });
  }

  /**
   * Register event listener
   */
  on<K extends keyof EventMap>(event: K, callback: EventMap[K]): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, new Set());
    }
    this.eventListeners.get(event)!.add(callback as EventCallback);
  }

  /**
   * Remove event listener
   */
  off<K extends keyof EventMap>(event: K, callback: EventMap[K]): void {
    this.eventListeners.get(event)?.delete(callback as EventCallback);
  }

  /**
   * Emit an event to all listeners
   */
  private emit<K extends keyof EventMap>(
    event: K,
    data: Parameters<EventMap[K]>[0]
  ): void {
    const listeners = this.eventListeners.get(event);
    if (listeners) {
      for (const callback of listeners) {
        try {
          callback(data);
        } catch (err) {
          console.error(`Error in event listener for ${event}:`, err);
        }
      }
    }
  }

  /**
   * Read stdout in a loop, parsing JSON messages
   */
  private async readLoop(): Promise<void> {
    if (!this.process) return;

    const reader = this.process.stdout.getReader();
    const decoder = new TextDecoder();

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        this.readBuffer += decoder.decode(value, { stream: true });
        this.processBuffer();
      }
    } catch (err) {
      if (this.isRunning) {
        this.emit("error", err instanceof Error ? err : new Error(String(err)));
      }
    }
  }

  /**
   * Process buffered data, extracting complete JSON lines
   */
  private processBuffer(): void {
    let newlineIndex: number;
    while ((newlineIndex = this.readBuffer.indexOf("\n")) !== -1) {
      const line = this.readBuffer.slice(0, newlineIndex);
      this.readBuffer = this.readBuffer.slice(newlineIndex + 1);

      if (line.trim()) {
        this.handleMessage(line);
      }
    }
  }

  /**
   * Handle a complete JSON message
   */
  private handleMessage(json: string): void {
    let message: unknown;
    try {
      message = JSON.parse(json);
    } catch (err) {
      console.error("Failed to parse IPC message:", json);
      return;
    }

    // Check if it's a response (has 'id' and 'success' fields)
    if (
      typeof message === "object" &&
      message !== null &&
      "id" in message &&
      "success" in message
    ) {
      this.handleResponse(message as IPCResponse);
      return;
    }

    // Check if it's an event (has 'event' field)
    if (
      typeof message === "object" &&
      message !== null &&
      "event" in message
    ) {
      this.handleEvent(message as IPCEvent);
      return;
    }

    console.error("Unknown IPC message format:", message);
  }

  /**
   * Handle a response message
   */
  private handleResponse(response: IPCResponse): void {
    const pending = this.pendingRequests.get(response.id);
    if (!pending) {
      console.warn("Received response for unknown request:", response.id);
      return;
    }

    clearTimeout(pending.timeout);
    this.pendingRequests.delete(response.id);

    if (response.success) {
      pending.resolve(response.result);
    } else {
      pending.reject(new Error(response.error));
    }
  }

  /**
   * Handle an event message
   */
  private handleEvent(event: IPCEvent): void {
    this.emit(event.event as keyof EventMap, event as never);
  }

  /**
   * Read and log stderr
   */
  private async readStderr(): Promise<void> {
    if (!this.process) return;

    const reader = this.process.stderr.getReader();
    const decoder = new TextDecoder();

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const text = decoder.decode(value, { stream: true });
        if (text.trim()) {
          console.error("[Swift Helper]", text.trim());
        }
      }
    } catch {
      // Ignore stderr read errors on shutdown
    }
  }

  /**
   * Check if the bridge is running
   */
  get running(): boolean {
    return this.isRunning;
  }
}

// Singleton instance
export const swiftBridge = new SwiftBridge();
