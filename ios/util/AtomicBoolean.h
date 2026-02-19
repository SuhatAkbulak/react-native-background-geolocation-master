//
//  AtomicBoolean.h
//  RNBackgroundLocation
//
//  Thread-safe boolean
//  ExampleIOS/AtomicBoolean.h pattern'ine göre
//

#import <Foundation/Foundation.h>

@interface AtomicBoolean : NSObject

- (instancetype)initWithValue:(BOOL)value;
- (BOOL)getValue;
- (void)setValue:(BOOL)value;
- (BOOL)compareTo:(BOOL)expected andSetValue:(BOOL)value;
- (BOOL)getAndSetValue:(BOOL)value;

@end





