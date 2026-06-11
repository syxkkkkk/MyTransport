import { useState } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { ScreenName, TransitionType } from './types';
import WelcomeScreen from './screens/WelcomeScreen';
import HomeScreen from './screens/HomeScreen';
import LocationSelectionScreen from './screens/LocationSelectionScreen';
import RouteDetailsScreen from './screens/RouteDetailsScreen';
import ChatbotScreen from './screens/ChatbotScreen';
import TripSummaryScreen from './screens/TripSummaryScreen';
import ARNavigationScreen from './screens/ARNavigationScreen';
import LiveTrainNotificationsScreen from './screens/LiveTrainNotificationsScreen';

export default function App() {
  const [currentScreen, setCurrentScreen] = useState<ScreenName>('Welcome');
  const [transitionType, setTransitionType] = useState<TransitionType>('push');

  const navigate = (screen: ScreenName, transition: TransitionType = 'push') => {
    setTransitionType(transition);
    setCurrentScreen(screen);
  };

  const variants = {
    push: {
      initial: { x: '100%', opacity: 0 },
      animate: { x: 0, opacity: 1 },
      exit: { x: '-100%', opacity: 0 },
    },
    push_back: {
      initial: { x: '-100%', opacity: 0 },
      animate: { x: 0, opacity: 1 },
      exit: { x: '100%', opacity: 0 },
    },
    slide_up: {
      initial: { y: '100%', opacity: 0 },
      animate: { y: 0, opacity: 1 },
      exit: { y: '100%', opacity: 0 },
    },
    none: {
      initial: { opacity: 0 },
      animate: { opacity: 1 },
      exit: { opacity: 0 },
    },
  };

  const getVariants = () => variants[transitionType];

  return (
    <div className="relative w-full h-[100dvh] overflow-hidden bg-background">
      <AnimatePresence mode="wait">
        <motion.div
          key={currentScreen}
          initial="initial"
          animate="animate"
          exit="exit"
          variants={getVariants()}
          transition={{ duration: 0.3, ease: 'easeInOut' }}
          className="absolute inset-0 w-full h-full"
        >
          {currentScreen === 'Welcome' && <WelcomeScreen navigate={navigate} />}
          {currentScreen === 'Home' && <HomeScreen navigate={navigate} />}
          {currentScreen === 'LocationSelection' && <LocationSelectionScreen navigate={navigate} />}
          {currentScreen === 'RouteDetails' && <RouteDetailsScreen navigate={navigate} />}
          {currentScreen === 'Chatbot' && <ChatbotScreen navigate={navigate} />}
          {currentScreen === 'TripSummary' && <TripSummaryScreen navigate={navigate} />}
          {currentScreen === 'ARNavigation' && <ARNavigationScreen navigate={navigate} />}
          {currentScreen === 'LiveTrainNotifications' && <LiveTrainNotificationsScreen navigate={navigate} />}
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
