import { Calendar, CalendarClock } from "lucide-react";
import { useMemo } from "react";

import { EmptyState, MetricCard, Spinner } from "@/components/avia/ui";
import { AppointmentRow } from "@/components/workspace/shared";
import { dayHeader, isToday, parseDate, startOfDay } from "@/lib/format";
import { useAllSchedule, useProfiles } from "@/lib/queries";
import type { ScheduleItemRow } from "@/lib/types";
import { cn } from "@/lib/utils";

export default function ScheduleLane() {
  const { data: schedule, isLoading } = useAllSchedule();
  const { data: profiles } = useProfiles();

  const upcoming = useMemo(() => {
    const start = startOfDay(new Date()).getTime();
    return (schedule ?? [])
      .filter((s) => {
        const d = parseDate(s.date);
        return d !== null && d.getTime() >= start;
      })
      .sort((a, b) => a.date.localeCompare(b.date));
  }, [schedule]);

  const grouped = useMemo(() => {
    const map = new Map<number, ScheduleItemRow[]>();
    for (const item of upcoming) {
      const d = parseDate(item.date);
      if (!d) continue;
      const key = startOfDay(d).getTime();
      const list = map.get(key) ?? [];
      list.push(item);
      map.set(key, list);
    }
    return Array.from(map.entries()).sort((a, b) => a[0] - b[0]);
  }, [upcoming]);

  const todayCount = upcoming.filter((s) => {
    const d = parseDate(s.date);
    return d !== null && isToday(d);
  }).length;
  const weekCount = upcoming.filter((s) => {
    const d = parseDate(s.date);
    if (!d || isToday(d)) return false;
    return d.getTime() <= Date.now() + 7 * 86400000;
  }).length;

  if (isLoading) return <Spinner />;

  return (
    <div className="space-y-5">
      <div className="flex gap-2.5">
        <MetricCard value={`${todayCount}`} label="Today" icon={CalendarClock} tone="brown" />
        <MetricCard value={`${weekCount}`} label="This Week" icon={Calendar} tone="blue" />
      </div>

      {grouped.length === 0 ? (
        <EmptyState
          icon={Calendar}
          title="Nothing scheduled"
          subtitle="Add milestones from a client's record."
        />
      ) : (
        grouped.map(([dayMs, items]) => {
          const day = new Date(dayMs);
          return (
            <div key={dayMs} className="space-y-2">
              <div
                className={cn(
                  "text-[11px] font-medium uppercase tracking-[0.1em]",
                  isToday(day) ? "text-avia-brown" : "text-avia-black/35",
                )}
              >
                {dayHeader(day)}
              </div>
              {items.map((item) => (
                <AppointmentRow key={item.id} item={item} profiles={profiles ?? []} />
              ))}
            </div>
          );
        })
      )}
    </div>
  );
}
