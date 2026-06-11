import { ArrowLeft, Search, Bot, Train, Footprints, Info, Home, Map as MapIcon, Megaphone, Scan, History, User } from 'lucide-react';
import { NavigateFunction } from '../types';

export default function ChatbotScreen({ navigate }: { navigate: NavigateFunction }) {
  return (
    <div className="bg-background text-on-background h-full flex flex-col antialiased">
      <header className="fixed top-0 w-full z-50 bg-surface shadow-sm">
        <div className="flex items-center justify-between px-margin-mobile h-14 w-full">
          <button 
            className="text-primary hover:bg-surface-container-high active:scale-95 transition-transform duration-150 p-2 rounded-full flex items-center justify-center"
            onClick={() => navigate('Home', 'push_back')}
          >
            <ArrowLeft size={24} />
            <span className="hidden sr-only">arrow_back</span>
          </button>
          <h1 className="font-headline-md font-bold text-primary">MyTransport Malaysia</h1>
          <button className="text-primary hover:bg-surface-container-high active:scale-95 transition-transform duration-150 p-2 rounded-full flex items-center justify-center">
            <Search size={24} />
          </button>
        </div>
      </header>

      <main className="flex-1 overflow-y-auto pt-20 pb-24 px-margin-mobile flex flex-col gap-lg w-full max-w-3xl mx-auto no-scrollbar">
        <div className="flex justify-end">
          <div className="bg-primary-container text-on-primary-container rounded-xl rounded-tr-none px-md py-sm max-w-[85%] shadow-sm">
            <p className="font-body-lg">How do I get from KL Sentral to Pavilion KL?</p>
          </div>
        </div>

        <div className="flex justify-start">
          <div className="flex gap-sm max-w-[95%]">
            <div className="w-8 h-8 rounded-full bg-surface-container-highest flex items-center justify-center shrink-0 mt-1">
              <Bot size={20} className="text-primary" />
            </div>
            <div className="flex flex-col gap-sm">
              <div className="bg-surface-container-lowest border border-outline-variant rounded-xl rounded-tl-none p-md shadow-sm">
                <p className="font-body-sm text-on-surface mb-sm">Here is the fastest route for you:</p>
                <div className="bg-surface rounded-lg border-l-4 border-tertiary-container p-sm mb-sm flex flex-col gap-xs">
                  <div className="flex justify-between items-start">
                    <div className="flex items-center gap-xs text-primary">
                      <Train size={20} />
                      <span className="font-label-caps">MRT KAJANG LINE</span>
                    </div>
                    <div className="text-right">
                      <div className="font-headline-md text-on-surface">25 min</div>
                      <div className="font-body-sm text-on-surface-variant">RM 2.40</div>
                    </div>
                  </div>
                  <div className="flex flex-col gap-xs mt-xs relative">
                    <div className="absolute left-2.5 top-2 bottom-6 w-0.5 bg-outline-variant"></div>
                    <div className="flex items-center gap-sm z-10">
                      <div className="w-5 h-5 rounded-full bg-surface border-2 border-primary flex items-center justify-center shrink-0"></div>
                      <span className="font-body-lg text-on-surface">Muzium Negara (Walk from KL Sentral)</span>
                    </div>
                    <div className="flex items-center gap-sm ml-7 py-1">
                      <Footprints size={16} className="text-on-surface-variant" />
                      <span className="font-body-sm text-on-surface-variant">Walk 5 min</span>
                    </div>
                    <div className="flex items-center gap-sm ml-7 py-1">
                      <Train size={16} className="text-tertiary-container" />
                      <span className="font-body-sm text-on-surface-variant">3 stops to Bukit Bintang</span>
                    </div>
                    <div className="flex items-center gap-sm z-10">
                      <div className="w-5 h-5 rounded-full bg-primary flex items-center justify-center shrink-0">
                        <div className="w-2 h-2 rounded-full bg-on-primary"></div>
                      </div>
                      <span className="font-body-lg text-on-surface">Bukit Bintang Station</span>
                    </div>
                  </div>
                </div>
                <button 
                  className="mt-xs w-full py-2 px-md border border-primary rounded-lg text-primary font-mono-label hover:bg-surface-container-high transition-colors flex items-center justify-center gap-xs"
                  onClick={() => navigate('RouteDetails', 'push')}
                >
                  <Info size={18} />
                  Show Details
                </button>
              </div>
            </div>
          </div>
        </div>
      </main>

      <div className="fixed bottom-0 w-full bg-surface border-t border-surface-variant z-40 pb-safe">
        <div className="max-w-3xl mx-auto px-2 py-2 flex items-center justify-between w-full">
          <button className="flex flex-col items-center justify-center flex-1 gap-1 text-on-surface-variant hover:bg-surface-container-highest rounded-lg py-1 transition-colors">
            <Home size={24} />
            <span className="text-[10px] font-medium">Home</span>
          </button>
          <button className="flex flex-col items-center justify-center flex-1 gap-1 text-on-surface-variant hover:bg-surface-container-highest rounded-lg py-1 transition-colors">
            <MapIcon size={24} />
            <span className="text-[10px] font-medium">Map</span>
          </button>
          <button className="flex flex-col items-center justify-center flex-1 gap-1 text-on-surface-variant hover:bg-surface-container-highest rounded-lg py-1 transition-colors">
            <Megaphone size={24} />
            <span className="text-[10px] font-medium">Announcement</span>
          </button>
          <button className="flex flex-col items-center justify-center flex-1 gap-1 text-on-surface-variant hover:bg-surface-container-highest rounded-lg py-1 transition-colors">
            <Scan size={24} />
            <span className="text-[10px] font-medium">AR Nav</span>
          </button>
          <button className="flex flex-col items-center justify-center flex-1 gap-1 text-on-surface-variant hover:bg-surface-container-highest rounded-lg py-1 transition-colors">
            <History size={24} />
            <span className="text-[10px] font-medium">History</span>
          </button>
          <button className="flex flex-col items-center justify-center flex-1 gap-1 text-on-surface-variant hover:bg-surface-container-highest rounded-lg py-1 transition-colors">
            <User size={24} />
            <span className="text-[10px] font-medium">Profile</span>
          </button>
        </div>
      </div>
    </div>
  );
}
