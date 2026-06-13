import * as DialogPrimitive from "@radix-ui/react-dialog";
import type { LucideIcon } from "lucide-react";
import { AlertTriangle, Loader2 } from "lucide-react";
import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

export type Tone = "brown" | "blue" | "warning" | "black" | "muted";

export const toneText: Record<Tone, string> = {
  brown: "text-avia-brown",
  blue: "text-avia-blue",
  warning: "text-avia-brown/80",
  black: "text-avia-black/85",
  muted: "text-avia-black/55",
};

export const toneBg: Record<Tone, string> = {
  brown: "bg-avia-brown/10",
  blue: "bg-avia-blue/15",
  warning: "bg-avia-brown/10",
  black: "bg-avia-black/10",
  muted: "bg-avia-black/5",
};

export function BentoCard({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return <div className={cn("rounded-[13px] bg-avia-card", className)}>{children}</div>;
}

export function IconCircle({
  icon: Icon,
  tone = "brown",
  className,
}: {
  icon: LucideIcon;
  tone?: Tone;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex h-9 w-9 shrink-0 items-center justify-center rounded-full",
        toneBg[tone],
        toneText[tone],
        className,
      )}
    >
      <Icon className="h-4 w-4" />
    </div>
  );
}

export function MetricCard({
  value,
  label,
  icon: Icon,
  tone = "brown",
}: {
  value: string;
  label: string;
  icon: LucideIcon;
  tone?: Tone;
}) {
  return (
    <BentoCard className="flex flex-1 flex-col gap-2 p-4">
      <IconCircle icon={Icon} tone={tone} className="h-8 w-8" />
      <div className="text-[26px] font-medium leading-none text-avia-black">{value}</div>
      <div className="text-[11px] font-medium uppercase tracking-wider text-avia-black/35">{label}</div>
    </BentoCard>
  );
}

export function StatusPill({
  label,
  tone = "brown",
  className,
}: {
  label: string;
  tone?: Tone;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center whitespace-nowrap rounded-full border px-2.5 py-0.5 text-[11px] font-medium",
        toneText[tone],
        tone === "brown" && "border-avia-brown/50",
        tone === "blue" && "border-avia-blue",
        tone === "warning" && "border-avia-brown/40",
        tone === "black" && "border-avia-black/40",
        tone === "muted" && "border-avia-black/25",
        className,
      )}
    >
      {label}
    </span>
  );
}

export function SectionLabel({
  title,
  count,
  tone = "brown",
}: {
  title: string;
  count?: number;
  tone?: Tone;
}) {
  return (
    <div className="flex items-center gap-2">
      <span className="text-[11px] font-medium uppercase tracking-[0.1em] text-avia-black/35">{title}</span>
      {typeof count === "number" && (
        <span
          className={cn(
            "rounded-full px-1.5 py-px text-[10px] font-medium",
            toneText[tone],
            toneBg[tone],
          )}
        >
          {count}
        </span>
      )}
    </div>
  );
}

export function EmptyState({
  icon: Icon,
  title,
  subtitle,
}: {
  icon: LucideIcon;
  title: string;
  subtitle?: string;
}) {
  return (
    <div className="flex flex-col items-center gap-3 py-16 text-center">
      <Icon className="h-9 w-9 text-avia-black/30" />
      <div className="text-[15px] font-medium text-avia-black">{title}</div>
      {subtitle && <div className="max-w-xs text-[13px] text-avia-black/55">{subtitle}</div>}
    </div>
  );
}

/**
 * Failed-query state with an optional retry. Use this instead of falling
 * through to an EmptyState when a fetch errors — otherwise users are told they
 * have nothing when the request actually failed.
 */
export function ErrorState({
  title = "Couldn’t load this",
  subtitle = "Check your connection and try again.",
  onRetry,
}: {
  title?: string;
  subtitle?: string;
  onRetry?: () => void;
}) {
  return (
    <div className="flex flex-col items-center gap-3 py-16 text-center">
      <AlertTriangle className="h-9 w-9 text-avia-black/30" />
      <div className="text-[15px] font-medium text-avia-black">{title}</div>
      <div className="max-w-xs text-[13px] text-avia-black/55">{subtitle}</div>
      {onRetry && (
        <button
          type="button"
          onClick={onRetry}
          className="mt-1 rounded-full bg-avia-black px-5 py-2 text-[13px] font-medium text-avia-white transition-opacity hover:opacity-90"
        >
          Try again
        </button>
      )}
    </div>
  );
}

