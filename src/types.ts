/**
 * Background Location Tracking API Tipleri
 *  profesyonel location tracking sistemi
 */

export interface Location {
  /** Konum koordinatları */
  coords: Coordinates;
  /** Timestamp (milliseconds) */
  timestamp: number;
  /** UUID */
  uuid: string;
  /** Aktivite tipi */
  activity?: Activity;
  /** Batarya seviyesi */
  battery?: Battery;
  /** Hareket halinde mi? */
  is_moving?: boolean;
  /** Odometer (km) */
  odometer?: number;
  /** Ekstra veriler */
  extras?: Record<string, any>;
}

export interface Coordinates {
  /** Enlem */
  latitude: number;
  /** Boylam */
  longitude: number;
  /** Doğruluk (metre) */
  accuracy: number;
  /** Hız (m/s) */
  speed: number;
  /** Yön (derece) */
  heading: number;
  /** İrtifa (metre) */
  altitude: number;
  /** İrtifa doğruluğu (metre) */
  altitude_accuracy: number;
}

export interface Activity {
  /** Aktivite tipi: still, on_foot, walking, running, in_vehicle, on_bicycle */
  type: 'still' | 'on_foot' | 'walking' | 'running' | 'in_vehicle' | 'on_bicycle' | 'unknown';
  /** Güven seviyesi (0-100) */
  confidence: number;
}

export interface Battery {
  /** Batarya seviyesi (0-1) */
  level: number;
  /** Şarj oluyor mu? */
  is_charging: boolean;
}

export interface Config {
  // Konum Ayarları
  /** Başlangıçta lokasyonları temizle */
  clearLocationsOnStart?: boolean;
  /** Konum doğruluğu (metre) */
  desiredAccuracy?: number;
  /** Minimum mesafe filtresi (metre) */
  distanceFilter?: number;
  /** Durağan konum tespit mesafesi (metre) */
  stationaryRadius?: number;
  /** Konum güncellemesi aralığı (ms) */
  locationUpdateInterval?: number;
  /** En hızlı konum aralığı (ms) */
  fastestLocationUpdateInterval?: number;
  
  // Aktivite Tanıma
  /** Aktivite tanıma aktif mi? */
  activityRecognitionInterval?: number;
  /** Stop tespit dakikası */
  stopTimeout?: number;
  /** Stop detection */
  stopOnStationary?: boolean;
  /** Initial moving state */
  isMoving?: boolean;
  
  // Hareket Algılama
  /** Hareket algılama aktif mi? */
  disableMotionActivityUpdates?: boolean;
  /** Dinamik interval devre dışı mı? */
  disableElasticity?: boolean;
  /** Interval çarpanı (elasticity multiplier) */
  elasticityMultiplier?: number;
  
  // Arka Plan Ayarları
  /** Arka plan modu */
  foregroundService?: boolean;
  /** Bildirim başlığı (orijinal Transistorsoft: title) */
  title?: string;
  /** Bildirim metni (orijinal Transistorsoft: text) */
  text?: string;
  /** Bildirim küçük ikonu (orijinal Transistorsoft: smallIcon) */
  smallIcon?: string;
  /** Bildirim büyük ikonu (orijinal Transistorsoft: largeIcon) */
  largeIcon?: string;
  /** Bildirim rengi (orijinal Transistorsoft: color) */
  color?: string;
  /** Bildirim önceliği (orijinal Transistorsoft: priority) */
  priority?: number;
  /** Bildirim kanal adı (orijinal Transistorsoft: channelName) */
  channelName?: string;
  /** Bildirim kanal ID (orijinal Transistorsoft: channelId) */
  channelId?: string;
  
  // Backward compatibility: Eski field isimlerini de destekle (deprecated)
  /** @deprecated Use 'title' instead */
  notificationTitle?: string;
  /** @deprecated Use 'text' instead */
  notificationText?: string;
  /** @deprecated Use 'smallIcon' instead */
  notificationIcon?: string;
  /** @deprecated Use 'largeIcon' instead */
  notificationLargeIcon?: string;
  /** @deprecated Use 'color' instead */
  notificationColor?: string;
  /** @deprecated Use 'priority' instead */
  notificationPriority?: number;
  /** @deprecated Use 'channelName' instead */
  notificationChannelName?: string;
  /** @deprecated Use 'channelId' instead */
  notificationChannelId?: string;
  
