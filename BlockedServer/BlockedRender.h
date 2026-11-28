static NSString *escape(NSString *s){return [[[[[s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"] stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"] stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"] stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"] stringByReplacingOccurrencesOfString:@"'" withString:@"&#39;"];}
// Renders the blocked page. Every value that came from a URL, an app or a request is escaped here; no untrusted
// text is ever placed into markup, an attribute, or script.
static NSString *appDisplayName(NSString *bundle){
 NSDictionary *known=@{@"com.apple.mobilesafari":@"Safari",@"org.mozilla.ios.Firefox":@"Firefox",@"com.apple.AppStore":@"App Store",@"com.apple.ios.StoreKitUIService":@"App Store"};
 if(known[bundle])return known[bundle];if(![bundle isKindOfClass:NSString.class]||!bundle.length)return @"";return bundle.length<=64?bundle:@"";
}
static NSString *renderBlockedPage(NSString *view,NSString *host,NSDictionary *why,NSString *app,NSDictionary *confirmation,NSString *allowTicket,BOOL preview){
 BOOL confirm=[view isEqual:@"confirm"];NSString *code=why[@"code"];
 NSString *reason=confirm?@"Choose how long this website may load. Only this website’s network filter changes.":(preview?@"Preview: this is how a blocked website looks.":blockedReasonText(why));
 NSString *mode=[code isEqual:@"filter-mode"]?why[@"mode"]:([code isEqual:@"custom-rule"]?@"Your rule":@"");
 NSString *detail=[code isEqual:@"custom-rule"]?@"You added this website to your own block rules. You can remove the rule, or allow the website, from MYbloXX® Settings.":
  [code isEqual:@"filter-mode"]?@"The blocking mode you selected in MYbloXX® blocks this website. Allowing it changes only this website; popup and App Store permissions are separate.":
  @"MYbloXX® protection blocked this website. The exact rule could not be identified from here.";
 NSString *from=appDisplayName(app);
 NSMutableString *body=[MYBBlockedPage mutableCopy];
 NSDictionary *replacements=@{@"{{MYB_BRAND}}":MYBBrandBase64,@"{{MYB_VIEW}}":confirm?@"confirm":@"blocked",@"{{MYB_SECRET}}":confirmation[@"secret"]?:@"",@"{{MYB_OP}}":confirmation[@"op"]?:@"",@"{{MYB_REPLAY}}":confirmation[@"replay"]?:@"none",
  @"{{MYB_TITLE}}":confirm?@"Allow this website?":@"Website blocked",@"{{MYB_HOST}}":host?:@"",@"{{MYB_REASON}}":reason,@"{{MYB_FROM}}":from,@"{{MYB_MODE}}":mode,@"{{MYB_DETAIL}}":detail,
  @"{{MYB_ALLOW_URL}}":[NSString stringWithFormat:@"%@/mybloxx-allow?request=%@",websiteOrigin(),allowTicket?:@""]};
 NSArray *raw=@[@"{{MYB_BRAND}}"]; // base64 is already inert
 for(NSString *key in replacements){NSString *value=replacements[key];[body replaceOccurrencesOfString:key withString:[raw containsObject:key]?value:escape(value) options:0 range:NSMakeRange(0,body.length)];}
 NSDictionary *flags=@{@"{{MYB_LINK_HIDDEN}}":(allowTicket&&!confirm)?@"":@"hidden",@"{{MYB_CONFIRM_HIDDEN}}":confirm?@"":@"hidden",@"{{MYB_ACTIONS_HIDDEN}}":confirm?@"hidden":@"",@"{{MYB_FROM_HIDDEN}}":from.length?@"":@"hidden",@"{{MYB_MODE_HIDDEN}}":mode.length?@"":@"hidden"};
 for(NSString *key in flags)[body replaceOccurrencesOfString:key withString:flags[key] options:0 range:NSMakeRange(0,body.length)];
 return body;
}
