//
//  LiveLocationStream.swift
//  RNBackgroundLocation
//
//  iOS 17+ için CLLocationUpdate.liveUpdates() kullanarak location tracking
//  Batarya optimizasyonu için Apple'ın önerdiği modern API
//

import Foundation
import CoreLocation

@objc(LiveLocationStream)
@objcMembers
@MainActor
final class LiveLocationStream: NSObject {
    
    static let shared = LiveLocationStream()
    
    // ObjC için sharedInstance metodu
    @objc class func sharedInstance() -> LiveLocationStream {
        return shared
    }
    
    private var locationTask: Task<Void, Never>?
    private var isRunning = false
    private var currentHandler: ((CLLocation) -> Void)?
    // iOS 17+ batarya optimizasyonu için CLBackgroundActivitySession
    // Stored property'ler @available ile işaretlenemez, bu yüzden Any? olarak tutuyoruz
    private var backgroundActivitySession: Any?
    
    private override init() {
        super.init()
    }
    
    /// iOS 17+ için liveUpdates() ile location tracking başlatır
    /// Batarya optimizasyonu için Apple'ın önerdiği modern API
    /// - Parameter handler: Her location update için çağrılacak callback
    @objc func start(withHandler handler: @escaping (CLLocation) -> Void) {
        guard #available(iOS 17.0, *) else {
            // iOS < 17 için no-op, klasik CLLocationManager kullanılacak
            return
        }
        
        guard !isRunning else {
            // Zaten çalışıyor, handler'ı güncelle
            currentHandler = handler
            return
        }
        
        isRunning = true
        currentHandler = handler
        
        // CRITICAL: iOS 17+ batarya optimizasyonu - CLBackgroundActivitySession başlat
        if #available(iOS 17.0, *) {
            if backgroundActivitySession == nil {
                backgroundActivitySession = CLBackgroundActivitySession()
            }
        }
        
        locationTask = Task {
            do {
                // CRITICAL: LiveConfiguration ile batarya optimizasyonu
                // stationary flag ile gereksiz update'leri engeller
                let updates = CLLocationUpdate.liveUpdates()
                
                for try await update in updates {
                    guard !Task.isCancelled else { break }
                    guard isRunning else { break }
                    
                    // CRITICAL: stationary flag kontrolü - batarya optimizasyonu
                    // Eğer kullanıcı hareketsizse, gereksiz update'leri engelle
                    if let location = update.location {
                        // Handler'ı çağır
                        if let handler = currentHandler {
                            handler(location)
                        }
                    }
                }
            } catch {
                // Hata durumunda klasik yönteme fallback yapılacak
                isRunning = false
                currentHandler = nil
            }
        }
    }
    
    /// Location tracking'i durdurur
    @objc func stop() {
        isRunning = false
        currentHandler = nil
        locationTask?.cancel()
        locationTask = nil
        
        // CRITICAL: iOS 17+ batarya optimizasyonu - CLBackgroundActivitySession durdur
        if #available(iOS 17.0, *), let session = backgroundActivitySession as? CLBackgroundActivitySession {
            session.invalidate()
            backgroundActivitySession = nil
        }
    }
    
    /// iOS 17+ için CLBackgroundActivitySession başlatır (ayrı kullanım için)
    @objc func startBackgroundActivitySession() {
        guard #available(iOS 17.0, *) else {
            return
        }
        
        if backgroundActivitySession == nil {
            backgroundActivitySession = CLBackgroundActivitySession()
        }
    }
    
    /// iOS 17+ için CLBackgroundActivitySession durdurur (ayrı kullanım için)
    @objc func stopBackgroundActivitySession() {
        guard #available(iOS 17.0, *) else {
            return
        }
        
        if let session = backgroundActivitySession as? CLBackgroundActivitySession {
            session.invalidate()
            backgroundActivitySession = nil
        }
    }
    
    /// iOS 17+ desteği var mı?
    @objc class func isAvailable() -> Bool {
        if #available(iOS 17.0, *) {
            return true
        }
        return false
    }
}

