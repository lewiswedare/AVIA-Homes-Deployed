import { ExternalLink, FileStack, Send, UsersRound } from "lucide-react";
import { useMemo } from "react";
import { Link } from "react-router-dom";

import { BentoCard, EmptyState, InitialsAvatar, Spinner } from "@/components/avia/ui";
import { initialsOf } from "@/lib/format";
import { useDocumentLibrary, useProfiles } from "@/lib/queries";

export default function SendingLane({ search }: { search: string }) {
  const { data: profiles, isLoading } = useProfiles();
  const { data: library } = useDocumentLibrary();

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

  if (isLoading) return <Spinner />;

  return (
    <div className="space-y-4">
      <BentoCard className="flex items-center gap-3.5 p-4">
        <div className="flex h-10 w-10 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
          <Send className="h-[18px] w-[18px]" />
        </div>
        <div>
          <div className="text-[14px] font-medium text-avia-black">Documents &amp; Sending</div>
          <div className="text-[12px] text-avia-black/55">
            Open a client to see their documents, what&apos;s been sent and what they&apos;ve opened.
          </div>
        </div>
      </BentoCard>

      {(library ?? []).length > 0 && (
        <div className="space-y-2">
          <div className="text-[11px] font-medium uppercase tracking-[0.1em] text-avia-black/35">
            Stock library
          </div>
          {(library ?? []).map((doc) => (
            <BentoCard key={doc.id} className="flex items-center gap-3 p-3.5">
              <div className="flex h-9 w-9 items-center justify-center rounded-[9px] bg-avia-brown text-avia-white">
                <FileStack className="h-4 w-4" />
              </div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-[13px] font-medium text-avia-black">{doc.name}</div>
                <div className="truncate text-[11px] text-avia-black/55">
                  {doc.category}
                  {doc.description ? ` · ${doc.description}` : ""}
                </div>
              </div>
              <a
                href={doc.file_url}
                target="_blank"
                rel="noreferrer"
                className="rounded-full p-2 text-avia-brown hover:bg-avia-brown/10"
                aria-label={`Open ${doc.name}`}
              >
                <ExternalLink className="h-4 w-4" />
              </a>
            </BentoCard>
          ))}
        </div>
      )}

      <div className="text-[11px] font-medium uppercase tracking-[0.1em] text-avia-black/35">
        Pick a client
      </div>

      {clients.length === 0 ? (
        <EmptyState
          icon={UsersRound}
          title="No clients found"
          subtitle={search ? "Try a different search." : "Clients will appear here."}
        />
      ) : (
        <div className="space-y-2">
          {clients.map((client) => (
            <Link key={client.id} to={`/clients/${client.id}?tab=sending`} className="block">
              <BentoCard className="flex items-center gap-3 p-3.5">
                <InitialsAvatar initials={initialsOf(client.first_name, client.last_name)} />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[14px] font-medium text-avia-black">
                    {`${client.first_name} ${client.last_name}`.trim() || client.email}
                  </div>
                  <div className="truncate text-[11px] text-avia-black/55">{client.email}</div>
                </div>
                <Send className="h-4 w-4 text-avia-brown" />
              </BentoCard>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
