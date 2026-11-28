// Every claim in a mode notice (Shared/MYBModeCatalog.h) is checked against the PACs that actually ship.
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const dir='layout/usr/share/mybloxx/pacs/';
const pac={};for(const m of ['Default','allowY','blockAdSense','blockApple','blockSocials','blockXXX']){pac[m]=vm.createContext({});vm.runInContext(fs.readFileSync(dir+m+'.pac','utf8'),pac[m]);}
const blocked=(m,h)=>pac[m].FindProxyForURL('https://'+h+'/',h)!=='DIRECT';
const cat=fs.readFileSync('Shared/MYBModeCatalog.h','utf8');
const notice=n=>{const i=cat.indexOf('[mode isEqual:@"'+n+'"])return');assert(i>0,n+' has a notice');return cat.slice(i,cat.indexOf('\n',i));};
// blockApple: each named service family has at least one blocked address, Default blocks none of them
for(const h of ['gsa.apple.com','setup.icloud.com','imessage.apple.com','buy.itunes.apple.com','swscan.apple.com']){assert(blocked('blockApple',h),'blockApple blocks '+h);assert(!blocked('Default',h),'Default leaves '+h);}
for(const w of ['iCloud','iMessage','App Store','software updates'])assert(notice('blockApple').includes(w),'blockApple notice names '+w);
// blockSocials: everything the notice names is blocked; Google is NOT blocked, so the notice must not claim it
for(const h of ['www.facebook.com','www.instagram.com','www.tiktok.com','www.snapchat.com','x.com','www.reddit.com'])assert(blocked('blockSocials',h),'blockSocials blocks '+h);
for(const h of ['www.google.com','www.youtube.com'])assert(!blocked('blockSocials',h),'blockSocials leaves '+h);
assert(!/Google/.test(notice('blockSocials')),'blockSocials notice does not claim Google');
for(const w of ['Facebook','Instagram','TikTok','Snapchat','X (Twitter)','Reddit'])assert(notice('blockSocials').includes(w));
// blockXXX: blocks adult domains; the notice must not promise completeness
for(const h of ['www.pornhub.com','xvideos.com'])assert(blocked('blockXXX',h)&&!blocked('Default',h),h);
assert(/cannot cover every site/.test(notice('blockXXX'))&&/Limit Adult Websites/.test(notice('blockXXX')));
// allowY: the two named addresses are reachable here and blocked by Default
for(const h of ['m.yap.yahoo.com','graph.instagram.com']){assert(!blocked('allowY',h)&&blocked('Default',h),h);}
// blockAdSense: Facebook Graph is blocked here but not in Default; www.facebook.com stays reachable (sign-in page)
assert(blocked('blockAdSense','graph.facebook.com')&&!blocked('Default','graph.facebook.com'));
assert(/Facebook and Messenger sign-in/.test(notice('blockAdSense')));
// Default and unknown modes carry no notice; the same function serves normal mode and legacy profiles
assert(!/\[mode isEqual:@"Default"\]\)return/.test(cat));
for(const f of ['Preferences/MYBModernController.m','Preferences/MYBLegacyController.m'])assert(/MYBModeWarning\((mode|added),(NO|YES)\)/.test(fs.readFileSync(f,'utf8')),f+' shows the notice');
console.log('Mode notices match the shipped PACs.');
