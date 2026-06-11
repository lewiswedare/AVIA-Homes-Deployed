/** Formatting helpers shared across the web app (mirrors AVIATheme.formatCost & iOS date styles). */

export function formatCost(amount: number): string {
  const hasCents = amount % 1 !== 0;
  return new Intl.NumberFormat("en-AU", {
    style: "currency",
    currency: "AUD",
    minimumFractionDigits: hasCents ? 2 : 0,
    maximumFractionDigits: hasCents ? 2 : 0,
  }).format(amount);
}

export function parseDate(value: string | null | undefined): Date | null {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

export function fmtDate(value: string | Date | null | undefined): string {
  const d = typeof value === "string" ? parseDate(value) : (value ?? null);
  if (!d) return "—";
  return d.toLocaleDateString("en-AU", { day: "numeric", month: "short", year: "numeric" });
}

export function fmtDateTime(value: string | Date | null | undefined): string {
  const d = typeof value === "string" ? parseDate(value) : (value ?? null);
  if (!d) return "—";
  return d.toLocaleDateString("en-AU", {
    day: "numeric",
    month: "short",
    hour: "numeric",
    minute: "2-digit",
  });
}

export function fmtTime(value: string | Date | null | undefined): string {
  const d = typeof value === "string" ? parseDate(value) : (value ?? null);
  if (!d) return "—";
  return d.toLocaleTimeString("en-AU", { hour: "numeric", minute: "2-digit" });
}

export function startOfDay(d: Date): Date {
  const out = new Date(d);
  out.setHours(0, 0, 0, 0);
  return out;
}

export function isToday(d: Date): boolean {
  return startOfDay(d).getTime() === startOfDay(new Date()).getTime();
}

export function isTomorrow(d: Date): boolean {
  const t = new Date();
  t.setDate(t.getDate() + 1);
  return startOfDay(d).getTime() === startOfDay(t).getTime();
}

export function relativeTime(value: string | Date | null | undefined): string {
  const d = typeof value === "string" ? parseDate(value) : (value ?? null);
  if (!d) return "";
  const diffMs = d.getTime() - Date.now();
  const abs = Math.abs(diffMs);
  const rtf = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
  const minutes = Math.round(diffMs / 60000);
  if (abs < 3600000) return rtf.format(minutes, "minute");
  const hours = Math.round(diffMs / 3600000);
  if (abs < 86400000) return rtf.format(hours, "hour");
  const days = Math.round(diffMs / 86400000);
  if (abs < 86400000 * 30) return rtf.format(days, "day");
  const months = Math.round(diffMs / (86400000 * 30));
  return rtf.format(months, "month");
}

export function dayHeader(d: Date): string {
  const weekday = d.toLocaleDateString("en-AU", { weekday: "long" });
  if (isToday(d)) return `TODAY · ${weekday}`;
  if (isTomorrow(d)) return `TOMORROW · ${weekday}`;
  return d
    .toLocaleDateString("en-AU", { weekday: "long", day: "numeric", month: "long" })
    .toUpperCase();
}

export function initialsOf(first: string | null | undefined, last?: string | null): string {
  const a = (first ?? "").trim();
  const b = (last ?? "").trim();
  if (a && b) return `${a[0]}${b[0]}`.toUpperCase();
  if (a) {
    const parts = a.split(/\s+/);
    if (parts.length > 1) return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
    return a[0].toUpperCase();
  }
  return "?";
}

export function fullNameOf(p: { first_name?: string | null; last_name?: string | null; email?: string | null }): string {
  const name = `${p.first_name ?? ""} ${p.last_name ?? ""}`.trim();
  return name.length > 0 ? name : (p.email ?? "Unknown");
}

/** Humanizes snake_case / camelCase status keys: "upgrade_requested" → "Upgrade Requested". Null-safe. */
export function humanize(value: string | null | undefined): string {
  return (value ?? "")
    .replace(/_/g, " ")
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

export function nowISO(): string {
  return new Date().toISOString();
}

export function uuid(): string {
  return crypto.randomUUID().toUpperCase();
}
