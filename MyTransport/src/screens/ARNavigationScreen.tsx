import { useState, useEffect, useRef, useCallback } from 'react';
import { X, Volume2, LocateFixed, AlertCircle, Compass, ArrowUp } from 'lucide-react';
import { NavigateFunction } from '../types';

interface Coords { lat: number; lng: number; }

interface Waypoint {
  name: string;
  instruction: string;
  coords: Coords;
}

// Route: Walk to Muzium Negara MRT → Bukit Bintang → Pavilion KL
const WAYPOINTS: Waypoint[] = [
  {
    name: 'Muzium Negara MRT',
    instruction: 'Head towards Muzium Negara MRT Station',
    coords: { lat: 3.1349, lng: 101.6866 },
  },
  {
    name: 'Bukit Bintang MRT Station',
    instruction: 'Exit train at Bukit Bintang Station, Gate D',
    coords: { lat: 3.1466, lng: 101.7105 },
  },
  {
    name: 'Pavilion KL',
    instruction: 'Walk to Pavilion KL — destination on the left',
    coords: { lat: 3.1489, lng: 101.7118 },
  },
];

const WAYPOINT_REACH_RADIUS = 30; // metres

function toRad(deg: number) { return (deg * Math.PI) / 180; }
function toDeg(rad: number) { return (rad * 180) / Math.PI; }

function getBearing(from: Coords, to: Coords): number {
  const dLng = toRad(to.lng - from.lng);
  const lat1 = toRad(from.lat), lat2 = toRad(to.lat);
  const y = Math.sin(dLng) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);
  return (toDeg(Math.atan2(y, x)) + 360) % 360;
}

