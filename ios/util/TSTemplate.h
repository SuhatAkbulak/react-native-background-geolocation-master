//
//  TSTemplate.h
//  RNBackgroundLocation
//
//  Template Engine
//  iOS_PRECEDUR pattern - 8 fonksiyon
//

#import <Foundation/Foundation.h>

@interface TSTemplate : NSObject

@property (nonatomic, strong) NSString *head;
@property (nonatomic, strong) NSString *tail;

#pragma mark - Methods
- (NSString *)scan:(NSString *)template dict:(NSDictionary *)dict error:(NSError **)error;

@end

@interface NSString (TSTemplate)
- (NSString *)templateFromDict:(NSDictionary *)dict;
@end





