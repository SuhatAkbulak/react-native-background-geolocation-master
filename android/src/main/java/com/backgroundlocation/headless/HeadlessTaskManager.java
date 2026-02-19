package com.backgroundlocation.headless;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import com.facebook.infer.annotation.Assertions;
import com.facebook.react.ReactApplication;
import com.facebook.react.ReactInstanceEventListener;
import com.facebook.react.ReactInstanceManager;
import com.facebook.react.ReactNativeHost;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.UiThreadUtil;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.jstasks.HeadlessJsTaskConfig;
import com.facebook.react.jstasks.HeadlessJsTaskContext;
import com.facebook.react.jstasks.HeadlessJsTaskEventListener;
import com.backgroundlocation.util.LogHelper;

import java.util.Iterator;
import java.util.Set;
import java.util.concurrent.CopyOnWriteArraySet;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Headless Task Manager
 * HeadlessTaskManager.java
 * React Native HeadlessJS task'larını yönetir
 */
public class HeadlessTaskManager implements HeadlessJsTaskEventListener {
    private static final String TAG = "HeadlessTaskManager";
    private static HeadlessTaskManager instance;
    
    private final AtomicBoolean isHeadlessJsTaskListenerRegistered = new AtomicBoolean(false);
    private final AtomicBoolean isInitializingReactContext = new AtomicBoolean(false);
    private final AtomicBoolean isReactContextInitialized = new AtomicBoolean(false);
    private final Set<Task> taskQueue = new CopyOnWriteArraySet<>();
    private final AtomicBoolean willDrainTaskQueue = new AtomicBoolean(false);
    
    public interface OnErrorCallback {
        void onError(Task task, Exception exc);
    }
    
    public interface OnFinishCallback {
        void onFinish(int taskId);
    }
    
    public interface OnInvokeCallback {
        void onInvoke(ReactContext reactContext, Task task);
    }
    
    private HeadlessTaskManager() {
    }
    
    public static HeadlessTaskManager getInstance() {
        if (instance == null) {
            synchronized (HeadlessTaskManager.class) {
                if (instance == null) {
                    instance = new HeadlessTaskManager();
                }
            }
        }
        return instance;
    }
    
    /**
     * Start headless task
     */
    public void startTask(Context context, Task task) throws AssertionError {
        UiThreadUtil.assertOnUiThread();
        addTask(task);
        
        if (!isReactContextInitialized.get()) {
            createReactContextAndScheduleTask(context);
        } else {
            ReactContext reactContext = getReactContext(context);
            if (reactContext != null) {
                if (!invokeStartTask(reactContext, task)) {
                    removeTask(task);
                }
            }
        }
    }
    
    /**
     * Finish headless task
     */
    public void finishTask(Context context, int taskId) throws TaskNotFoundError, ContextError {
        if (!isReactContextInitialized.get()) {
            throw new ContextError(getClass().getName() + ".finishTask: ReactContext not initialized");
        }
        
        ReactContext reactContext = getReactContext(context.getApplicationContext());
        if (reactContext == null) {
            throw new ContextError(getClass().getName() + ".finishTask ReactContext is null");
        }
        
        Task task = findTask(taskId);
        if (task == null) {
            throw new TaskNotFoundError(taskId);
        }
        
        HeadlessJsTaskContext headlessJsTaskContext = HeadlessJsTaskContext.getInstance(reactContext);
        if (headlessJsTaskContext.isTaskRunning(task.getReactTaskId())) {
            headlessJsTaskContext.finishTask(task.getReactTaskId());
        }
    }
    
    private boolean invokeStartTask(ReactContext reactContext, Task task) {
        HeadlessJsTaskContext headlessJsTaskContext = HeadlessJsTaskContext.getInstance(reactContext);
        
        if (isHeadlessJsTaskListenerRegistered.compareAndSet(false, true)) {
            headlessJsTaskContext.addTaskEventListener(this);
        }
        
        try {
            return task.invoke(reactContext);
        } catch (Exception e) {
            task.onError(e);
            return false;
        }
    }
    
    @Override
    public void onHeadlessJsTaskStart(int taskId) {
        LogHelper.d(TAG, "HeadlessJS task started: " + taskId);
    }
    
