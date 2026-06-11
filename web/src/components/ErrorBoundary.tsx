import { Component, type ErrorInfo, type ReactNode } from "react";

interface ErrorBoundaryProps {
  children: ReactNode;
}

interface ErrorBoundaryState {
  error: Error | null;
}

/**
 * Catches render-time errors anywhere in the app, logs a readable message
 * (so error reports carry real context instead of an empty object), and
 * shows a friendly recovery screen instead of a blank page.
 */
export default class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { error: null };

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error(
      `[App] Render error: ${error.message}\n${error.stack ?? ""}\nComponent stack:${info.componentStack ?? ""}`,
    );
  }

  private readonly handleReload = () => {
    this.setState({ error: null });
    window.location.assign("/");
  };

  render() {
    if (this.state.error) {
      return (
        <div className="flex min-h-screen flex-col items-center justify-center gap-5 bg-avia-white px-8 text-center">
          <img src="/brand/avia-logo.png" alt="AVIA Homes" className="h-8 w-auto opacity-80" />
          <div>
            <div className="text-[18px] font-medium text-avia-black">Something went wrong</div>
            <div className="mt-1 max-w-sm text-[13px] text-avia-black/55">
              An unexpected error occurred. Reloading usually fixes it.
            </div>
          </div>
          <button
            type="button"
            onClick={this.handleReload}
            className="rounded-[11px] bg-gradient-to-br from-avia-black to-avia-brown px-6 py-3 text-[14px] font-medium text-avia-white"
          >
            Reload App
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
