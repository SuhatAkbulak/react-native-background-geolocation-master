/**
 * React Native Background Location - Örnek Uygulama
 *  profesyonel location tracking
 */

import React, { useEffect, useState } from 'react';
import {
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  Alert,
  Platform,
} from 'react-native';

import BackgroundLocation, {
  Location,
  Config,
  State,
  MotionChangeEvent,
  GeofenceEvent,
  HttpEvent,
} from 'react-native-background-location';

const App = () => {
  const [isTracking, setIsTracking] = useState(false);
  const [currentLocation, setCurrentLocation] = useState<Location | null>(null);
  const [locationCount, setLocationCount] = useState(0);
  const [odometer, setOdometer] = useState(0);
  const [config, setConfig] = useState<State | null>(null);

  useEffect(() => {
    initializeBackgroundLocation();

    // Event listeners
    const locationSub = BackgroundLocation.onLocation(handleLocation);
    const motionSub = BackgroundLocation.onMotionChange(handleMotionChange);
    const geofenceSub = BackgroundLocation.onGeofence(handleGeofence);
    const httpSub = BackgroundLocation.onHttp(handleHttp);

    return () => {
      locationSub();
      motionSub();
      geofenceSub();
      httpSub();
    };
  }, []);

  const initializeBackgroundLocation = async () => {
    try {
      // Konfigürasyon
      const config: Config = {
        // Konum ayarları
        desiredAccuracy: 10, // 10 metre doğruluk
        distanceFilter: 10, // 10 metre mesafe filtresi
        stationaryRadius: 25,
        locationUpdateInterval: 10000, // 10 saniye
        fastestLocationUpdateInterval: 5000,

        // Arka plan servisi
        foregroundService: true,
        notificationTitle: 'Konum Takibi Aktif',
        notificationText: 'Konumunuz arka planda izleniyor',
        notificationColor: '#3498db',

        // HTTP Sync (opsiyonel)
        // url: 'https://your-server.com/api/locations',
        // method: 'POST',
        // autoSync: true,
        // autoSyncThreshold: 10,

        // Debug
        debug: true,
        logLevel: 5, // VERBOSE
      };

      // Hazırla
      const state = await BackgroundLocation.ready(config);
      setConfig(state);
      setIsTracking(state.enabled);

      console.log('Background Location hazır:', state);

      // İzinleri kontrol et
      const status = await BackgroundLocation.requestPermission();
      console.log('İzin durumu:', status);
    } catch (error) {
      console.error('Initialization error:', error);
      Alert.alert('Hata', 'Location servisi başlatılamadı: ' + error);
    }
  };

  const handleLocation = (location: Location) => {
    console.log('[Location]', location);
    setCurrentLocation(location);
    
    // Odometer güncelle
    if (location.odometer) {
      setOdometer(location.odometer);
    }
  };

  const handleMotionChange = (event: MotionChangeEvent) => {
    console.log('[Motion Change]', event.isMoving ? 'MOVING' : 'STATIONARY');
    Alert.alert(
      'Hareket Değişikliği',
      event.isMoving ? 'Hareket ediyorsunuz' : 'Durağansınız'
    );
  };

  const handleGeofence = (event: GeofenceEvent) => {
    console.log('[Geofence]', event);
    Alert.alert(
      'Geofence Olayı',
      `${event.identifier}: ${event.action}`
    );
  };

  const handleHttp = (event: HttpEvent) => {
    console.log('[HTTP]', event);
    if (!event.success) {
      Alert.alert('HTTP Hatası', `Status: ${event.status}`);
    }
  };

  const startTracking = async () => {
    try {
      const state = await BackgroundLocation.start();
      setIsTracking(true);
      Alert.alert('Başarılı', 'Konum takibi başlatıldı');
      console.log('Tracking started:', state);
    } catch (error) {
      Alert.alert('Hata', 'Başlatılamadı: ' + error);
    }
  };

  const stopTracking = async () => {
    try {
      const state = await BackgroundLocation.stop();
      setIsTracking(false);
      Alert.alert('Başarılı', 'Konum takibi durduruldu');
      console.log('Tracking stopped:', state);
    } catch (error) {
      Alert.alert('Hata', 'Durdurulamadı: ' + error);
    }
  };

  const getCurrentPosition = async () => {
    try {
      const location = await BackgroundLocation.getCurrentPosition({
        timeout: 30000,
        maximumAge: 5000,
        desiredAccuracy: 10,
        persist: false,
      });
      
      setCurrentLocation(location);
      Alert.alert(
        'Güncel Konum',
        `Lat: ${location.coords.latitude.toFixed(6)}\n` +
        `Lng: ${location.coords.longitude.toFixed(6)}\n` +
        `Doğruluk: ${location.coords.accuracy.toFixed(1)}m`
      );
    } catch (error) {
      Alert.alert('Hata', 'Konum alınamadı: ' + error);
    }
  };

  const getStoredLocations = async () => {
    try {
      const locations = await BackgroundLocation.getLocations();
      const count = await BackgroundLocation.getCount();
      
      setLocationCount(count);
      Alert.alert('Kayıtlı Konumlar', `Toplam: ${count} konum`);
      console.log('Stored locations:', locations);
    } catch (error) {
      Alert.alert('Hata', 'Konumlar alınamadı: ' + error);
    }
  };

  const clearLocations = async () => {
    try {
      await BackgroundLocation.destroyLocations();
      setLocationCount(0);
      Alert.alert('Başarılı', 'Tüm konumlar silindi');
    } catch (error) {
      Alert.alert('Hata', 'Silinemedi: ' + error);
    }
  };

  const addTestGeofence = async () => {
    try {
      // Test geofence ekle (mevcut konumunuzun yakınına)
      if (!currentLocation) {
        Alert.alert('Hata', 'Önce konum alın');
        return;
      }

      await BackgroundLocation.addGeofence({
        identifier: 'test-geofence',
        latitude: currentLocation.coords.latitude,
        longitude: currentLocation.coords.longitude,
        radius: 100, // 100 metre
        notifyOnEntry: true,
        notifyOnExit: true,
        notifyOnDwell: false,
      });

      Alert.alert('Başarılı', 'Test geofence eklendi (100m yarıçap)');
    } catch (error) {
      Alert.alert('Hata', 'Geofence eklenemedi: ' + error);
    }
  };

  const syncLocations = async () => {
    try {
      const synced = await BackgroundLocation.sync();
      Alert.alert('Başarılı', `${synced.length} konum senkronize edildi`);
    } catch (error) {
      Alert.alert('Hata', 'Senkronize edilemedi: ' + error);
    }
  };

  const resetOdometer = async () => {
    try {
      await BackgroundLocation.setOdometer(0);
      setOdometer(0);
      Alert.alert('Başarılı', 'Odometer sıfırlandı');
    } catch (error) {
      Alert.alert('Hata', 'Sıfırlanamadı: ' + error);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView}>
        <View style={styles.header}>
          <Text style={styles.title}>🌍 Background Location</Text>
          <Text style={styles.subtitle}>Transistorsoft Benzeri</Text>
        </View>

        {/* Durum Kartı */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>📊 Durum</Text>
          <View style={styles.statusRow}>
            <Text style={styles.label}>Tracking:</Text>
            <Text style={[styles.value, isTracking ? styles.active : styles.inactive]}>
              {isTracking ? '✅ AKTİF' : '❌ PASİF'}
            </Text>
          </View>
          <View style={styles.statusRow}>
            <Text style={styles.label}>Kayıtlı Konum:</Text>
            <Text style={styles.value}>{locationCount}</Text>
          </View>
          <View style={styles.statusRow}>
            <Text style={styles.label}>Odometer:</Text>
            <Text style={styles.value}>{odometer.toFixed(2)} km</Text>
          </View>
        </View>

        {/* Konum Kartı */}
        {currentLocation && (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>📍 Güncel Konum</Text>
            <Text style={styles.coordText}>
              Lat: {currentLocation.coords.latitude.toFixed(6)}
            </Text>
            <Text style={styles.coordText}>
              Lng: {currentLocation.coords.longitude.toFixed(6)}
            </Text>
            <Text style={styles.coordText}>
              Doğruluk: {currentLocation.coords.accuracy.toFixed(1)}m
            </Text>
            {currentLocation.coords.speed > 0 && (
              <Text style={styles.coordText}>
                Hız: {(currentLocation.coords.speed * 3.6).toFixed(1)} km/h
              </Text>
            )}
          </View>
        )}

        {/* Kontrol Butonları */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>🎮 Kontroller</Text>
          
          {!isTracking ? (
            <TouchableOpacity style={styles.button} onPress={startTracking}>
              <Text style={styles.buttonText}>▶️ Tracking Başlat</Text>
            </TouchableOpacity>
          ) : (
            <TouchableOpacity style={[styles.button, styles.stopButton]} onPress={stopTracking}>
              <Text style={styles.buttonText}>⏸️ Tracking Durdur</Text>
            </TouchableOpacity>
          )}

          <TouchableOpacity style={styles.button} onPress={getCurrentPosition}>
            <Text style={styles.buttonText}>📍 Güncel Konum Al</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.button} onPress={getStoredLocations}>
            <Text style={styles.buttonText}>💾 Kayıtlı Konumlar</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.button} onPress={addTestGeofence}>
            <Text style={styles.buttonText}>⭕ Test Geofence Ekle</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.button} onPress={resetOdometer}>
            <Text style={styles.buttonText}>🔄 Odometer Sıfırla</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.button} onPress={clearLocations}>
            <Text style={styles.buttonText}>🗑️ Konumları Temizle</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.footer}>
          <Text style={styles.footerText}>
            Transistorsoft Benzeri{'\n'}
            Professional Location Tracking
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollView: {
    flex: 1,
  },
  header: {
    backgroundColor: '#3498db',
    padding: 20,
    alignItems: 'center',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: 'white',
    marginBottom: 5,
  },
  subtitle: {
    fontSize: 16,
    color: 'rgba(255,255,255,0.9)',
  },
  card: {
    backgroundColor: 'white',
    margin: 15,
    padding: 15,
    borderRadius: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 15,
    color: '#2c3e50',
  },
  statusRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  label: {
    fontSize: 14,
    color: '#7f8c8d',
  },
  value: {
    fontSize: 14,
    fontWeight: '600',
    color: '#2c3e50',
  },
  active: {
    color: '#27ae60',
  },
  inactive: {
    color: '#e74c3c',
  },
  coordText: {
    fontSize: 14,
    color: '#34495e',
    marginBottom: 5,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
  },
  button: {
    backgroundColor: '#3498db',
    padding: 15,
    borderRadius: 8,
    marginBottom: 10,
    alignItems: 'center',
  },
  stopButton: {
    backgroundColor: '#e74c3c',
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
  footer: {
    padding: 20,
    alignItems: 'center',
    marginBottom: 30,
  },
  footerText: {
    fontSize: 12,
    color: '#95a5a6',
    textAlign: 'center',
    lineHeight: 18,
  },
});

export default App;



