import { ArrowLeft, X, Home, Briefcase, Plane, MapPin, LocateFixed, Map as MapIcon, Megaphone, Scan, History, User } from 'lucide-react';
import { NavigateFunction } from '../types';

export default function LocationSelectionScreen({ navigate }: { navigate: NavigateFunction }) {
  return (
    <div className="bg-background text-on-background h-full w-full overflow-hidden font-body-lg relative">
      <div 
        className="absolute inset-0 z-0 bg-cover bg-center" 
        style={{ backgroundImage: 'url(https://lh3.googleusercontent.com/aida-public/AB6AXuDo6h_t8O2nHiroIE039WhVhBEkWaQoZ-HgLxXW7Pub8zullCAegk8ZRgHxgDe3hL04rgySqZNkVJYc4R7m4vfNrEeX8ylJDLRhud0NGc6zzFUx5JkaWyEvvqQt1v_JzmasnyjBwczmmckrcZRMUV1_wzf6ZNZIZX0I1T8F2ds_De4VxZ8UyXGZm-GpI5dfCxhmKArUYCSy_dvYvp1EwGvqwtzgxnJgnQyfnqMXUPZ_vmACoAwqwV-k7ZueOlQQweA6W7ne4ZB3iJE)' }}
      >
        <div className="absolute inset-0 bg-gradient-to-b from-surface/80 via-transparent to-surface border-0" />
      </div>

      <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 z-10 flex flex-col items-center">
        <div className="bg-surface px-md py-sm rounded-lg shadow-md mb-2 flex items-center gap-2 border border-surface-variant">
          <MapPin className="text-primary" size={20} />
          <span className="font-mono-label text-on-surface">KL Sentral</span>
        </div>
        <div className="relative">
          <div className="w-8 h-8 bg-primary rounded-full flex items-center justify-center shadow-lg relative z-20">
            <div className="w-3 h-3 bg-on-primary rounded-full"></div>
          </div>
          <div className="w-4 h-1 bg-on-surface/30 rounded-full absolute -bottom-1 left-1/2 transform -translate-x-1/2 blur-[1px]"></div>
        </div>
      </div>

      <div className="fixed top-0 w-full z-50 pt-4 px-margin-mobile">
        <div className="bg-surface rounded-xl shadow-sm flex items-center px-md h-14 border border-surface-variant">
          <button 
            className="p-2 -ml-2 text-on-surface-variant hover:bg-surface-container-high rounded-full focus:outline-none flex items-center justify-center"
            onClick={() => navigate('Home', 'push_back')}
          >
            <ArrowLeft size={24} />
            <span className="hidden sr-only">arrow_back</span>
          </button>
          <input className="flex-1 bg-transparent border-none focus:ring-0 font-body-lg text-on-surface placeholder-on-surface-variant px-md h-full outline-none" placeholder="Where to?" type="text" defaultValue="KL Sentral" />
          <button className="p-2 -mr-2 text-on-surface-variant hover:bg-surface-container-high rounded-full flex items-center justify-center">
            <X size={24} />
          </button>
        </div>
        <div className="flex gap-2 mt-sm overflow-x-auto pb-2 no-scrollbar">
          <button className="whitespace-nowrap bg-surface-container text-on-surface font-mono-label px-md py-sm rounded-full border border-surface-variant hover:bg-surface-variant flex items-center gap-1 shadow-sm">
            <Home size={16} /> Home
          </button>
          <button className="whitespace-nowrap bg-surface-container text-on-surface font-mono-label px-md py-sm rounded-full border border-surface-variant hover:bg-surface-variant flex items-center gap-1 shadow-sm">
            <Briefcase size={16} /> Work
          </button>
          <button className="whitespace-nowrap bg-surface-container text-on-surface font-mono-label px-md py-sm rounded-full border border-surface-variant hover:bg-surface-variant flex items-center gap-1 shadow-sm">
            <Plane size={16} /> KLIA Express
          </button>
        </div>
      </div>

      <div className="fixed bottom-0 left-0 w-full z-50 px-margin-mobile pb-margin-mobile pt-lg bg-gradient-to-t from-surface via-surface/90 to-transparent flex flex-col gap-md mb-14">
        <div className="flex justify-end w-full mb-2">
          <button className="bg-surface text-primary w-12 h-12 rounded-full shadow-md flex items-center justify-center border border-surface-variant active:scale-95">
            <LocateFixed size={24} />
          </button>
        </div>
        <div className="bg-surface rounded-xl p-md shadow-sm border border-surface-variant">
          <div className="flex items-start gap-md">
            <div className="w-10 h-10 rounded-full bg-primary-container text-on-primary-container flex items-center justify-center shrink-0">
              <MapPin size={20} />
            </div>
            <div className="flex-1 min-w-0">
              <h2 className="font-headline-md text-on-surface truncate">KL Sentral</h2>
              <p className="font-body-sm text-on-surface-variant truncate">Kuala Lumpur Sentral, 50470 Kuala Lumpur</p>
            </div>
          </div>
          <div className="mt-md flex gap-2">
            <span className="bg-surface-container-high px-2 py-1 rounded text-[10px] font-bold text-on-surface tracking-wider uppercase">Transit Hub</span>
            <span className="bg-surface-container-high px-2 py-1 rounded text-[10px] font-bold text-on-surface tracking-wider uppercase">LRT</span>
            <span className="bg-surface-container-high px-2 py-1 rounded text-[10px] font-bold text-on-surface tracking-wider uppercase">MRT</span>
          </div>
        </div>
        <button 
          className="w-full bg-primary text-on-primary font-headline-md py-sm rounded-lg shadow-sm hover:bg-primary/90 active:scale-[0.98] h-14 flex items-center justify-center"
          onClick={() => navigate('RouteDetails', 'push')}
        >
          Confirm Location
        </button>
      </div>

      <nav className="fixed bottom-0 left-0 w-full bg-surface border-t border-surface-variant z-50 px-2 pb-2 pt-1 flex justify-between items-center">
        <button className="flex flex-col items-center justify-center flex-1 py-1 text-on-surface-variant rounded-lg">
          <Home size={24} />
          <span className="text-[10px] font-medium w-full text-center">Home</span>
        </button>
        <button className="flex flex-col items-center justify-center flex-1 py-1 text-primary rounded-lg">
          <MapIcon size={24} />
          <span className="text-[10px] font-bold w-full text-center">Map</span>
        </button>
        <button className="flex flex-col items-center justify-center flex-1 py-1 text-on-surface-variant rounded-lg">
          <Megaphone size={24} />
          <span className="text-[10px] font-medium w-full text-center">Announcement</span>
        </button>
        <button className="flex flex-col items-center justify-center flex-1 py-1 text-on-surface-variant rounded-lg">
          <Scan size={24} />
          <span className="text-[10px] font-medium w-full text-center">AR Nav</span>
        </button>
        <button className="flex flex-col items-center justify-center flex-1 py-1 text-on-surface-variant rounded-lg">
          <History size={24} />
          <span className="text-[10px] font-medium w-full text-center">History</span>
        </button>
        <button className="flex flex-col items-center justify-center flex-1 py-1 text-on-surface-variant rounded-lg">
          <User size={24} />
          <span className="text-[10px] font-medium w-full text-center">Profile</span>
        </button>
      </nav>
    </div>
  );
}
