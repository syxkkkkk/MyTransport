import { 
  ArrowLeft, Search, LocateFixed, Pin, Bot, Mic, Train, Bus, Route, Bookmark, Home, Map as MapIcon, Megaphone, Scan, History, User 
} from 'lucide-react';
import { NavigateFunction } from '../types';

export default function HomeScreen({ navigate }: { navigate: NavigateFunction }) {
  return (
    <div className="bg-background text-on-background h-full flex flex-col antialiased">
      {/* TopAppBar */}
      <header className="fixed top-0 w-full z-50 bg-surface shadow-sm flex items-center justify-between px-margin-mobile h-14 transition-all">
        <button className="text-primary hover:bg-surface-container-high p-sm rounded-full flex items-center justify-center">
          <ArrowLeft size={24} />
          <span className="hidden sr-only">arrow_back</span>
        </button>
        <img 
          src="https://lh3.googleusercontent.com/aida-public/AB6AXuBV-MBafhuN1xSdHHX6FFYGzEHrKnnCoDX87dVFvYVSP4YlFZDbZXZjoiebEHG3C7IIqthh0iuAORTnJtJCAU4oHDLpAGjExCaPewGOhXnHBuE4pr3MwdUnRRpG41N5EWdDOy6iBvgqvmftwDwJAK6x9FCpR4NdoDA18TcqqKrC4n2THF3crEnwhFLd05dV9_hhHrKfsUCUpKFYvr9XAfuPGyUWQ580ZDT3edhA84-CDPvHsesgie3YHVoV4wYCrHrqFewsEhLiZUA" 
          alt="MyTransport Malaysia Logo" 
          className="h-8 w-auto object-contain" 
        />
        <button className="text-primary hover:bg-surface-container-high p-sm rounded-full flex items-center justify-center">
          <Search size={24} />
        </button>
      </header>

      {/* Main Canvas */}
      <main className="flex-grow overflow-y-auto pt-[calc(3.5rem+24px)] pb-[calc(5rem+24px)] px-margin-mobile flex flex-col gap-lg no-scrollbar">
        {/* Location Card */}
        <section className="bg-surface-container-lowest rounded-xl p-md border border-outline-variant shadow-sm flex flex-col gap-sm">
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-xs text-on-surface-variant">
              <LocateFixed size={16} className="text-primary" />
              <span className="font-mono-label uppercase text-outline">Current Location</span>
            </div>
          </div>
          <div className="flex flex-col gap-xs">
            <h2 className="font-headline-md text-on-surface">Kuala Lumpur Sentral</h2>
            <p className="font-body-sm text-on-surface-variant line-clamp-1">Jalan Stesen Sentral, Kuala Lumpur, 50470</p>
          </div>
          <div className="pt-sm border-t border-surface-variant mt-xs">
            <a 
              className="w-full bg-primary text-on-primary font-mono-label rounded-lg py-sm px-md flex items-center justify-center gap-xs hover:bg-primary-container transition-colors cursor-pointer"
              onClick={() => navigate('LocationSelection', 'push')}
            >
              <Pin size={18} />
              Pin Location
            </a>
          </div>
        </section>

        {/* AI Input Field */}
        <a 
          className="relative block cursor-pointer"
          onClick={() => navigate('Chatbot', 'push')}
        >
          <div className="bg-surface-container-lowest rounded-full p-[2px] border border-outline-variant hover:border-primary transition-all shadow-sm">
            <div className="flex items-center gap-sm px-md py-sm bg-surface-container-lowest rounded-full">
              <Bot size={24} className="text-primary animate-pulse" />
              <div className="flex-grow font-body-lg text-outline-variant">Ask AI: How to get to KLCC?</div>
              <button className="text-primary rounded-full p-xs">
                <Mic size={20} />
              </button>
            </div>
          </div>
        </a>

        {/* Quick Shortcuts Grid */}
        <section className="grid grid-cols-2 gap-md">
          <a 
            className="bg-surface-container-lowest border border-outline-variant rounded-xl p-md flex flex-col items-center justify-center gap-sm shadow-sm hover:bg-surface-container-low transition-all cursor-pointer"
            onClick={() => navigate('LiveTrainNotifications', 'push')}
          >
            <div className="w-12 h-12 bg-primary-fixed rounded-full flex items-center justify-center text-primary">
              <Train size={24} />
            </div>
            <span className="font-mono-label text-on-surface text-center">Nearby Stations</span>
          </a>
          <button className="bg-surface-container-lowest border border-outline-variant rounded-xl p-md flex flex-col items-center justify-center gap-sm shadow-sm hover:bg-surface-container-low transition-all">
            <div className="w-12 h-12 bg-secondary-fixed rounded-full flex items-center justify-center text-secondary">
              <Bus size={24} />
            </div>
            <span className="font-mono-label text-on-surface text-center">Bus Routes</span>
          </button>
          <button className="bg-surface-container-lowest border border-outline-variant rounded-xl p-md flex flex-col items-center justify-center gap-sm shadow-sm hover:bg-surface-container-low transition-all">
            <div className="w-12 h-12 bg-tertiary-fixed rounded-full flex items-center justify-center text-tertiary">
              <Route size={24} />
            </div>
            <span className="font-mono-label text-on-surface text-center">Train Routes</span>
          </button>
          <button className="bg-surface-container-lowest border border-outline-variant rounded-xl p-md flex flex-col items-center justify-center gap-sm shadow-sm hover:bg-surface-container-low transition-all">
            <div className="w-12 h-12 bg-surface-variant rounded-full flex items-center justify-center text-on-surface-variant">
              <Bookmark size={24} />
            </div>
            <span className="font-mono-label text-on-surface text-center">Saved Locations</span>
          </button>
        </section>
      </main>

      {/* BottomNavBar */}
      <nav className="fixed bottom-0 left-0 w-full flex justify-around items-center px-xs py-base bg-surface z-50 shadow-[0_-4px_12px_rgba(0,0,0,0.04)]">
        <a className="flex flex-col items-center justify-center bg-primary-container text-on-primary-container rounded-full py-1 hover:bg-surface-container-highest transition-colors px-2 cursor-pointer">
          <Home size={24} />
          <span className="font-label-caps mt-1">Home</span>
        </a>
        <a 
          className="flex flex-col items-center justify-center text-on-surface-variant hover:bg-surface-container-highest transition-colors py-1 rounded-full px-2 cursor-pointer"
          onClick={() => navigate('LocationSelection', 'none')}
        >
          <MapIcon size={24} />
          <span className="font-label-caps mt-1">Map</span>
        </a>
        <a 
          className="flex flex-col items-center justify-center text-on-surface-variant hover:bg-surface-container-highest transition-colors px-2 py-1 rounded-full cursor-pointer"
          onClick={() => navigate('LiveTrainNotifications', 'none')}
        >
          <Megaphone size={24} />
          <span className="font-label-caps mt-1">Announcement</span>
        </a>
        <a 
          className="flex flex-col items-center justify-center text-on-surface-variant hover:bg-surface-container-highest transition-colors py-1 rounded-full px-2 cursor-pointer"
          onClick={() => navigate('ARNavigation', 'none')}
        >
          <Scan size={24} />
          <span className="font-label-caps mt-1">AR Nav</span>
        </a>
        <a className="flex flex-col items-center justify-center text-on-surface-variant hover:bg-surface-container-highest transition-colors py-1 rounded-full px-2 cursor-pointer">
          <History size={24} />
          <span className="font-label-caps mt-1">History</span>
        </a>
        <a className="flex flex-col items-center justify-center text-on-surface-variant hover:bg-surface-container-highest transition-colors py-1 rounded-full px-2 cursor-pointer">
          <User size={24} />
          <span className="font-label-caps mt-1">Profile</span>
        </a>
      </nav>
    </div>
  );
}
