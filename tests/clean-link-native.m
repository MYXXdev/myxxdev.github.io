// Focused check of Shared/MYBCleanLink.h (no object subscripting so it also builds with the GNU runtime).
#import "../Shared/MYBCleanLink.h"
static int fails=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL %s\n",m);fails++;}}while(0)
static NSString *C(NSString *u){return [MYBCleanLink(u) objectForKey:@"clean"];}
static BOOL Ch(NSString *u){return [[MYBCleanLink(u) objectForKey:@"changed"] boolValue];}
int main(void){@autoreleasepool{
 CHECK([C(@"https://example.com/a?utm_source=x&utm_medium=y&id=7")isEqual:@"https://example.com/a?id=7"],"utm removed, unknown id kept");
 CHECK([C(@"https://example.com/a?fbclid=abc")isEqual:@"https://example.com/a"],"only tracker: query dropped");
 CHECK([C(@"https://example.com/a?id=7&gclid=1#section-2")isEqual:@"https://example.com/a?id=7#section-2"],"fragment kept");
 CHECK([C(@"https://example.com/a?utm_x=1#frag")isEqual:@"https://example.com/a#frag"],"fragment kept when query empties");
 CHECK([C(@"https://example.com/s?q=caf%C3%A9+au+lait&utm_campaign=z")isEqual:@"https://example.com/s?q=caf%C3%A9+au+lait"],"original encoding untouched");
 CHECK([C(@"https://example.com/s?b=2&a=1&igsh=q&c=3")isEqual:@"https://example.com/s?b=2&a=1&c=3"],"order of unknown parameters kept");
 CHECK([C(@"https://example.com/a?ref=friend&id=1")isEqual:@"https://example.com/a?ref=friend&id=1"]&&!Ch(@"https://example.com/a?ref=friend&id=1"),"unknown ref kept, nothing changed");
 CHECK([C(@"https://youtu.be/abc?si=xyz&t=30")isEqual:@"https://youtu.be/abc?t=30"],"YouTube si removed, time kept");
 CHECK(!Ch(@"https://example.com/a?si=1"),"si is only tracking on its own sites");
 CHECK(!Ch(@"https://shop.example.com/checkout?utm_source=a"),"checkout left alone");
 CHECK(!Ch(@"https://example.com/login?utm_source=a"),"login left alone");
 CHECK(!Ch(@"https://example.com/invite/abc?utm_source=a"),"invitation left alone");
 CHECK(!Ch(@"https://example.com/f?utm_source=a&X-Amz-Signature=abc"),"signed link left alone");
 CHECK(!Ch(@"https://example.com/f?utm_source=a&token=abc"),"token link left alone");
 CHECK(!Ch(@"https://user:pw@example.com/f?utm_source=a"),"credentials in link left alone");
 CHECK(!Ch(@"mailto:a@b.com?utm_source=a")&&!Ch(@"not a link"),"non-web text left alone");
 CHECK(!Ch(@"https://example.com/a"),"no query, nothing to do");
 CHECK([[MYBCleanLink(@"https://example.com/a?UTM_Source=x&fbclid=1")objectForKey:@"removed"]isEqual:(@[@"utm_source",@"fbclid"])],"removed list holds names, not values");
 CHECK([C(@"  https://example.com/a?gclid=1\n")isEqual:@"https://example.com/a"],"surrounding whitespace trimmed");
 if(fails){fprintf(stderr,"%d failed\n",fails);return 1;}
 puts("clean-link-native ok");return 0;}}
