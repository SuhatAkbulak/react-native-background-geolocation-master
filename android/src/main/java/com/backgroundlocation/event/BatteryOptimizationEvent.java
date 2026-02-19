package com.backgroundlocation.event;

/**
 * BatteryOptimizationEvent
 * BatteryOptimizationEvent.java
 * Battery optimization event
 */
public class BatteryOptimizationEvent {
    private final boolean isIgnoringBatteryOptimizations;
    
    public BatteryOptimizationEvent(boolean isIgnoringBatteryOptimizations) {
        this.isIgnoringBatteryOptimizations = isIgnoringBatteryOptimizations;
    }
    
    public boolean isIgnoringBatteryOptimizations() {
        return isIgnoringBatteryOptimizations;
    }
    
    public String getEventName() {
        return "batteryoptimization";
    }
}

