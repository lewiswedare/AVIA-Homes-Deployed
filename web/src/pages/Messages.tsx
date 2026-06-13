import { useMutation, useQueryClient } from "@tanstack/react-query";
import { MessageSquare, Plus, Send } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { toast } from "sonner";

import { BentoCard, EmptyState, InitialsAvatar, Modal, PrimaryButton, Spinner } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { fmtTime, fullNameOf, initialsOf, nowISO, relativeTime, uuid } from "@/lib/format";
import { useConversations, useMessages, useProfiles, useUnreadCounts } from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import { isClientRole } from "@/lib/types";
import type { ChatMessageRow, ConversationRow, ProfileRow } from "@/lib/types";
import { cn } from "@/lib/utils";

export default function Messages() {
  const { userId, role } = useAuth();
  const { data: conversations, isLoading } = useConversations(userId);
  const { data: profiles } = useProfiles();
  const [searchParams, setSearchParams] = useSearchParams();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [composeOpen, setComposeOpen] = useState<boolean>(false);

  const list = conversations ?? [];
  const conversationIds = useMemo(() => (conversations ?? []).map((c) => c.id), [conversations]);
  const { data: unreadCounts } = useUnreadCounts(userId, conversationIds);

  // Deep link from a notification: /messages?conversation=<id> opens that
  // thread once conversations have loaded, then clears the param.
  const deepLinkId = searchParams.get("conversation");
  useEffect(() => {
    if (!deepLinkId) return;
    if (list.some((c) => c.id === deepLinkId)) {
      setSelectedId(deepLinkId);
      setSearchParams({}, { replace: true });
    }
  }, [deepLinkId, list, setSearchParams]);
  const selected = list.find((c) => c.id === selectedId) ?? null;

  const nameForConversation = (c: ConversationRow): string => {
    const others = (c.participant_ids ?? []).filter((p) => p !== userId);
    const names = others.map((pid) => {
      const p = (profiles ?? []).find((x) => x.id === pid);
      return p ? `${p.first_name ?? ""} ${p.last_name ?? ""}`.trim() || p.email || "Member" : "Member";
    });
    return names.join(", ") || "Conversation";
  };

  if (isLoading) return <Spinner />;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-[28px] font-medium text-avia-black">Messages</h1>
        <button
          type="button"
          onClick={() => setComposeOpen(true)}
          className="flex items-center gap-1.5 rounded-full bg-avia-brown px-4 py-2 text-[13px] font-medium text-white transition-opacity hover:opacity-90"
        >
          <Plus className="h-4 w-4" /> New
        </button>
      </div>

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
                <div className="flex shrink-0 flex-col items-end gap-1">
                  <span className="text-[11px] text-avia-black/35">{relativeTime(c.last_message_date)}</span>
                  {(unreadCounts?.[c.id] ?? 0) > 0 && (
                    <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-avia-brown px-1.5 text-[10px] font-semibold text-white">
                      {unreadCounts?.[c.id]}
                    </span>
                  )}
                </div>
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

      {composeOpen && (
        <NewConversationModal
          client={isClientRole(role)}
          conversations={list}
          profiles={profiles ?? []}
          userId={userId}
          onClose={() => setComposeOpen(false)}
          onCreated={(id) => {
            setComposeOpen(false);
            setSelectedId(id);
          }}
        />
      )}
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

  // Mark incoming messages read when the thread opens (iOS parity), then refresh
  // the unread badges and conversation list.
  useEffect(() => {
    void (async () => {
      const { error } = await supabase
        .from("messages")
        .update({ is_read: true })
        .eq("conversation_id", conversation.id)
        .eq("is_read", false)
        .neq("sender_id", userId ?? "");
      if (error) return;
      void qc.invalidateQueries({ queryKey: ["messages", "unread"] });
      void qc.invalidateQueries({ queryKey: ["conversations"] });
    })();
  }, [conversation.id, userId, qc]);

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

/**
 * Start a new conversation. Clients open the shared "Message AVIA" general
 * thread (one per client); staff/admin/partner pick a person for a direct 1:1.
 * Both reuse an existing matching thread instead of creating duplicates,
 * mirroring the iOS getOrCreate{General,}Conversation flow.
 */
function NewConversationModal({
  client,
  conversations,
  profiles,
  userId,
  onClose,
  onCreated,
}: {
  client: boolean;
  conversations: ConversationRow[];
  profiles: ProfileRow[];
  userId: string | null;
  onClose: () => void;
  onCreated: (conversationId: string) => void;
}) {
  const qc = useQueryClient();
  const [search, setSearch] = useState<string>("");
  const meId = (userId ?? "").toLowerCase();

  const recipients = useMemo(
    () =>
      profiles
        .filter((p) => p.id.toLowerCase() !== meId)
        .filter((p) => {
          const q = search.trim().toLowerCase();
          if (!q) return true;
          return fullNameOf(p).toLowerCase().includes(q) || (p.email ?? "").toLowerCase().includes(q);
        }),
    [profiles, meId, search],
  );

  const create = useMutation({
    mutationFn: async (otherId: string | null): Promise<string> => {
      if (client || otherId === null) {
        const existing = conversations.find(
          (c) => c.conversation_type === "general" && (c.participant_ids ?? []).some((p) => p.toLowerCase() === meId),
        );
        if (existing) return existing.id;
        const id = uuid();
        const { error } = await supabase.from("conversations").insert({
          id,
          participant_ids: [meId],
          last_message: "",
          last_message_date: nowISO(),
          last_sender_id: "",
          unread_count: 0,
          conversation_type: "general",
        });
        if (error) throw error;
        return id;
      }
      const other = otherId.toLowerCase();
      const existing = conversations.find(
        (c) =>
          (c.conversation_type ?? "direct") === "direct" &&
          (c.participant_ids ?? []).some((p) => p.toLowerCase() === meId) &&
          (c.participant_ids ?? []).some((p) => p.toLowerCase() === other),
      );
      if (existing) return existing.id;
      const id = uuid();
      const { error } = await supabase.from("conversations").insert({
        id,
        participant_ids: [meId, other],
        last_message: "",
        last_message_date: nowISO(),
        last_sender_id: "",
        unread_count: 0,
        conversation_type: "direct",
      });
      if (error) throw error;
      return id;
    },
    onSuccess: async (id) => {
      await qc.invalidateQueries({ queryKey: ["conversations", userId] });
      onCreated(id);
    },
    onError: () => toast.error("Couldn't start the conversation."),
  });

  return (
    <Modal open onClose={onClose} title="New message">
      {client ? (
        <div className="space-y-3">
          <p className="text-[14px] text-avia-black/70">
            Send a message to the AVIA Homes team — someone will get back to you right here.
          </p>
          <PrimaryButton onClick={() => create.mutate(null)} loading={create.isPending}>
            Message the AVIA team
          </PrimaryButton>
        </div>
      ) : (
        <div className="space-y-3">
          <input
            className="w-full rounded-[10px] border border-avia-line bg-avia-card px-4 py-2.5 text-[16px] outline-none placeholder:text-avia-black/35 focus:border-avia-brown sm:text-[14px]"
            placeholder="Search people…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            aria-label="Search people"
          />
          <div className="max-h-80 space-y-1 overflow-y-auto">
            {recipients.map((p) => (
              <button
                key={p.id}
                type="button"
                disabled={create.isPending}
                onClick={() => create.mutate(p.id)}
                className="flex w-full items-center gap-3 rounded-[10px] px-2 py-2 text-left transition-colors hover:bg-avia-black/5 disabled:opacity-60"
              >
                <InitialsAvatar initials={initialsOf(p.first_name, p.last_name)} className="h-8 w-8 text-[11px]" />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[14px] font-medium text-avia-black">{fullNameOf(p)}</div>
                  <div className="truncate text-[12px] text-avia-black/45">
                    {p.role} · {p.email}
                  </div>
                </div>
              </button>
            ))}
            {recipients.length === 0 && (
              <div className="py-8 text-center text-[13px] text-avia-black/45">No people found</div>
            )}
          </div>
        </div>
      )}
    </Modal>
  );
}
