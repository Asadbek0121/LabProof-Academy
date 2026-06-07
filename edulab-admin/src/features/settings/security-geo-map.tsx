"use client";

import { Minus, Plus, RefreshCcw } from "lucide-react";
import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { cn } from "@/lib/utils";

type Theme = "light" | "dark";

export type SecurityMapPoint = {
  id: string;
  label: string;
  location: string;
  ip: string;
  success: boolean;
  attempts: number;
  createdAt: string;
  longitude: number;
  latitude: number;
};

type MapLibreModule = typeof import("maplibre-gl");
type MapInstance = import("maplibre-gl").Map;
type MarkerInstance = import("maplibre-gl").Marker;

const defaultStyles = {
  dark: "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json",
  light: "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json",
};

function getDocumentTheme(): Theme | null {
  if (typeof document === "undefined") return null;
  if (document.documentElement.classList.contains("dark")) return "dark";
  if (document.documentElement.classList.contains("light")) return "light";
  return null;
}

function getSystemTheme(): Theme {
  if (typeof window === "undefined") return "light";
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function useResolvedTheme(): Theme {
  const [theme, setTheme] = useState<Theme>(() => getDocumentTheme() ?? getSystemTheme());

  useEffect(() => {
    const observer = new MutationObserver(() => {
      setTheme(getDocumentTheme() ?? getSystemTheme());
    });
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    });

    const query = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => setTheme(getDocumentTheme() ?? getSystemTheme());
    query.addEventListener("change", onChange);

    return () => {
      observer.disconnect();
      query.removeEventListener("change", onChange);
    };
  }, []);

  return theme;
}

