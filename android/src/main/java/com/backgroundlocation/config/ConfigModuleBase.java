package com.backgroundlocation.config;

import java.util.ArrayList;
import java.util.List;

/**
 * ConfigModuleBase
 * a.java (base config class)
 * Config modülleri için base sınıf - dirty fields tracking
 */
public class ConfigModuleBase {
    private final List<String> dirtyFields = new ArrayList<>();
    private final String moduleName;
    
    ConfigModuleBase(String moduleName) {
        this.moduleName = moduleName;
    }
    
    protected void markDirty(String fieldName) {
        dirtyFields.add(moduleName + "." + fieldName);
    }
    
    public List<String> getDirtyFields() {
        return new ArrayList<>(dirtyFields);
    }
    
    protected void clearDirtyFields() {
        dirtyFields.clear();
    }
}

