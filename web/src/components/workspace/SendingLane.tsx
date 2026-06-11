import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  ExternalLink,
  FileStack,
  LibraryBig,
  Pencil,
  Plus,
  Send,
  Trash2,
  UsersRound,
} from "lucide-react";
import { useMemo, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { toast } from "sonner";

import {
  BentoCard,
  EmptyState,
  FieldLabel,
  InitialsAvatar,
  Modal,
  PrimaryButton,
  Spinner,
  inputClass,
} from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { initialsOf, nowISO, uuid } from "@/lib/format";
import { useDocumentLibrary, useProfiles } from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import { DOCUMENT_CATEGORIES, isAdminRole, type LibraryDocumentRow } from "@/lib/types";
import { cn } from "@/lib/utils";

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export default function SendingLane({ search }: { search: string }) {
  const { role } = useAuth();
  const admin = isAdminRole(role);
  const { data: profiles, isLoading } = useProfiles();
  const { data: library } = useDocumentLibrary();

  const [showUpload, setShowUpload] = useState<boolean>(false);
  const [editingDoc, setEditingDoc] = useState<LibraryDocumentRow | null>(null);

  const clients = useMemo(() => {
    let list = (profiles ?? []).filter((p) => p.role === "Client");
    const q = search.trim().toLowerCase();
    if (q) {
      list = list.filter(
        (p) =>
          `${p.first_name ?? ""} ${p.last_name ?? ""}`.toLowerCase().includes(q) ||
          (p.email ?? "").toLowerCase().includes(q),
      );
    }
    return list;
  }, [profiles, search]);

  const grouped = useMemo(() => {
    const docs = library ?? [];
    return DOCUMENT_CATEGORIES.map((category) => ({
      category,
      docs: docs.filter((d) => d.category === category),
    })).filter((g) => g.docs.length > 0);
  }, [library]);

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

      {/* Stock library — admins can manage, staff pick from it when composing */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-1.5 text-[11px] font-medium uppercase tracking-[0.1em] text-avia-black/35">
          <LibraryBig className="h-3.5 w-3.5" />
          Stock library
        </div>
        {admin && (
          <button
            type="button"
            onClick={() => setShowUpload(true)}
            className="flex items-center gap-1.5 rounded-full bg-avia-brown px-3 py-1.5 text-[11px] font-medium text-avia-white"
          >
            <Plus className="h-3 w-3" /> Add file
          </button>
        )}
      </div>

      {grouped.length === 0 ? (
        <BentoCard className="p-4 text-[12px] text-avia-black/55">
          {admin
            ? "No stock files yet. Upload brochures, standard contracts and templates so your team can send them in a click."
            : "No stock files yet. Admins can upload reusable files here."}
        </BentoCard>
      ) : (
        grouped.map(({ category, docs }) => (
          <div key={category} className="space-y-2">
            <div className="text-[10px] font-medium uppercase tracking-[0.12em] text-avia-black/35">
              {category}
            </div>
            {docs.map((doc) => (
              <BentoCard key={doc.id} className="flex items-center gap-3 p-3.5">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[9px] bg-avia-brown text-avia-white">
                  <FileStack className="h-4 w-4" />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13px] font-medium text-avia-black">{doc.name}</div>
                  <div className="truncate text-[11px] text-avia-black/55">
                    {doc.description || doc.file_size || doc.category}
                  </div>
                </div>
                {admin && (
                  <button
                    type="button"
                    onClick={() => setEditingDoc(doc)}
                    className="rounded-full p-2 text-avia-black/45 hover:bg-avia-black/5 hover:text-avia-black"
                    aria-label={`Edit ${doc.name}`}
                  >
                    <Pencil className="h-3.5 w-3.5" />
                  </button>
                )}
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
        ))
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
                    {`${client.first_name ?? ""} ${client.last_name ?? ""}`.trim() || client.email || "Client"}
                  </div>
                  <div className="truncate text-[11px] text-avia-black/55">{client.email}</div>
                </div>
                <Send className="h-4 w-4 text-avia-brown" />
              </BentoCard>
            </Link>
          ))}
        </div>
      )}

      {showUpload && <LibraryDocModal doc={null} onClose={() => setShowUpload(false)} />}
      {editingDoc && (
        <LibraryDocModal key={editingDoc.id} doc={editingDoc} onClose={() => setEditingDoc(null)} />
      )}
    </div>
  );
}

