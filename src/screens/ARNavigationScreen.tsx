import { X, ArrowUp, Volume2, LocateFixed } from 'lucide-react';
import { NavigateFunction } from '../types';

export default function ARNavigationScreen({ navigate }: { navigate: NavigateFunction }) {
  return (
    <div className="font-body-lg text-on-surface antialiased h-full w-full bg-black relative overflow-hidden">
      <div 
        className="absolute top-0 left-0 w-full h-full z-0 bg-cover bg-center" 
        style={{ backgroundImage: "url('https://lh3.googleusercontent.com/aida-public/AB6AXuAu85AV9lXuMTvTcGbsbswqGGk2SFnWPQgGjBBh4X1cX76glxmFcipDhkwExRCTu9cxAsqNNF4nN0_4bh-PcdToIkmyI0fcAim7X3GZVxlKtay7p6o09jH4CzFAxgXJpB73JlnvTxp-semeXMuAZyOMKabu5IeuQLU5YYIPUiVynWnNYa51O9HNMAyZStPacfytAOmqn937yYFxMhb7dYjGYyiSZ-IXvBdu2daxUj9P4efItG2fzCNAYmfQor7UIeeZmIBD-90buH0')" }}
      ></div>

      <div className="absolute bottom-[20%] left-1/2 -translate-x-1/2 w-[120px] h-[200px] z-10" style={{
        background: 'linear-gradient(to top, rgba(0, 77, 153, 0), rgba(0, 77, 153, 0.8))',
        clipPath: 'polygon(50% 0%, 100% 50%, 75% 50%, 75% 100%, 25% 100%, 25% 50%, 0% 50%)',
        animation: 'pulse-arrow 2s infinite ease-in-out'
      }}></div>

      <div className="fixed top-0 w-full z-50 flex items-center justify-between px-margin-mobile h-14 bg-surface/85 backdrop-blur-md border hover:bg-surface/90 transition-colors rounded-b-xl shadow-sm border-white/30">
        <button 
          className="w-10 h-10 flex items-center justify-center rounded-full text-on-surface hover:bg-surface-variant transition-colors active:scale-95"
          onClick={() => navigate('RouteDetails', 'push_back')}
        >
          <X size={24} />
          <span className="hidden sr-only">close</span>
        </button>
        <h1 className="font-headline-md font-bold text-primary">AR Navigation</h1>
        <div className="w-10"></div>
      </div>

      <div className="fixed top-20 left-margin-mobile right-margin-mobile z-40">
        <div className="bg-surface/85 backdrop-blur-md rounded-xl p-md shadow-lg flex items-start gap-md border border-outline-variant/30">
          <div className="w-12 h-12 rounded-full bg-primary flex items-center justify-center flex-shrink-0 shadow-sm">
            <ArrowUp size={28} className="text-on-primary" />
          </div>
          <div className="flex-1">
            <p className="font-headline-md text-on-surface font-semibold mb-base">Walk straight 200m</p>
            <p className="font-body-sm text-on-surface-variant">towards Muzium Negara MRT</p>
          </div>
        </div>
      </div>

      <div className="fixed right-margin-mobile top-1/2 -translate-y-1/2 z-40 flex flex-col gap-sm">
        <button className="w-12 h-12 rounded-full bg-surface shadow-md flex items-center justify-center text-primary">
          <Volume2 size={24} />
        </button>
        <button className="w-12 h-12 rounded-full bg-surface shadow-md flex items-center justify-center text-on-surface-variant">
          <LocateFixed size={24} />
        </button>
      </div>

      <div className="fixed bottom-0 left-0 w-full z-50 bg-surface/85 backdrop-blur-md rounded-t-xl shadow-sm pb-10">
        <div className="p-md">
          <div className="flex justify-between items-end mb-sm">
            <div>
              <p className="font-headline-lg-mobile text-primary font-bold">150m</p>
              <p className="font-body-sm text-on-surface-variant">remaining</p>
            </div>
            <div className="text-right">
              <p className="font-body-lg text-on-surface font-medium">2 mins</p>
              <p className="font-body-sm text-on-surface-variant">Estimated arrival</p>
            </div>
          </div>
          <div 
            className="w-full h-2 bg-surface-variant rounded-full overflow-hidden cursor-pointer"
            onClick={() => navigate('TripSummary', 'push')}
          >
            <div className="h-full bg-primary rounded-full transition-all duration-1000 ease-in-out" style={{ width: '25%' }}></div>
          </div>
        </div>
      </div>
    </div>
  );
}