    @Override
    public void onHeadlessJsTaskFinish(int taskId) {
        Task task = findTaskByReactId(taskId);
        if (task != null) {
            removeTask(task);
            task.onFinish();
            LogHelper.d(TAG, "HeadlessJS task finished: " + taskId);
        }
    }
    
    private ReactNativeHost getReactNativeHost(Context context) {
        return ((ReactApplication) context.getApplicationContext()).getReactNativeHost();
    }
    
    private Object getReactHost(Context context) {
        Context appContext = context.getApplicationContext();
        try {
            return appContext.getClass().getMethod("getReactHost", new Class[0])
                .invoke(appContext, new Object[0]);
        } catch (Exception e) {
            return null;
        }
    }
    
    private ReactContext getReactContext(Context context) {
        if (isBridglessArchitectureEnabled()) {
            Object reactHost = getReactHost(context);
            Assertions.assertNotNull(reactHost, "getReactHost() is null in New Architecture");
            try {
                return (ReactContext) reactHost.getClass()
                    .getMethod("getCurrentReactContext", new Class[0])
                    .invoke(reactHost, new Object[0]);
            } catch (Exception e) {
                LogHelper.e(TAG, "Reflection error getCurrentReactContext: " + e.getMessage(), e);
            }
        }
        return getReactNativeHost(context).getReactInstanceManager().getCurrentReactContext();
    }
    
    private void createReactContextAndScheduleTask(Context context) {
        ReactContext reactContext = getReactContext(context);
        if (reactContext != null && !isInitializingReactContext.get()) {
            isReactContextInitialized.set(true);
            drainTaskQueue(reactContext);
            return;
        }
        
        if (isInitializingReactContext.compareAndSet(false, true)) {
            LogHelper.d(TAG, "Initializing ReactContext for headless task");
            
            final Object reactHost = getReactHost(context);
            
            if (isBridglessArchitectureEnabled()) {
                ReactInstanceEventListener callback = new ReactInstanceEventListener() {
                    @Override
                    public void onReactContextInitialized(ReactContext reactContext) {
                        isReactContextInitialized.set(true);
                        drainTaskQueue(reactContext);
                        try {
                            reactHost.getClass()
                                .getMethod("removeReactInstanceEventListener", 
                                    new Class[]{ReactInstanceEventListener.class})
                                .invoke(reactHost, new Object[]{this});
                        } catch (Exception e) {
                            LogHelper.e(TAG, "Reflection error removeReactInstanceEventListener: " + e.getMessage(), e);
                        }
                    }
                };
                try {
                    reactHost.getClass()
                        .getMethod("addReactInstanceEventListener", 
                            new Class[]{ReactInstanceEventListener.class})
                        .invoke(reactHost, new Object[]{callback});
                    reactHost.getClass()
                        .getMethod("start", new Class[0])
                        .invoke(reactHost, new Object[0]);
                } catch (Exception e) {
                    LogHelper.e(TAG, "Reflection error ReactHost start: " + e.getMessage(), e);
                }
            } else {
                final ReactInstanceManager reactInstanceManager = 
                    getReactNativeHost(context).getReactInstanceManager();
                reactInstanceManager.addReactInstanceEventListener(new ReactInstanceEventListener() {
                    @Override
                    public void onReactContextInitialized(ReactContext reactContext) {
                        isReactContextInitialized.set(true);
                        drainTaskQueue(reactContext);
                        reactInstanceManager.removeReactInstanceEventListener(this);
                    }
                });
                reactInstanceManager.createReactContextInBackground();
            }
        }
    }
    
    private boolean isBridglessArchitectureEnabled() {
        try {
            Class<?> clazz = Class.forName("com.facebook.react.defaults.DefaultNewArchitectureEntryPoint");
            Object result = clazz.getMethod("getBridgelessEnabled", new Class[0])
                .invoke(null, new Object[0]);
            return Boolean.TRUE.equals(result);
        } catch (Exception e) {
            return false;
        }
    }
    
