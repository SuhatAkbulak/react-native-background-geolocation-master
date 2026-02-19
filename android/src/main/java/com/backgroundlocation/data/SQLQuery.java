package com.backgroundlocation.data;

/**
 * SQLQuery
 * SQLQuery
 * SQL query builder - basitleştirilmiş versiyon
 */
public class SQLQuery {
    
    private String selection;
    private String[] selectionArgs;
    private String orderBy;
    private String limit;
    
    public SQLQuery() {
    }
    
    public String getSelection() {
        return selection;
    }
    
    public void setSelection(String selection) {
        this.selection = selection;
    }
    
    public String[] getSelectionArgs() {
        return selectionArgs;
    }
    
    public void setSelectionArgs(String[] selectionArgs) {
        this.selectionArgs = selectionArgs;
    }
    
    public String getOrderBy() {
        return orderBy;
    }
    
    public void setOrderBy(String orderBy) {
        this.orderBy = orderBy;
    }
    
    public String getLimit() {
        return limit;
    }
    
    public void setLimit(String limit) {
        this.limit = limit;
    }
    
    /**
     * Get selection for logback database resolver
     */
    public String getSelection(Object resolver) {
        // Simplified - return selection as is
        return selection;
    }
}

