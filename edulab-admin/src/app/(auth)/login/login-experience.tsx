"use client";

import {
  ArrowRight,
  Eye,
  EyeOff,
  GraduationCap,
  Loader2,
  LockKeyhole,
  UserRound,
} from "lucide-react";
import { useActionState, useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import { loginAdmin } from "./actions";

type PointerState = {
  x: number;
  y: number;
  active: boolean;
};

type MascotName = "violet" | "ink" | "coral" | "sun";

type CharacterState = {
  ref: React.RefObject<HTMLDivElement | null>;
  width: number;
  height: number;
  left: number;
  color: string;
  radius: string;
  zIndex: number;
  eyeLeft: number;
  eyeTop: number;
  eyeGap: number;
  eyeSize: number;
  pupilSize: number;
  whiteEyes: boolean;
};

const characters: Record<MascotName, Omit<CharacterState, "ref">> = {
  violet: {
    width: 176,
    height: 372,
    left: 82,
    color: "#635bff",
    radius: "8px 8px 0 0",
    zIndex: 1,
    eyeLeft: 48,
    eyeTop: 40,
    eyeGap: 30,
    eyeSize: 18,
    pupilSize: 7,
    whiteEyes: true,
  },
  ink: {
    width: 118,
    height: 294,
    left: 246,
    color: "#1f2937",
    radius: "8px 8px 0 0",
    zIndex: 2,
    eyeLeft: 26,
    eyeTop: 34,
    eyeGap: 24,
    eyeSize: 16,
    pupilSize: 6,
    whiteEyes: true,
  },
  coral: {
    width: 228,
    height: 184,
    left: 16,
    color: "#ff9566",
    radius: "114px 114px 0 0",
    zIndex: 3,
    eyeLeft: 76,
    eyeTop: 82,
    eyeGap: 32,
    eyeSize: 12,
    pupilSize: 12,
    whiteEyes: false,
  },
  sun: {
    width: 138,
    height: 218,
    left: 316,
    color: "#f2d85f",
    radius: "69px 69px 0 0",
    zIndex: 4,
    eyeLeft: 42,
    eyeTop: 38,
    eyeGap: 24,
    eyeSize: 12,
    pupilSize: 12,
    whiteEyes: false,
  },
};

function useReducedMotion() {
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReduced(media.matches);
    const onChange = () => setReduced(media.matches);
    media.addEventListener("change", onChange);
    return () => media.removeEventListener("change", onChange);
  }, []);

  return reduced;
}

function usePointerTracking(enabled: boolean) {
  const [pointer, setPointer] = useState<PointerState>({ x: 0, y: 0, active: false });
  const nextPointer = useRef<PointerState>(pointer);
  const frameRef = useRef<number | null>(null);

  useEffect(() => {
    if (!enabled) return undefined;

    const flush = () => {
      frameRef.current = null;
      setPointer(nextPointer.current);
    };

    const onMove = (event: PointerEvent) => {
      nextPointer.current = { x: event.clientX, y: event.clientY, active: true };
      if (frameRef.current === null) {
        frameRef.current = window.requestAnimationFrame(flush);
      }
    };

    window.addEventListener("pointermove", onMove, { passive: true });
    return () => {
      window.removeEventListener("pointermove", onMove);
      if (frameRef.current !== null) window.cancelAnimationFrame(frameRef.current);
    };
  }, [enabled]);

  return pointer;
}

