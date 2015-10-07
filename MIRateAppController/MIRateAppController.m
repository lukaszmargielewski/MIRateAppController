//
//  MIRateAppController.m
//  FF
//
//  Created by Lukasz Margielewski on 12/05/15.
//
//

#import "MIRateAppController.h"
#import <StoreKit/StoreKit.h>

#define APP_STORE_ALERT_TAG 876
#define RESET_ALERT_TAG 877

#define kTimeUsageTotalNeededForNextReviewPrompt_key    @"min_time_appstore"
#define kAppStoreReviewCancelled_key                    @"appstore_review_canceled"
#define kTimeUsageTotal_key                             @"total_time_active"
#define kAppStoreReviewed_key                           @"appstore_reviewed"


@interface MIRateAppController()<SKStoreProductViewControllerDelegate>
-(void)rateTheAppNow;
-(void)reset;
@end

@implementation MIRateAppController{

    double _time_active_started;
    NSString *_appstoreID;
    
    NSTimer *_timer;
}

@synthesize appstoreId = _appstoreID;
@synthesize applicationName  = _applicationName;


#pragma mark - Public API:

static MIRateAppController *shared = nil;

+(MIRateAppController *)startWithAppID:(NSString *)appId minimumTimeUsage:(NSTimeInterval)minimumTimeUsage{
    
    static dispatch_once_t pred;
    
    
    dispatch_once(&pred, ^{
        shared = [[MIRateAppController alloc] initWithAppID:appId minimumTimeUsage:minimumTimeUsage];
    });
    return shared;
}
+(void)reset{

    [shared reset];
}
-(void)reset{
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    [ud removeObjectForKey:kTimeUsageTotalNeededForNextReviewPrompt_key];
    [ud removeObjectForKey:kTimeUsageTotal_key];
    [ud removeObjectForKey:kAppStoreReviewCancelled_key];
    [ud removeObjectForKey:kAppStoreReviewed_key];
    [ud synchronize];
    
    [self resumeCheck];
    
}
+(void)rateTheAppNow{
    
    [shared rateTheAppNow];
}


#pragma mark - Private:

-(id)initWithAppID:(NSString *)appId minimumTimeUsage:(NSTimeInterval)minimumTimeUsage{


    NSAssert(appId && appId.length, @"AppStore application ID not specified");
    
    self = [super init];
    
    if (self) {
        
        _appstoreID = appId;
        
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
        _applicationName    = infoDict[@"CFBundleDisplayName"];
        
        self.minimumTimeUsage = minimumTimeUsage;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:[UIApplication sharedApplication]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:[UIApplication sharedApplication]];
        
    }
    return self;
    
}
-(id)init{
    

    NSAssert1(YES, @"Default init not allowed, use startWithMinimumTimeUsage: instead....: %@", [NSThread callStackSymbols]);
    return nil;
    
}
                   

-(void)applicationWillResignActive:(UIApplication *)application{
    //DLog(@"Application WILL RESIGN ACTIVE!!!");
    
    [self updateTotalUsageTime];
    
    [self pauseCheck];
    
}
-(void)applicationDidBecomeActive:(UIApplication *)application{
    
    //DLog(@"Application DID BECOME ACTIVE!!!");
    
    _time_active_started = CACurrentMediaTime();
    
    // TODO: Implement, better, timer based approach to avoid poing up alert view at launch
    
    NSUserDefaults *ud              = [NSUserDefaults standardUserDefaults];
    BOOL appstore_reviewed          = [ud boolForKey:kAppStoreReviewed_key];
    BOOL appstore_review_canceled   = [ud boolForKey:kAppStoreReviewCancelled_key];
    

    if (appstore_review_canceled || appstore_reviewed) {
        
#ifdef DEBUG
        NSString *message = (appstore_reviewed) ? @"Reset review app?" : @"Reset review cancel?";
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Reset App Review?" message:message delegate:self cancelButtonTitle:@"YES" otherButtonTitles:@"No", nil];
        alertView.tag = RESET_ALERT_TAG;
        [alertView show];
#endif
    
    }else{
    
        [self resumeCheck];
    }
    
    
    
}

-(void)pauseCheck{

    [_timer invalidate];
    _timer = nil;
}
-(void)resumeCheck{

    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:kMIRateAppControllerCheckIntervalDefault target:self selector:@selector(checkTimerFired:) userInfo:nil repeats:YES];
}

