#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "../Shared/MYBSetupBackup.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
@interface MYBBackupController:MYBMenuBase<UIDocumentPickerDelegate> @end
@implementation MYBBackupController
- (NSDictionary *)backupStatus{return [NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/BackupStatus.plist")]?:@{};}
- (void)rebuildMenu{
 self.title=@"Backup & Restore";NSDictionary *status=self.backupStatus;NSDate *date=status[@"lastSuccess"];
 NSString *last=[date isKindOfClass:NSDate.class]?[NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle]:@"No saved backup yet";
 self.menuSections=@[
 @{@"title":@"YOUR SAVED SETUP",@"rows":@[@{@"title":@"On This iPhone",@"detail":last,@"icon":@"externaldrive",@"action":@"backupInfo"}],@"footer":@"Changes save automatically. Your backup and last PAC remain after uninstalling MYbloXX®."},
 @{@"title":@"BACKUP & RECOVERY",@"rows":@[@{@"title":@"Back Up Now",@"detail":@"Save your settings, rules and current PAC",@"icon":@"arrow.down.doc",@"action":@"backupNow"},@{@"title":@"Restore Backup",@"detail":@"Recover a previously saved setup",@"icon":@"arrow.counterclockwise",@"action":@"restoreOptions"},@{@"title":@"Export Backup",@"detail":@"Share a copy or save it somewhere else",@"icon":@"square.and.arrow.up",@"action":@"shareSetup"}]}];[self.tableView reloadData];
}
- (void)backupInfo{MYBMessage(self,@"Your Saved Setup",@"Files → On My iPhone → MYbloXX\n\nMYbloXX-Settings.plist contains your complete backup. MYbloXX.pac is your last exported PAC. These files are kept when MYbloXX® is removed.");}
- (void)restoreOptions{if(self.busy)return;MYBChoose(self,@"Restore Backup",@[@"Use Saved Backup",@"Choose a Backup File"],^(NSUInteger choice){if(choice==0)[self restoreSaved];else [self chooseBackup];});}
- (void)backupNow{if(self.busy)return;[self runHelper:@[@"backupfiles"] completion:^(int rc){[self showMessage:rc?@"Backup Failed":@"Setup Backed Up" detail:rc?@"The previous saved setup was retained. Please check the Backup Status and try again.":@"Your complete settings and current effective PAC are saved in Files → On My iPhone → MYbloXX."];}];}
- (void)shareSetup{
 if(self.busy)return;
 NSString *folder=MYBPublicFilesFolder();if(!folder){[self showMessage:@"Files Folder Unavailable" detail:@"Try Back Up Now first."];return;}
 NSString *shareFolder=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"MYbloXX-Setup-" stringByAppendingString:NSUUID.UUID.UUIDString]];[NSFileManager.defaultManager createDirectoryAtPath:shareFolder withIntermediateDirectories:YES attributes:nil error:NULL];
 NSMutableArray *urls=[NSMutableArray array];for(NSString *name in @[@"MYbloXX-Settings.plist"]){NSString *path=[folder stringByAppendingPathComponent:name];if(![NSFileManager.defaultManager fileExistsAtPath:path]){[self showMessage:@"Backup Not Ready" detail:@"Choose Back Up Now, then share your setup."];return;}NSString *copy=[shareFolder stringByAppendingPathComponent:name];if(![NSFileManager.defaultManager copyItemAtPath:path toPath:copy error:NULL]){[NSFileManager.defaultManager removeItemAtPath:shareFolder error:NULL];[self showMessage:@"Unable to Share" detail:@"The setup files could not be copied. Please try again."];return;}[urls addObject:[NSURL fileURLWithPath:copy]];}
 UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil];share.completionWithItemsHandler=^(__unused UIActivityType type,__unused BOOL completed,__unused NSArray *items,__unused NSError *error){[NSFileManager.defaultManager removeItemAtPath:shareFolder error:NULL];};share.popoverPresentationController.sourceView=self.view;share.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,self.view.bounds.size.height/2,1,1);[self presentViewController:share animated:YES completion:nil];
}
- (void)confirmRestore:(NSString *)command name:(NSString *)name{
 [self confirm:@"Restore Your Backup?" message:[NSString stringWithFormat:@"Restore %@? This replaces all MYbloXX® settings, manual rules and PAC modes with the saved setup, including its enabled/disabled state. The backup is checked before changes are applied.",name] action:^{[self runHelper:@[command] completion:^(int rc){NSString *detail=rc==65?@"This is not a complete supported MYbloXX® settings backup. Your current setup was retained.":rc==78?@"The saved Legacy Supervision state cannot be safely restored on this device. Your current setup was retained.":rc==74?@"A saved companion component is not installed. Your current setup was retained.":@"Your previous setup was retained. Please check that the backup file and required components are available.";[self showMessage:rc?@"Restore Failed":@"Setup Restored" detail:rc?detail:@"Your saved settings are applied. Close and reopen Safari and affected apps. Respring if you changed the Control Center module."];}];}];
}
- (void)restoreSaved{if(self.busy)return;[self confirmRestore:@"restorebackup" name:@"MYbloXX-Settings.plist from your MYbloXX folder"];}
- (void)chooseBackup{if(self.busy)return;UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypePropertyList] asCopy:YES];picker.delegate=self;picker.allowsMultipleSelection=NO;[self presentViewController:picker animated:YES completion:nil];}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls{
 NSURL *url=urls.firstObject;if(!url)return;BOOL scoped=[url startAccessingSecurityScopedResource];NSNumber *size=nil;[url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
 NSData *data=size && size.unsignedLongLongValue<=48*1024*1024?[NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:NULL]:nil;
 if(scoped)[url stopAccessingSecurityScopedResource];NSString *path=MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.restore-import.plist");
 if(!data.length||data.length>48*1024*1024||![data writeToFile:path atomically:YES]){[self showMessage:@"Unable to Import Backup" detail:@"Choose a readable MYbloXX-Settings.plist smaller than 48 MB."];return;}
 [self confirmRestore:@"restoreimport" name:url.lastPathComponent];
}
@end
