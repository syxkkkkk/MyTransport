import { ArrowRight } from 'lucide-react';
import { NavigateFunction } from '../types';

export default function WelcomeScreen({ navigate }: { navigate: NavigateFunction }) {
  return (
    <div className="bg-background text-on-background font-body-lg h-full flex flex-col items-center justify-center relative overflow-hidden">
      {/* Abstract Background Pattern */}
      <div className="absolute inset-0 pointer-events-none opacity-20 z-0">
        <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-primary-fixed-dim via-transparent to-transparent"></div>
        <div className="absolute bottom-0 left-0 w-full h-full bg-[radial-gradient(ellipse_at_bottom_left,_var(--tw-gradient-stops))] from-surface-tint via-transparent to-transparent opacity-10"></div>
      </div>
      
      {/* Main Content */}
      <main className="z-10 flex flex-col items-center justify-center w-full max-w-md px-margin-mobile flex-1 space-y-xl">
        <div className="flex flex-col items-center space-y-md animate-fade-in-up" style={{ animationDelay: '0.2s', animationFillMode: 'both' }}>
          <img 
            alt="MyTransport Malaysia Logo" 
            className="w-32 h-32 rounded shadow-sm object-contain" 
            src="https://lh3.googleusercontent.com/aida-public/AB6AXuBV-MBafhuN1xSdHHX6FFYGzEHrKnnCoDX87dVFvYVSP4YlFZDbZXZjoiebEHG3C7IIqthh0iuAORTnJtJCAU4oHDLpAGjExCaPewGOhXnHBuE4pr3MwdUnRRpG41N5EWdDOy6iBvgqvmftwDwJAK6x9FCpR4NdoDA18TcqqKrC4n2THF3crEnwhFLd05dV9_hhHrKfsUCUpKFYvr9XAfuPGyUWQ580ZDT3edhA84-CDPvHsesgie3YHVoV4wYCrHrqFewsEhLiZUA" 
          />
        </div>
        <div className="text-center space-y-xs animate-fade-in-up" style={{ animationDelay: '0.4s', animationFillMode: 'both' }}>
          <h1 className="font-headline-lg-mobile md:font-headline-lg text-primary">
            MyTransport Malaysia
          </h1>
          <p className="font-body-lg text-on-surface-variant">
            Your AI-Powered Travel Partner.
          </p>
        </div>
      </main>
      
      {/* Bottom Action */}
      <div className="w-full max-w-md px-margin-mobile pb-xl z-10 animate-fade-in-up" style={{ animationDelay: '0.6s', animationFillMode: 'both' }}>
        <button 
          onClick={() => navigate('Home', 'push')}
          className="w-full bg-primary-container text-on-primary-container font-headline-md py-sm rounded-lg shadow-sm hover:opacity-90 transition-opacity flex items-center justify-center gap-2"
        >
          <span>Get Started</span>
          <ArrowRight size={24} />
        </button>
      </div>
    </div>
  );
}