function formatDate(value: string) {
  return new Date(value).toLocaleString("uz-UZ", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

function markerColor(point: SecurityMapPoint) {
  if (!point.success) return "#ef4444";
  if (point.attempts > 1) return "#f59e0b";
  return "#22c55e";
}

function markerLabel(point: SecurityMapPoint) {
  if (!point.success) return "Xavfli";
  if (point.attempts > 1) return "Shubhali";
  return "Muvaffaqiyatli";
}

function DefaultLoader() {
  return (
    <div className="absolute inset-0 z-10 flex items-center justify-center bg-white/60 backdrop-blur-sm dark:bg-slate-950/60">
      <div className="flex gap-1">
        <span className="size-1.5 animate-pulse rounded-full bg-slate-500/70" />
        <span className="size-1.5 animate-pulse rounded-full bg-slate-500/70 [animation-delay:150ms]" />
        <span className="size-1.5 animate-pulse rounded-full bg-slate-500/70 [animation-delay:300ms]" />
      </div>
    </div>
  );
}

function ControlButton({
  label,
  children,
  onClick,
}: {
  label: string;
  children: ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className="grid size-9 place-items-center border-b border-slate-200 bg-white text-slate-700 transition last:border-b-0 hover:bg-slate-50 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100"
    >
      {children}
    </button>
  );
}

function createMarkerElement(point: SecurityMapPoint) {
  const color = markerColor(point);
  const element = document.createElement("button");
  element.type = "button";
  element.style.setProperty("--security-marker-color", color);
  element.className = "security-map-marker";
  element.setAttribute("aria-label", `${point.location}: ${markerLabel(point)}`);
  element.innerHTML = `<span></span>`;
  return element;
}

function popupHtml(point: SecurityMapPoint) {
  const color = markerColor(point);
  return `
    <div class="min-w-[210px] rounded-xl bg-white p-3 text-slate-900 shadow-xl dark:bg-slate-900 dark:text-slate-100">
      <div class="flex items-center gap-2">
        <span style="background:${color}" class="block h-2.5 w-2.5 rounded-full"></span>
        <strong class="text-sm">${markerLabel(point)}</strong>
      </div>
      <p class="mt-2 text-xs font-bold text-slate-500">${point.location}</p>
      <p class="mt-1 text-xs text-slate-500">IP: ${point.ip}</p>
      <p class="mt-1 text-xs text-slate-500">Urinishlar: ${point.attempts}</p>
      <p class="mt-2 text-[11px] font-bold text-slate-400">${formatDate(point.createdAt)}</p>
    </div>
  `;
}

export function SecurityGeoMap({ points }: { points: SecurityMapPoint[] }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MapInstance | null>(null);
  const maplibreRef = useRef<MapLibreModule | null>(null);
  const markersRef = useRef<MarkerInstance[]>([]);
  const [isLoaded, setIsLoaded] = useState(false);
  const [error, setError] = useState("");
  const theme = useResolvedTheme();

  const center = useMemo<[number, number]>(() => {
    if (points.length === 0) return [64.5853, 41.3775];
    const longitude = points.reduce((sum, point) => sum + point.longitude, 0) / points.length;
    const latitude = points.reduce((sum, point) => sum + point.latitude, 0) / points.length;
    return [longitude, latitude];
  }, [points]);

  useEffect(() => {
    let cancelled = false;

    async function initMap() {
      if (!containerRef.current || mapRef.current) return;
      try {
        const maplibre = await import("maplibre-gl");
        if (cancelled || !containerRef.current) return;
        maplibreRef.current = maplibre;

        const map = new maplibre.Map({
          container: containerRef.current,
          style: theme === "dark" ? defaultStyles.dark : defaultStyles.light,
          center,
          zoom: points.length > 1 ? 4.4 : 5.1,
          renderWorldCopies: false,
          attributionControl: { compact: true },
        });

        map.on("load", () => {
          if (cancelled) return;
          setIsLoaded(true);
        });
        mapRef.current = map;
      } catch (mapError) {
        setError(mapError instanceof Error ? mapError.message : "Xarita yuklanmadi");
      }
    }

    initMap();

    return () => {
      cancelled = true;
      markersRef.current.forEach((marker) => marker.remove());
      markersRef.current = [];
      mapRef.current?.remove();
      mapRef.current = null;
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;
    map.setStyle(theme === "dark" ? defaultStyles.dark : defaultStyles.light, { diff: true });
  }, [theme]);

  useEffect(() => {
    const map = mapRef.current;
    const maplibre = maplibreRef.current;
    if (!map || !maplibre || !isLoaded) return;

    markersRef.current.forEach((marker) => marker.remove());
    markersRef.current = [];

    points.forEach((point) => {
      const marker = new maplibre.Marker({
        element: createMarkerElement(point),
        anchor: "center",
      })
        .setLngLat([point.longitude, point.latitude])
        .setPopup(
          new maplibre.Popup({ closeButton: false, offset: 18 })
            .setHTML(popupHtml(point)),
        )
        .addTo(map);

      markersRef.current.push(marker);
    });

    if (points.length > 1) {
      const bounds = new maplibre.LngLatBounds();
      points.forEach((point) => bounds.extend([point.longitude, point.latitude]));
      map.fitBounds(bounds, { padding: 54, maxZoom: 6.2, duration: 500 });
    } else if (points[0]) {
      map.easeTo({ center: [points[0].longitude, points[0].latitude], zoom: 6, duration: 500 });
    }
  }, [isLoaded, points]);

  const zoomIn = () => mapRef.current?.zoomTo(mapRef.current.getZoom() + 1, { duration: 250 });
  const zoomOut = () => mapRef.current?.zoomTo(mapRef.current.getZoom() - 1, { duration: 250 });
  const reset = () => mapRef.current?.flyTo({ center, zoom: points.length > 1 ? 4.4 : 5.1, duration: 700 });

  return (
    <div className="relative h-56 overflow-hidden rounded-xl border border-slate-100 bg-slate-50 dark:border-slate-800 dark:bg-slate-950">
      <div ref={containerRef} className="h-full w-full" />
      {!isLoaded && !error ? <DefaultLoader /> : null}
      {error ? (
        <div className="absolute inset-0 z-10 flex items-center justify-center bg-white/85 p-6 text-center text-xs font-bold text-slate-500 dark:bg-slate-950/85">
          Xarita style yuklanmadi. Login geografiyasi ma'lumotlari quyida statistikada qoladi.
        </div>
      ) : null}
      {isLoaded ? (
        <div className="absolute right-3 top-3 z-10 overflow-hidden rounded-xl border border-slate-200 shadow-sm">
          <ControlButton label="Zoom in" onClick={zoomIn}><Plus className="size-4" /></ControlButton>
          <ControlButton label="Zoom out" onClick={zoomOut}><Minus className="size-4" /></ControlButton>
          <ControlButton label="Reset map" onClick={reset}><RefreshCcw className="size-4" /></ControlButton>
        </div>
      ) : null}
      <style jsx global>{`
        .security-map-marker {
          width: 18px;
          height: 18px;
          border: 3px solid white;
          border-radius: 999px;
          background: var(--security-marker-color);
          box-shadow: 0 12px 26px rgba(15, 23, 42, 0.2);
          cursor: pointer;
          position: relative;
        }
        .security-map-marker span {
          position: absolute;
          inset: -8px;
          border-radius: 999px;
          background: var(--security-marker-color);
          opacity: 0.18;
          animation: security-map-pulse 1.8s ease-out infinite;
        }
        @keyframes security-map-pulse {
          from { transform: scale(0.55); opacity: 0.28; }
          to { transform: scale(1.65); opacity: 0; }
        }
      `}</style>
    </div>
  );
}
