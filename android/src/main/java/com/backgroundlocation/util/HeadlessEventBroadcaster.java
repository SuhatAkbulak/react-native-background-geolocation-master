package com.backgroundlocation.util;

import android.content.Context;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.event.HeadlessEvent;
import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.EventBusException;

import java.lang.reflect.InvocationTargetException;

/**
 * Headless Event Broadcaster
 * HeadlessEventBroadcaster.java
 * Headless mode'da event'leri JavaScript'e gönderir
 */
public class HeadlessEventBroadcaster {
    private static final String TAG = "HeadlessEventBroadcaster";
    public static final String DEFAULT_HEADLESS_TASK_CLASSNAME = "BackgroundLocationHeadlessTask";
    
    /**
     * Post headless event
     * post()
     */
    public static void post(HeadlessEvent headlessEvent) {
        Config config = Config.getInstance(headlessEvent.getContext().getApplicationContext());
        
        if (!config.enableHeadless) {
            LogHelper.d(TAG, "Headless mode disabled, ignoring event: " + headlessEvent.getName());
            return;
        }
        
        EventBus eventBus = EventBus.getDefault();
        
        // Check if HeadlessTask is registered
        if (!eventBus.hasSubscriberForEvent(HeadlessEvent.class)) {
            // Try to register HeadlessTask
            if (!registerHeadlessTask(headlessEvent.getContext(), config.headlessJobService)) {
                LogHelper.w(TAG, "Failed to register HeadlessTask, event ignored: " + headlessEvent.getName());
                return;
            }
        }
        
        // Post event
        if (eventBus.hasSubscriberForEvent(HeadlessEvent.class)) {
            eventBus.post(headlessEvent);
            LogHelper.d(TAG, "✅ Headless event posted: " + headlessEvent.getName());
        } else {
            LogHelper.w(TAG, "Attempted to post headless event " + headlessEvent.getName() + 
                " but there are no listeners.");
        }
    }
    
    /**
     * Register HeadlessTask class
     */
    private static boolean registerHeadlessTask(Context context, String className) {
        EventBus eventBus = EventBus.getDefault();
        
        if (eventBus.hasSubscriberForEvent(HeadlessEvent.class)) {
            return true;
        }
        
        try {
            Class<?> headlessTaskClass = getHeadlessTaskClass(context, className);
            Object headlessTaskInstance = headlessTaskClass.getConstructor().newInstance();
            
            if (!eventBus.isRegistered(headlessTaskInstance)) {
                eventBus.register(headlessTaskInstance);
            }
            
            LogHelper.d(TAG, "✅ HeadlessTask registered: " + className);
            return true;
        } catch (EventBusException e) {
            LogHelper.e(TAG, "Failed to register headlessTask: " + className + ": " + e.getMessage(), e);
            return false;
        } catch (ClassNotFoundException e) {
            LogHelper.e(TAG, "HeadlessTask failed to find " + className + 
                ".java. If you've configured enableHeadless: true, you must provide a custom " +
                DEFAULT_HEADLESS_TASK_CLASSNAME + ".java");
            return false;
        } catch (NoSuchMethodException | IllegalAccessException | InstantiationException | InvocationTargetException e) {
            LogHelper.e(TAG, "Failed to instantiate HeadlessTask: " + e.getMessage(), e);
            return false;
        }
    }
    
    /**
     * Get HeadlessTask class
     */
    private static Class<?> getHeadlessTaskClass(Context context, String className) throws ClassNotFoundException {
        try {
            return Class.forName(className);
        } catch (ClassNotFoundException e) {
            // Try default class name
            return Class.forName(context.getPackageName() + "." + DEFAULT_HEADLESS_TASK_CLASSNAME);
        }
    }
}

