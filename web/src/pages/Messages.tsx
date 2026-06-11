import { useMutation, useQueryClient } from "@tanstack/react-query";
import { MessageSquare, Send } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { toast } from "sonner";

import { BentoCard, EmptyState, InitialsAvatar, Spinner } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { fmtTime, initialsOf, nowISO, relativeTime, uuid } from "@/lib/format";
import { useConversations, useMessages, useProfiles } from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import type { ChatMessageRow, ConversationRow } from "@/lib/types";
import { cn } from "@/lib/utils";

export default function Messages() {
  const { userId } = useAuth();
  const { data: conversations, isLoading } = useConversations(userId);
  const { data: profiles } = useProfiles();
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const list = conversations ?? [];
  const selected = list.find((c) => c.id === selectedId) ?? null;

  const nameForConversation = (c: ConversationRow): string => {
    const others = c.participant_ids.filter((p) => p !== userId);
    const names = others.map((pid) => {
      const p = (profiles ?? []).find((x) => x.id === pid);
      return p ? `${p.first_name} ${p.last_name}`.trim() || p.email : "Member";
    });
    return names.join(", ") || "Conversation";
  };

  if (isLoading) return <Spinner />;

  return (
    <div className="space-y-4">
      <h1 className="text-[28px] font-medium text-avia-black">Messages</h1>

      <div className="grid gap-4 lg:grid-cols-[320px_1fr]">
        {/* Conversation list */}
        <div className={cn("space-y-2", selected && "hidden lg:block")}>
          {list.length === 0 && (
            <EmptyState
              icon={MessageSquare}
              title="No conversations"
              subtitle="Conversations with your AVIA team will appear here."
            />
          )}
          {list.map((c) => (
            <button key={c.id} type="button" onClick={() => setSelectedId(c.id)} className="block w-full text-left">
              <BentoCard
                className={cn(
                  "flex items-center gap-3 p-3.5",
                  selectedId === c.id && "ring-1 ring-avia-brown",
                )}
              >
                <InitialsAvatar initials={initialsOf(nameForConversation(c))} />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[14px] font-medium text-avia-black">
                    {nameForConversation(c)}
                  </div>
                  <div className="truncate text-[12px] text-avia-black/55">{c.last_message ?? ""}</div>
                </div>
                <span className="shrink-0 text-[11px] text-avia-black/35">
                  {relativeTime(c.last_message_date)}
                </span>
              </BentoCard>
            </button>
          ))}
        </div>

        {/* Thread */}
        <div className={cn(!selected && "hidden lg:block")}>
          {selected ? (
            <Thread
              conversation={selected}
              title={nameForConversation(selected)}
              onBack={() => setSelectedId(null)}
            />
          ) : (
            <BentoCard className="hidden h-full min-h-[360px] items-center justify-center lg:flex">
              <EmptyState icon={MessageSquare} title="Select a conversation" />
            </BentoCard>
          )}
        </div>
      </div>
    </div>
  );
}

function Thread({
  conversation,
  title,
  onBack,
}: {
  conversation: ConversationRow;
  title: string;
  onBack: () => void;
}) {
  const { userId } = useAuth();
  const qc = useQueryClient();
  const { data: messages, isLoading } = useMessages(conversation.id);
  const [draft, setDraft] = useState<string>("");
  const bottomRef = useRef<HTMLDivElement | null>(null);

  const messageList = useMemo(() => messages ?? [], [messages]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messageList.length]);

  const send = useMutation({
    mutationFn: async (content: string): Promise<void> => {
      const row: ChatMessageRow = {
        id: uuid(),
        conversation_id: conversation.id,
        sender_id: userId ?? "",
        content,
        created_at: nowISO(),
        is_read: false,
        attachment_url: null,
        attachment_type: null,
      };
      const { error } = await supabase.from("messages").insert(row);
      if (error) throw error;
      await supabase
        .from("conversations")
        .update({
          last_message: content,
          last_message_date: nowISO(),
          last_sender_id: userId ?? "",
        })
        .eq("id", conversation.id);
    },
    onSuccess: () => {
      setDraft("");
      void qc.invalidateQueries({ queryKey: ["messages", conversation.id] });
      void qc.invalidateQueries({ queryKey: ["conversations"] });
    },
    onError: () => toast.error("Message failed to send."),
  });

  return (
    <BentoCard className="flex h-[70vh] flex-col">
      <div className="flex items-center gap-3 border-b border-avia-line px-4 py-3">
        <button
          type="button"
          onClick={onBack}
          className="rounded-full px-2 py-1 text-[13px] font-medium text-avia-brown lg:hidden"
        >
          Back
        </button>
        <div className="text-[15px] font-medium text-avia-black">{title}</div>
      </div>

      <div className="flex-1 space-y-2.5 overflow-y-auto p-4">
        {isLoading && <Spinner />}
        {messageList.map((m) => {
          const mine = m.sender_id === userId;
          return (
            <div key={m.id} className={cn("flex", mine ? "justify-end" : "justify-start")}>
              <div
                className={cn(
                  "max-w-[75%] rounded-2xl px-4 py-2.5 text-[14px]",
                  mine
                    ? "rounded-br-md bg-avia-brown text-avia-white"
                    : "rounded-bl-md bg-avia-cardAlt text-avia-black",
                )}
              >
                <div>{m.content}</div>
                <div className={cn("mt-1 text-right text-[10px]", mine ? "text-avia-white/60" : "text-avia-black/35")}>
                  {fmtTime(m.created_at)}
                </div>
              </div>
            </div>
          );
        })}
        <div ref={bottomRef} />
      </div>

      <form
        className="flex items-center gap-2 border-t border-avia-line p-3"
        onSubmit={(e) => {
          e.preventDefault();
          if (draft.trim()) send.mutate(draft.trim());
        }}
      >
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder="Type a message…"
          className="flex-1 rounded-full border border-avia-line bg-avia-cardAlt px-4 py-2.5 text-[14px] outline-none placeholder:text-avia-black/35 focus:border-avia-brown"
        />
        <button
          type="submit"
          disabled={!draft.trim() || send.isPending}
          className="flex h-10 w-10 items-center justify-center rounded-full bg-avia-brown text-avia-white disabled:opacity-40"
          aria-label="Send message"
        >
          <Send className="h-4 w-4" />
        </button>
      </form>
    </BentoCard>
  );
}