  // HTTP / Sync
  /** HTTP endpoint URL */
  url?: string;
  /** HTTP method */
  method?: 'POST' | 'PUT';
  /** HTTP headers */
  headers?: Record<string, string>;
  /** HTTP params */
  params?: Record<string, any>;
  /** Extras (her location'a eklenir) */
  extras?: Record<string, any>;
  /** Otomatik sync aktif mi? */
  autoSync?: boolean;
  /** Sync intervali (saniye) */
  autoSyncThreshold?: number;
  /** Maksimum batch size */
  maxBatchSize?: number;
  /** Maksimum günlük kayıt sayısı */
  maxDaysToPersist?: number;
  /** Maksimum database boyutu (MB) */
  maxRecordsToPersist?: number;
  /** Batch sync aktif mi? */
  batchSync?: boolean;
  
  // Geofence
  /** Geofence aktif mi? */
  geofenceProximityRadius?: number;
  /** Geofence loitering delay (ms) */
  geofenceInitialTriggerEntry?: boolean;
  
  // Güç Yönetimi
  /** Güç tasarrufu modu */
  deferTime?: number;
  /** Allow standby */
  allowIdenticalLocations?: boolean;
  /** Prevent suspend (Android Doze koruması) */
  preventSuspend?: boolean;
  /** Timestamp metadata ekle */
  enableTimestampMeta?: boolean;
  /** Schedule için AlarmManager kullan (Android) */
  scheduleUseAlarmManager?: boolean;
  /** Heartbeat interval (saniye) */
  heartbeatInterval?: number;
  /** Stop after elapsed minutes */
  stopAfterElapsedMinutes?: number;
  
  // Debug
  /** Debug modu */
  debug?: boolean;
  /** Log seviyesi */
  logLevel?: number;
  /** Log maksimum gün sayısı */
  logMaxDays?: number;
  
  // Platform Specific
  /** Android: Enable headless mode */
  enableHeadless?: boolean;
  /** App kill'de durdur */
  stopOnTerminate?: boolean;
  /** Boot'ta başlat */
  startOnBoot?: boolean;
  /** iOS: Background modes */
  pausesLocationUpdatesAutomatically?: boolean;
  /** iOS: Location authorization request type ('Always' | 'WhenInUse') */
  locationAuthorizationRequest?: 'Always' | 'WhenInUse';
  /** iOS: Show background location indicator */
  showsBackgroundLocationIndicator?: boolean;
  /** iOS: Disable location authorization alert */
  disableLocationAuthorizationAlert?: boolean;
}

export interface Geofence {
  /** Unique identifier */
  identifier: string;
  /** Latitude */
  latitude: number;
  /** Longitude */
  longitude: number;
  /** Radius (metre) */
  radius: number;
  /** Entry olayını dinle */
  notifyOnEntry?: boolean;
  /** Exit olayını dinle */
  notifyOnExit?: boolean;
  /** Dwell olayını dinle */
  notifyOnDwell?: boolean;
  /** Loitering delay (ms) */
  loiteringDelay?: number;
  /** Ekstra veriler */
  extras?: Record<string, any>;
}

export interface GeofenceEvent {
  /** Geofence identifier */
  identifier: string;
  /** Aksiyon: ENTER, EXIT, DWELL */
  action: 'ENTER' | 'EXIT' | 'DWELL';
  /** Location */
  location: Location;
  /** Extras */
  extras?: Record<string, any>;
}

export interface ProviderChangeEvent {
  /** GPS aktif mi? */
  gps: boolean;
  /** Network provider aktif mi? */
  network: boolean;
  /** Location servisleri aktif mi? */
  enabled: boolean;
  /** Authorization status */
  status: number;
  /** Accuracy authorization */
  accuracyAuthorization: number;
}

export interface MotionChangeEvent {
  /** Hareket halinde mi? */
  isMoving: boolean;
  /** Location */
  location: Location;
}

export interface ActivityChangeEvent {
  /** Activity */
  activity: Activity;
  /** Güven seviyesi */
  confidence: number;
}

export interface HttpEvent {
  /** HTTP başarılı mı? */
  success: boolean;
  /** HTTP status code */
  status: number;
  /** Response text */
  responseText: string;
}

