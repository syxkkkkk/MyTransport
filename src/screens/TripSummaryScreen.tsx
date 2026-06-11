import { X, CheckCircle2, Banknote, Check, Route as RouteIcon, Clock, Star, Bookmark, Home, Map as MapIcon, Megaphone, Scan, History, User } from 'lucide-react';
import { NavigateFunction } from '../types';

export default function TripSummaryScreen({ navigate }: { navigate: NavigateFunction }) {
  return (
    <div className="bg-background text-on-background font-body-lg h-full flex flex-col items-center overflow-hidden">
      <header className="fixed top-0 w-full z-50 bg-surface shadow-sm flex items-center justify-between px-margin-mobile h-14">
        <button 
          className="text-primary hover:bg-surface-container-high active:scale-95 transition-transform p-2 rounded-full flex items-center justify-center"
          onClick={() => navigate('Home', 'push_back')}
        >
          <X size={24} />
          <span className="hidden sr-only">close</span>
        </button>
        <h1 className="font-headline-md font-bold text-primary">MyTransport Malaysia</h1>
        <div className="w-10"></div>
      </header>

      <main className="w-full max-w-md mx-auto pt-24 pb-32 px-margin-mobile flex-grow overflow-y-auto no-scrollbar flex flex-col gap-lg">
        <section className="flex flex-col items-center text-center gap-sm mt-md">
          <div className="w-20 h-20 bg-tertiary-container text-on-tertiary-container rounded-full flex items-center justify-center mb-xs">
            <CheckCircle2 size={40} className="text-on-tertiary-container" />
          </div>
          <h2 className="font-headline-lg-mobile text-on-surface">Trip Completed</h2>
          <p className="font-body-lg text-on-surface-variant">You have successfully reached your destination.</p>
        </section>

        <section className="grid grid-cols-2 gap-sm mt-md">
          <div className="col-span-2 bg-surface-container-lowest border border-outline-variant/30 rounded-xl p-md flex items-center justify-between shadow-sm">
            <div className="flex items-center gap-md">
              <div className="w-12 h-12 bg-primary-container text-on-primary-container rounded-full flex items-center justify-center">
                <Banknote size={24} />
              </div>
              <div>
                <p className="font-label-caps text-on-surface-variant uppercase">Total Cost</p>
                <p className="font-headline-md text-primary">RM 2.40</p>
              </div>
            </div>
            <div className="text-right">
              <span className="inline-flex items-center gap-xs px-2 py-1 bg-tertiary-container/20 text-tertiary rounded-full font-mono-label">
                <Check size={14} /> Paid
              </span>
            </div>
          </div>
          <div className="bg-surface-container-lowest border border-outline-variant/30 rounded-xl p-md flex flex-col gap-xs shadow-sm">
            <div className="w-8 h-8 bg-surface-variant text-on-surface-variant rounded-full flex items-center justify-center">
              <RouteIcon size={18} />
            </div>
            <p className="font-label-caps text-on-surface-variant uppercase mt-xs">Total Distance</p>
            <p className="font-headline-md text-on-surface">5.2 km</p>
          </div>
          <div className="bg-surface-container-lowest border border-outline-variant/30 rounded-xl p-md flex flex-col gap-xs shadow-sm">
            <div className="w-8 h-8 bg-surface-variant text-on-surface-variant rounded-full flex items-center justify-center">
              <Clock size={18} />
            </div>
            <p className="font-label-caps text-on-surface-variant uppercase mt-xs">Travel Time</p>
            <p className="font-headline-md text-on-surface">22 min</p>
          </div>
        </section>

        <section className="bg-surface-container-low rounded-xl p-md flex flex-col items-center gap-md mt-sm">
          <p className="font-body-lg text-on-surface font-medium">Rate your experience</p>
          <div className="flex gap-sm">
            {[1, 2, 3, 4, 5].map((s) => (
              <button key={s} className="text-outline-variant hover:text-primary transition-colors">
                <Star size={32} />
              </button>
            ))}
          </div>
        </section>

        <section className="flex flex-col gap-sm mt-auto pt-lg">
          <a 
            className="w-full bg-primary text-on-primary font-body-lg font-medium py-3 rounded-lg shadow-sm hover:opacity-90 transition-colors active:scale-95 flex items-center justify-center cursor-pointer"
            onClick={() => navigate('Home', 'slide_up')}
          >
            Done
          </a>
          <button className="w-full border-[1.5px] border-primary text-primary font-body-lg font-medium py-3 rounded-lg hover:bg-primary-container/10 transition-colors active:scale-95 flex items-center justify-center gap-xs">
            <Bookmark size={20} />
            Save Route
          </button>
        </section>
      </main>

      <nav className="fixed bottom-0 w-full bg-surface border-t border-outline-variant/30 px-2 py-2 flex justify-between items-center z-50">
        <a className="flex flex-col items-center gap-1 flex-1 text-on-surface-variant cursor-pointer"><Home size={24} /><span className="text-[10px] font-medium">Home</span></a>
        <a className="flex flex-col items-center gap-1 flex-1 text-on-surface-variant cursor-pointer"><MapIcon size={24} /><span className="text-[10px] font-medium">Map</span></a>
        <a className="flex flex-col items-center gap-1 flex-1 text-on-surface-variant cursor-pointer"><Megaphone size={24} /><span className="text-[10px] font-medium">Announcement</span></a>
        <a className="flex flex-col items-center gap-1 flex-1 text-on-surface-variant cursor-pointer"><Scan size={24} /><span className="text-[10px] font-medium">AR Nav</span></a>
        <a className="flex flex-col items-center gap-1 flex-1 text-on-surface-variant cursor-pointer"><History size={24} /><span className="text-[10px] font-medium">History</span></a>
        <a className="flex flex-col items-center gap-1 flex-1 text-on-surface-variant cursor-pointer"><User size={24} /><span className="text-[10px] font-medium">Profile</span></a>
      </nav>
    </div>
  );
}