#pragma mark - AppStore Review Time Check:
-(void)checkTimerFired:(NSTimer *)timer{

    [self updateTotalUsageTime];
    [self checkTotalUsageTime];
    
}
-(void)updateTotalUsageTime{
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    double time_active = CACurrentMediaTime() - _time_active_started;
    double total_time_active = [ud doubleForKey:kTimeUsageTotal_key];
    total_time_active += time_active;
    //DLog(@"total time active: %.2f sec (added: %.1f sec)", total_time_active, time_active);
    
    _time_active_started = CACurrentMediaTime();
    
    [ud setDouble:total_time_active forKey:kTimeUsageTotal_key];
    [ud synchronize];
}
-(void)checkTotalUsageTime{
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    double total_time_active              = [ud doubleForKey:kTimeUsageTotal_key];
    
    BOOL appstore_reviewed          = [ud boolForKey:kAppStoreReviewed_key];
    BOOL appstore_review_canceled   = [ud boolForKey:kAppStoreReviewCancelled_key];
    
    double usageTimeTotalForNextReviewPrompt = [ud doubleForKey:kTimeUsageTotalNeededForNextReviewPrompt_key];
    if (usageTimeTotalForNextReviewPrompt < 1) {
        usageTimeTotalForNextReviewPrompt = _minimumTimeUsage;
        
    }
    
    //DLog(@"reviewed: %i, canceled: %i, total time active: %.2f sec, min time: %.2f",appstore_reviewed, appstore_review_canceled, total_time_active, usageTimeTotalForNextReviewPrompt);
    
    if (!appstore_reviewed && !appstore_review_canceled) {
        
            if (total_time_active >= usageTimeTotalForNextReviewPrompt) {
                
                NSString *titleFormat = MILocalizedString(@"Vi håber, du har glæde af %@!", @"");
                NSString *title = [NSString stringWithFormat:titleFormat, _applicationName];
                NSString *message = MILocalizedString(@"Hvis du vil, kan du hjælpe ved at give din bedømmelse af appen...", @"");
                
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:MILocalizedString(@"Jeg vil gerne hjælpe", @"") otherButtonTitles:MILocalizedString(@"Nej tak", @""), MILocalizedString(@"Senere", @""), nil];
                alertView.tag = APP_STORE_ALERT_TAG;
                [alertView show];
                [self pauseCheck];
                
            }
        
        
    }
    
}

-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
    
    switch (alertView.tag) {
        case APP_STORE_ALERT_TAG:
        {
            NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
            
            ////DLog(@"Button index: %i", buttonIndex);
            switch (buttonIndex) {
                case 1:  // cancel:
                {
                    [ud setBool:YES forKey:kAppStoreReviewCancelled_key];
                    [ud synchronize];
                }
                    break;
                case 0:
                {
                    [self rateTheAppNow];
                }
                    break;
                case 2:
                {
                    [self updateTotalUsageTime];
                    double usageTimeTotalForNextReviewPrompt = [ud doubleForKey:kTimeUsageTotalNeededForNextReviewPrompt_key];
                    double total_time_active              = [ud doubleForKey:kTimeUsageTotal_key];
                    usageTimeTotalForNextReviewPrompt = total_time_active + _minimumTimeUsage;
                    
                    [ud setDouble:usageTimeTotalForNextReviewPrompt forKey:kTimeUsageTotalNeededForNextReviewPrompt_key];
                    [ud synchronize];
                    [self resumeCheck];
                    
                }
                default:
                    break;
            }
        }
            break;
            case RESET_ALERT_TAG:
            {
                //DLog(@"button index: %i", buttonIndex);
                switch (buttonIndex) {
                    case 0: // YES
                    {
              
                        //DLog(@"resetting...");
                        [self reset];
                    }
                        break;
                    case 1: // NO:
                    {
 
                    }
                        break;
                }
            }
            break;
        default:
            break;
    }
}


-(void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    
    UIColor *navText = [MITheme colorWithName:@"navigation_bar_title"];
    [[UINavigationBar appearance] setTintColor:navText];
    
    [[UIApplication sharedApplication].keyWindow.rootViewController dismissViewControllerAnimated: YES completion: nil];
}

#pragma mark - Review Dialog:

-(void)rateTheAppNow{
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    if ([SKStoreProductViewController class] != nil) {
        
        [[UINavigationBar appearance] setTintColor:[UIColor darkGrayColor]];
        
        SKStoreProductViewController* skpvc = [SKStoreProductViewController new];
        skpvc.delegate = self;
        NSDictionary* dict = [NSDictionary dictionaryWithObject:_appstoreID forKey:SKStoreProductParameterITunesItemIdentifier];
        [skpvc loadProductWithParameters: dict completionBlock: nil];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController: skpvc animated: YES completion: ^{
            
            [ud setBool:YES forKey:kAppStoreReviewed_key];
            [ud synchronize];
            
        }];
    }
    else {
        
        static NSString *const iOS7AppStoreURLFormat = @"itms-apps://itunes.apple.com/app/id%@";
        static NSString *const iOSAppStoreURLFormat = @"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%@";
        
        
        NSURL *appstoreurl = [NSURL URLWithString:[NSString stringWithFormat:([[UIDevice currentDevice].systemVersion floatValue] >= 7.0f)? iOS7AppStoreURLFormat: iOSAppStoreURLFormat, _appstoreID]]; // Would contain the right link
        [[UIApplication sharedApplication] openURL:appstoreurl];
        
        [ud setBool:YES forKey:kAppStoreReviewed_key];
        [ud synchronize];
        
        
    }
    
    
    
}
@end
