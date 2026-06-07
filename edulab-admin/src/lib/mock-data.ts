import {
  Activity,
  Award,
  Bell,
  CheckCircle2,
  FileArchive,
  FileText,
  GalleryVerticalEnd,
  ImageIcon,
  LineChart,
  MessageCircle,
  ShieldCheck,
  Trophy,
  UploadCloud,
  Users,
  Video,
} from "lucide-react";
import type {
  Certificate,
  Conversation,
  MediaItem,
  Permission,
  RoleRecord,
  SettingSection,
  StatCard,
  Student,
} from "@/lib/types";

export const students: Student[] = [
  {
    id: "stu_1",
    name: "Preview Student",
    email: "preview@student.com",
    phone: "+998900000001",
    initials: "P",
    modules: 0,
    progress: 0,
    averageScore: 0,
    status: "Faol",
    joinedAt: "15.05.2026",
  },
  {
    id: "stu_2",
    name: "Asadbek Davronov",
    email: "asadbek@gmail.com",
    phone: "+998336862001",
    initials: "A",
    modules: 0,
    progress: 0,
    averageScore: 0,
    status: "Faol",
    joinedAt: "15.05.2026",
  },
];

export const studentStats: StatCard[] = [
  {
    title: "Jami talabalar",
    value: "2",
    hint: "Barchasini ko'rish",
    tone: "blue",
    icon: Users,
  },
  {
    title: "Faol talabalar",
    value: "0",
    hint: "Yaxshi natijalar",
    tone: "green",
    icon: CheckCircle2,
  },
  {
    title: "O'rtacha ball",
    value: "0%",
    hint: "Umumiy o'rtacha",
    tone: "orange",
    icon: Award,
  },
  {
    title: "Umumiy progress",
    value: "0%",
    hint: "Progressni ko'rish",
    tone: "violet",
    icon: LineChart,
  },
];

export const analyticsStats: StatCard[] = [
  { title: "Jami talabalar", value: "2,482", hint: "+12.5%", tone: "blue", icon: Users },
  { title: "Faol foydalanuvchilar", value: "1,842", hint: "+8.3%", tone: "green", icon: Activity },
  { title: "Modullar soni", value: "24", hint: "+2", tone: "violet", icon: GalleryVerticalEnd },
  { title: "Mavzular soni", value: "156", hint: "+7", tone: "orange", icon: FileArchive },
  { title: "Testlar soni", value: "320", hint: "+18", tone: "red", icon: FileText },
  { title: "Sertifikatlar", value: "1,203", hint: "+15.7%", tone: "blue", icon: Trophy },
];

export const conversations: Conversation[] = [
  {
    id: "conv_bot",
    name: "EduLab Bot",
    label: "Bot",
    lastMessage: "Yangi dars: Laboratoriya ishi N3...",
    time: "18:21",
    unread: 2,
    online: true,
    source: "telegram",
    messages: [
      {
        id: "m1",
        author: "bot",
        body: "Assalomu alaykum! EduLab Academy botiga xush kelibsiz. Sizga qanday yordam bera olaman?",
        time: "18:21",
        kind: "text",
      },
      {
        id: "m2",
        author: "admin",
        body: "Laboratoriya ishi haqida ma'lumot berasizmi?",
        time: "18:22",
        kind: "text",
        read: true,
      },
      {
        id: "m3",
        author: "bot",
        body: "Albatta! Quyida laboratoriya ishi N3 haqida batafsil ma'lumot:",
        time: "18:23",
        kind: "pdf",
        fileName: "Laboratoriya ishi N3.pdf",
        fileSize: "2.4 MB",
      },
      {
        id: "m4",
        author: "bot",
        body: "Shuningdek, namunaviy rasm:",
        time: "18:23",
        kind: "image",
        previewUrl:
          "https://images.unsplash.com/photo-1581093458791-9f3c3250a45f?auto=format&fit=crop&w=900&q=80",
      },
      {
        id: "m5",
        author: "admin",
        body: "Ovozli javob yuborildi",
        time: "18:24",
        kind: "voice",
        duration: "0:28",
        read: true,
      },
      {
        id: "m6",
        author: "admin",
        body: "Hisobot.docx",
        time: "18:25",
        kind: "document",
        fileName: "Hisobot.docx",
        fileSize: "1.6 MB",
        read: true,
      },
    ],
  },
  {
    id: "conv_asadbek",
    name: "Asadbek Davronov",
    lastMessage: "Rasm yubordi",
    time: "17:45",
    unread: 1,
    online: true,
    source: "student_app",
    messages: [],
  },
  {
    id: "conv_sardor",
    name: "Sardor Karimov",
    lastMessage: "Ovozli xabar",
    time: "17:20",
    unread: 0,
    online: false,
    source: "student_app",
    messages: [],
  },
  {
    id: "conv_malika",
    name: "Malika To'xtayeva",
    lastMessage: "Dumaloq video",
    time: "15:12",
    unread: 1,
    online: false,
    source: "student_app",
    messages: [],
  },
];