/** Upload a new stock file or edit/delete an existing one — mirrors the iOS stock library editor. */
function LibraryDocModal({
  doc,
  onClose,
}: {
  doc: LibraryDocumentRow | null;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const { userId } = useAuth();
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const [file, setFile] = useState<File | null>(null);
  const [name, setName] = useState<string>(doc?.name ?? "");
  const [category, setCategory] = useState<string>(doc?.category ?? "Marketing");
  const [description, setDescription] = useState<string>(doc?.description ?? "");
  const [confirmDelete, setConfirmDelete] = useState<boolean>(false);

  const save = useMutation({
    mutationFn: async (): Promise<void> => {
      let fileUrl = doc?.file_url ?? "";
      let fileSize = doc?.file_size ?? null;
      let fileType = doc?.file_type ?? null;

      if (file) {
        const safeName = file.name.replace(/\s+/g, "_");
        const path = `library/${uuid()}_${safeName}`;
        const { error: uploadError } = await supabase.storage.from("documents").upload(path, file, {
          cacheControl: "3600",
          contentType: file.type || "application/octet-stream",
          upsert: false,
        });
        if (uploadError) throw uploadError;
        const { data: urlData } = supabase.storage.from("documents").getPublicUrl(path);
        fileUrl = urlData.publicUrl;
        fileSize = formatBytes(file.size);
        fileType = file.type || null;
      }
      if (!fileUrl) throw new Error("No file selected");

      const row: LibraryDocumentRow = {
        id: doc?.id ?? uuid(),
        name: name.trim() || file?.name || "Untitled",
        category,
        description: description.trim() || null,
        file_url: fileUrl,
        file_size: fileSize,
        file_type: fileType,
        uploaded_by: doc?.uploaded_by ?? userId,
        sort_order: doc?.sort_order ?? 0,
        created_at: doc?.created_at ?? nowISO(),
      };
      const { error } = await supabase.from("document_library").upsert(row);
      if (error) throw error;
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["document_library"] });
      toast.success(doc ? "File updated" : "File added to the stock library");
      onClose();
    },
    onError: () => toast.error("Could not save the file. Please try again."),
  });

  const remove = useMutation({
    mutationFn: async (): Promise<void> => {
      if (!doc) return;
      const { error } = await supabase.from("document_library").delete().eq("id", doc.id);
      if (error) throw error;
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["document_library"] });
      toast.success("File removed from the stock library");
      onClose();
    },
    onError: () => toast.error("Could not delete the file."),
  });

  const canSave = doc ? name.trim().length > 0 : file !== null;

  return (
    <Modal open onClose={onClose} title={doc ? "Edit stock file" : "Add to stock library"}>
      {!doc && (
        <div className="space-y-1.5">
          <FieldLabel>File</FieldLabel>
          <input
            ref={fileInputRef}
            type="file"
            className="hidden"
            onChange={(e) => {
              const f = e.target.files?.[0] ?? null;
              setFile(f);
              if (f && !name.trim()) setName(f.name.replace(/\.[^.]+$/, ""));
            }}
          />
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            className={cn(
              "flex w-full items-center justify-center gap-2 rounded-[11px] border-2 border-dashed py-6 text-[13px] font-medium transition-colors",
              file
                ? "border-avia-brown/40 bg-avia-brown/5 text-avia-brown"
                : "border-avia-line text-avia-black/45 hover:border-avia-brown/40 hover:text-avia-brown",
            )}
          >
            <FileStack className="h-4 w-4" />
            {file ? `${file.name} · ${formatBytes(file.size)}` : "Choose a file to upload"}
          </button>
        </div>
      )}
      <div className="space-y-1.5">
        <FieldLabel>Name</FieldLabel>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          className={inputClass}
          placeholder="e.g. Standard Inclusions Brochure"
        />
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Category</FieldLabel>
        <select value={category} onChange={(e) => setCategory(e.target.value)} className={inputClass}>
          {DOCUMENT_CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Description (optional)</FieldLabel>
        <input
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          className={inputClass}
          placeholder="What is this file for?"
        />
      </div>

      <PrimaryButton onClick={() => save.mutate()} disabled={!canSave} loading={save.isPending}>
        {doc ? "Save Changes" : "Upload to Library"}
      </PrimaryButton>

      {doc && !confirmDelete && (
        <button
          type="button"
          onClick={() => setConfirmDelete(true)}
          className="flex w-full items-center justify-center gap-1.5 py-1 text-[12px] font-medium text-avia-black/45 hover:text-avia-black"
        >
          <Trash2 className="h-3.5 w-3.5" /> Remove from library
        </button>
      )}
      {doc && confirmDelete && (
        <div className="space-y-2 rounded-[11px] border border-avia-brown/25 bg-avia-brown/5 p-3.5">
          <div className="text-[13px] text-avia-black">
            &quot;{doc.name}&quot; will be removed from the stock library. Emails already sent are unaffected.
          </div>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => remove.mutate()}
              disabled={remove.isPending}
              className="rounded-full bg-avia-brown px-3.5 py-2 text-[12px] font-medium text-avia-white disabled:opacity-50"
            >
              Delete
            </button>
            <button
              type="button"
              onClick={() => setConfirmDelete(false)}
              className="rounded-full border border-avia-line px-3.5 py-2 text-[12px] font-medium text-avia-black/60"
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </Modal>
  );
}
