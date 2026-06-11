import { ArrowLeft, Search, AlertTriangle, X, Settings, MapPin, CheckCircle2, Clock, Star, Home, Map as MapIcon, Megaphone, Scan, History, User } from 'lucide-react';
import { NavigateFunction } from '../types';

export default function LiveTrainNotificationsScreen({ navigate }: { navigate: NavigateFunction }) {
  return (
    <div className="bg-background text-on-background antialiased h-full flex flex-col overflow-hidden items-center">
      <header className="fixed top-0 w-full z-50 bg-surface shadow-sm flex items-center justify-between px-margin-mobile h-14 md:hidden">
        <button 
          className="text-primary hover:bg-surface-container-high p-2 rounded-full active:scale-95 flex items-center"
          onClick={() => navigate('Home', 'push_back')}
        >
          <ArrowLeft size={24} />
          <span className="hidden sr-only">arrow_back</span>
        </button>
        <h1 className="font-headline-md font-bold text-primary">Live Train Notifications</h1>
        <button className="text-primary hover:bg-surface-container-high p-2 rounded-full active:scale-95 flex items-center">
          <Search size={24} />
        </button>
      </header>

      <main className="w-full max-w-2xl px-margin-mobile pt-20 md:pt-8 flex flex-col gap-lg flex-1 overflow-y-auto no-scrollbar pb-24">
        <div className="hidden md:flex items-center justify-between mb-sm">
          <h1 className="font-headline-lg text-primary">Live Train Notifications</h1>
          <img alt="Brand Logo" className="h-12 w-12 rounded-md object-contain border border-surface-variant shadow-sm" src="https://lh3.googleusercontent.com/aida/AP1WRLvEuAb8sZ8iECft5vTdW_kEfblxtd_ZXSYpM96WKjYWtpjbSx7FCxEklu3fUno2F6ZYwxIOT5ScPqYN5P37_ZS3rsIMFHgJMTm2v6H7Eebx1pDGEYyzB_MCH_m0trYPaAAHF9jDJIkTwiA6irW9xJxx7Tgj4H2G1R7lfSlO-mLI5-cNNZxoTqYQd8pONVKUusnW329YvWnZZW6_VGnmojDV2hFY1RLritb454sOG2vC0mVyVR3h492gXg" />
        </div>

        <section className="bg-error-container rounded-lg p-md border border-secondary shadow-sm flex gap-sm items-start">
          <AlertTriangle size={24} className="text-secondary shrink-0 mt-1" />
          <div className="flex-1">
            <h2 className="font-headline-md text-secondary mb-base">Service Disruption</h2>
            <p className="font-body-sm text-on-error-container">Minor delays on the MRT Putrajaya Line due to track maintenance near Cyberjaya. Please allow extra travel time.</p>
          </div>
          <button className="text-secondary hover:bg-white/20 p-1 rounded-full"><X size={16}/></button>
        </section>

        <div className="flex items-center justify-between mt-xs">
          <h2 className="font-headline-md text-on-surface">Departures</h2>
          <button className="flex items-center gap-xs font-mono-label text-primary hover:text-primary-container">
            <Settings size={18} /> Customize Notifications
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-md">
          <article className="bg-[#ffffff] border border-outline-variant rounded-lg p-md shadow-sm relative overflow-hidden group">
            <div className="absolute top-0 left-0 w-1.5 h-full bg-[#E51937]"></div>
            <div className="flex justify-between items-start mb-sm pl-2">
              <div>
                <div className="flex items-center gap-xs mb-1">
                  <span className="bg-[#E51937]/10 text-[#E51937] font-label-caps px-2 py-0.5 rounded-full">KJ Line</span>
                  <span className="font-mono-label text-on-surface-variant flex items-center gap-1"><MapPin size={16} /> Platform 1</span>
                </div>
                <h3 className="font-headline-md text-on-surface">KL Sentral</h3>
              </div>
              <button className="text-primary active:scale-90"><Star size={24} className="fill-primary" /></button>
            </div>
            <div className="pl-2 space-y-sm">
              <div className="flex items-center justify-between bg-surface-container-low p-sm rounded border border-surface-variant">
                <div>
                  <p className="font-body-sm text-on-surface-variant">Towards Gombak</p>
                  <div className="flex items-center gap-2 mt-1">
                    <span className="bg-tertiary-container/15 text-tertiary font-label-caps px-2 py-0.5 rounded-full flex items-center gap-1"><CheckCircle2 size={12} /> On Time</span>
                  </div>
                </div>
                <div className="text-right">
                  <span className="font-headline-lg-mobile text-primary block">2 min</span>
                </div>
              </div>
              <div className="flex items-center justify-between bg-surface-container-low p-sm rounded border border-surface-variant opacity-70">
                <div><p className="font-body-sm text-on-surface-variant">Towards Gombak</p></div>
                <div className="text-right"><span className="font-headline-md text-on-surface-variant block">8 min</span></div>
              </div>
            </div>
          </article>

          <article className="bg-[#ffffff] border border-outline-variant rounded-lg p-md shadow-sm relative overflow-hidden group">
            <div className="absolute top-0 left-0 w-1.5 h-full bg-[#00A54F]"></div>
            <div className="flex justify-between items-start mb-sm pl-2">
              <div>
                <div className="flex items-center gap-xs mb-1">
                  <span className="bg-[#00A54F]/10 text-[#00A54F] font-label-caps px-2 py-0.5 rounded-full">Kajang Line</span>
                  <span className="font-mono-label text-on-surface-variant flex items-center gap-1"><MapPin size={16} /> Platform 2</span>
                </div>
                <h3 className="font-headline-md text-on-surface">Pasar Seni</h3>
              </div>
              <button className="text-outline active:scale-90"><Star size={24} /></button>
            </div>
            <div className="pl-2 space-y-sm">
              <div className="flex items-center justify-between bg-surface-container-low p-sm rounded border border-surface-variant">
                <div>
                  <p className="font-body-sm text-on-surface-variant">Towards Kwasa Damansara</p>
                  <div className="flex items-center gap-2 mt-1">
                    <span className="bg-secondary/10 text-secondary font-label-caps px-2 py-0.5 rounded-full flex items-center gap-1"><Clock size={12} /> 10 min Delay</span>
                  </div>
                </div>
                <div className="text-right">
                  <span className="font-headline-lg-mobile text-secondary block animate-pulse">14 min</span>
                </div>
              </div>
            </div>
          </article>
        </div>
      </main>

      <nav className="fixed bottom-0 left-0 w-full flex justify-around items-center px-xs py-base bg-surface shadow-sm z-50 md:hidden">
        <button className="flex flex-col items-center justify-center text-on-surface-variant p-2 rounded-lg"><Home size={24} /><span className="font-label-caps">Home</span></button>
        <button className="flex flex-col items-center justify-center text-on-surface-variant p-2 rounded-lg"><MapIcon size={24} /><span className="font-label-caps">Map</span></button>
        <button className="flex flex-col items-center justify-center bg-primary-container text-on-primary-container rounded-full px-4 py-1"><Megaphone size={24} /><span className="font-label-caps">Announcement</span></button>
        <button className="flex flex-col items-center justify-center text-on-surface-variant p-2 rounded-lg"><Scan size={24} /><span className="font-label-caps">AR Nav</span></button>
        <button className="flex flex-col items-center justify-center text-on-surface-variant p-2 rounded-lg"><History size={24} /><span className="font-label-caps">History</span></button>
        <button className="flex flex-col items-center justify-center text-on-surface-variant p-2 rounded-lg"><User size={24} /><span className="font-label-caps">Profile</span></button>
      </nav>
    </div>
  );
}