function getDistance(from: Coords, to: Coords): number {
  const R = 6371000;
  const dLat = toRad(to.lat - from.lat);
  const dLng = toRad(to.lng - from.lng);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(from.lat)) * Math.cos(toRad(to.lat)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function formatDist(m: number): string {
  return m >= 1000 ? `${(m / 1000).toFixed(1)} km` : `${Math.round(m)} m`;
}

function formatETA(m: number): string {
  const mins = Math.round(m / 80); // ~80 m/min walking
  return mins < 1 ? '<1 min' : `${mins} min`;
}

// Total static route distance (WP0 → WP1 → WP2)
const TOTAL_ROUTE = WAYPOINTS.slice(1).reduce(
  (acc, wp, i) => acc + getDistance(WAYPOINTS[i].coords, wp.coords),
  0
);

export default function ARNavigationScreen({ navigate }: { navigate: NavigateFunction }) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);

  const [position, setPosition] = useState<Coords | null>(null);
  const [compass, setCompass] = useState(0);
  const [compassReady, setCompassReady] = useState(false);
  const [waypointIdx, setWaypointIdx] = useState(0);
  const [cameraError, setCameraError] = useState(false);
  const [gpsError, setGpsError] = useState(false);
  const [muted, setMuted] = useState(false);
  const [arrived, setArrived] = useState(false);

  // Camera
  useEffect(() => {
    navigator.mediaDevices
      .getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false })
      .then(stream => {
        streamRef.current = stream;
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          videoRef.current.play().catch(() => {});
        }
      })
      .catch(() => setCameraError(true));
    return () => { streamRef.current?.getTracks().forEach(t => t.stop()); };
  }, []);

  // GPS
  useEffect(() => {
    if (!navigator.geolocation) { setGpsError(true); return; }
    const id = navigator.geolocation.watchPosition(
      pos => setPosition({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => setGpsError(true),
      { enableHighAccuracy: true, maximumAge: 1000, timeout: 10000 }
    );
    return () => navigator.geolocation.clearWatch(id);
  }, []);

  // Compass
  const handleOrientation = useCallback((e: DeviceOrientationEvent) => {
    // iOS provides webkitCompassHeading; Android uses alpha (degrees counterclockwise from north)
    const heading =
      (e as DeviceOrientationEvent & { webkitCompassHeading?: number }).webkitCompassHeading ??
      (e.alpha != null ? (360 - e.alpha) : null);
    if (heading != null) {
      setCompass(heading);
      setCompassReady(true);
    }
  }, []);

  useEffect(() => {
    const attach = () => {
      window.addEventListener('deviceorientationabsolute', handleOrientation as EventListener, true);
      window.addEventListener('deviceorientation', handleOrientation as EventListener, true);
    };
    const DOE = DeviceOrientationEvent as typeof DeviceOrientationEvent & {
      requestPermission?: () => Promise<string>;
    };
    if (typeof DOE.requestPermission === 'function') {
      DOE.requestPermission().then(p => { if (p === 'granted') attach(); }).catch(() => {});
    } else {
      attach();
    }
    return () => {
      window.removeEventListener('deviceorientationabsolute', handleOrientation as EventListener, true);
      window.removeEventListener('deviceorientation', handleOrientation as EventListener, true);
    };
  }, [handleOrientation]);

  // Auto-advance waypoint when within radius
  useEffect(() => {
    if (!position || waypointIdx >= WAYPOINTS.length) return;
    const dist = getDistance(position, WAYPOINTS[waypointIdx].coords);
    if (dist < WAYPOINT_REACH_RADIUS) {
      if (waypointIdx < WAYPOINTS.length - 1) {
        setWaypointIdx(i => i + 1);
      } else {
        setArrived(true);
      }
    }
  }, [position, waypointIdx]);

  const currentWaypoint = WAYPOINTS[waypointIdx];

  const distToWaypoint = position ? getDistance(position, currentWaypoint.coords) : null;
  const bearing = position ? getBearing(position, currentWaypoint.coords) : 0;
  const arrowRotation = bearing - compass;

  const totalRemaining = position
    ? WAYPOINTS.slice(waypointIdx).reduce((acc, wp, i, arr) => {
        if (i === 0) return acc + getDistance(position, wp.coords);
        return acc + getDistance(arr[i - 1].coords, wp.coords);
      }, 0)
    : null;

  const progress =
    totalRemaining != null
      ? Math.max(0, Math.min(100, ((TOTAL_ROUTE - totalRemaining) / TOTAL_ROUTE) * 100))
      : 0;

  return (
    <div className="h-full w-full bg-black relative overflow-hidden font-body-lg text-on-surface antialiased">
      {/* Camera feed */}
      {cameraError ? (
        <div className="absolute inset-0 bg-gradient-to-b from-slate-900 to-slate-800" />
      ) : (
        <video
          ref={videoRef}
          className="absolute inset-0 w-full h-full object-cover"
          playsInline
          muted
          autoPlay
        />
      )}
      <div className="absolute inset-0 bg-black/25 pointer-events-none" />

      {/* Header */}
      <div className="fixed top-0 w-full z-50 flex items-center justify-between px-4 h-14 bg-surface/85 backdrop-blur-md rounded-b-xl shadow-sm border-b border-white/20">
        <button
          className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-surface-variant transition-colors active:scale-95"
          onClick={() => navigate('RouteDetails', 'push_back')}
        >
          <X size={24} />
        </button>
        <h1 className="font-headline-md font-bold text-primary">AR Navigation</h1>
        <div className="w-10 flex items-center justify-center">
          <Compass size={20} className={compassReady ? 'text-primary' : 'text-on-surface-variant'} />
        </div>
      </div>

      {/* Direction / instruction card */}
      <div className="fixed top-20 left-4 right-4 z-40">
        <div className="bg-surface/90 backdrop-blur-md rounded-xl p-4 shadow-lg flex items-center gap-4 border border-outline-variant/30">
          {/* Rotating arrow */}
          <div
            className="w-14 h-14 rounded-full bg-primary flex items-center justify-center flex-shrink-0 shadow-md"
            style={{
              transform: position ? `rotate(${arrowRotation}deg)` : 'none',
              transition: 'transform 0.4s ease-out',
            }}
          >
            <ArrowUp size={30} className="text-on-primary" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="font-headline-md text-on-surface font-semibold leading-tight">
              {distToWaypoint != null ? formatDist(distToWaypoint) : 'Acquiring GPS…'}
            </p>
            <p className="font-body-sm text-on-surface-variant mt-0.5 line-clamp-2">
              {currentWaypoint.instruction}
            </p>
            {!compassReady && position && (
              <p className="font-body-sm text-amber-400 mt-1">Rotate device to calibrate compass</p>
            )}
          </div>
        </div>
      </div>

      {/* Error banners */}
      {(gpsError || cameraError) && (
        <div className="fixed top-36 left-4 right-4 z-40 flex flex-col gap-2">
          {gpsError && (
            <div className="bg-red-600/90 backdrop-blur-sm rounded-lg px-3 py-2 flex items-center gap-2">
              <AlertCircle size={16} className="text-white flex-shrink-0" />
              <span className="font-body-sm text-white">GPS unavailable — enable location access</span>
            </div>
          )}
          {cameraError && (
            <div className="bg-amber-600/90 backdrop-blur-sm rounded-lg px-3 py-2 flex items-center gap-2">
              <AlertCircle size={16} className="text-white flex-shrink-0" />
              <span className="font-body-sm text-white">Camera unavailable — enable camera access</span>
            </div>
          )}
        </div>
      )}

      {/* Waypoint progress dots */}
      <div className="fixed left-4 top-1/2 -translate-y-1/2 z-40 flex flex-col gap-2.5">
        {WAYPOINTS.map((wp, i) => (
          <div
            key={wp.name}
            title={wp.name}
            className={`rounded-full border-2 transition-all duration-300 ${
              i < waypointIdx
                ? 'w-3 h-3 bg-primary border-primary'
                : i === waypointIdx
                ? 'w-4 h-4 bg-primary border-white shadow-lg'
                : 'w-3 h-3 bg-transparent border-white/50'
            }`}
          />
        ))}
      </div>

      {/* Side controls */}
      <div className="fixed right-4 top-1/2 -translate-y-1/2 z-40 flex flex-col gap-3">
        <button
          className="w-12 h-12 rounded-full bg-surface/90 shadow-md flex items-center justify-center transition-colors"
          onClick={() => setMuted(m => !m)}
        >
          <Volume2 size={24} className={muted ? 'text-on-surface-variant' : 'text-primary'} />
        </button>
        <button className="w-12 h-12 rounded-full bg-surface/90 shadow-md flex items-center justify-center">
          <LocateFixed size={24} className={position ? 'text-primary' : 'text-on-surface-variant'} />
        </button>
      </div>

      {/* GPS coordinates badge (debug) */}
      {position && (
        <div className="fixed bottom-40 left-4 z-40">
          <div className="bg-black/60 backdrop-blur-sm rounded-lg px-2 py-1">
            <p className="font-mono text-[10px] text-white/70">
              {position.lat.toFixed(5)}, {position.lng.toFixed(5)}
            </p>
          </div>
        </div>
      )}

      {/* Bottom panel */}
      <div className="fixed bottom-0 left-0 w-full z-50 bg-surface/90 backdrop-blur-md rounded-t-2xl shadow-lg pb-8">
        <div className="px-4 pt-4 pb-2">
          <div className="flex justify-between items-end mb-3">
            <div>
              <p className="font-headline-lg-mobile text-primary font-bold">
                {totalRemaining != null ? formatDist(totalRemaining) : '---'}
              </p>
              <p className="font-body-sm text-on-surface-variant">remaining</p>
            </div>
            <div className="text-right">
              <p className="font-body-lg text-on-surface font-medium">
                {totalRemaining != null ? formatETA(totalRemaining) : '---'}
              </p>
              <p className="font-body-sm text-on-surface-variant">Estimated arrival</p>
            </div>
          </div>

          {/* Progress bar */}
          <div className="w-full h-2 bg-surface-variant rounded-full overflow-hidden mb-2">
            <div
              className="h-full bg-primary rounded-full transition-all duration-1000 ease-in-out"
              style={{ width: `${progress}%` }}
            />
          </div>

          {/* Next waypoint label or arrive button */}
          {!arrived && waypointIdx < WAYPOINTS.length - 1 && (
            <p className="font-body-sm text-on-surface-variant text-center">
              Next: {WAYPOINTS[waypointIdx + 1].name}
            </p>
          )}
          {(arrived || waypointIdx === WAYPOINTS.length - 1) && (
            <button
              className="mt-2 w-full bg-primary text-on-primary rounded-xl py-2.5 font-body-lg font-semibold active:scale-95 transition-transform"
              onClick={() => navigate('TripSummary', 'push')}
            >
              Arrive at Destination
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
