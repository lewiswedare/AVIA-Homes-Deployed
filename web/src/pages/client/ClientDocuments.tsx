import { ExternalLink, FileText } from "lucide-react";
import { useMemo, useState } from "react";

import { BentoCard, EmptyState, Spinner, StatusPill } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { fmtDate } from "@/lib/format";
import { useClientDocuments } from "@/lib/queries";
import { cn } from "@/lib/utils";

export default function ClientDocuments() {
  const { userId } = useAuth();
  const { data: documents, isLoading } = useClientDocuments(userId);
  const [category, setCategory] = useState<string>("All");

  const docs = useMemo(() => documents ?? [], [documents]);
  const categories = useMemo(() => {
    const set = new Set<string>(docs.map((d) => d.category));
    return ["All", ...Array.from(set).sort()];
  }, [docs]);

  const filtered = category === "All" ? docs : docs.filter((d) => d.category === category);

  if (isLoading) return <Spinner />;

  return (
    <div className="space-y-5">
      <h1 className="text-[28px] font-medium text-avia-black">Documents</h1>

      {docs.length > 0 && (
        <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-none">
          {categories.map((c) => (
            <button
              key={c}
              type="button"
              onClick={() => setCategory(c)}
              className={cn(
                "whitespace-nowrap rounded-full px-3.5 py-2 text-[12px] font-medium transition-colors",
                category === c
                  ? "bg-avia-brown text-avia-white"
                  : "border border-avia-line bg-avia-card text-avia-black/55 hover:text-avia-black",
              )}
            >
              {c}
            </button>
          ))}
        </div>
      )}

      <div className="space-y-2.5">
        {filtered.map((doc) => (
          <BentoCard key={doc.id} className="flex items-center gap-3.5 p-4">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
              <FileText className="h-[18px] w-[18px]" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate text-[14px] font-medium text-avia-black">{doc.name}</div>
              <div className="text-[12px] text-avia-black/55">
                {doc.category} · {fmtDate(doc.date_added)}
                {doc.file_size ? ` · ${doc.file_size}` : ""}
              </div>
            </div>
            {doc.is_new && <StatusPill label="NEW" tone="blue" />}
            {doc.file_url && (
              <a
                href={doc.file_url}
                target="_blank"
                rel="noreferrer"
                className="rounded-full p-2 text-avia-brown transition-colors hover:bg-avia-brown/10"
                aria-label={`Open ${doc.name}`}
              >
                <ExternalLink className="h-4 w-4" />
              </a>
            )}
          </BentoCard>
        ))}

        {filtered.length === 0 && (
          <EmptyState
            icon={FileText}
            title="No documents yet"
            subtitle="Contracts, plans and certificates shared by your team will appear here."
          />
        )}
      </div>
    </div>
  );
}
