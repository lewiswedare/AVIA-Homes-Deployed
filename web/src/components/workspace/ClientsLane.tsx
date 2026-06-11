import { ChevronRight, Users } from "lucide-react";
import { useMemo } from "react";
import { Link } from "react-router-dom";

import { BentoCard, EmptyState, InitialsAvatar, MetricCard, Spinner, StatusPill } from "@/components/avia/ui";
import { humanize, initialsOf, relativeTime } from "@/lib/format";
import { useCRMProfiles, useProfiles } from "@/lib/queries";
import type { ClientCRMProfileRow } from "@/lib/types";

export default function ClientsLane({ search }: { search: string }) {
  const { data: profiles, isLoading } = useProfiles();
  const { data: crm } = useCRMProfiles();

  const crmMap = useMemo(() => {
    const map = new Map<string, ClientCRMProfileRow>();
    for (const row of crm ?? []) map.set(row.client_id, row);
    return map;
  }, [crm]);

  const clients = useMemo(() => {
    let list = (profiles ?? []).filter((p) => p.role === "Client");
    const q = search.trim().toLowerCase();
    if (q) {
      list = list.filter(
        (p) =>
          `${p.first_name} ${p.last_name}`.toLowerCase().includes(q) ||
          p.email.toLowerCase().includes(q),
      );
    }
    return list;
  }, [profiles, search]);

  const followUpsDue = clients.filter((c) => {
    const next = crmMap.get(c.id)?.next_follow_up_at;
    return next !== null && next !== undefined && new Date(next).getTime() <= Date.now();
  });

  if (isLoading) return <Spinner />;

  return (
    <div className="space-y-4">
      <div className="flex gap-2.5">
        <MetricCard value={`${clients.length}`} label="Clients" icon={Users} tone="brown" />
        <MetricCard value={`${followUpsDue.length}`} label="Follow-ups due" icon={Users} tone="warning" />
      </div>

      {clients.length === 0 ? (
        <EmptyState
          icon={Users}
          title="No clients found"
          subtitle={search ? "Try a different search." : "Registered clients will appear here."}
        />
      ) : (
        <div className="space-y-2">
          {clients.map((client) => {
            const record = crmMap.get(client.id);
            const name = `${client.first_name} ${client.last_name}`.trim() || client.email;
            return (
              <Link key={client.id} to={`/clients/${client.id}`} className="block">
                <BentoCard className="flex items-center gap-3 p-3.5">
                  <InitialsAvatar initials={initialsOf(client.first_name, client.last_name)} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[14px] font-medium text-avia-black">{name}</div>
                    <div className="mt-0.5 flex items-center gap-2 text-[11px] text-avia-black/55">
                      <span className="truncate">{client.email}</span>
                      {record?.next_follow_up_at && (
                        <span className="whitespace-nowrap text-avia-brown/80">
                          Follow up {relativeTime(record.next_follow_up_at)}
                        </span>
                      )}
                    </div>
                  </div>
                  {record && <StatusPill label={humanize(record.lead_status)} tone="brown" />}
                  <ChevronRight className="h-4 w-4 text-avia-black/30" />
                </BentoCard>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