    private void drainTaskQueue(ReactContext reactContext) {
        if (willDrainTaskQueue.compareAndSet(false, true)) {
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                synchronized (taskQueue) {
                    Iterator<Task> iterator = taskQueue.iterator();
                    while (iterator.hasNext()) {
                        Task task = iterator.next();
                        if (!invokeStartTask(reactContext, task)) {
                            removeTask(task);
                        }
                    }
                }
            }, 250);
        }
    }
    
    private Task findTask(int taskId) {
        synchronized (taskQueue) {
            for (Task task : taskQueue) {
                if (task.getId() == taskId) {
                    return task;
                }
            }
        }
        return null;
    }
    
    private Task findTaskByReactId(int reactTaskId) {
        synchronized (taskQueue) {
            for (Task task : taskQueue) {
                if (task.getReactTaskId() == reactTaskId) {
                    return task;
                }
            }
        }
        return null;
    }
    
    private void addTask(Task task) {
        synchronized (taskQueue) {
            taskQueue.add(task);
        }
    }
    
    private void removeTask(Task task) {
        synchronized (taskQueue) {
            taskQueue.remove(task);
        }
    }
    
    /**
     * Task class
     */
    public static class Task {
        private static final AtomicInteger lastTaskId = new AtomicInteger(0);
        private final int id = getNextTaskId();
        private final OnErrorCallback onErrorCallback;
        private final OnFinishCallback onFinishCallback;
        private final OnInvokeCallback onInvokeCallback;
        private final WritableMap params;
        private int reactTaskId;
        private final String taskName;
        private final int timeout;
        
        private static synchronized int getNextTaskId() {
            return lastTaskId.incrementAndGet();
        }
        
        Task(Builder builder) {
            this.taskName = builder.name;
            this.onInvokeCallback = builder.onInvokeCallback;
            this.onFinishCallback = builder.onFinishCallback;
            this.onErrorCallback = builder.onErrorCallback;
            this.timeout = builder.timeout;
            this.params = builder.params;
            this.params.putInt("_headlessTaskId", this.id);
        }
        
        boolean invoke(ReactContext reactContext) throws IllegalStateException {
            if (this.reactTaskId > 0) {
                LogHelper.w(TAG, "Task already invoked <IGNORED>: " + this);
                return true;
            }
            
            this.reactTaskId = HeadlessJsTaskContext.getInstance(reactContext)
                .startTask(buildTaskConfig());
            
            if (this.onInvokeCallback != null) {
                this.onInvokeCallback.onInvoke(reactContext, this);
            }
            
            return true;
        }
        
        public int getId() {
            return this.id;
        }
        
        int getReactTaskId() {
            return this.reactTaskId;
        }
        
        private HeadlessJsTaskConfig buildTaskConfig() {
            return new HeadlessJsTaskConfig(this.taskName, this.params, (long) this.timeout);
        }
        
        void onFinish() {
            if (this.onFinishCallback != null) {
                this.onFinishCallback.onFinish(this.id);
            }
        }
        
        void onError(Exception e) {
            if (this.onErrorCallback != null) {
                this.onErrorCallback.onError(this, e);
            }
        }
        
        @Override
        public String toString() {
            return "[HeadlessTaskManager.Task name: " + this.taskName + " id: " + this.id + "]";
        }
        
        public static class Builder {
            private static final int DEFAULT_TIMEOUT = 120000; // 2 minutes
            private String name;
            private OnErrorCallback onErrorCallback;
            private OnFinishCallback onFinishCallback;
            private OnInvokeCallback onInvokeCallback;
            private WritableMap params;
            private int timeout = DEFAULT_TIMEOUT;
            
            public Builder setName(String name) {
                this.name = name;
                return this;
            }
            
            public Builder setOnInvokeCallback(OnInvokeCallback callback) {
                this.onInvokeCallback = callback;
                return this;
            }
            
            public Builder setOnFinishCallback(OnFinishCallback callback) {
                this.onFinishCallback = callback;
                return this;
            }
            
            public Builder setOnErrorCallback(OnErrorCallback callback) {
                this.onErrorCallback = callback;
                return this;
            }
            
            public Builder setParams(WritableMap params) {
                this.params = params;
                return this;
            }
            
            public Builder setTimeout(int timeout) {
                this.timeout = timeout;
                return this;
            }
            
            public Task build() {
                return new Task(this);
            }
        }
    }
    
    public static class TaskNotFoundError extends Exception {
        public TaskNotFoundError(int taskId) {
            super(HeadlessTaskManager.class.getName() + " failed to find task: " + taskId);
        }
    }
    
    public static class ContextError extends Exception {
        public ContextError(String message) {
            super(message);
        }
    }
}

