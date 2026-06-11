import { createRoot } from "react-dom/client";

import ErrorBoundary from "./components/ErrorBoundary";
import App from "./App.tsx";
import "./index.css";

/**
 * Produces a readable description for any thrown value. Error objects have
 * non-enumerable properties, so JSON.stringify(error) yields "{}" — this
 * extracts the real message/stack instead.
 */
function describeError(value: unknown): string {
  if (value instanceof Error) return value.stack ?? value.message;
  if (typeof value === "string") return value;
  if (value && typeof value === "object") {
    const maybe = value as { message?: unknown; code?: unknown; name?: unknown };
    const parts: string[] = [];
    if (typeof maybe.name === "string") parts.push(maybe.name);
    if (typeof maybe.message === "string") parts.push(maybe.message);
    if (typeof maybe.code === "string" || typeof maybe.code === "number") parts.push(`(code: ${String(maybe.code)})`);
    if (parts.length > 0) return parts.join(" ");
    try {
      const json = JSON.stringify(value);
      return json && json !== "{}" ? json : String(value);
    } catch {
      return String(value);
    }
  }
  return String(value ?? "unknown");
}

/**
 * Log uncaught errors and promise rejections with readable messages, and mark
 * them handled so default reporting doesn't surface an opaque "{}" object.
 */
window.addEventListener("error", (event: ErrorEvent) => {
  const detail = event.error != null ? describeError(event.error) : event.message;
  console.error(`[App] Uncaught error: ${detail}`);
  event.preventDefault();
});

window.addEventListener("unhandledrejection", (event: PromiseRejectionEvent) => {
  console.error(`[App] Unhandled rejection: ${describeError(event.reason)}`);
  event.preventDefault();
});

createRoot(document.getElementById("root")!).render(
  <ErrorBoundary>
    <App />
  </ErrorBoundary>,
);
