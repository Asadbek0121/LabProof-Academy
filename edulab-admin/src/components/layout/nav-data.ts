import {
  Award,
  Bell,
  BookOpen,
  FileText,
  Folder,
  GalleryVerticalEnd,
  LayoutGrid,
  LineChart,
  PlayCircle,
  Settings,
  ShieldCheck,
  Trophy,
  Users,
  LayoutDashboard,
  Tags,
  CheckSquare,
  MessageSquareCode,
  Bot,
  History,
} from "lucide-react";

export const navigation = [
  {
    label: "DASHBOARD",
    items: [
      { title: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
    ],
  },
  {
    label: "LEARNING",
    items: [
      { title: "Kategoriyalar", href: "/categories", icon: Tags },
      { title: "Modullar", href: "/modules", icon: LayoutGrid },
      { title: "Mavzular", href: "/topics", icon: Folder },
      { title: "PDF/Text", href: "/lessons", icon: FileText },
      { title: "Videolar", href: "/videos", icon: PlayCircle },
      { title: "Testlar", href: "/tests", icon: BookOpen },
      { title: "Yakuniy imtihon", href: "/exams", icon: Trophy },
    ],
  },
  {
    label: "MANAGEMENT",
    items: [
      { title: "Talabalar", href: "/students", icon: Users },
      { title: "Progress monitoring", href: "/progress-monitoring", icon: CheckSquare },
      { title: "Tahlillar", href: "/analytics", icon: LineChart },
      { title: "Yordam so'rovlari", href: "/support-requests", icon: MessageSquareCode },
      { title: "Xabarnomalar", href: "/notifications", icon: Bell },
      { title: "Sertifikatlar", href: "/certificates", icon: Award },
      { title: "Media kutubxona", href: "/media-library", icon: GalleryVerticalEnd },
      { title: "Telegram bot", href: "/bot-management", icon: Bot },
    ],
  },
  {
    label: "SYSTEM",
    items: [
      { title: "Administratorlar", href: "/administrators", icon: ShieldCheck },
      { title: "Sozlamalar", href: "/settings", icon: Settings },
      { title: "Rollar", href: "/roles", icon: ShieldCheck },
      { title: "Tizim loglari", href: "/activity-logs", icon: History },
    ],
  },
];

