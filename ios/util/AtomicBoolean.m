//
//  AtomicBoolean.m
//  RNBackgroundLocation
//
//  Thread-safe boolean
//  ExampleIOS/AtomicBoolean.h pattern'ine göre
//

#import "AtomicBoolean.h"

@interface AtomicBoolean ()
@property (nonatomic, assign) BOOL value;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation AtomicBoolean

- (instancetype)initWithValue:(BOOL)value {
    self = [super init];
    if (self) {
        _value = value;
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (BOOL)getValue {
    [self.lock lock];
    BOOL result = self.value;
    [self.lock unlock];
    return result;
}

- (void)setValue:(BOOL)value {
    [self.lock lock];
    self.value = value;
    [self.lock unlock];
}

- (BOOL)compareTo:(BOOL)expected andSetValue:(BOOL)value {
    [self.lock lock];
    BOOL currentValue = self.value;
    if (currentValue == expected) {
        self.value = value;
    }
    [self.lock unlock];
    return (currentValue == expected);
}

- (BOOL)getAndSetValue:(BOOL)value {
    [self.lock lock];
    BOOL oldValue = self.value;
    self.value = value;
    [self.lock unlock];
    return oldValue;
}

@end





