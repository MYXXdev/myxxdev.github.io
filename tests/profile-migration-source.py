"""Source guards for legacy-profile migration (the helper cannot run on Linux; the behaviour itself is covered by
tests/profile-migration-native.m with a fake system, which CI compiles and runs)."""
import re,sys
from pathlib import Path
r=Path(__file__).resolve().parents[1]
inc=re.sub(r'//.*','',(r/'Helper/MYBProfileMigrate.inc').read_text()+(r/'Shared/MYBProfileService.h').read_text());eng=re.sub(r'//.*','',(r/'Shared/MYBProfileMigration.h').read_text());main=(r/'Helper/MYXXdev.m').read_text();f=[]
def c(ok,m):
    print(('PASS ' if ok else 'FAIL ')+m)
    if not ok:f.append(m)
c(eng.count('e.remove(ident)')==1 and 'kind==MYBProfileStandaloneLegacy' in eng and 'kind==MYBProfileCandidate' in eng and 'MYBProfileOrganisationOurs' in eng,'the only removal call sits behind the classifier')
c(eng.index('e.record(r)')<eng.index('e.remove(ident)'),'recovery is stored before removal and a failed store aborts')
c('MYB_MIGRATE_RECORD_FAILED' in eng,'a failed recovery write returns without removing')
c('containsObject:ident' in eng or 'MYBLegacyProfileKnownIdentifiers() containsObject:ident' in eng,'only known identifiers are ever described')
c('e.managedGone()&&e.effectiveClear(pac)' in eng and 'MYBMigrationListed(now,ident)' in eng,'removal is confirmed from the service, the managed file and the effective proxy')
c('for(int i=0;i<=e.steps;i++)' in eng,'the confirmation wait is bounded')
c('removeProfileAsyncWithIdentifier' not in inc,'the installation-type variant (unknown integer argument) is not used')
c('MYBSignatureIs(svc,s,"v",@[@"@",@"@?"])' in inc and 'MYBSignatureIs(svc,s,"@",@[])' in inc,'every private selector is signature-checked before it is called')
c('void(^completion)(void *,void *)' in inc,'the completion block never dereferences its unknown arguments')
c('F_FULLFSYNC' in inc and 'rename(' in inc,'the recovery record is flushed to disk and replaced atomically')
c('kCFProxyAutoConfigurationURLKey' in inc,'the effective proxy configuration is observed')
c(not re.search(r'ConfigurationProfiles|enrol|unlink\(path|removeItem|rm -',inc),'no profile database deletion, no enrolment')
c("MYBMigrateLegacyProfile(YES)" in main and "MYBMigrateLegacyProfile(NO)" in main and '"migrateprofile"' in main and 'MYB_MIGRATE_APPLY_FAILED' in main,'enable and migrateprofile reach the migration and surface an apply failure')
c('!userChose' in eng and 'MYB_MIGRATE_SWITCH_NEEDED' in eng,'the engine returns SWITCH_NEEDED instead of removing unless the person chose')
ui=(r/'Preferences/MYBMenuBase.m').read_text();c('Switch to Native Protection' in ui and 'runHelper:@[@"migrateprofile"]' in ui and 'ManagedConfigurationList' in ui,'the UI offers Switch to Native Protection and Device Management')
st=(r/'Helper/MYBStartup.inc').read_text();c('MYBMigrateLegacyProfile(NO)' in st and 'MYBMigrateLegacyProfile(YES)' not in st,'startup only inspects, never removes')
c(not re.search(r'MYBMigrateLegacyProfile\(YES\)',main.replace('rc=MYBMigrateLegacyProfile(YES);','',1)),'only the explicit migrateprofile action removes')
sys.exit(1 if f else 0)
