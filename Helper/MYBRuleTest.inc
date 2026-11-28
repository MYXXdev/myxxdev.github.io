static int testPACDomain(NSString *input){
 NSString *raw=[input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];NSURLComponents *url=[NSURLComponents componentsWithString:[raw containsString:@"://"]?raw:[@"https://" stringByAppendingString:raw]];if(![@[@"http",@"https"] containsObject:url.scheme.lowercaseString]||url.user.length||url.password.length)return 64;NSString *host=url.host.lowercaseString;
 NSArray *domains=validateDomainList(host);
 if(domains.count!=1 || ![domains.firstObject isEqual:host])return 64;
 NSString *mode=selectedMode();
 if(![loadSavedState()[@"enabled"] boolValue])return [@{@"domain":host,@"mode":mode,@"result":@"DIRECT",@"testedAt":NSDate.date} writeToFile:MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.ruletest.plist") atomically:YES]?0:73;if(!validMode(mode) && ![mode isEqual:@"Custom"])return 69;
 NSString *path=filePACValid(PACFile(mode))?PACFile(mode):BundledPAC(mode);
 NSString *script=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
 if(!script)return 66;
 script=MYBWebsitePAC(script,MYBWebsiteLiveDomains([NSDictionary dictionaryWithContentsOfFile:MYBWebsiteFile()]));if(!script)return 65;
 JSContext *context=[JSContext new];
 context[@"dnsDomainIs"]=^BOOL(NSString *h,NSString *d){return [h hasSuffix:d];};
 context[@"shExpMatch"]=^BOOL(NSString *value,NSString *pattern){
  NSString *escaped=[NSRegularExpression escapedPatternForString:pattern];
  escaped=[[escaped stringByReplacingOccurrencesOfString:@"\\*" withString:@".*"] stringByReplacingOccurrencesOfString:@"\\?" withString:@"."];
  NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^%@$",escaped] options:0 error:NULL];
  return [regex numberOfMatchesInString:value options:0 range:NSMakeRange(0,value.length)]>0;
 };
 [context evaluateScript:script];if(context.exception)return 65;
 JSValue *value=[context[@"FindProxyForURL"] callWithArguments:@[url.URL.absoluteString,host]];
 if(context.exception || !value.isString)return 65;
 NSDictionary *result=@{@"domain":host,@"mode":mode,@"result":value.toString,@"testedAt":[NSDate date]};
 return [result writeToFile:MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.ruletest.plist") atomically:YES]?0:73;
}
