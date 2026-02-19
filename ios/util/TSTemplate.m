//
//  TSTemplate.m
//  RNBackgroundLocation
//
//  Template Engine
//  iOS_PRECEDUR pattern - 8 fonksiyon
//  Orijinal implementasyon: TSTemplate.o (iOS_PRECEDUR)
//

#import "TSTemplate.h"
#import "LogHelper.h"

@implementation TSTemplate

#pragma mark - Methods

/**
 * Scan template and replace variables
 * iOS_PRECEDUR pattern: -[TSTemplate scan:dict:error:]
 * 
 * Template format: ERB-style tags <%= variable_name %>
 * Example: "{"lat":<%= latitude %>,"lng":<%= longitude %>}"
 */
- (NSString *)scan:(NSString *)template dict:(NSDictionary *)dict error:(NSError **)error {
    if (!template || template.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TSTemplate" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Template is empty"}];
        }
        return nil;
    }
    
    if (!dict || dict.count == 0) {
        // No dictionary provided, return template as-is
        return template;
    }
    
    NSMutableString *result = [NSMutableString stringWithString:template];
    
    // Find all <%= variable %> patterns
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<%=\\s*([^%]+)\\s*%>" options:0 error:error];
    if (!regex) {
        return nil;
    }
    
    // Replace from end to start to preserve indices
    NSArray *matches = [regex matchesInString:result options:0 range:NSMakeRange(0, result.length)];
    
    for (NSInteger i = matches.count - 1; i >= 0; i--) {
        NSTextCheckingResult *match = matches[i];
        NSRange fullRange = [match rangeAtIndex:0];
        NSRange variableRange = [match rangeAtIndex:1];
        
        NSString *variableName = [[result substringWithRange:variableRange] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // Get value from dictionary (support nested keys like "activity.type")
        id value = [self getValueForKeyPath:variableName fromDict:dict];
        
        if (value == nil) {
            // Variable not found, leave as-is or replace with empty string
            [LogHelper w:@"TSTemplate" message:[NSString stringWithFormat:@"⚠️ Template variable not found: %@", variableName]];
            [result replaceCharactersInRange:fullRange withString:@""];
            continue;
        }
        
        // Convert value to string
        NSString *stringValue = [self stringValueFromObject:value];
        
        // Replace template tag with value
        [result replaceCharactersInRange:fullRange withString:stringValue];
    }
    
    return result;
}

#pragma mark - Private Methods

/**
 * Get value from dictionary using key path (supports nested keys like "activity.type")
 */
- (id)getValueForKeyPath:(NSString *)keyPath fromDict:(NSDictionary *)dict {
    NSArray *keys = [keyPath componentsSeparatedByString:@"."];
    
    id currentValue = dict;
    for (NSString *key in keys) {
        if ([currentValue isKindOfClass:[NSDictionary class]]) {
            currentValue = currentValue[key];
        } else {
            return nil;
        }
    }
    
    return currentValue;
}

/**
 * Convert object to string representation
 * Handles: NSString, NSNumber, BOOL, NSNull
 */
- (NSString *)stringValueFromObject:(id)value {
    if (value == nil || value == [NSNull null]) {
        return @"null";
    }
    
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *)value;
        
        // Check if it's a boolean
        if (CFBooleanGetTypeID() == CFGetTypeID((__bridge CFTypeRef)value)) {
            return [number boolValue] ? @"true" : @"false";
        }
        
        // Check if it's an integer
        if (number == (id)kCFBooleanTrue || number == (id)kCFBooleanFalse) {
            return [number boolValue] ? @"true" : @"false";
        }
        
        // Check if it has decimal part
        double doubleValue = [number doubleValue];
        if (doubleValue == floor(doubleValue)) {
            // Integer
            return [NSString stringWithFormat:@"%ld", (long)[number longLongValue]];
        } else {
            // Float
            return [NSString stringWithFormat:@"%.15g", doubleValue];
        }
    }
    
    // Fallback: use description
    return [value description];
}

@end

#pragma mark - NSString Category

@implementation NSString (TSTemplate)

/**
 * Template from dictionary (convenience method)
 * iOS_PRECEDUR pattern: -[NSString(TSTemplate) templateFromDict:]
 */
- (NSString *)templateFromDict:(NSDictionary *)dict {
    TSTemplate *template = [[TSTemplate alloc] init];
    NSError *error = nil;
    NSString *result = [template scan:self dict:dict error:&error];
    
    if (error) {
        [LogHelper e:@"TSTemplate" message:[NSString stringWithFormat:@"❌ Template error: %@", error.localizedDescription] error:error];
        return self; // Return original template on error
    }
    
    return result ?: self;
}

@end

