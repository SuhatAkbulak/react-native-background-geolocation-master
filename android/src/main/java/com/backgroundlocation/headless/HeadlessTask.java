package com.backgroundlocation.headless;

import android.content.Context;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.backgroundlocation.event.HeadlessEvent;
import com.backgroundlocation.headless.HeadlessTaskManager.OnErrorCallback;
import com.backgroundlocation.headless.HeadlessTaskManager.OnFinishCallback;
import com.backgroundlocation.headless.HeadlessTaskManager.OnInvokeCallback;
import com.backgroundlocation.headless.HeadlessTaskManager.Task;
import com.backgroundlocation.RNBackgroundLocationModule;
import com.backgroundlocation.util.LogHelper;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Headless Task
 * HeadlessTask.java
 * Headless mode'da JavaScript task'larını başlatır
 */
public class HeadlessTask {
    private static final String TAG = "HeadlessTask";
    private static final String HEADLESS_TASK_NAME = "BackgroundLocation";
    private static final int TASK_TIMEOUT = 120000; // 2 minutes
    
    /**
     * Handle headless event
     * @Subscribe onHeadlessEvent
     */
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onHeadlessEvent(HeadlessEvent event) {
        String name = event.getName();
        LogHelper.d(TAG, "💀 Headless event: " + name);
        
        WritableMap clientEvent = new WritableNativeMap();
        clientEvent.putString("name", name);
        
        JSONObject params = null;
        
        try {
            // Convert event to JSON based on type
            switch (name) {
                case "location":
                    params = event.getLocationEvent().toJson();
                    break;
                case "motionchange":
                    params = event.getMotionChangeEvent().toJson();
                    break;
                case "geofence":
                    params = event.getGeofenceEvent().toJson();
                    break;
                case "heartbeat":
                    params = event.getHeartbeatEvent().toJson();
                    break;
                case "http":
                    params = event.getHttpEvent().toJson();
                    break;
                case "activitychange":
                    params = event.getActivityChangeEvent().toJson();
                    break;
                case "connectivitychange":
                    params = event.getConnectivityChangeEvent().toJson();
                    break;
                case "enabledchange":
                    WritableMap enabledMap = new WritableNativeMap();
                    enabledMap.putBoolean("enabled", event.getEnabledChangeEvent().isEnabled());
                    clientEvent.putMap("params", enabledMap);
                    params = null; // Already set in clientEvent
                    break;
                default:
                    LogHelper.w(TAG, "Unknown Headless Event: " + name);
                    clientEvent.putString("error", "Unknown event: " + name);
                    clientEvent.putNull("params");
                    params = null;
                    break;
            }
            
            // Add params to clientEvent if available
            if (params != null) {
                try {
                    WritableMap paramsMap = RNBackgroundLocationModule.jsonToWritableMap(params);
                    clientEvent.putMap("params", paramsMap);
                } catch (Exception e) {
                    clientEvent.putNull("params");
                    clientEvent.putString("error", e.getMessage());
                    LogHelper.e(TAG, "Error converting params to WritableMap: " + e.getMessage(), e);
                }
            }
            
            // Start headless task
            HeadlessTaskManager.getInstance().startTask(
                event.getContext(),
                new Task.Builder()
                    .setName(HEADLESS_TASK_NAME)
                    .setParams(clientEvent)
                    .setTimeout(TASK_TIMEOUT)
                    .setOnInvokeCallback(new OnInvokeCallback() {
                        @Override
                        public void onInvoke(ReactContext reactContext, Task task) {
                            LogHelper.d(TAG, "Headless task invoked: " + task.getId());
                        }
                    })
                    .setOnFinishCallback(new OnFinishCallback() {
                        @Override
                        public void onFinish(int taskId) {
                            LogHelper.d(TAG, "Headless task finished: " + taskId);
                        }
                    })
                    .setOnErrorCallback(new OnErrorCallback() {
                        @Override
                        public void onError(Task task, Exception exc) {
                            LogHelper.e(TAG, "Headless task error: " + exc.getMessage(), exc);
                        }
                    })
                    .build()
            );
        } catch (Exception e) {
            LogHelper.e(TAG, "Failed to invoke HeadlessTask " + name + ". Task ignored: " + e.getMessage(), e);
        }
    }
    
}