export interface HeartbeatEvent {
  /** Location */
  location: Location;
}

export interface ConnectivityChangeEvent {
  /** İnternet bağlantısı var mı? */
  connected: boolean;
}

export interface State extends Config {
  /** Tracking aktif mi? */
  enabled: boolean;
  /** Hareket halinde mi? */
  isMoving?: boolean;
  /** Odometer (km) */
  odometer?: number;
}

export interface CurrentPositionOptions {
  /** Timeout (ms) */
  timeout?: number;
  /** Maksimum yaş (ms) */
  maximumAge?: number;
  /** İstenilen doğruluk (metre) */
  desiredAccuracy?: number;
  /** Kalıcı olarak kaydet */
  persist?: boolean;
  /** Sample sayısı */
  samples?: number;
  /** Ekstra veriler */
  extras?: Record<string, any>;
}

export interface WatchPositionOptions {
  /** Güncelleme aralığı (ms) */
  interval?: number;
  /** İstenilen doğruluk (metre) */
  desiredAccuracy?: number;
  /** Kalıcı olarak kaydet */
  persist?: boolean;
  /** Ekstra veriler */
  extras?: Record<string, any>;
}

export interface DeviceInfo {
  /** Platform: ios, android */
  platform: string;
  /** İşletim sistemi versiyonu */
  version: string;
  /** Cihaz modeli */
  model: string;
  /** Üretici */
  manufacturer: string;
  /** Framework */
  framework: string;
}

export interface Sensors {
  /** Platform */
  platform: string;
  /** Accelerometer var mı? */
  accelerometer: boolean;
  /** Magnetometer var mı? */
  magnetometer: boolean;
  /** Gyroscope var mı? */
  gyroscope: boolean;
  /** Significant motion var mı? */
  significant_motion: boolean;
}

/** Event listener callback types */
export type LocationCallback = (location: Location) => void;
export type MotionChangeCallback = (event: MotionChangeEvent) => void;
export type ActivityChangeCallback = (event: ActivityChangeEvent) => void;
export type ProviderChangeCallback = (event: ProviderChangeEvent) => void;
export type GeofenceCallback = (event: GeofenceEvent) => void;
export type GeofencesChangeCallback = (event: { on: Geofence[]; off: Geofence[] }) => void;
export type HeartbeatCallback = (event: HeartbeatEvent) => void;
export type HttpCallback = (event: HttpEvent) => void;
export type ConnectivityChangeCallback = (event: ConnectivityChangeEvent) => void;
export type EnabledChangeCallback = (enabled: boolean) => void;
export type PowerSaveChangeCallback = (isPowerSaveMode: boolean) => void;
export type NotificationActionCallback = (buttonId: string) => void;

/** Authorization status constants */
export enum AuthorizationStatus {
  NOT_DETERMINED = 0,
  RESTRICTED = 1,
  DENIED = 2,
  ALWAYS = 3,
  WHEN_IN_USE = 4,
}

/** Location accuracy constants */
export enum LocationAccuracy {
  NAVIGATION = -2,
  BEST = -1,
  TEN_METERS = 10,
  HUNDRED_METERS = 100,
  KILOMETER = 1000,
  THREE_KILOMETERS = 3000,
}

/** Desired accuracy constants () */
export namespace DesiredAccuracy {
  export const LOW = 1000;      // 1 km
  export const MEDIUM = 100;    // 100 metre
  export const HIGH = 10;       // 10 metre
}

// Export as individual constants for convenience
export const DESIRED_ACCURACY_LOW = DesiredAccuracy.LOW;
export const DESIRED_ACCURACY_MEDIUM = DesiredAccuracy.MEDIUM;
export const DESIRED_ACCURACY_HIGH = DesiredAccuracy.HIGH;

/** Log level constants */
export enum LogLevel {
  OFF = 0,
  ERROR = 1,
  WARNING = 2,
  INFO = 3,
  DEBUG = 4,
  VERBOSE = 5,
}

/** Notification priority constants */
export enum NotificationPriority {
  MIN = -2,
  LOW = -1,
  DEFAULT = 0,
  HIGH = 1,
  MAX = 2,
}

// Default export for TypeScript compatibility
export default {};

