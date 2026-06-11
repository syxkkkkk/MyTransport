import { ArrowLeft, Search, Footprints, Train, MapPin, Flag, CircleDot, Home, Map as MapIcon, Megaphone, Scan, History, User } from 'lucide-react';
import { NavigateFunction } from '../types';

export default function RouteDetailsScreen({ navigate }: { navigate: NavigateFunction }) {
  return (
    <div className="bg-background text-on-background h-full font-body-lg flex flex-col overflow-hidden">
      <header className="fixed top-0 w-full z-50 bg-surface shadow-sm flex items-center justify-between px-margin-mobile h-14">
        <button 
          className="text-primary hover:bg-surface-container-high p-2 rounded-full active:scale-95 flex items-center justify-center"
          onClick={() => navigate('LocationSelection', 'push_back')}
        >
          <ArrowLeft size={24} />
          <span className="hidden sr-only">arrow_back</span>
        </button>
        <h1 className="font-headline-md font-bold text-primary truncate px-4">MyTransport Malaysia</h1>
        <button className="text-primary hover:bg-surface-container-high p-2 rounded-full active:scale-95 flex items-center justify-center">
          <Search size={24} />
        </button>
      </header>

      <main className="flex-grow overflow-y-auto no-scrollbar pt-[72px] pb-[100px] px-margin-mobile md:px-margin-desktop max-w-3xl mx-auto w-full">
        <div className="bg-surface-container-lowest rounded-xl shadow-sm border border-surface-variant overflow-hidden mb-lg">
          <div className="h-48 w-full bg-surface-container-highest relative">
            <img 
              alt="Map showing route" 
              className="w-full h-full object-cover" 
              src="https://lh3.googleusercontent.com/aida-public/AB6AXuAWxXK2-d_hYIwRcSIHPkl5czDaF8l0-S8kbzIxcv1WoASrG7mpUJBxzjkW1i2rBAC9S9MNeJGI1lQYZEHgmgRGk3xZz9YLt251Ano68HwufqVbQEoICUsiO8RgYrnT45sbzHMBO5ecr1eYLAETj2xwnlNwlnhRpDR3BNwtG5PukoInGMzFTqGBnOUIzL8fJQc30A5uO7IOo7B3fUfzen8lx6zZ-ltqv9GYWArGwLJUkUp8kR8k4BUoteakgTjRTquAbmhRI8QbpUY" 
            />
          </div>
          <div className="p-md md:p-lg flex flex-col gap-sm">
            <div className="flex justify-between items-start">
              <div>
                <p className="font-label-caps text-on-surface-variant uppercase tracking-wider mb-base">Destination</p>
                <h2 className="font-headline-lg-mobile md:font-headline-lg text-on-surface">Pavilion KL</h2>
              </div>
              <div className="text-right">
                <p className="font-headline-md text-primary">25 min</p>
                <p className="font-body-sm text-on-surface-variant">RM 2.40</p>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-surface-container-lowest rounded-xl shadow-sm border border-surface-variant p-md md:p-lg relative">
          <h3 className="font-headline-md text-on-surface mb-lg">Journey Details</h3>
          <div className="flex flex-col relative z-0">
            {/* Step 1 */}
            <div className="flex gap-md mb-lg relative timeline-item z-10">
              <div className="flex flex-col items-center relative z-20">
                <div className="w-12 h-12 rounded-full bg-surface-variant flex items-center justify-center flex-shrink-0 z-30">
                  <Footprints size={24} className="text-on-surface-variant" />
                </div>
                <div className="absolute top-12 bottom-[-24px] w-0.5 bg-outline-variant z-[-1]" />
              </div>
              <div className="flex-grow pt-2 pb-6">
                <div className="flex justify-between items-baseline mb-base">
                  <h4 className="font-body-lg font-semibold text-on-surface">Walk to Muzium Negara MRT</h4>
                  <span className="font-mono-label text-on-surface-variant ml-4 shrink-0">5 min</span>
                </div>
                <p className="font-body-sm text-on-surface-variant">Head east toward Jalan Damansara</p>
              </div>
            </div>

            {/* Step 2 */}
            <div className="flex gap-md mb-lg relative timeline-item z-10">
              <div className="flex flex-col items-center relative z-20">
                <div className="w-12 h-12 rounded-full bg-[#007b5f] flex items-center justify-center flex-shrink-0 shadow-sm z-30">
                  <Train size={24} className="text-white" />
                </div>
                <div className="absolute top-12 bottom-[-24px] w-0.5 bg-outline-variant z-[-1]" />
              </div>
              <div className="flex-grow pt-2 pb-6">
                <div className="flex justify-between items-baseline mb-base">
                  <h4 className="font-body-lg font-semibold text-on-surface">MRT Kajang Line</h4>
                  <span className="font-mono-label text-on-surface-variant ml-4 shrink-0">12 min</span>
                </div>
                <p className="font-body-sm text-on-surface-variant mb-2">Toward Kwasa Damansara</p>
                <div className="bg-surface-container p-sm rounded-lg flex items-center gap-xs">
                  <CircleDot size={18} className="text-outline" />
                  <span className="font-body-sm text-on-surface">3 stops</span>
                </div>
              </div>
            </div>

            {/* Step 3 */}
            <div className="flex gap-md mb-lg relative timeline-item z-10">
              <div className="flex flex-col items-center relative z-20">
                <div className="w-12 h-12 rounded-full bg-surface-variant flex items-center justify-center flex-shrink-0 z-30">
                  <MapPin size={24} className="text-on-surface-variant" />
                </div>
                <div className="absolute top-12 bottom-[-24px] w-0.5 bg-outline-variant z-[-1]" />
              </div>
              <div className="flex-grow pt-2 pb-6">
                <div className="flex justify-between items-baseline mb-base">
                  <h4 className="font-body-lg font-semibold text-on-surface">Arrive at Bukit Bintang Station</h4>
                </div>
                <p className="font-body-sm text-on-surface-variant">Exit at Gate D (Pavilion)</p>
              </div>
            </div>

            {/* Step 4 */}
            <div className="flex gap-md relative timeline-item z-10">
              <div className="flex flex-col items-center relative z-20">
                <div className="w-12 h-12 rounded-full bg-primary-container flex items-center justify-center flex-shrink-0 shadow-sm z-30">
                  <Flag size={24} className="text-on-primary-container" />
                </div>
              </div>
              <div className="flex-grow pt-2">
                <div className="flex justify-between items-baseline mb-base">
                  <h4 className="font-body-lg font-semibold text-on-surface">Walk to Pavilion KL</h4>
                  <span className="font-mono-label text-on-surface-variant ml-4 shrink-0">3 min</span>
                </div>
                <p className="font-body-sm text-on-surface-variant">Destination will be on the left</p>
              </div>
            </div>
          </div>
        </div>
      </main>

      <nav className="fixed bottom-0 left-0 w-full bg-surface border-t border-surface-variant px-2 py-2 shadow-sm z-50">
        <div className="flex justify-between items-center max-w-3xl mx-auto">
          <a className="flex flex-col items-center gap-1 flex-1 min-w-0 text-on-surface-variant rounded-lg py-1 cursor-pointer">
            <Home size={24} />
            <span className="text-[10px] font-medium truncate">Home</span>
          </a>
          <a 
            className="flex flex-col items-center gap-1 flex-1 min-w-0 text-primary rounded-lg py-1 cursor-pointer"
            onClick={() => navigate('LocationSelection', 'none')}
          >
            <MapIcon size={24} />
            <span className="text-[10px] font-bold truncate">Map</span>
          </a>
          <a 
            className="flex flex-col items-center gap-1 flex-1 min-w-0 text-on-surface-variant rounded-lg py-1 cursor-pointer"
            onClick={() => navigate('LiveTrainNotifications', 'none')}
          >
            <Megaphone size={24} />
            <span className="text-[10px] font-medium truncate">Announcement</span>
          </a>
          <a 
            className="flex flex-col items-center gap-1 flex-1 min-w-0 text-on-surface-variant rounded-lg py-1 cursor-pointer"
            onClick={() => navigate('ARNavigation', 'none')}
          >
            <Scan size={24} />
            <span className="text-[10px] font-medium truncate">AR Nav</span>
          </a>
          <a className="flex flex-col items-center gap-1 flex-1 min-w-0 text-on-surface-variant rounded-lg py-1 cursor-pointer">
            <History size={24} />
            <span className="text-[10px] font-medium truncate">History</span>
          </a>
          <a className="flex flex-col items-center gap-1 flex-1 min-w-0 text-on-surface-variant rounded-lg py-1 cursor-pointer">
            <User size={24} />
            <span className="text-[10px] font-medium truncate">Profile</span>
          </a>
        </div>
      </nav>
    </div>
  );
}
