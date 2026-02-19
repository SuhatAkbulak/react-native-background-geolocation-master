package com.backgroundlocation.lifecycle;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.content.Context;

import androidx.lifecycle.DefaultLifecycleObserver;

import com.backgroundlocation.util.LogHelper;
import androidx.lifecycle.LifecycleOwner;
import androidx.lifecycle.ProcessLifecycleOwner;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Lifecycle Manager
 * Uygulama lifecycle yönetimi ve headless mode detection
 */
public class LifecycleManager implements DefaultLifecycleObserver, Runnable {
    
    private static final String TAG = "LifecycleManager";
    private static LifecycleManager instance = null;
    
    private final List<OnHeadlessChangeCallback> headlessCallbacks = new ArrayList<>();
    private final List<OnStateChangeCallback> stateCallbacks = new ArrayList<>();
    private final Handler handler = new Handler(Looper.getMainLooper());
    private Runnable delayedCallback;
    
    private final AtomicBoolean isBackground = new AtomicBoolean(true);
    private final AtomicBoolean isHeadless = new AtomicBoolean(true);
    private final AtomicBoolean isInitialized = new AtomicBoolean(false);
    private final AtomicBoolean isPaused = new AtomicBoolean(false);
    
    /**
     * Callback interface for headless state changes
     */
    public interface OnHeadlessChangeCallback {
        void onChange(boolean isHeadless);
    }
    
    /**
     * Callback interface for background/foreground state changes
     */
    public interface OnStateChangeCallback {
        void onChange(boolean isBackground);
    }
    
    private LifecycleManager() {
        // Private constructor for singleton
    }
    
    /**
     * Get singleton instance
     */
    public static synchronized LifecycleManager getInstance() {
        if (instance == null) {
            instance = new LifecycleManager();
        }
        return instance;
    }
    
    /**
     * Initialize lifecycle manager
     * Registers with ProcessLifecycleOwner
     */
    public void initialize() {
        if (isInitialized.compareAndSet(false, true)) {
            ProcessLifecycleOwner.get().getLifecycle().addObserver(this);
            LogHelper.d(TAG, "✅ LifecycleManager initialized");
        }
    }
    
    /**
     * Check if app is in background
     */
    public boolean isBackground() {
        return isBackground.get();
    }
    
    /**
     * Check if app is in headless mode
     */
    public boolean isHeadless() {
        return isHeadless.get();
    }
    
    /**
     * Register callback for headless state changes
     */
    public void onHeadlessChange(OnHeadlessChangeCallback callback) {
        if (isInitialized.get()) {
            // Already initialized, call immediately
            callback.onChange(isHeadless.get());
        } else {
            // Not initialized yet, add to list
            synchronized (headlessCallbacks) {
                headlessCallbacks.add(callback);
            }
        }
    }
    
    /**
     * Register callback for state changes
     */
    public void onStateChange(OnStateChangeCallback callback) {
        synchronized (stateCallbacks) {
            stateCallbacks.add(callback);
        }
    }
    
    @Override
    public void onCreate(LifecycleOwner owner) {
        LogHelper.d(TAG, "☯️ onCreate");
        isHeadless.set(true);
        isBackground.set(true);
        
        // Schedule delayed callback to check if app is still headless
        delayedCallback = () -> {
            isInitialized.set(true);
            notifyHeadlessCallbacks();
        };
        handler.postDelayed(delayedCallback, 50);
    }
    
    @Override
    public void onStart(LifecycleOwner owner) {
        LogHelper.d(TAG, "☯️ onStart");
        
        // Cancel delayed callback if app started
        if (delayedCallback != null) {
            handler.removeCallbacks(delayedCallback);
            delayedCallback = null;
        }
        
        isInitialized.set(true);
        isHeadless.set(false);
        isBackground.set(false);
        
        notifyHeadlessCallbacks();
        notifyStateCallbacks(false);
    }
    
    @Override
    public void onResume(LifecycleOwner owner) {
        LogHelper.d(TAG, "☯️ onResume");
        if (!isPaused.get()) {
            isBackground.set(false);
            isHeadless.set(false);
            notifyStateCallbacks(false);
        }
    }
    
    @Override
    public void onPause(LifecycleOwner owner) {
        LogHelper.d(TAG, "☯️ onPause");
        isBackground.set(true);
        notifyStateCallbacks(true);
    }
    
    @Override
    public void onStop(LifecycleOwner owner) {
        LogHelper.d(TAG, "☯️ onStop");
        if (!isPaused.compareAndSet(false, true)) {
            isBackground.set(true);
        }
        notifyStateCallbacks(true);
    }
    
    @Override
    public void onDestroy(LifecycleOwner owner) {
        LogHelper.d(TAG, "☯️ onDestroy");
        isBackground.set(true);
        isHeadless.set(true);
        
        // Fire TerminateEvent
        // This will be handled by BackgroundLocationAdapter to check stopOnTerminate
        org.greenrobot.eventbus.EventBus.getDefault().post(
            new com.backgroundlocation.event.TerminateEvent(owner.getLifecycle().getClass().getSimpleName())
        );
    }
    
    @Override
    public void run() {
        // Initialize when run is called
        initialize();
    }
    
    /**
     * Manually set headless state
     */
    public void setHeadless(boolean headless) {
        isHeadless.set(headless);
        if (headless) {
            LogHelper.d(TAG, "☯️ HeadlessMode? " + headless);
        }
        
        // Cancel delayed callback
        if (delayedCallback != null) {
            handler.removeCallbacks(delayedCallback);
            delayedCallback = null;
            isInitialized.set(true);
        }
        
        notifyHeadlessCallbacks();
    }
    
    /**
     * Pause lifecycle monitoring
     */
    public void pause() {
        isPaused.set(true);
    }
    
    /**
     * Resume lifecycle monitoring
     */
    public void resume() {
        isPaused.set(false);
    }
    
    /**
     * Notify headless callbacks
     */
    private void notifyHeadlessCallbacks() {
        synchronized (headlessCallbacks) {
            boolean headless = isHeadless.get();
            for (OnHeadlessChangeCallback callback : headlessCallbacks) {
                callback.onChange(headless);
            }
            headlessCallbacks.clear();
        }
    }
    
    /**
     * Notify state callbacks
     */
    private void notifyStateCallbacks(boolean background) {
        synchronized (stateCallbacks) {
            for (OnStateChangeCallback callback : stateCallbacks) {
                callback.onChange(background);
            }
        }
    }
}