export function InitialsAvatar({
  initials,
  className,
}: {
  initials: string;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-avia-black to-avia-brown text-[12px] font-medium text-avia-white",
        className,
      )}
    >
      {initials}
    </div>
  );
}

export function ProgressBar({ value, className }: { value: number; className?: string }) {
  const pct = Math.max(0, Math.min(100, Math.round(value * 100)));
  return (
    <div className={cn("h-1.5 w-full overflow-hidden rounded-full bg-avia-black/10", className)}>
      <div
        className="h-full rounded-full bg-avia-brown transition-all duration-500"
        style={{ width: `${pct}%` }}
      />
    </div>
  );
}

export function PrimaryButton({
  children,
  onClick,
  disabled,
  loading,
  type = "button",
  className,
}: {
  children: ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  loading?: boolean;
  type?: "button" | "submit";
  className?: string;
}) {
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled || loading}
      className={cn(
        "flex h-[50px] w-full items-center justify-center gap-2 rounded-[11px] bg-gradient-to-br from-avia-black to-avia-brown text-[15px] font-medium text-avia-white transition-all",
        "hover:opacity-95 active:scale-[0.99] disabled:opacity-50",
        className,
      )}
    >
      {loading ? <Loader2 className="h-5 w-5 animate-spin" /> : children}
    </button>
  );
}

export function SecondaryButton({
  children,
  onClick,
  disabled,
  type = "button",
  className,
}: {
  children: ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  type?: "button" | "submit";
  className?: string;
}) {
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={cn(
        "flex h-[50px] w-full items-center justify-center gap-2 rounded-[11px] border border-avia-brown/20 bg-avia-brown/10 text-[15px] font-medium text-avia-brown transition-all",
        "hover:bg-avia-brown/15 active:scale-[0.99] disabled:opacity-50",
        className,
      )}
    >
      {children}
    </button>
  );
}

export function FieldLabel({ children }: { children: ReactNode }) {
  return <label className="text-[12px] font-medium text-avia-black/55">{children}</label>;
}

/** Inline validation message shown directly under a form field. */
export function FieldError({ message }: { message?: string }) {
  if (!message) return null;
  return <p className="text-[12px] text-red-600">{message}</p>;
}

// Font is 16px on phones so iOS Safari doesn't auto-zoom the page on focus,
// stepping back down to the designed 15px from the sm breakpoint up.
export const inputClass =
  "w-full rounded-[10px] border border-avia-line bg-avia-card px-4 py-3 text-[16px] sm:text-[15px] text-avia-black outline-none transition-colors placeholder:text-avia-black/35 focus:border-avia-brown";

export function Spinner({ className }: { className?: string }) {
  return (
    <div className={cn("flex w-full items-center justify-center py-12", className)}>
      <Loader2 className="h-6 w-6 animate-spin text-avia-brown" />
    </div>
  );
}

/**
 * Centered modal overlay used for quick add/edit sheets. Built on Radix
 * Dialog so it gets a real focus trap, Escape-to-close, scroll locking and
 * `aria-modal` semantics for free.
 */
export function Modal({
  open,
  onClose,
  title,
  children,
  footer,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <DialogPrimitive.Root open={open} onOpenChange={(next) => { if (!next) onClose(); }}>
      <DialogPrimitive.Portal>
        <DialogPrimitive.Overlay className="fixed inset-0 z-50 bg-avia-black/40 backdrop-blur-[2px]" />
        <div className="fixed inset-0 z-50 flex items-end justify-center sm:items-center">
          <DialogPrimitive.Content
            className="max-h-[88vh] w-full max-w-lg animate-fade-in overflow-y-auto rounded-t-[18px] bg-avia-cardAlt p-5 pb-[calc(env(safe-area-inset-bottom)+1.25rem)] shadow-2xl outline-none sm:rounded-[18px] sm:pb-5"
            onPointerDownOutside={onClose}
          >
            <div className="mb-4 flex items-center justify-between">
              <DialogPrimitive.Title className="text-[18px] font-medium text-avia-black">
                {title}
              </DialogPrimitive.Title>
              <DialogPrimitive.Close
                className="rounded-full px-3 py-1 text-[13px] font-medium text-avia-black/55 hover:bg-avia-black/5"
              >
                Close
              </DialogPrimitive.Close>
            </div>
            <div className="space-y-4">{children}</div>
            {footer && <div className="mt-5">{footer}</div>}
          </DialogPrimitive.Content>
        </div>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  );
}
