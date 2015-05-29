# MIRateViewController
Simple iOS class to engage users to rate an application

# Simplest usage:
Add this to your AppDelegate didFinishWithLaunchingOptions:...

NSString *appStoreAppID = [[NSBundle mainBundle] infoDictionary][@"AppStoreApplicationID"];
[MIRateAppController startWithAppID:appStoreAppID minimumTimeUsage:kMIRateAppControllerTimeUsageMinDefault];
