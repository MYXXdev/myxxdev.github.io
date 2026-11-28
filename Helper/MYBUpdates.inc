#import "../Shared/MYBPACStamp.h"
#import "../Shared/MYBRulesGen.h"
// MYbloXX rules updater. Trusted source is fixed; no private GitHub tokens.
// Stage a complete generation, then change one symlink atomically.
static NSArray<NSString *> *updateModes(void){return MYBGeneratedPACNames();}
static NSString *BundledPACDirectory(void){return [MYBBootstrapRoot() stringByAppendingPathComponent:@"usr/share/mybloxx/pacs"];}
static NSString *GeneratorDirectory(void){return [MYBBootstrapRoot() stringByAppendingPathComponent:@"usr/share/mybloxx/generator"];}
static NSString *UpdateRoot(void){return MYBDataPath(@"/var/mobile/Library/MYbloXX");}
static NSString *UpdateStatePath(void){return [UpdateRoot() stringByAppendingPathComponent:@"Updates.plist"];}
static NSMutableDictionary *UpdateState(void){return [[NSDictionary dictionaryWithContentsOfFile:UpdateStatePath()] mutableCopy]?:[NSMutableDictionary dictionary];}
static BOOL SaveUpdates(NSDictionary *state){
 NSError *error=nil;BOOL ok=MYBSaveUpdateState(UpdateRoot(),state,&error);
 if(ok){chown(UpdateStatePath().fileSystemRepresentation,501,501);chmod(UpdateStatePath().fileSystemRepresentation,0644);}
 else logLine([NSString stringWithFormat:@"UPDATES_STATE: root=%@ error=%@",UpdateRoot(),error.localizedDescription?:@"missing writable data path"]);
 return ok;
}
static int setUpdatePolicy(BOOL enabled){NSMutableDictionary *state=UpdateState();state[@"automatic"]=@(enabled);return SaveUpdates(state)?0:73;}
static NSData *GitHubData(NSString *url){
#ifdef MYB_HELPER_TESTING
 if(gMYBTestFetch)return gMYBTestFetch(url);
#endif
 NSURL *target=[NSURL URLWithString:url];
 if(![target.scheme isEqual:@"https"] || ![@[@"api.github.com",@"raw.githubusercontent.com"] containsObject:target.host])return nil;
 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:target cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:18];
 [request setValue:@"MYbloXX-Rules-Updater" forHTTPHeaderField:@"User-Agent"];
 NSURLResponse *response=nil;NSError *error=nil;
 NSData *data=[NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
 if(error || ![response isKindOfClass:NSHTTPURLResponse.class] || [(NSHTTPURLResponse *)response statusCode]!=200 || !data.length || data.length>2*1024*1024){
  logLine([NSString stringWithFormat:@"UPDATES_FETCH: host=%@ code=%ld bytes=%lu error=%@",target.host,(long)([response isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse *)response statusCode]:0),(unsigned long)data.length,error.localizedDescription?:@"none"]);
  return nil;
 }
 return data;
}
static NSString *GitBlobSHA(NSData *data){
 NSString *header=[NSString stringWithFormat:@"blob %lu",(unsigned long)data.length];
 NSMutableData *blob=[[header dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
 uint8_t zero=0;[blob appendBytes:&zero length:1];[blob appendData:data];
 unsigned char digest[CC_SHA1_DIGEST_LENGTH];CC_SHA1(blob.bytes,(CC_LONG)blob.length,digest);
 NSMutableString *hex=[NSMutableString string];for(int i=0;i<CC_SHA1_DIGEST_LENGTH;i++)[hex appendFormat:@"%02x",digest[i]];return hex;
}
static BOOL SyntaxValid(NSData *data){
 NSString *script=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
 if(data.length<100 || data.length>2*1024*1024 || ![script containsString:@"function FindProxyForURL"])return NO;
 JSGlobalContextRef context=JSGlobalContextCreate(NULL);
 JSStringRef text=JSStringCreateWithCFString((__bridge CFStringRef)script);
 BOOL valid=JSCheckScriptSyntax(context,text,NULL,1,NULL);
 JSStringRelease(text);JSGlobalContextRelease(context);return valid;
}
static NSString *StoredCanonicalPath(NSString *generation){return [generation stringByAppendingPathComponent:@"canonical.json"];}
static BOOL PointPACs(NSString *directory){
 if(![directory hasPrefix:[UpdateRoot() stringByAppendingString:@"/"]] || ![FM() fileExistsAtPath:directory])return NO;
 NSString *temporary=[UpdateRoot() stringByAppendingPathComponent:@"PACCurrent.next"];
 [FM() removeItemAtPath:temporary error:NULL];
 if(![FM() createSymbolicLinkAtPath:temporary withDestinationPath:directory error:NULL])return NO;
 return rename(temporary.fileSystemRepresentation,[UpdateRoot() stringByAppendingPathComponent:@"PACCurrent"].fileSystemRepresentation)==0;
}
static int rollbackPACs(void){
 NSMutableDictionary *state=UpdateState();NSString *previous=state[@"previousDirectory"];
 if(![previous isKindOfClass:NSString.class])return 66;
 // A generation saved by an earlier release has only the historical files. Complete it with the built-in files for the
 // combinations it lacks, in a copy; the saved generation itself is never modified.
 NSMutableArray *missing=[NSMutableArray array];
 for(NSString *mode in updateModes())if(!filePACValid([previous stringByAppendingPathComponent:[mode stringByAppendingString:@".pac"]]))[missing addObject:mode];
 if(missing.count){
  if(![missing containsObject:@"Default"]){
   NSString *completed=[UpdateRoot() stringByAppendingPathComponent:[@"PAC-" stringByAppendingString:NSUUID.UUID.UUIDString]];
   if(![FM() copyItemAtPath:previous toPath:completed error:NULL])return 73;
   for(NSString *mode in missing){NSString *name=[mode stringByAppendingString:@".pac"];NSData *bytes=[NSData dataWithContentsOfFile:[BundledPACDirectory() stringByAppendingPathComponent:name]];
    if(!bytes||!SyntaxValid(bytes)||![bytes writeToFile:[completed stringByAppendingPathComponent:name] atomically:YES]){[FM() removeItemAtPath:completed error:NULL];return 65;}}
   previous=completed;
  }else return 65;
 }
 NSString *current=[PACDirectory() stringByResolvingSymlinksInPath];
 if(!PointPACs(previous))return 73;
 // The same transaction as every other change: regenerate the effective PAC from the restored
 // generation and apply it; on failure the previous generation and runtime are put back.
 BOOL linked=ownedLink();
 int rc=linked?MYBReapplyIfLinked():0;
 if(!rc && linked)rc=restartConfigd();
 if(rc){PointPACs(current);if(linked){MYBReapplyIfLinked();restartConfigd();}return rc;}
 // The restored generation's own rules file decides what "unchanged upstream rules" means from now on.
 NSData *restoredCanonical=[NSData dataWithContentsOfFile:StoredCanonicalPath(previous)];
 if(restoredCanonical.length)state[@"canonicalSHA"]=GitBlobSHA(restoredCanonical);else [state removeObjectForKey:@"canonicalSHA"];
 [state removeObjectForKey:@"staleRevision"];
 state[@"previousDirectory"]=current;state[@"revision"]=@"Rolled back";state[@"lastResult"]=@"Previous working rules restored";SaveUpdates(state);return 0;
}

// ---- Generations ---------------------------------------------------------------------------------
// A generation is a folder PAC-<uuid>: the 40 PAC files, the canonical.json they were generated from (so a later engine
// can regenerate them without a download), the applied custom rules and, if present, a legacy Custom.pac.
static NSData *BundledCanonical(void){return [NSData dataWithContentsOfFile:[GeneratorDirectory() stringByAppendingPathComponent:@"canonical.json"]];}
static NSData *GenerationDefault(NSString *generation){return [NSData dataWithContentsOfFile:[generation stringByAppendingPathComponent:@"Default.pac"]];}
static BOOL GenerationMatchesEngine(NSString *generation);
// RAGGR is the only rule set this release builds in. A rules file is RAGGR-based when it carries the engine-2 "compact" section
// (RAGGR host labels, shapes, families and words). Older audited feeds have the same format number but no compact section.
static BOOL CanonicalIsRAGGR(NSData *canonical){
 id parsed=canonical.length?[NSJSONSerialization JSONObjectWithData:canonical options:0 error:NULL]:nil;
 id compact=[parsed isKindOfClass:NSDictionary.class]?parsed[@"compact"]:nil;
 return [compact isKindOfClass:NSDictionary.class]&&[compact[@"format"] isKindOfClass:NSNumber.class]&&[compact[@"format"] integerValue]>=2&&[compact[@"host_labels"] isKindOfClass:NSArray.class]&&[compact[@"host_labels"] count]>0;
}
// A generation is RAGGR when the rules file stored beside it is, or (older generations store none) when its Default is byte for
// byte the built-in RAGGR Default. Anything else, including a downloaded or cached r16 set, is not RAGGR whatever its date says.
static BOOL GenerationIsRAGGR(NSString *generation){
 NSData *stored=[NSData dataWithContentsOfFile:[generation stringByAppendingPathComponent:@"canonical.json"]];
 if(stored.length)return CanonicalIsRAGGR(stored);
 NSData *def=GenerationDefault(generation);
 return def.length&&[def isEqualToData:[NSData dataWithContentsOfFile:[BundledPACDirectory() stringByAppendingPathComponent:@"Default.pac"]]];
}
static BOOL ActiveEngineCurrent(void){NSString *active=[PACDirectory() stringByResolvingSymlinksInPath];return MYBPACEngineCurrent(GenerationDefault(active))&&GenerationMatchesEngine(active)&&GenerationIsRAGGR(active);}
static NSString *StageGeneration(NSDictionary<NSString *,NSData *> *files,NSData *canonical,int *rc){
 NSString *stage=[UpdateRoot() stringByAppendingPathComponent:[@"PAC-" stringByAppendingString:NSUUID.UUID.UUIDString]];
 if(![FM() createDirectoryAtPath:stage withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:NULL]){*rc=73;return nil;}
 BOOL ok=YES;
 for(NSString *mode in updateModes())if(![files[mode] writeToFile:[stage stringByAppendingPathComponent:[mode stringByAppendingString:@".pac"]] atomically:YES]){ok=NO;break;}
 if(ok&&canonical.length)ok=[canonical writeToFile:StoredCanonicalPath(stage) atomically:YES];
 if(ok){
  // Everything the user owns travels with the new generation: applied custom rules and a Proxy Override PAC.
  NSDictionary *applied=[NSDictionary dictionaryWithContentsOfFile:[UpdateRoot() stringByAppendingPathComponent:@"AppliedRules.plist"]];
  if(applied)[applied writeToFile:[stage stringByAppendingPathComponent:@"AppliedRules.plist"] atomically:YES];
  NSString *oldCustom=PACFile(@"Custom");
  if(filePACValid(oldCustom)&&![FM() copyItemAtPath:oldCustom toPath:[stage stringByAppendingPathComponent:@"Custom.pac"] error:NULL])ok=NO;
 }
 if(!ok){[FM() removeItemAtPath:stage error:NULL];*rc=73;return nil;}
 return stage;
}
// One transaction for every change of generation: switch the link, regenerate the effective PAC, restart; on any failure the previous generation and runtime come back.
static int ActivateGeneration(NSString *stage,NSString *previous){
 if(!PointPACs(stage)){logLine(@"UPDATES: atomic PACCurrent switch failed");return 73;}
 BOOL linked=ownedLink();
 int rc=linked?MYBReapplyIfLinked():0;
 if(!rc&&linked)rc=restartConfigd();
 if(rc){PointPACs(previous);if(linked){MYBReapplyIfLinked();restartConfigd();}}
 return rc;
}
static void DropObsoleteGeneration(NSDictionary *state,NSString *keepA,NSString *keepB,NSString *keepC){
 NSString *obsolete=state[@"previousDirectory"];
 if([obsolete isKindOfClass:NSString.class]&&[obsolete hasPrefix:[UpdateRoot() stringByAppendingPathComponent:@"PAC-"]]&&![obsolete isEqual:keepA]&&![obsolete isEqual:keepB]&&![obsolete isEqual:keepC])[FM() removeItemAtPath:obsolete error:NULL];
}

// ---- Built-in rules generation -------------------------------------------------------------------
// A package upgrade ships new bundled PACs, but the rules actually in use live in the data folder (PACCurrent from an
// earlier update, else PAC). Engine and rule age are decided separately:
//  * rules older than the bundled rules, or the same date as the bundled rules, are replaced by the bundled set: an equal
//    date from the old engine still installs the new engine (a downloaded set of the same date from the CURRENT engine
//    is kept, a built-in set is refreshed);
//  * downloaded rules NEWER than the bundled rules are never replaced by older data. If they came from the old engine they
//    are regenerated with the new engine from the canonical.json stored beside them; if none was stored (every earlier
//    release) they stay active unchanged and the next rules check fetches and converts them.
// The replaced generation stays as the rollback target.
// The PAC header tells the file format, not which generator made a generation. A generation counts as the installed engine's
// only when that engine regenerates exactly its Default from the canonical.json stored beside it, so rules an older engine built
// (for example r16 output of rules that carry an engine-2 compact section) are converted on upgrade instead of being kept.
// Without a stored rules file the header decides, as before.
static BOOL GenerationMatchesEngine(NSString *generation){
 NSData *stored=[NSData dataWithContentsOfFile:StoredCanonicalPath(generation)];
 if(!stored.length)return YES;
 NSString *why=nil;NSDictionary<NSString *,NSData *> *again=MYBGenerateModePACs(stored,GeneratorDirectory(),&why);
 return again&&[again[@"Default"] isEqualToData:GenerationDefault(generation)];
}
static int refreshBundledPACs(void){
 migrateSavedMode();
 NSArray<NSString *> *names=updateModes();
 NSString *bundled=BundledPACDirectory();
 NSString *digest=MYBPACSetDigest(bundled,names);
 if(!digest){logLine(@"BUNDLED_RULES: the bundled PAC set is incomplete or unreadable; active rules unchanged");return 65;}
 NSMutableDictionary *state=UpdateState();
 NSData *bundledCanonical=BundledCanonical();
 if([state[@"bundledDigest"] isEqual:digest])return 0;
 NSMutableDictionary *data=[NSMutableDictionary dictionary];
 for(NSString *mode in names){NSData *bytes=[NSData dataWithContentsOfFile:[bundled stringByAppendingPathComponent:[mode stringByAppendingString:@".pac"]]];if(!bytes||!SyntaxValid(bytes)){logLine([NSString stringWithFormat:@"BUNDLED_RULES: bundled %@.pac failed validation; active rules unchanged",mode]);return 65;}data[mode]=bytes;}
 NSString *active=[PACDirectory() stringByResolvingSymlinksInPath];
 BOOL identical=YES;
 for(NSString *mode in names)if(![[NSData dataWithContentsOfFile:[active stringByAppendingPathComponent:[mode stringByAppendingString:@".pac"]]] isEqualToData:data[mode]]){identical=NO;break;}
 NSData *activeDefault=GenerationDefault(active);
 long long activeStamp=MYBPACStamp(activeDefault),bundledStamp=MYBPACStamp(data[@"Default"]);
 BOOL activeRAGGR=GenerationIsRAGGR(active);
 BOOL activeCurrent=MYBPACEngineCurrent(activeDefault)&&GenerationMatchesEngine(active)&&activeRAGGR;
 // Active rules without a revision, or installed from the package, are built-in rules; anything else was downloaded.
 NSString *activeRevision=[state[@"revision"] isKindOfClass:NSString.class]?state[@"revision"]:@"";
 BOOL activeBuiltIn=!activeRevision.length||[activeRevision hasPrefix:@"built-in-"];
 if(identical){
  state[@"bundledDigest"]=digest;
  if(bundledCanonical.length&&!state[@"canonicalSHA"]){state[@"canonicalSHA"]=GitBlobSHA(bundledCanonical);state[@"rulesSource"]=@"built-in";}
  return SaveUpdates(state)?0:73;
 }
 NSDictionary<NSString *,NSData *> *install=data;NSData *installCanonical=bundledCanonical;long long installStamp=bundledStamp;BOOL converted=NO;
 // Cached or downloaded rules that are not RAGGR (r16 and earlier) never win on date: the built-in RAGGR set replaces them.
 if(activeStamp>bundledStamp&&!activeRAGGR)logLine([NSString stringWithFormat:@"BUNDLED_RULES: cached non-RAGGR rules (%@) replaced by the built-in RAGGR rules (%@)",MYBPACStampText(activeStamp),MYBPACStampText(bundledStamp)]);
 if(activeStamp>bundledStamp&&activeRAGGR){
  if(activeCurrent){
   // A downloaded generation newer than this package is never downgraded by an upgrade.
   state[@"bundledDigest"]=digest;
   state[@"lastResult"]=[NSString stringWithFormat:@"Kept downloaded rules (%@), newer than this package's built-in rules (%@)",MYBPACStampText(activeStamp),MYBPACStampText(bundledStamp)];
   logLine(state[@"lastResult"]);
   return SaveUpdates(state)?0:73;
  }
  // Newer rules from the old engine: keep their data, move them to the new engine.
  NSData *stored=[NSData dataWithContentsOfFile:StoredCanonicalPath(active)];NSString *why=nil;
  NSDictionary<NSString *,NSData *> *regenerated=stored.length?MYBGenerateModePACs(stored,GeneratorDirectory(),&why):nil;
  if(regenerated&&MYBGenerationStamp(regenerated)>=activeStamp){install=regenerated;installCanonical=stored;installStamp=MYBGenerationStamp(regenerated);converted=YES;}
  else{
   state[@"bundledDigest"]=digest;[state removeObjectForKey:@"revision"];
   state[@"lastResult"]=[NSString stringWithFormat:@"Kept downloaded rules (%@), newer than this package's built-in rules (%@). They are converted to the optimized engine at the next rules check",MYBPACStampText(activeStamp),MYBPACStampText(bundledStamp)];
   logLine([state[@"lastResult"] stringByAppendingString:stored.length?[@" (stored rules did not regenerate: " stringByAppendingString:[(why?:@"unknown") stringByAppendingString:@")"]]:@" (no stored rules file)"]);
   return SaveUpdates(state)?0:73;
  }
 }else if(activeStamp==bundledStamp&&activeCurrent&&!activeBuiltIn){
  // Same date, same engine, downloaded: the user's downloaded set stays.
  state[@"bundledDigest"]=digest;
  state[@"lastResult"]=[NSString stringWithFormat:@"Kept downloaded rules (%@); the package's built-in rules have the same date",MYBPACStampText(activeStamp)];
  logLine(state[@"lastResult"]);
  return SaveUpdates(state)?0:73;
 }
 int rc=0;
 // The rollback target must keep the OLD rules even when they live in the fallback PAC folder that is refreshed below.
 NSString *fallback=MYBDataPath(@"/var/mobile/Library/MYbloXX/PAC"),*previousTarget=active;
 if([[fallback stringByResolvingSymlinksInPath] isEqual:active]&&[FM() fileExistsAtPath:active]){
  previousTarget=[UpdateRoot() stringByAppendingPathComponent:[@"PAC-" stringByAppendingString:NSUUID.UUID.UUIDString]];
  if(![FM() copyItemAtPath:active toPath:previousTarget error:NULL]){logLine(@"BUNDLED_RULES: could not preserve the previous rules for rollback; active rules unchanged");return 73;}
 }
 NSString *stage=StageGeneration(install,installCanonical,&rc);
 if(stage)rc=ActivateGeneration(stage,active);
 if(rc){if(stage)[FM() removeItemAtPath:stage error:NULL];if(![previousTarget isEqual:active])[FM() removeItemAtPath:previousTarget error:NULL];logLine([NSString stringWithFormat:@"BUNDLED_RULES: could not activate the built-in rules (code %d); previous rules retained",rc]);return rc;}
 // The fallback copies must not be stale either (they are what a reset or a missing PACCurrent falls back to).
 if(!converted&&[FM() fileExistsAtPath:fallback])for(NSString *mode in names){NSString *path=[fallback stringByAppendingPathComponent:[mode stringByAppendingString:@".pac"]];if([data[mode] writeToFile:path atomically:YES]){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}}
 DropObsoleteGeneration(state,active,previousTarget,stage);
 state[@"previousDirectory"]=previousTarget;state[@"bundledDigest"]=digest;
 [state removeObjectForKey:@"staleRevision"];
 if(converted){
  state[@"lastResult"]=[NSString stringWithFormat:@"Downloaded rules (%@) converted to the optimized engine; your custom rules and selected mode are preserved",MYBPACStampText(installStamp)];
 }else{
  state[@"revision"]=[@"built-in-" stringByAppendingString:[digest substringToIndex:12]];
  if(installCanonical.length){state[@"canonicalSHA"]=GitBlobSHA(installCanonical);state[@"rulesSource"]=@"built-in";}
  state[@"lastResult"]=[NSString stringWithFormat:@"Built-in rules (%@) are now active; your custom rules and selected mode are preserved",MYBPACStampText(installStamp)];
 }
 state[@"lastSuccess"]=[NSDate date];
 logLine(state[@"lastResult"]);
 return SaveUpdates(state)?0:73;
}
// ---- Check Now and the daily automatic check: one path --------------------------------------------
// Fetch one GitHub revision, verify the canonical blob against that revision's listing, validate and generate every
// combination locally, compare engine and age separately, stage, switch atomically, and put the old generation back on
// any failure. Nothing is changed unless every step before it succeeded.
static BOOL LegacyDateFormat(id text){
 return [text isKindOfClass:NSString.class]&&MYBStampGroups(text,@"\\A\\d{2}/\\d{2}/\\d{2} - \\d{2}:\\d{2}(?: [A-Za-z]{2,5})?\\z")!=nil;
}
static int updatePACs(BOOL automatic){
 int built=refreshBundledPACs();if(built)return built;
 NSMutableDictionary *state=UpdateState();
 if(automatic && !MYBUpdateDue(state,[NSDate date]))return 0;
 state[@"lastAttempt"]=[NSDate date];if(automatic)state[@"lastAutomaticAttempt"]=[NSDate date];state[@"lastResult"]=@"Checking upstream rule manifest";if(!SaveUpdates(state))return 73;
 NSString *stage=nil;int rc=69;
 do {
  NSData *commitData=GitHubData(@"https://api.github.com/repos/MYXXdev/myxxdev.github.io/commits/master");
  NSDictionary *commit=commitData?[NSJSONSerialization JSONObjectWithData:commitData options:0 error:NULL]:nil;
  NSString *revision=[commit isKindOfClass:NSDictionary.class]?commit[@"sha"]:nil;
  NSCharacterSet *hex=[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
  if(![revision isKindOfClass:NSString.class] || revision.length!=40 || [revision rangeOfCharacterFromSet:hex.invertedSet].location!=NSNotFound){state[@"lastResult"]=@"Unable to reach or verify upstream GitHub revision";break;}
  BOOL engineCurrent=ActiveEngineCurrent();
  if(engineCurrent&&[revision isEqual:state[@"revision"]]){rc=0;state[@"lastCheck"]=[NSDate date];state[@"lastResult"]=@"Rules are up to date";break;}
  if([revision isEqual:state[@"staleRevision"]]){rc=0;state[@"lastCheck"]=[NSDate date];state[@"lastResult"]=@"Upstream rules are still older than the installed rules; installed rules kept until upstream is updated";break;}
  NSData *listing=GitHubData([NSString stringWithFormat:@"https://api.github.com/repos/MYXXdev/myxxdev.github.io/contents/MYbloXX?ref=%@",revision]);
  NSArray *entries=listing?[NSJSONSerialization JSONObjectWithData:listing options:0 error:NULL]:nil;
  if(![entries isKindOfClass:NSArray.class]){state[@"lastResult"]=@"Unable to download verified GitHub rule manifest";break;}
  NSMutableDictionary *hashes=[NSMutableDictionary dictionary];
  for(id entry in entries)if([entry isKindOfClass:NSDictionary.class] && [entry[@"name"] isKindOfClass:NSString.class] && [entry[@"sha"] isKindOfClass:NSString.class])hashes[entry[@"name"]]=entry[@"sha"];
  // One rules file is the update. Every combination is generated here from it; no per-mode PAC file is downloaded or required.
  // (Upstream may keep publishing the standalone PACs and aliases for older app versions; this version ignores them.)
  if(!hashes[@"canonical.json"]){
   state[@"staleRevision"]=revision;state[@"lastCheck"]=[NSDate date];
   state[@"lastResult"]=@"Upstream has not published the canonical rules file yet; built-in rules kept";logLine(@"UPDATES: upstream has no canonical.json at this revision; nothing installed");
   rc=0;break;
  }
  // The same rules file as the installed ones: nothing to do, whatever else changed on master. (Not while the installed set still needs the new engine.)
  if(engineCurrent&&[hashes[@"canonical.json"] isEqual:state[@"canonicalSHA"]]){rc=0;state[@"revision"]=revision;[state removeObjectForKey:@"staleRevision"];state[@"lastCheck"]=[NSDate date];state[@"lastResult"]=@"Rules are up to date";break;}
  NSData *canonical=GitHubData([NSString stringWithFormat:@"https://raw.githubusercontent.com/MYXXdev/myxxdev.github.io/%@/MYbloXX/canonical.json",revision]);
  if(!canonical||![GitBlobSHA(canonical) isEqual:hashes[@"canonical.json"]]){state[@"lastResult"]=@"The downloaded rules could not be verified; existing rules preserved";logLine(@"UPDATES: canonical.json failed the revision hash check");break;}
  // The release date comes first: a file in the previous date format is a release that has not been moved to UTC yet, anything else
  // without a real UTC date is refused.
  {
   NSDictionary *parsed=[NSJSONSerialization JSONObjectWithData:canonical options:0 error:NULL];
   id stamp=[parsed isKindOfClass:NSDictionary.class]?parsed[@"stamp"]:nil;
   if(![parsed isKindOfClass:NSDictionary.class]||!MYBCanonicalStamp(stamp)){
    if(LegacyDateFormat(stamp)){
     state[@"staleRevision"]=revision;state[@"lastCheck"]=[NSDate date];rc=0;
     state[@"lastResult"]=@"Upstream rules still use the previous date format and have not been updated yet; installed rules kept";
     logLine(@"UPDATES: upstream canonical.json has a legacy date; nothing installed");break;
    }
    state[@"lastResult"]=@"Upstream rules have a missing or invalid date; existing rules preserved";logLine(@"UPDATES: canonical.json has no valid UTC date; nothing installed");rc=65;break;
   }
  }
  if(!CanonicalIsRAGGR(canonical)){
   // An older-format (audited, non-RAGGR) feed can never replace RAGGR, however new its date. The built-in or installed RAGGR rules stay.
   state[@"staleRevision"]=revision;state[@"lastCheck"]=[NSDate date];rc=0;
   state[@"lastResult"]=@"Upstream rules do not include the RAGGR rules yet; the built-in RAGGR rules are kept";
   logLine(@"UPDATES: upstream canonical.json has no RAGGR (compact) section; nothing installed");break;
  }
  NSString *why=nil;NSDictionary<NSString *,NSData *> *generated=MYBGenerateModePACs(canonical,GeneratorDirectory(),&why);
  if(!generated){state[@"lastResult"]=@"Rule validation failed; existing rules preserved";logLine([@"UPDATES: " stringByAppendingString:why?:@"generation failed"]);rc=65;break;}
  for(NSString *mode in updateModes())if(!SyntaxValid(generated[mode])){state[@"lastResult"]=@"Rule syntax validation failed; existing rules preserved";logLine([NSString stringWithFormat:@"UPDATES: generated %@ failed the syntax check",mode]);rc=65;break;}
  if(rc==65)break;
  long long got=MYBGenerationStamp(generated);
  if(!MYBStampPlausible(got,[NSDate date])){state[@"lastResult"]=@"Upstream rules have a date that is not plausible; existing rules preserved";logLine([NSString stringWithFormat:@"UPDATES: stamp %@ is not plausible; nothing installed",MYBPACStampText(got)]);rc=65;break;}
  // Age and engine are separate questions. Older than what is installed or built in is never installed. The same date is
  // installed only to move an installed set to the new engine (or to catch up from a rolled-back older set).
  NSString *previous=[PACDirectory() stringByResolvingSymlinksInPath];
  long long activeStamp=GenerationIsRAGGR(previous)?MYBPACStamp(GenerationDefault(previous)):0,have=MAX(MYBPACStamp([NSData dataWithContentsOfFile:[BundledPACDirectory() stringByAppendingPathComponent:@"Default.pac"]]),activeStamp);
  if(got<have){
   state[@"staleRevision"]=revision;state[@"lastCheck"]=[NSDate date];
   state[@"lastResult"]=[NSString stringWithFormat:@"Upstream rules (%@) are older than the installed rules (%@); installed rules kept until upstream is updated",MYBPACStampText(got),MYBPACStampText(have)];
   logLine([NSString stringWithFormat:@"UPDATES: upstream stamp %@ older than local %@; generation not installed",MYBPACStampText(got),MYBPACStampText(have)]);
   rc=0;break;
  }
  if(got==have&&engineCurrent&&got<=activeStamp){
   state[@"revision"]=revision;[state removeObjectForKey:@"staleRevision"];state[@"lastCheck"]=[NSDate date];state[@"lastResult"]=@"Rules are up to date";rc=0;break;
  }
  stage=StageGeneration(generated,canonical,&rc);
  if(!stage){state[@"lastResult"]=@"Could not stage the new rules; existing rules preserved";break;}
  rc=ActivateGeneration(stage,previous);
  if(rc)break;
  DropObsoleteGeneration(state,previous,stage,nil);
  state[@"previousDirectory"]=previous;state[@"revision"]=revision;state[@"rulesSource"]=@"canonical";state[@"canonicalSHA"]=hashes[@"canonical.json"];[state removeObjectForKey:@"staleRevision"];state[@"lastSuccess"]=[NSDate date];state[@"lastCheck"]=[NSDate date];
  state[@"lastResult"]=[NSString stringWithFormat:@"Updated rules (%@): all combinations generated on this device; custom rules and selected mode preserved",MYBPACStampText(got)];
  stage=nil; // Installed generation must not be removed below.
 }while(NO);
 if(stage)[FM() removeItemAtPath:stage error:NULL];
 if(rc && [state[@"lastResult"] isEqualToString:@"Checking upstream rule manifest"])state[@"lastResult"]=rc==65?@"Rule syntax validation failed; existing rules preserved":@"Update failed while applying rules; existing rules preserved";
 if(rc)logLine(@"Rules update failed; previous generation retained. Automatic checks run once per 24 hours; Check Now can retry immediately.");
 if(!SaveUpdates(state) && !rc)return 73;return rc;
}
