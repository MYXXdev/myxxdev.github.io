#import <UIKit/UIKit.h>

%hook CUTTelephonyManager
- (void)setDisableFastDormancyTokens:(id)arg1 {
	%orig;
}

- (bool)disableFastDormancy {
	return YES;
}

- (void)addFastDormancyDisableToken:(id)arg1 {
	%orig;
}

- (void)_setFastDormancySuspended:(bool)arg1 {
	arg1 = YES;
	//%orig;
}

- (void)set_suspendDormancyAssertion:(void*)arg1 {
	%orig;
}

- (id)disableFastDormancyTokens {
	return %orig;
}

- (bool)registered {
	return YES;
}

- (void)setRegistered:(bool)arg1 {
	arg1 = YES;
	//%orig;
}
%end

%hook UIDevice
- (bool)sf_isChinaRegionCellularDevice {
	return YES;
}
%end

%hook NSURLSessionConfiguration
- (bool)_preventsIdleSleepOnceConnected {
	return YES;
}

- (bool)_preventsIdleSleep {
	return YES;
}
%end

%hook NSURLSessionTask
- (bool)_preventsIdleSystemSleep {
	return YES;
}
%end

%hook _NSHTTPConnectionInfo
- (bool)isValid {
	return YES;
}
%end