export const certificates: Certificate[] = [
  {
    id: "CERT-2026-000128",
    student: "Asadbek Davronov",
    email: "asadbek.davronov@gmail.com",
    module: "Laboratoriya ishlari",
    date: "14.05.2026 - 18:21",
    status: "Berilgan",
    qrCode: "/certificates/verify/CERT-2026-000128",
    certificateUrl: null,
  },
  {
    id: "CERT-2026-000129",
    student: "Malika To'xtayeva",
    email: "malika.toxtayeva@gmail.com",
    module: "Biokimyo asoslari",
    date: "14.05.2026 - 16:02",
    status: "Berilgan",
    qrCode: "/certificates/verify/CERT-2026-000129",
    certificateUrl: null,
  },
  {
    id: "CERT-2026-000130",
    student: "Dilshodbek Karimov",
    email: "dilshod.karimov@gmail.com",
    module: "Genetika va molekulyar biol.",
    date: "14.05.2026 - 11:30",
    status: "Kutilmoqda",
    qrCode: "/certificates/verify/CERT-2026-000130",
    certificateUrl: null,
  },
];

export const mediaItems: MediaItem[] = [
  {
    id: "media_1",
    name: "strip test - Video dars.mp4",
    publicId: "labproof/videos/strip-test",
    secureUrl: "https://res.cloudinary.com/demo/video/upload/sample.mp4",
    resourceType: "video",
    format: "mp4",
    kind: "video",
    bytes: 245_600_000,
    duration: 762,
    width: 1920,
    height: 1080,
    createdAt: "15.05.2026 18:21",
    uploadedBy: "Admin",
    usedIn: ["Biokimyo asoslari", "Laboratoriya ishlari", "Biokimyo amaliyot"],
    previewUrl:
      "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80",
  },
  {
    id: "media_2",
    name: "laboratoriya-rasm.jpg",
    publicId: "labproof/images/laboratoriya-rasm",
    secureUrl:
      "https://images.unsplash.com/photo-1581093588401-fbb62a02f120?auto=format&fit=crop&w=900&q=80",
    resourceType: "image",
    format: "jpg",
    kind: "image",
    bytes: 1_200_000,
    width: 1920,
    height: 1080,
    createdAt: "15.05.2026 17:45",
    uploadedBy: "Admin",
    usedIn: ["Laboratoriya ishlari", "Tajriba jarayoni"],
  },
  {
    id: "media_3",
    name: "biokimyo-asoslari.pdf",
    publicId: "labproof/docs/biokimyo-asoslari",
    secureUrl: "https://res.cloudinary.com/demo/image/upload/sample.pdf",
    resourceType: "raw",
    format: "pdf",
    kind: "pdf",
    bytes: 2_400_000,
    createdAt: "15.05.2026 16:30",
    uploadedBy: "Admin",
    usedIn: ["5 modulda"],
  },
  {
    id: "media_4",
    name: "tajriba-jarayoni.mp3",
    publicId: "labproof/audio/tajriba-jarayoni",
    secureUrl: "https://res.cloudinary.com/demo/video/upload/dog.mp3",
    resourceType: "video",
    format: "mp3",
    kind: "voice",
    bytes: 98_300_000,
    duration: 762,
    createdAt: "15.05.2026 14:05",
    uploadedBy: "Admin",
    usedIn: ["1 modulda"],
  },
];

