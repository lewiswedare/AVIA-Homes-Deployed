import { useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";

import { supabase } from "@/lib/supabase";

/**
 * Live cache invalidation over Supabase Realtime.
 *
 * Replaces the aggressive polling the app shipped with (messages every 8s,
 * conversations every 20s, notifications every 30s): one websocket channel
 * listens for inserts/updates and invalidates exactly the affected query keys,
 * so chat and alerts update instantly. The queries keep a slow refetch as a
 * fallback for missed events.
 */
export function useRealtimeSync(userId: string | null): void {
  const queryClient = useQueryClient();

  useEffect(() => {
    if (!userId) return;

    const channel = supabase
      .channel(`web-sync-${userId}`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "notifications", filter: `recipient_id=eq.${userId}` },
        () => {
          void queryClient.invalidateQueries({ queryKey: ["notifications", userId] });
        },
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "messages" },
        (payload) => {
          const row = (payload.new ?? payload.old) as { conversation_id?: string } | null;
          if (row?.conversation_id) {
            void queryClient.invalidateQueries({ queryKey: ["messages", row.conversation_id] });
          }
          // A new message also bumps the conversation list ordering/preview
          // and the per-conversation unread badges.
          void queryClient.invalidateQueries({ queryKey: ["conversations", userId] });
          void queryClient.invalidateQueries({ queryKey: ["messages", "unread", userId] });
        },
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "conversations" },
        () => {
          void queryClient.invalidateQueries({ queryKey: ["conversations", userId] });
        },
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [userId, queryClient]);
}
