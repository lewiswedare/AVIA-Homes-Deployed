import { createRoot } from "react-dom/client";

import ErrorBoundary from "./components/ErrorBoundary";
import App from "./App.tsx";
import "./index.css";

/**
 * Log uncaught errors and promise rejections with readable messages so error
 * reports carry real context (Error objects serialize to "{}" otherwise).
 */
window.addEventListener("error", (event: ErrorEvent) => {
  const detail = event.error instanceof Error ? (event.error.stack ?? event.error.message) : event.message;
  console.error(`[App] Uncaught error: ${detail}`);
});

window.addEventListener("unhandledrejection", (event: PromiseRejectionEvent) => {
  const reason: unknown = event.reason;
  const detail =
    reason instanceof Error
      ? (reason.stack ?? reason.message)
      : typeof reason === "string"
        ? reason
        : JSON.stringify(reason ?? "unknown");
  console.error(`[App] Unhandled rejection: ${detail}`);
});

createRoot(document.getElementById("root")!).render(
  <ErrorBoundary>
    <App />
  </ErrorBoundary>,
);
