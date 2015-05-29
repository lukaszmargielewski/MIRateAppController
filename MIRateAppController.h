//
//  MIRateAppController.h
//  FF
//
//  Created by Lukasz Margielewski on 12/05/15.
//
//

#import <Foundation/Foundation.h>

#ifdef AppStore

    #define kMIRateAppControllerTimeUsageMinDefault     30 * 60
    #define kMIRateAppControllerCheckIntervalDefault    60

#else

    #define kMIRateAppControllerTimeUsageMinDefault     30 * 60
    #define kMIRateAppControllerCheckIntervalDefault    60

#endif


@interface MIRateAppController : NSObject

@property (nonatomic) NSTimeInterval minimumTimeUsage;
@property (nonatomic, copy, readonly) NSString *appstoreId;
@property (nonatomic, copy, readonly) NSString *applicationName;

+(MIRateAppController *)startWithAppID:(NSString *)appId minimumTimeUsage:(NSTimeInterval)minimumTimeUsage;
+(void)rateTheAppNow;
+(void)reset;

@end
