import type { LucideIcon } from "lucide-react";

export type AdminRole = "admin" | "teacher" | "student";
export type MediaKind =
  | "image"
  | "video"
  | "round_video"
  | "voice"
  | "pdf"
  | "document"
  | "text"
  | "file";

export type Student = {
  id: string;
  name: string;
  email: string;
  phone: string;
  initials: string;
  modules: number;
  progress: number;
  averageScore: number;
  status: "Faol" | "Nofaol" | "O'rtacha" | "Qoniqarsiz";
  joinedAt: string;
};

export type StatCard = {
  title: string;
  value: string;
  hint: string;
  tone: "blue" | "green" | "orange" | "red" | "violet";
  icon: LucideIcon;
};

export type ChatMessage = {
  id: string;
  author: "admin" | "student" | "bot";
  body: string;
  time: string;
  kind: MediaKind;
  fileName?: string;
  fileSize?: string;
  previewUrl?: string;
  duration?: string;
  read?: boolean;
  createdAt?: string;
};

export type Conversation = {
  id: string;
  name: string;
  label?: string;
  lastMessage: string;
  time: string;
  unread: number;
  online: boolean;
  source: "telegram" | "student_app";
  avatar?: string;
  messages: ChatMessage[];
};

export type Certificate = {
  id: string;
  student: string;
  email: string;
  module: string;
  date: string;
  status: "Berilgan" | "Kutilmoqda";
  qrCode: string;
  certificateUrl: string | null;
};

export type MediaItem = {
  id: string;
  name: string;
  publicId: string;
  secureUrl: string;
  resourceType: string;
  format: string;
  kind: MediaKind;
  bytes: number;
  duration?: number;
  width?: number;
  height?: number;
  createdAt: string;
  uploadedBy: string;
  usedIn: string[];
  previewUrl?: string;
};

export type Permission = {
  id: string;
  label: string;
  group: string;
};

export type RoleRecord = {
  id: string;
  name: string;
  description: string;
  color: string;
  users: number;
  permissions: string[];
  moduleAccess: string[];
};

export type SettingSection =
  | "general"
  | "system"
  | "localization"
  | "backup"
  | "security"
  | "email"
  | "payments"
  | "integrations"
  | "notifications"
  | "files";