function useBlink(enabled: boolean, minDelay = 3200, maxDelay = 6800) {
  const [blinking, setBlinking] = useState(false);

  useEffect(() => {
    if (!enabled) return undefined;

    let blinkTimer: number | undefined;
    let resetTimer: number | undefined;

    const schedule = () => {
      blinkTimer = window.setTimeout(() => {
        setBlinking(true);
        resetTimer = window.setTimeout(() => {
          setBlinking(false);
          schedule();
        }, 135);
      }, minDelay + Math.random() * (maxDelay - minDelay));
    };

    schedule();
    return () => {
      window.clearTimeout(blinkTimer);
      window.clearTimeout(resetTimer);
    };
  }, [enabled, maxDelay, minDelay]);

  return blinking;
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function getMotion(
  ref: React.RefObject<HTMLDivElement | null>,
  pointer: PointerState,
  reducedMotion: boolean,
) {
  if (reducedMotion || !pointer.active || !ref.current) {
    return { faceX: 0, faceY: 0, skew: 0 };
  }

  const rect = ref.current.getBoundingClientRect();
  const centerX = rect.left + rect.width / 2;
  const centerY = rect.top + rect.height / 3;
  const deltaX = pointer.x - centerX;
  const deltaY = pointer.y - centerY;

  return {
    faceX: clamp(deltaX / 22, -12, 12),
    faceY: clamp(deltaY / 34, -8, 8),
    skew: clamp(-deltaX / 140, -4.5, 4.5),
  };
}

function getPupilOffset(
  ref: React.RefObject<HTMLDivElement | null>,
  pointer: PointerState,
  maxDistance: number,
  forced?: { x: number; y: number },
) {
  if (forced) return forced;
  if (!pointer.active || !ref.current) return { x: 0, y: 0 };

  const rect = ref.current.getBoundingClientRect();
  const centerX = rect.left + rect.width / 2;
  const centerY = rect.top + rect.height / 2;
  const deltaX = pointer.x - centerX;
  const deltaY = pointer.y - centerY;
  const distance = Math.min(Math.hypot(deltaX, deltaY), maxDistance);
  const angle = Math.atan2(deltaY, deltaX);

  return { x: Math.cos(angle) * distance, y: Math.sin(angle) * distance };
}

function EyePair({
  config,
  pointer,
  blinking,
  forced,
}: {
  config: CharacterState;
  pointer: PointerState;
  blinking: boolean;
  forced?: { x: number; y: number };
}) {
  const offset = getPupilOffset(config.ref, pointer, config.whiteEyes ? 5 : 4, forced);

  return (
    <div
      className="absolute flex transition-transform duration-200 ease-out"
      style={{
        gap: config.eyeGap,
        left: config.eyeLeft,
        top: config.eyeTop,
      }}
    >
      {[0, 1].map((index) => (
        <span
          key={index}
          className={cn(
            "flex items-center justify-center overflow-hidden rounded-full",
            config.whiteEyes ? "bg-white" : "bg-transparent",
          )}
          style={{
            width: config.eyeSize,
            height: blinking && config.whiteEyes ? 2 : config.eyeSize,
            transition: "height 135ms ease",
          }}
        >
          {!blinking && (
            <span
              className="block rounded-full bg-slate-950 transition-transform duration-100 ease-out"
              style={{
                width: config.pupilSize,
                height: config.pupilSize,
                transform: `translate(${offset.x}px, ${offset.y}px)`,
              }}
            />
          )}
        </span>
      ))}
    </div>
  );
}

function MascotStage({
  pointer,
  passwordActive,
  passwordVisible,
  reducedMotion,
}: {
  pointer: PointerState;
  passwordActive: boolean;
  passwordVisible: boolean;
  reducedMotion: boolean;
}) {
  const violetRef = useRef<HTMLDivElement>(null);
  const inkRef = useRef<HTMLDivElement>(null);
  const coralRef = useRef<HTMLDivElement>(null);
  const sunRef = useRef<HTMLDivElement>(null);
  const violetBlink = useBlink(!reducedMotion);
  const inkBlink = useBlink(!reducedMotion, 2600, 6200);

  const refs: Record<MascotName, React.RefObject<HTMLDivElement | null>> = {
    violet: violetRef,
    ink: inkRef,
    coral: coralRef,
    sun: sunRef,
  };

  const passwordMode = passwordActive || passwordVisible;

  return (
    <div className="relative h-[440px] w-[540px] max-w-full">
      <div className="absolute inset-x-8 bottom-0 h-px bg-white/15" />
      {(Object.keys(characters) as MascotName[]).map((name) => {
        const base = characters[name];
        const ref = refs[name];
        const motion = getMotion(ref, pointer, reducedMotion);
        const config: CharacterState = { ...base, ref };
        const isViolet = name === "violet";
        const isInk = name === "ink";
        const forcedLook = passwordVisible
          ? { x: isViolet ? -4 : -3, y: isViolet ? -5 : -4 }
          : passwordActive
            ? { x: isViolet ? 4 : isInk ? -2 : 0, y: isViolet ? 4 : -3 }
            : undefined;

        return (
          <div
            key={name}
            ref={ref}
            className="absolute bottom-0 shadow-[0_24px_70px_rgba(15,23,42,0.28)] transition-all duration-500 ease-out"
            style={{
              left: base.left,
              width: base.width,
              height: passwordMode && isViolet ? base.height + 24 : base.height,
              borderRadius: base.radius,
              backgroundColor: base.color,
              zIndex: base.zIndex,
              transform: reducedMotion
                ? "none"
                : `skewX(${passwordMode && isViolet ? motion.skew - 7 : motion.skew}deg) translateX(${passwordMode && isViolet ? 22 : 0}px)`,
              transformOrigin: "bottom center",
            }}
          >
            <div
              className="absolute transition-transform duration-300 ease-out"
              style={{
                transform: `translate(${passwordMode ? 0 : motion.faceX}px, ${passwordMode ? 0 : motion.faceY}px)`,
              }}
            >
              <EyePair
                config={config}
                pointer={pointer}
                blinking={name === "violet" ? violetBlink : name === "ink" ? inkBlink : false}
                forced={forcedLook}
              />
              {name === "sun" && (
                <span className="absolute left-9 top-[88px] block h-1 w-20 rounded-full bg-slate-950/90" />
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}

export function LoginExperience({ nextPath }: { nextPath: string }) {
  const reducedMotion = useReducedMotion();
  const pointer = usePointerTracking(!reducedMotion);
  const [loginState, formAction, isPending] = useActionState(loginAdmin, {
    ok: false,
    error: "",
  });
  const [login, setLogin] = useState("");
  const [rememberLogin, setRememberLogin] = useState(false);
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [passwordFocused, setPasswordFocused] = useState(false);

  useEffect(() => {
    const remembered = window.localStorage.getItem("labproof-admin-login");
    if (remembered) {
      setLogin(remembered);
      setRememberLogin(true);
    }
  }, []);

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    if (rememberLogin) {
      window.localStorage.setItem("labproof-admin-login", login.trim());
    } else {
      window.localStorage.removeItem("labproof-admin-login");
    }
  };

  return (
    <main className="min-h-screen bg-[#f7f9fc] text-slate-950">
      <div className="grid min-h-screen lg:grid-cols-[1.08fr_0.92fr]">
        <section className="relative hidden overflow-hidden bg-[#101b3d] px-10 py-9 text-white lg:flex lg:flex-col">
          <div className="absolute inset-0 bg-[linear-gradient(rgba(255,255,255,0.055)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.045)_1px,transparent_1px)] bg-[size:32px_32px]" />
          <div className="relative z-10 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="flex size-10 items-center justify-center rounded-lg bg-white text-[#172554]">
                <GraduationCap className="size-5" />
              </span>
              <div>
                <p className="text-sm font-bold tracking-wide">LabProof Academy</p>
                <p className="text-xs font-medium text-white/58">Admin boshqaruv paneli</p>
              </div>
            </div>
          </div>

          <div className="relative z-10 flex flex-1 flex-col justify-center">
            <div className="max-w-xl">
              <h1 className="text-5xl font-black leading-[1.02] tracking-tight">
                Ta'lim jarayonini ishonchli boshqaring.
              </h1>
              <p className="mt-5 max-w-lg text-base leading-7 text-white/68">
                Admin va teacher rollari uchun himoyalangan kirish, real vaqtli LMS nazorati va
                laboratoriya kontenti ustidan to'liq boshqaruv.
              </p>
            </div>
            <div className="mt-8">
              <MascotStage
                pointer={pointer}
                passwordActive={passwordFocused || password.length > 0}
                passwordVisible={showPassword}
                reducedMotion={reducedMotion}
              />
            </div>
          </div>
        </section>

        <section className="flex min-h-screen items-center justify-center px-5 py-10 sm:px-8">
          <div className="w-full max-w-[430px]">
            <div className="mb-9 flex items-center gap-3 lg:hidden">
              <span className="flex size-10 items-center justify-center rounded-lg bg-blue-600 text-white">
                <GraduationCap className="size-5" />
              </span>
              <div>
                <p className="text-sm font-extrabold">LabProof Academy</p>
                <p className="text-xs font-semibold text-slate-500">Admin panel</p>
              </div>
            </div>

            <div className="mb-8">
              <h2 className="text-3xl font-black tracking-tight text-slate-950">
                Admin panelga kirish
              </h2>
              <p className="mt-2 text-sm leading-6 text-slate-500">
                Hozircha sodda login va parol bilan kiring. Keyin real Supabase admin hisoblari
                ham ishlashda davom etadi.
              </p>
            </div>

            <form action={formAction} onSubmit={handleSubmit} className="space-y-5">
              <input type="hidden" name="next" value={nextPath} />
              <div className="space-y-2">
                <label htmlFor="login" className="text-sm font-bold text-slate-800">
                  Login
                </label>
                <div className="relative">
                  <UserRound className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
                  <Input
                    id="login"
                    name="login"
                    type="text"
                    autoComplete="username"
                    placeholder="admin"
                    value={login}
                    disabled={isPending}
                    onChange={(event) => setLogin(event.target.value)}
                    className="h-12 rounded-lg border-slate-200 bg-white pl-10 pr-3 font-semibold"
                    required
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label htmlFor="password" className="text-sm font-bold text-slate-800">
                  Parol
                </label>
                <div className="relative">
                  <LockKeyhole className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
                  <Input
                    id="password"
                    name="password"
                    type={showPassword ? "text" : "password"}
                    autoComplete="current-password"
                    placeholder="Parolingiz"
                    value={password}
                    disabled={isPending}
                    onFocus={() => setPasswordFocused(true)}
                    onBlur={() => setPasswordFocused(false)}
                    onChange={(event) => setPassword(event.target.value)}
                    className="h-12 rounded-lg border-slate-200 bg-white pl-10 pr-12 font-semibold"
                    required
                  />
                  <button
                    type="button"
                    aria-label={showPassword ? "Parolni yashirish" : "Parolni ko'rsatish"}
                    onClick={() => setShowPassword((value) => !value)}
                    className="absolute right-2 top-1/2 flex size-8 -translate-y-1/2 items-center justify-center rounded-md text-slate-500 transition hover:bg-slate-100 hover:text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-500/25"
                  >
                    {showPassword ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
                  </button>
                </div>
              </div>

              <div className="flex items-center justify-between gap-4">
                <label className="flex cursor-pointer items-center gap-2 text-sm font-semibold text-slate-600">
                  <input
                    type="checkbox"
                    checked={rememberLogin}
                    onChange={(event) => setRememberLogin(event.target.checked)}
                    className="size-4 rounded border-slate-300 text-blue-600 focus:ring-blue-500"
                  />
                  Loginni eslab qolish
                </label>
                <span className="text-sm font-bold text-slate-400">Standart: admin / 1234</span>
              </div>

              {loginState.error && (
                <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">
                  {loginState.error}
                </div>
              )}

              <Button
                type="submit"
                disabled={isPending}
                className="h-12 w-full rounded-lg text-base"
              >
                {isPending ? (
                  <>
                    <Loader2 className="size-4 animate-spin" />
                    Tekshirilmoqda...
                  </>
                ) : (
                  <>
                    Kirish
                    <ArrowRight className="size-4" />
                  </>
                )}
              </Button>
            </form>

            <p className="mt-6 text-center text-xs font-semibold leading-5 text-slate-400">
              Bu vaqtinchalik sodda kirish. Real admin email/parol hisoblari ham ishlaydi.
            </p>
          </div>
        </section>
      </div>
    </main>
  );
}
