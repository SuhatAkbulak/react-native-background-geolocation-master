 
import { NativeModules, NativeEventEmitter, Platform } from 'react-native';
import type {
  Config,
  State,
  Location,
  Geofence,
  GeofenceEvent,
  MotionChangeEvent,
  ActivityChangeEvent,
  ProviderChangeEvent,
  HttpEvent,
  HeartbeatEvent,
  ConnectivityChangeEvent,
  CurrentPositionOptions,
  WatchPositionOptions,
  DeviceInfo,
  Sensors,
  Activity,
  LocationCallback,
  MotionChangeCallback,
  ActivityChangeCallback,
  ProviderChangeCallback,
  GeofenceCallback,
  GeofencesChangeCallback,
  HeartbeatCallback,
  HttpCallback,
  ConnectivityChangeCallback,
  EnabledChangeCallback,
  PowerSaveChangeCallback,
  NotificationActionCallback,
} from './types';

const LINKING_ERROR =
  `The package 'react-native-background-location' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- Run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo managed workflow\n' +
  '- If using New Architecture, make sure the module is properly registered\n';

// React Native modülünü yükle
// Önce NativeModules'den dene (hem eski hem yeni mimari için)
const RNBackgroundLocation = NativeModules.RNBackgroundLocation
  ? NativeModules.RNBackgroundLocation
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

const eventEmitter = new NativeEventEmitter(RNBackgroundLocation);

/**
 * Background Location API Class
 */
class BackgroundLocation {
  private static _instance: BackgroundLocation;
  private _isReady: boolean = false;
  private _listeners: Map<string, any> = new Map();
  private _eventSubscriptions: Map<string, any> = new Map(); // Event bazında subscription'ları takip et
  private _activeEventListeners: Map<string, any> = new Map(); // Event -> Subscription mapping (duplicate prevention)

  private constructor() {}

  static getInstance(): BackgroundLocation {
    if (!BackgroundLocation._instance) {
      BackgroundLocation._instance = new BackgroundLocation();
    }
    return BackgroundLocation._instance;
  }

  /**
   * Eklentiyi hazırla ve yapılandır
   * @param config Konfigürasyon objesi
   * @returns Promise<State>
   */
  async ready(config: Config): Promise<State> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.ready(
        config,
        (state: State) => {
          this._isReady = true;
          resolve(state);
        },
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Yapılandırmayı sıfırla ve yeniden yapılandır
   * @param config Konfigürasyon objesi
   * @returns Promise<State>
   */
  async configure(config: Config): Promise<State> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.configure(
        config,
        (state: State) => {
          this._isReady = true;
          resolve(state);
        },
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Yapılandırmayı güncelle (reset etmeden)
   * @param config Konfigürasyon objesi
   * @returns Promise<State>
   */
  async setConfig(config: Config): Promise<State> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.setConfig(
        config,
        (state: State) => resolve(state),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Yapılandırmayı sıfırla
   * @param config Varsayılan konfigürasyon
   * @returns Promise<State>
   */
  async reset(config?: Config): Promise<State> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.reset(
        config || {},
        (state: State) => resolve(state),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Location tracking'i başlat
   * @returns Promise<State>
   */
  async start(): Promise<State> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.start(
        (state: State) => resolve(state),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Location tracking'i durdur
   * @returns Promise<State>
   */
  async stop(): Promise<State> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.stop(
        (state: State) => resolve(state),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Geofence tracking'i başlat
   * @returns Promise<State>
   */
  async startGeofences(): Promise<State> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.startGeofences(
        (state: State) => resolve(state),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Zamanlama tabanlı tracking'i başlat
   * @returns Promise<State>
   */
  async startSchedule(): Promise<State> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.startSchedule(
        (state: State) => resolve(state),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Zamanlama tabanlı tracking'i durdur
   * @returns Promise<State>
   */
  async stopSchedule(): Promise<State> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.stopSchedule(
        (state: State) => resolve(state),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Hareket durumunu değiştir (moving/stationary)
   * @param isMoving Hareket halinde mi?
   * @returns Promise<void>
   */
  async changePace(isMoving: boolean): Promise<void> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.changePace(
        isMoving,
        () => resolve(),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Güncel konumu al (tek seferlik)
   * @param options Konum ayarları
   * @returns Promise<Location>
   */
  async getCurrentPosition(
    options?: CurrentPositionOptions
  ): Promise<Location> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.getCurrentPosition(
        options || {},
        (location: Location) => resolve(location),
        (error: string | number) => reject(error)
      );
    });
  }

  /**
   * Konumu sürekli izle
   * @param options İzleme ayarları
   * @returns Promise<void>
   */
  async watchPosition(options?: WatchPositionOptions): Promise<void> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.watchPosition(
        options || {},
        () => resolve(),
        (error: string | number) => reject(error)
      );
    });
  }

  /**
   * Konum izlemeyi durdur
   * @returns Promise<void>
   */
  async stopWatchPosition(): Promise<void> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.stopWatchPosition(
        () => resolve(),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Mevcut durumu al
   * @returns Promise<State>
   */
  async getState(): Promise<State> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.getState(
        (state: State) => resolve(state),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Kaydedilmiş konumları al
   * @returns Promise<Location[]>
   */
  async getLocations(): Promise<Location[]> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.getLocations(
        (locations: Location[]) => resolve(locations),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Kaydedilmiş konum sayısını al
   * @returns Promise<number>
   */
  async getCount(): Promise<number> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.getCount(
        (count: number) => resolve(count),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Manuel konum ekle
   * @param location Konum objesi
   * @returns Promise<string> UUID
   */
  async insertLocation(location: Partial<Location>): Promise<string> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.insertLocation(
        location,
        (uuid: string) => resolve(uuid),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Tüm kayıtlı konumları sil
   * @returns Promise<void>
   */
  async destroyLocations(): Promise<void> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.destroyLocations(
        () => resolve(),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Belirli bir konumu sil
   * @param uuid Konum UUID'si
   * @returns Promise<void>
   */
  async destroyLocation(uuid: string): Promise<void> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.destroyLocation(
        uuid,
        () => resolve(),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Konumları sunucuya senkronize et
   * @returns Promise<Location[]> Senkronize edilen konumlar
   */
  async sync(): Promise<Location[]> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.sync(
        (locations: Location[]) => resolve(locations),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Odometer değerini al
   * @returns Promise<number> Kilometre
   */
  async getOdometer(): Promise<number> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.getOdometer(
        (odometer: number) => resolve(odometer),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Odometer değerini ayarla
   * @param value Kilometre değeri
   * @returns Promise<Location>
   */
  async setOdometer(value: number): Promise<Location> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.setOdometer(
        value,
        (location: Location) => resolve(location),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Geofence ekle
   * @param geofence Geofence objesi
   * @returns Promise<void>
   */
  async addGeofence(geofence: Geofence): Promise<void> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.addGeofence(
        geofence,
        () => resolve(),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Birden fazla geofence ekle
   * @param geofences Geofence array
   * @returns Promise<void>
   */
  async addGeofences(geofences: Geofence[]): Promise<void> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.addGeofences(
        geofences,
        () => resolve(),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Geofence kaldır
   * @param identifier Geofence ID
   * @returns Promise<void>
   */
  async removeGeofence(identifier: string): Promise<void> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.removeGeofence(
        identifier,
        () => resolve(),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Tüm geofence'leri kaldır
   * @returns Promise<void>
   */
  async removeGeofences(): Promise<void> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.removeGeofences(
        () => resolve(),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Geofence'leri al
   * @returns Promise<Geofence[]>
   */
  async getGeofences(): Promise<Geofence[]> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.getGeofences(
        (geofences: Geofence[]) => resolve(geofences),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Belirli bir geofence'i al
   * @param identifier Geofence ID
   * @returns Promise<Geofence>
   */
  async getGeofence(identifier: string): Promise<Geofence> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.getGeofence(
        identifier,
        (geofence: Geofence) => resolve(geofence),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Geofence var mı kontrol et
   * @param identifier Geofence ID
   * @returns Promise<boolean>
   */
  async geofenceExists(identifier: string): Promise<boolean> {
    return new Promise((resolve) => {
      RNBackgroundLocation.geofenceExists(identifier, (exists: boolean) =>
        resolve(exists)
      );
    });
  }

  /**
   * Konum izinlerini iste
   * @returns Promise<number> Authorization status
   */
  async requestPermission(): Promise<number> {
    return new Promise((resolve) => {
      RNBackgroundLocation.requestPermission((status: number) =>
        resolve(status)
      );
    });
  }

  /**
   * Güç tasarrufu modunda mı?
   * @returns Promise<boolean>
   */
  async isPowerSaveMode(): Promise<boolean> {
    return new Promise((resolve) => {
      RNBackgroundLocation.isPowerSaveMode((isPowerSave: boolean) =>
        resolve(isPowerSave)
      );
    });
  }

  /**
   * Cihaz bilgilerini al
   * @returns Promise<DeviceInfo>
   */
  async getDeviceInfo(): Promise<DeviceInfo> {
    return new Promise((resolve) => {
      RNBackgroundLocation.getDeviceInfo((info: DeviceInfo) => resolve(info));
    });
  }

  /**
   * Sensör bilgilerini al
   * @returns Promise<Sensors>
   */
  async getSensors(): Promise<Sensors> {
    return new Promise((resolve) => {
      RNBackgroundLocation.getSensors((sensors: Sensors) => resolve(sensors));
    });
  }

  /**
   * Son aktiviteyi al ()
   * @returns Promise<Activity>
   */
  async getActivity(): Promise<Activity> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.getActivity(
        (activity: Activity) => resolve(activity),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Hareket halinde mi kontrol et ()
   * @returns Promise<boolean>
   */
  async isMoving(): Promise<boolean> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.isMoving(
        (moving: boolean) => resolve(moving),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Arka planda mı kontrol et ()
   * @returns Promise<boolean>
   */
  async isBackground(): Promise<boolean> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.isBackground(
        (background: boolean) => resolve(background),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Headless mode'da mı kontrol et ()
   * @returns Promise<boolean>
   */
  async isHeadless(): Promise<boolean> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.isHeadless(
        (headless: boolean) => resolve(headless),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Provider durumunu al
   * @returns Promise<ProviderChangeEvent>
   */
  async getProviderState(): Promise<ProviderChangeEvent> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.getProviderState(
        (state: ProviderChangeEvent) => resolve(state),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Log kayıtlarını sil
   * @returns Promise<boolean>
   */
  async destroyLog(): Promise<boolean> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.destroyLog(
        (success: boolean) => resolve(success),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Log kayıtlarını al ()
   * @param params SQL query parametreleri (limit, order, etc.)
   * @returns Promise<string[]> Log satırları
   */
  async getLog(params?: { limit?: number; order?: 'ASC' | 'DESC' }): Promise<string[]> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.getLog(
        params || {},
        (logs: string[]) => resolve(logs),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Log kayıtlarını email ile gönder ()
   * @param email Email adresi
   * @param params SQL query parametreleri
   * @returns Promise<boolean>
   */
  async emailLog(email: string, params?: { limit?: number; order?: 'ASC' | 'DESC' }): Promise<boolean> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.emailLog(
        email,
        params || {},
        (success: boolean) => resolve(success),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Cihaz ayarlarını iste ()
   * @param action Ayarlar action'ı (batteryOptimization, etc.)
   * @returns Promise<any> Settings request objesi
   */
  async requestSettings(action: string): Promise<any> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.requestSettings(
        { action },
        (settings: any) => resolve(settings),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Cihaz ayarlarını göster ()
   * @param action Ayarlar action'ı
   * @returns Promise<void>
   */
  async showSettings(action: string): Promise<void> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.showSettings(
        { action },
        () => resolve(),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Geçici tam doğruluk iste (Android 12+ - )
   * @param purpose Amaç açıklaması
   * @returns Promise<number> Accuracy authorization status
   */
  async requestTemporaryFullAccuracy(purpose: string): Promise<number> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.requestTemporaryFullAccuracy(
        purpose,
        (status: number) => resolve(status),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Batarya optimizasyonlarını yok sayıyor mu? ()
   * @returns Promise<boolean>
   */
  async isIgnoringBatteryOptimizations(): Promise<boolean> {
    return new Promise((resolve, reject) => {
      RNBackgroundLocation.isIgnoringBatteryOptimizations(
        (ignoring: boolean) => resolve(ignoring),
        (error: string) => reject(error)
      );
    });
  }

  /**
   * Ses çal (debug için)
   * @param soundId Ses ID
   */
  playSound(soundId: string): void {
    RNBackgroundLocation.playSound(soundId);
  }

  // Event Listeners

  /**
   * Location event listener
   */
  onLocation(callback: LocationCallback): () => void {
    return this._addEventListener('location', callback);
  }

  /**
   * Motion change event listener
   */
  onMotionChange(callback: MotionChangeCallback): () => void {
    return this._addEventListener('motionchange', callback);
  }

  /**
   * Activity change event listener
   */
  onActivityChange(callback: ActivityChangeCallback): () => void {
    return this._addEventListener('activitychange', callback);
  }

  /**
   * Provider change event listener
   */
  onProviderChange(callback: ProviderChangeCallback): () => void {
    return this._addEventListener('providerchange', callback);
  }

  /**
   * Geofence event listener
   */
  onGeofence(callback: GeofenceCallback): () => void {
    return this._addEventListener('geofence', callback);
  }

  /**
   * Geofences change event listener
   */
  onGeofencesChange(callback: GeofencesChangeCallback): () => void {
    return this._addEventListener('geofenceschange', callback);
  }

  /**
   * Heartbeat event listener
   */
  onHeartbeat(callback: HeartbeatCallback): () => void {
    return this._addEventListener('heartbeat', callback);
  }

  /**
   * HTTP event listener
   */
  onHttp(callback: HttpCallback): () => void {
    return this._addEventListener('http', callback);
  }

  /**
   * Connectivity change event listener
   */
  onConnectivityChange(callback: ConnectivityChangeCallback): () => void {
    return this._addEventListener('connectivitychange', callback);
  }

  /**
   * Enabled change event listener
   */
  onEnabledChange(callback: EnabledChangeCallback): () => void {
    return this._addEventListener('enabledchange', callback);
  }

  /**
   * Power save change event listener
   */
  onPowerSaveChange(callback: PowerSaveChangeCallback): () => void {
    return this._addEventListener('powersavechange', callback);
  }

  /**
   * Notification action event listener
   */
  onNotificationAction(callback: NotificationActionCallback): () => void {
    return this._addEventListener('notificationaction', callback);
  }

  /**
   * Watch position event listener
   */
  onWatchPosition(callback: LocationCallback): () => void {
    return this._addEventListener('watchposition', callback);
  }

  /**
   * Tüm event listener'ları kaldır
   */
  removeAllListeners(): void {
    this._listeners.forEach((subscription) => subscription.remove());
    this._listeners.clear();
    this._eventSubscriptions.clear();
    this._activeEventListeners.clear(); // Cleanup active listeners map
  }

  // Private Methods

  private _addEventListener(event: string, callback: Function): () => void {
    // CRITICAL: Duplicate prevention - aynı event için önceki listener'ı kaldır
    // Bu, useEffect'in birden fazla kez çalışması durumunda duplicate listener'ları önler
    const existingSubscription = this._activeEventListeners.get(event);
    if (existingSubscription) {
      try {
        existingSubscription.remove();
        console.warn(`⚠️ Duplicate listener removed for event: ${event}`);
      } catch (e) {
        // Ignore - subscription zaten kaldırılmış olabilir
      }
      this._activeEventListeners.delete(event);
      
      // Ayrıca _listeners Map'inden de kaldır
      const existingKey = Array.from(this._listeners.keys()).find(key => key.startsWith(`${event}_`));
      if (existingKey) {
        this._listeners.delete(existingKey);
      }
    }
    
    // CRITICAL: Yeni listener ekle - her event için sadece BİR listener olmalı
    // NativeEventEmitter.addListener her çağrıldığında yeni bir listener ekler
    // Bu yüzden önceki listener'ı mutlaka kaldırmalıyız
    const subscription = eventEmitter.addListener(event, (data: any) => {
      // CRITICAL: Callback'i sadece bir kez çağır (duplicate prevention)
      try {
        // CRITICAL: enabledchange ve powersavechange event'leri için data.enabled veya data.isPowerSaveMode extract et
        // Native tarafından { enabled: boolean } veya { isPowerSaveMode: boolean } olarak geliyor
        // Ama callback boolean bekliyor
        if (event === 'enabledchange' && typeof data === 'object' && 'enabled' in data) {
          callback(data.enabled);
        } else if (event === 'powersavechange' && typeof data === 'object' && 'isPowerSaveMode' in data) {
          callback(data.isPowerSaveMode);
        } else {
          callback(data);
        }
      } catch (error) {
        console.error(`Error in ${event} listener:`, error);
      }
    });
    
    const key = `${event}_${Date.now()}_${Math.random()}`;
    this._listeners.set(key, subscription);
    this._activeEventListeners.set(event, subscription); // Event -> Subscription mapping

    return () => {
      try {
        subscription.remove();
      } catch (e) {
        // Ignore - subscription zaten kaldırılmış olabilir
      }
      this._listeners.delete(key);
      this._activeEventListeners.delete(event); // Cleanup
    };
  }
}

// Export singleton instance
const backgroundLocation = BackgroundLocation.getInstance();

export default backgroundLocation;

// Export types
export * from './types';

// Export constants
export { 
  AuthorizationStatus, 
  LocationAccuracy, 
  LogLevel, 
  NotificationPriority,
  DESIRED_ACCURACY_LOW,
  DESIRED_ACCURACY_MEDIUM,
  DESIRED_ACCURACY_HIGH
} from './types';



