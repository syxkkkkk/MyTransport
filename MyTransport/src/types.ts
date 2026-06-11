export type ScreenName =
  | 'Welcome'
  | 'Home'
  | 'LocationSelection'
  | 'RouteDetails'
  | 'Chatbot'
  | 'TripSummary'
  | 'ARNavigation'
  | 'LiveTrainNotifications';

export type TransitionType = 'push' | 'push_back' | 'slide_up' | 'none';

export interface NavigateFunction {
  (screen: ScreenName, transition?: TransitionType): void;
}
