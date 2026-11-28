// Read-only PAC snapshot for the Settings "PAC Script" screen.
//
// Two different facts are kept apart on purpose:
//   generated  the script MYbloXX builds from the selected mode, the bundled/updated rules and the user's Custom Rules
//   confirmed  whether iOS itself reports using that exact script (MYBRuntimeVerify, the same check Status uses)
// The snapshot is a mobile-owned 0600 file that Settings deletes when the screen closes. It is never served over
// HTTP and never copied into diagnostics, because the script contains the user's custom domains. Nothing here
// changes the system configuration.
static int MYBPACViewSnapshot(void){
 NSString *path=MYBDataPath(@"/var/mobile/Library/MYbloXX/PACView.plist");if(!path.length)return 73;
 NSString *mode=selectedMode(),*script=mode.length?MYBEffectiveScript(mode):nil;
 NSDictionary *structural=MYBRuntimeStatus();
 CFDictionaryRef proxies=CFNetworkCopySystemProxySettings();NSDictionary *effective=proxies?CFBridgingRelease(proxies):nil;
 NSString *sha=script.length?MYBRuntimeSHA256(script):nil;
 NSDictionary *verified=MYBRuntimeVerify(structural,sha,effective);
 NSMutableDictionary *record=[@{@"mode":mode?:@"",@"state":structural[@"state"]?:@"error",@"verification":verified[@"verification"]?:@"unchecked",@"time":[NSDate date]} mutableCopy];
 if(script.length){record[@"script"]=script;record[@"sha256"]=sha;record[@"bytes"]=@([script dataUsingEncoding:NSUTF8StringEncoding].length);}
 [FM() createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
 NSData *data=[NSPropertyListSerialization dataWithPropertyList:record format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
 if(!data||![data writeToFile:path options:NSDataWritingAtomic error:NULL])return 73;
 chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0600);
 return 0;
}