export const permissions: Permission[] = [
  { id: "students.read", label: "Talabalarni ko'rish", group: "Talabalar" },
  { id: "students.write", label: "Talabalarni tahrirlash", group: "Talabalar" },
  { id: "analytics.read", label: "Tahlillarni ko'rish", group: "Tahlillar" },
  { id: "notifications.send", label: "Xabar yuborish", group: "Xabarnomalar" },
  { id: "media.manage", label: "Median boshqarish", group: "Media" },
  { id: "certificates.manage", label: "Sertifikat yaratish", group: "Sertifikatlar" },
  { id: "settings.manage", label: "Sozlamalarni boshqarish", group: "Sozlamalar" },
  { id: "roles.manage", label: "Rollarni boshqarish", group: "Rollar" },
];

export const roles: RoleRecord[] = [
  {
    id: "role_admin",
    name: "Admin",
    description: "To'liq boshqaruv va kontent huquqlari",
    color: "#2563EB",
    users: 1,
    permissions: permissions.map((permission) => permission.id),
    moduleAccess: ["all"],
  },
  {
    id: "role_teacher",
    name: "Teacher",
    description: "Darslar, testlar va xabarlar bilan ishlaydi",
    color: "#10B981",
    users: 0,
    permissions: ["students.read", "analytics.read", "notifications.send"],
    moduleAccess: ["learning"],
  },
  {
    id: "role_student",
    name: "Student",
    description: "Student ilova va o'z natijalarini ko'radi",
    color: "#F59E0B",
    users: 2,
    permissions: [],
    moduleAccess: ["student"],
  },
];

export const settingSections: Array<{
  id: SettingSection;
  title: string;
  subtitle: string;
  icon: typeof Bell;
}> = [
  { id: "general", title: "Umumiy sozlamalar", subtitle: "Asosiy tizim parametrlari", icon: ShieldCheck },
  { id: "system", title: "Tizim ma'lumotlari", subtitle: "Versiya va server holati", icon: Activity },
  { id: "backup", title: "Zaxira nusxa", subtitle: "Backup va tiklash", icon: UploadCloud },
  { id: "security", title: "Xavfsizlik", subtitle: "Xavfsizlik va sessiyalar", icon: ShieldCheck },
  { id: "payments", title: "To'lov sozlamalari", subtitle: "To'lov tizimlari va valyuta", icon: Award },
  { id: "integrations", title: "Integratsiyalar", subtitle: "Uchinchi tomon servislar", icon: GalleryVerticalEnd },
];

export const chartSeries = [
  { name: "1 May", active: 350, newUsers: 120, revenue: 22 },
  { name: "6 May", active: 620, newUsers: 220, revenue: 46 },
  { name: "11 May", active: 740, newUsers: 310, revenue: 72 },
  { name: "16 May", active: 560, newUsers: 230, revenue: 80 },
  { name: "21 May", active: 780, newUsers: 370, revenue: 69 },
  { name: "26 May", active: 870, newUsers: 390, revenue: 101 },
  { name: "31 May", active: 710, newUsers: 260, revenue: 132 },
];

export const mediaStats: StatCard[] = [
  { title: "Rasmlar", value: "864", hint: "Jami fayllar ichida 24%", tone: "blue", icon: ImageIcon },
  { title: "Videolar", value: "1,256", hint: "Jami fayllar ichida 35%", tone: "violet", icon: Video },
  { title: "PDF fayllar", value: "312", hint: "Jami fayllar ichida 18%", tone: "red", icon: FileText },
  { title: "Boshqalar", value: "1,116", hint: "Jami fayllar ichida 23%", tone: "blue", icon: FileArchive },
];
