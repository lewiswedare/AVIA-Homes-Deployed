import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  Bell,
  CheckCheck,
  DollarSign,
  FileText,
  Hammer,
  Mail,
  MessageSquare,
  Palette,
  UserCheck,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { useNavigate } from "react-router-dom";

import { BentoCard, EmptyState, Spinner } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { relativeTime } from "@/lib/format";
import { useNotifications } from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import { isClientRole } from "@/lib/types";
import type { NotificationRow } from "@/lib/types";
import { cn } from "@/lib/utils";

const typeIcon: Record<string, LucideIcon> = {
  new_message: MessageSquare,
  build_update: Hammer,
  document_added: FileText,
  contract_uploaded: FileText,
  contract_signed: FileText,
  invoice_raised: DollarSign,
  invoice_paid: DollarSign,
  upgrade_quoted: DollarSign,
  colour_selection_submitted: Palette,
  role_assigned: UserCheck,
  request_submitted: Mail,
  request_response: Mail,
};

/**
 * Where tapping a notification should land, mirroring the iOS app's
 * notification routing. Staff land on the workspace (its Action Required
 * panel covers EOIs, packages, contracts and requests); clients land on the
 * screen that owns the update. Returns null when there is no destination.
 */
function destinationFor(n: NotificationRow, client: boolean): string | null {
  switch (n.type) {
    case "new_message":
      return n.reference_id ? `/messages?conversation=${n.reference_id}` : "/messages";
    case "build_update":
    case "handover_triggered":
      return client ? "/progress" : "/workspace";
    case "document_added":
    case "contract_uploaded":
    case "contract_signed":
    case "contract_raised":
      return client ? "/documents" : "/workspace";
    case "spec_tier_changed":
    case "upgrade_quoted":
    case "colour_selection_submitted":
      return client ? "/selections" : "/workspace";
    case "request_submitted":
    case "request_response":
    case "package_shared":
    case "package_approved":
    case "package_declined":
    case "package_accepted":
    case "deposit_invoice":
    case "deposit_received":
    case "eoi_submitted":
    case "eoi_approved":
    case "eoi_changes_requested":
    case "invoice_raised":
    case "invoice_paid":
      return client ? "/home" : "/workspace";
    case "design_enquiry":
      return client ? null : "/workspace";
    default:
      return null;
  }
}

export default function Notifications() {
  const { userId, role } = useAuth();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { data: notifications, isLoading } = useNotifications(userId);
  const client = isClientRole(role);

  const list = notifications ?? [];
  const unread = list.filter((n) => !n.is_read);

  const markRead = useMutation({
    mutationFn: async (id: string): Promise<void> => {
      const { error } = await supabase.from("notifications").update({ is_read: true }).eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["notifications"] });
    },
  });

  const markAllRead = useMutation({
    mutationFn: async (): Promise<void> => {
      const { error } = await supabase
        .from("notifications")
        .update({ is_read: true })
        .eq("recipient_id", userId ?? "")
        .eq("is_read", false);
      if (error) throw error;
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["notifications"] });
    },
  });

  if (isLoading) return <Spinner />;

  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between">
        <h1 className="text-[28px] font-medium text-avia-black">Alerts</h1>
        {unread.length > 0 && (
          <button
            type="button"
            onClick={() => markAllRead.mutate()}
            className="flex items-center gap-1.5 text-[13px] font-medium text-avia-brown hover:underline"
          >
            <CheckCheck className="h-4 w-4" /> Mark all read
          </button>
        )}
      </div>

      {list.length === 0 ? (
        <EmptyState icon={Bell} title="No alerts" subtitle="Updates about your build and account will appear here." />
      ) : (
        <div className="space-y-2">
          {list.map((n: NotificationRow) => {
            const Icon = typeIcon[n.type] ?? Bell;
            const destination = destinationFor(n, client);
            return (
              <button
                key={n.id}
                type="button"
                onClick={() => {
                  if (!n.is_read) markRead.mutate(n.id);
                  if (destination) navigate(destination);
                }}
                className="block w-full text-left"
              >
                <BentoCard className={cn("flex items-start gap-3.5 p-4", !n.is_read && "ring-1 ring-avia-brown/30")}>
                  <div
                    className={cn(
                      "flex h-9 w-9 shrink-0 items-center justify-center rounded-full",
                      n.is_read ? "bg-avia-black/5 text-avia-black/40" : "bg-avia-brown/10 text-avia-brown",
                    )}
                  >
                    <Icon className="h-4 w-4" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <span className={cn("truncate text-[14px]", n.is_read ? "text-avia-black/70" : "font-medium text-avia-black")}>
                        {n.title || n.type}
                      </span>
                      {!n.is_read && <span className="h-2 w-2 shrink-0 rounded-full bg-avia-brown" />}
                    </div>
                    <div className="mt-0.5 text-[13px] text-avia-black/55">{n.message}</div>
                    <div className="mt-1 text-[11px] text-avia-black/35">
                      {n.sender_name ? `${n.sender_name} · ` : ""}
                      {relativeTime(n.created_at)}
                    </div>
                  </div>
                </BentoCard>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
