#import "PrivateAlbum.h"
#import "PrivateUI.h"
#import <Photos/Photos.h>
#import <PhotosUI/PHLivePhotoView.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <Block.h>

// Heap blocks receive their Objective-C isa from the iOS Blocks runtime.
#define MYXXHeapBlock(...) ((__typeof__((__VA_ARGS__)))CFBridgingRelease(\
    _Block_copy((__bridge const void *)(__VA_ARGS__))))

// Photos uses an explicit PhotoKit library in its multi-library process.
@interface PHPhotoLibrary (MYXXPhotosLibrary)
+ (PHPhotoLibrary *)px_appPhotoLibrary;
@end

@interface PHFetchOptions (MYXXPhotosLibrary)
@property(nonatomic, strong) PHPhotoLibrary *photoLibrary;
@end

@interface PHAssetChangeRequest (MYXXPermanentRemoval)
+ (void)expungeAssets:(id<NSFastEnumeration>)assets;
@end

static PHPhotoLibrary *AppPhotoLibrary(void) {
    @try {
        if ([PHPhotoLibrary respondsToSelector:@selector(px_appPhotoLibrary)]) {
            return [PHPhotoLibrary px_appPhotoLibrary];
        }
    } @catch (__unused NSException *exception) {
        // Leave the operation unavailable if Photos cannot provide a library.
    }
    return nil;
}

static NSURL *OpenPrivateRoot(NSURL *root, NSError **error) {
    NSFileManager *files = NSFileManager.defaultManager;
    if (![files createDirectoryAtURL:root withIntermediateDirectories:YES
        attributes:@{NSFilePosixPermissions: @0700} error:error]) {
        return nil;
    }

    NSURL *probe = [root URLByAppendingPathComponent:
        [@".write-check-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    if (![[NSData data] writeToURL:probe options:NSDataWritingFileProtectionComplete error:error] ||
        ![files removeItemAtURL:probe error:error]) {
        return nil;
    }
    return root;
}

static NSURL *PrivateRoot(NSError **error) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *storageKey = @"com.myxxdev.privatephotos.storagePath";
    NSMutableArray<NSURL *> *candidates = [NSMutableArray array];

    NSURL *support = [files URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    if (support) [candidates addObject:[support URLByAppendingPathComponent:@"MYXXPrivatePhotos" isDirectory:YES]];

    // System Photos can have a mobile home directory instead of a writable app container.
    // Keep the fallback under PhotoData, outside DCIM and outside the Photos catalog.
    [candidates addObject:[NSURL fileURLWithPath:@"/var/mobile/Media/PhotoData/.MYXXPrivatePhotos" isDirectory:YES]];

    NSString *savedPath = [defaults stringForKey:storageKey];
    for (NSURL *root in candidates) {
        if ([root.path isEqualToString:savedPath]) return OpenPrivateRoot(root, error);
    }

    // Retain any previously used folder even if it is temporarily unwritable.
    for (NSURL *root in candidates) {
        NSArray *items = [files contentsOfDirectoryAtURL:root includingPropertiesForKeys:nil
            options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
        if (items.count) {
            NSURL *opened = OpenPrivateRoot(root, error);
            if (opened) [defaults setObject:opened.path forKey:storageKey];
            return opened;
        }
    }

    for (NSURL *root in candidates) {
        NSURL *opened = OpenPrivateRoot(root, error);
        if (opened) {
            [defaults setObject:opened.path forKey:storageKey];
            return opened;
        }
    }
    return nil;
}

@interface MYXXAlbumItem : NSObject
@property(nonatomic, strong) NSURL *directory;
@property(nonatomic, strong) NSURL *file;
@property(nonatomic, strong) NSURL *motionFile;
@property(nonatomic, copy) NSString *assetID;
@property(nonatomic, strong) NSDate *date;
@property(nonatomic) BOOL video;
+ (instancetype)itemAtDirectory:(NSURL *)directory;
@end

@implementation MYXXAlbumItem
+ (instancetype)itemAtDirectory:(NSURL *)directory {
    NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfURL:
        [directory URLByAppendingPathComponent:@"item.plist"]];
    NSString *filename = metadata[@"filename"];
    if (![filename isKindOfClass:NSString.class] || !filename.length ||
        ![filename isEqualToString:filename.lastPathComponent] ||
        [filename isEqualToString:@"."] || [filename isEqualToString:@".."] ||
        ![metadata[@"assetID"] isKindOfClass:NSString.class] ||
        ![metadata[@"date"] isKindOfClass:NSDate.class]) {
        return nil;
    }

    NSURL *file = [directory URLByAppendingPathComponent:filename];
    if (![NSFileManager.defaultManager fileExistsAtPath:file.path]) {
        return nil;
    }
    MYXXAlbumItem *item = [self new];
    item.directory = directory;
    item.file = file;
    if ([metadata[@"live"] isEqual:@YES]) {
        item.motionFile = [directory URLByAppendingPathComponent:@"paired-motion.mov"];
        if (![NSFileManager.defaultManager fileExistsAtPath:item.motionFile.path]) return nil;
    }
    item.assetID = metadata[@"assetID"];
    item.date = metadata[@"date"];
    item.video = [metadata[@"video"] boolValue];
    return item;
}
@end

static NSError *AlbumError(NSString *message) {
    return [NSError errorWithDomain:@"com.myxxdev.emptyrecentlydeleted" code:1
        userInfo:@{NSLocalizedDescriptionKey: message}];
}

static BOOL VerifyCopy(NSURL *file, BOOL video, NSError **error) {
    NSNumber *size;
    if (![file getResourceValue:&size forKey:NSURLFileSizeKey error:error]) {
        return NO;
    }
    BOOL readable;
    if (video) {
        readable = [AVURLAsset URLAssetWithURL:file options:nil].playable;
    } else {
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)file, NULL);
        readable = source && CGImageSourceGetCount(source) > 0;
        if (source) CFRelease(source);
    }
    if (!size.unsignedLongLongValue || !readable) {
        if (error) *error = AlbumError(@"The copied file could not be opened.");
        return NO;
    }
    return YES;
}

static void StreamResource(PHAssetResource *resource, NSURL *file, void (^completion)(NSError *)) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSError *error = nil;
    PHAssetResourceRequestOptions *options = [PHAssetResourceRequestOptions new];
    options.networkAccessAllowed = YES;
    if (![files createFileAtPath:file.path contents:nil
        attributes:@{NSFileProtectionKey: NSFileProtectionComplete, NSFilePosixPermissions: @0600}]) {
        
        completion(AlbumError(@"Private Album could not create a protected copy in its storage folder."));
        return;
    }
    NSFileHandle *output = [NSFileHandle fileHandleForWritingToURL:file error:&error];
    if (!output) {
        
        completion(error);
        return;
    }

    __block NSError *writeError = nil;
    [[PHAssetResourceManager defaultManager] requestDataForAssetResource:resource options:options
        dataReceivedHandler:MYXXHeapBlock(^(NSData *chunk) {
            if (!writeError) [output writeData:chunk error:&writeError];
        }) completionHandler:MYXXHeapBlock(^(NSError *exportError) {
            NSError *result = writeError ?: exportError;
            NSError *closeError = nil;
            if (![output closeAndReturnError:&closeError] && !result) result = closeError;
            if (!result) {
                // The system's own size for this resource, when it will tell us: a shorter copy is an incomplete copy.
                id expected = nil;
                @try { expected = [resource respondsToSelector:NSSelectorFromString(@"fileSize")] ? [resource valueForKey:@"fileSize"] : nil; } @catch (__unused id e) { expected = nil; }
                NSNumber *written = nil;
                [file getResourceValue:&written forKey:NSURLFileSizeKey error:NULL];
                if ([expected isKindOfClass:NSNumber.class] && [expected longLongValue] > 0 &&
                    written.longLongValue != [expected longLongValue]) {
                    result = AlbumError(@"The private copy is not the same size as the original, so the original was kept.");
                }
            }
            completion(result);
        })];
}

static void ExportAsset(PHAsset *asset, NSURL *root, void (^completion)(NSError *, BOOL)) {
    NSArray<PHAssetResource *> *resources = [PHAssetResource assetResourcesForAsset:asset];
    BOOL video = asset.mediaType == PHAssetMediaTypeVideo;
    PHAssetResourceType original = video ? PHAssetResourceTypeVideo : PHAssetResourceTypePhoto;
    PHAssetResourceType rendered = video ? PHAssetResourceTypeFullSizeVideo : PHAssetResourceTypeFullSizePhoto;
    PHAssetResource *resource = nil;
    for (PHAssetResource *candidate in resources) {
        if (candidate.type == rendered) {
            resource = candidate;
            break;
        }
        if (candidate.type == original && !resource) resource = candidate;
    }
    if (!resource || (!video && asset.mediaType != PHAssetMediaTypeImage)) {
        completion(AlbumError(@"Photos did not provide a readable photo or video resource."), NO);
        return;
    }

    BOOL live = (asset.mediaSubtypes & PHAssetMediaSubtypePhotoLive) != 0;
    PHAssetResource *paired = nil;
    if (live) {
        PHAssetResourceType motionType = resource.type == rendered
            ? PHAssetResourceTypeFullSizePairedVideo : PHAssetResourceTypePairedVideo;
        for (PHAssetResource *candidate in resources) {
            if (candidate.type == motionType) {
                paired = candidate;
                break;
            }
        }
        if (!paired) {
            completion(AlbumError(@"Photos did not provide the matching Live Photo motion file."), NO);
            return;
        }
    }
    BOOL canRemoveOriginal = resource.type == original && resources.count == (paired ? 2 : 1);

    NSFileManager *files = NSFileManager.defaultManager;
    NSString *identifier = NSUUID.UUID.UUIDString;
    NSURL *staging = [root URLByAppendingPathComponent:[@"." stringByAppendingString:identifier] isDirectory:YES];
    NSURL *destination = [root URLByAppendingPathComponent:identifier isDirectory:YES];
    NSError *error = nil;
    if (![files createDirectoryAtURL:staging withIntermediateDirectories:NO
        attributes:@{NSFilePosixPermissions: @0700} error:&error]) {
        completion(error, NO);
        return;
    }

    NSString *filename = resource.originalFilename.lastPathComponent;
    if (!filename.length || [@[@".", @"..", @"item.plist", @"paired-motion.mov"] containsObject:filename]) {
        filename = video ? @"Video.mov" : @"Photo.jpg";
    }
    NSURL *file = [staging URLByAppendingPathComponent:filename];
    void (^finish)(NSError *) = MYXXHeapBlock(^(NSError *result) {
            NSDictionary *metadata = @{
                @"filename": filename, @"assetID": asset.localIdentifier,
                @"date": asset.creationDate ?: NSDate.date, @"video": @(video), @"live": @(paired != nil)
            };
            if (!result && VerifyCopy(file, video, &result) &&
                [files setAttributes:@{NSFileProtectionKey: NSFileProtectionComplete}
                    ofItemAtPath:file.path error:&result]) {
                NSURL *manifest = [staging URLByAppendingPathComponent:@"item.plist"];
                NSData *data = [NSPropertyListSerialization dataWithPropertyList:metadata
                    format:NSPropertyListBinaryFormat_v1_0 options:0 error:&result];
                if (data && [data writeToURL:manifest
                    options:NSDataWritingAtomic | NSDataWritingFileProtectionComplete error:&result]) {
                    [files moveItemAtURL:staging toURL:destination error:&result];
                }
            }
            if (result) [files removeItemAtURL:staging error:NULL];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(result, !result && canRemoveOriginal); });
    });
    StreamResource(resource, file, MYXXHeapBlock(^(NSError *result) {
        if (result || !paired) {
            finish(result);
            return;
        }
        NSURL *motion = [staging URLByAppendingPathComponent:@"paired-motion.mov"];
        StreamResource(paired, motion, MYXXHeapBlock(^(NSError *motionError) {
            NSError *result = motionError;
            if (!result) VerifyCopy(motion, YES, &result);
            finish(result);
        }));
    }));
}

// Every message is a MYbloXX® sheet. The positive look is for a completed save or Move only.
static void PresentMessage(UIViewController *presenter, NSString *title, NSString *message) {
    BOOL ok = [title hasPrefix:@"Moved"] || [title hasPrefix:@"Added"];
    MYXXShowMessage(presenter, title, message, ok);
}

static void PresentShare(UIViewController *presenter, NSArray<MYXXAlbumItem *> *items, UIBarButtonItem *anchor) {
    if (!items.count) return;
    NSMutableArray<NSURL *> *files = [NSMutableArray array];
    for (MYXXAlbumItem *item in items) {
        [files addObject:item.file];
        if (item.motionFile) [files addObject:item.motionFile];
    }
    UIActivityViewController *sheet = [[UIActivityViewController alloc]
        initWithActivityItems:files applicationActivities:nil];
    sheet.popoverPresentationController.barButtonItem = anchor;
    [presenter presentViewController:sheet animated:YES completion:nil];
}

// ---- Export as ZIP ----------------------------------------------------------------------------------------------------------------------
// Bulk export is a copy: the private items stay where they are. The items are linked (or, if linking is refused, copied) into a staging folder with
// ordered names, iOS zips that folder itself, and the ZIP goes to the share sheet. The staging folder and the ZIP live in the temporary directory and are
// removed when the share sheet closes, when the next export starts and when the album opens.
static NSURL *ExportRoot(void) {
    return [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:@"MYXXPrivateExport" isDirectory:YES];
}
static void CleanExports(void) { [NSFileManager.defaultManager removeItemAtURL:ExportRoot() error:NULL]; }

static BOOL StageFile(NSURL *source, NSURL *destination, NSError **error) {
    NSFileManager *files = NSFileManager.defaultManager;
    if ([files linkItemAtURL:source toURL:destination error:NULL]) return YES;
    return [files copyItemAtURL:source toURL:destination error:error];
}

static void BuildZip(NSArray<MYXXAlbumItem *> *items, void (^completion)(NSURL *zip, NSError *error)) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSFileManager *files = NSFileManager.defaultManager;
        CleanExports();
        NSURL *staging = [ExportRoot() URLByAppendingPathComponent:@"Private Album" isDirectory:YES];
        NSError *error = nil;
        if (![files createDirectoryAtURL:staging withIntermediateDirectories:YES attributes:nil error:&error]) { completion(nil, error); return; }
        NSUInteger number = 0;
        for (MYXXAlbumItem *item in items) {
            number++;
            NSString *name = [NSString stringWithFormat:@"%04lu-%@", (unsigned long)number, item.file.lastPathComponent];
            if (!StageFile(item.file, [staging URLByAppendingPathComponent:name], &error)) { CleanExports(); completion(nil, error); return; }
            if (item.motionFile) {   // a Live Photo keeps its video next to its still, with the same number and name
                NSString *motion = [[name stringByDeletingPathExtension] stringByAppendingPathExtension:@"MOV"];
                if (!StageFile(item.motionFile, [staging URLByAppendingPathComponent:motion], &error)) { CleanExports(); completion(nil, error); return; }
            }
        }
        __block NSURL *zip = nil;
        __block NSError *copyError = nil;
        NSError *coordinationError = nil;
        [[[NSFileCoordinator alloc] initWithFilePresenter:nil] coordinateReadingItemAtURL:staging options:NSFileCoordinatorReadingForUploading
            error:&coordinationError byAccessor:^(NSURL *zipped) {
            NSURL *destination = [ExportRoot() URLByAppendingPathComponent:@"Private Album.zip"];
            [files removeItemAtURL:destination error:NULL];
            if ([files copyItemAtURL:zipped toURL:destination error:&copyError]) zip = destination;   // the system's copy is only valid inside this block
        }];
        [files removeItemAtURL:staging error:NULL];
        NSData *head = zip ? [NSData dataWithContentsOfURL:zip options:NSDataReadingMappedIfSafe error:NULL] : nil;
        BOOL valid = head.length > 4 && memcmp(head.bytes, "PK", 2) == 0;
        if (!valid) { CleanExports(); completion(nil, coordinationError ?: copyError ?: AlbumError(@"The ZIP could not be created.")); return; }
        completion(zip, nil);
    });
}

@interface MYXXAlbumCell : UICollectionViewCell
@property(nonatomic, strong) UIImageView *thumbnail;
@property(nonatomic, strong) UILabel *badge;
@property(nonatomic, strong) NSURL *representedFile;
@property(nonatomic, strong) NSObject *previewToken;
@end

@implementation MYXXAlbumCell
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _thumbnail = [[UIImageView alloc] initWithFrame:self.contentView.bounds];
    _thumbnail.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _thumbnail.contentMode = UIViewContentModeScaleAspectFill;
    _thumbnail.clipsToBounds = YES;
    _thumbnail.backgroundColor = MYXXPanel();
    self.contentView.layer.cornerRadius = 10;
    self.contentView.layer.cornerCurve = kCACornerCurveContinuous;
    self.contentView.layer.masksToBounds = YES;
    [self.contentView addSubview:_thumbnail];
    _badge = [[UILabel alloc] initWithFrame:CGRectZero];
    _badge.translatesAutoresizingMaskIntoConstraints = NO;
    _badge.textColor = UIColor.whiteColor;
    _badge.backgroundColor = [MYXXBackground() colorWithAlphaComponent:0.82];
    _badge.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    [self.contentView addSubview:_badge];
    [NSLayoutConstraint activateConstraints:@[
        [_badge.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-4],
        [_badge.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4]
    ]];
    return self;
}
- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    self.contentView.layer.borderColor = MYXXAccent().CGColor;
    self.contentView.layer.borderWidth = selected ? 2 : 0;
}
@end

static UIImage *Thumbnail(MYXXAlbumItem *item) {
    if (item.video) {
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc]
            initWithAsset:[AVURLAsset URLAssetWithURL:item.file options:nil]];
        generator.appliesPreferredTrackTransform = YES;
        generator.maximumSize = CGSizeMake(360, 360);
        CGImageRef image = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:NULL];
        UIImage *thumbnail = image ? [UIImage imageWithCGImage:image] : nil;
        if (image) CGImageRelease(image);
        return thumbnail;
    }

    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)item.file, NULL);
    if (!source) return nil;
    NSDictionary *options = @{
        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @360
    };
    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    UIImage *thumbnail = image ? [UIImage imageWithCGImage:image] : nil;
    if (image) CGImageRelease(image);
    return thumbnail;
}

static void ConfirmPrivateDeletion(UIViewController *presenter, NSUInteger count, void (^confirmed)(void)) {
    NSString *title = count == 1 ? @"Delete this item?" : [NSString stringWithFormat:
        @"Delete %lu items?", (unsigned long)count];
    MYXXShowChoice(presenter, title, @"Items deleted from Private Album are permanently removed. This cannot be undone.",
        @"trash.fill", @[
        @{@"title": @"Delete", @"style": @"destructive", @"handler": MYXXHeapBlock(^{ confirmed(); })},
        @{@"title": @"Cancel", @"style": @"cancel"}]);
}

@interface MYXXPrivateAlbumController : UICollectionViewController
    <UICollectionViewDelegateFlowLayout>
@property(nonatomic, copy) NSArray<MYXXAlbumItem *> *items;
@property(nonatomic, strong) NSURL *root;
@property(nonatomic, strong) UIBarButtonItem *addButton;
@property(nonatomic, strong) UIBarButtonItem *selectButton;
@property(nonatomic, strong) UIBarButtonItem *shareButton;
@property(nonatomic, strong) UIBarButtonItem *actionsButton;
@property(nonatomic, strong) UIBarButtonItem *trashButton;
@property(nonatomic, strong) UIBarButtonItem *exportButton;
@property(nonatomic, strong) NSCache<NSURL *, UIImage *> *thumbnails;
@property(nonatomic, strong) dispatch_queue_t thumbnailQueue;
@property(nonatomic, strong) PHFetchResult<PHAsset *> *importAssets;
@property(nonatomic, strong) PHPhotoLibrary *importLibrary;
@property(nonatomic, strong) PHImageManager *imageManager;
@property(nonatomic, strong) UIBarButtonItem *importButton;
@property(nonatomic) BOOL selecting;
@property(nonatomic) BOOL busy;
- (void)reloadItems;
@end

@interface MYXXAlbumPreview : UIViewController <UIScrollViewDelegate, UIGestureRecognizerDelegate>
@property(nonatomic, copy) NSArray<MYXXAlbumItem *> *items;
@property(nonatomic) NSInteger index;
@property(nonatomic, strong) UIImageView *photo;
@property(nonatomic, strong) UIScrollView *zoomView;
@property(nonatomic, strong) PHLivePhotoView *liveView;
@property(nonatomic, strong) UIButton *play;
@property(nonatomic, weak) MYXXPrivateAlbumController *album;
@property(nonatomic, strong) UIBarButtonItem *shareButton;
@property(nonatomic) BOOL controlsHidden;
@end

@implementation MYXXAlbumPreview
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = MYXXBackground();
    self.photo = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.photo.translatesAutoresizingMaskIntoConstraints = NO;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.photo.contentMode = UIViewContentModeScaleAspectFit;
    self.zoomView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.zoomView.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomView.delegate = self;
    self.zoomView.maximumZoomScale = 4;
    self.zoomView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.zoomView];
    [self.zoomView addSubview:self.photo];
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    UILayoutGuide *content = self.zoomView.contentLayoutGuide;
    UILayoutGuide *frame = self.zoomView.frameLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.zoomView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [self.zoomView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [self.zoomView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [self.zoomView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
        [self.photo.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.photo.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [self.photo.topAnchor constraintEqualToAnchor:content.topAnchor],
        [self.photo.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [self.photo.widthAnchor constraintEqualToAnchor:frame.widthAnchor],
        [self.photo.heightAnchor constraintEqualToAnchor:frame.heightAnchor]
    ]];
    self.play = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.play setTitle:@"Play Video" forState:UIControlStateNormal];
    self.play.translatesAutoresizingMaskIntoConstraints = NO;
    [self.play addTarget:self action:@selector(playVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.play];
    [NSLayoutConstraint activateConstraints:@[
        [self.play.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.play.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
    for (NSNumber *direction in @[@(UISwipeGestureRecognizerDirectionLeft), @(UISwipeGestureRecognizerDirectionRight), @(UISwipeGestureRecognizerDirectionDown)]) {
        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipe:)];
        swipe.direction = direction.unsignedIntegerValue;
        [self.zoomView.panGestureRecognizer requireGestureRecognizerToFail:swipe];
        swipe.delegate = self;
        [self.view addGestureRecognizer:swipe];
    }
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleControls)];
    tap.cancelsTouchesInView = NO;
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(zoomAtTap:)];
    doubleTap.numberOfTapsRequired = 2;
    doubleTap.cancelsTouchesInView = NO;
    [tap requireGestureRecognizerToFail:doubleTap];
    [self.photo addGestureRecognizer:doubleTap];
    [self.photo addGestureRecognizer:tap];
    self.photo.userInteractionEnabled = YES;
    self.shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
        target:self action:@selector(share)];
    UIBarButtonItem *trash = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
        target:self action:@selector(deleteCurrent)];
    UIBarButtonItem *info = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"info.circle"]
        style:UIBarButtonItemStylePlain target:self action:@selector(showItemInfo)];
    info.accessibilityLabel = @"Info";
    self.toolbarItems = @[self.shareButton,
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
        info,
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
        trash];
    [self displayItem];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:self.controlsHidden animated:animated];
    [self.navigationController setToolbarHidden:self.controlsHidden animated:animated];
}

- (void)toggleControls {
    self.controlsHidden = !self.controlsHidden;
    [self.navigationController setNavigationBarHidden:self.controlsHidden animated:YES];
    [self.navigationController setToolbarHidden:self.controlsHidden animated:YES];
}

- (void)zoomAtTap:(UITapGestureRecognizer *)gesture {
    if (self.items[self.index].video) return;
    UIScrollView *scroll = self.zoomView;
    if (scroll.zoomScale > scroll.minimumZoomScale + 0.01) {
        [scroll setZoomScale:scroll.minimumZoomScale animated:YES];
        return;
    }
    CGFloat scale = MIN(2.5, scroll.maximumZoomScale);
    CGPoint point = [gesture locationInView:self.photo];
    CGSize size = CGSizeMake(CGRectGetWidth(scroll.bounds) / scale, CGRectGetHeight(scroll.bounds) / scale);
    CGRect target = CGRectMake(point.x - size.width / 2, point.y - size.height / 2, size.width, size.height);
    [scroll zoomToRect:target animated:YES];
}

- (void)showItemInfo {
    MYXXAlbumItem *item = self.items[self.index];
    NSString *date = [NSDateFormatter localizedStringFromDate:item.date dateStyle:NSDateFormatterLongStyle
        timeStyle:NSDateFormatterShortStyle];
    NSString *kind = item.motionFile ? @"Live Photo" : (item.video ? @"Video" : @"Photo");
    NSString *message = [NSString stringWithFormat:@"%@\n%@\n%@", date, kind, item.file.lastPathComponent];
    PresentMessage(self, @"Item Info", message);
}

- (void)deleteCurrent {
    MYXXAlbumItem *item = self.items[self.index];
    ConfirmPrivateDeletion(self, 1, MYXXHeapBlock(^{
        NSError *error = nil;
        if (![NSFileManager.defaultManager removeItemAtURL:item.directory error:&error]) {
            PresentMessage(self, @"Delete failed", error.localizedDescription);
            return;
        }
        NSMutableArray *remaining = [self.items mutableCopy];
        [remaining removeObjectAtIndex:self.index];
        self.items = remaining;
        [self.album reloadItems];
        if (!remaining.count) {
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }
        self.index = MIN(self.index, (NSInteger)remaining.count - 1);
        [self displayItem];
    }));
}

- (void)displayItem {
    MYXXAlbumItem *item = self.items[self.index];
    self.title = [NSDateFormatter localizedStringFromDate:item.date dateStyle:NSDateFormatterMediumStyle
        timeStyle:NSDateFormatterNoStyle];
    [self.liveView stopPlayback];
    [self.liveView removeFromSuperview];
    self.liveView = nil;
    self.play.enabled = YES;
    [self.zoomView setZoomScale:1 animated:NO];
    self.photo.image = item.video ? Thumbnail(item) : [UIImage imageWithContentsOfFile:item.file.path];
    self.play.hidden = !item.video && !item.motionFile;
    [self.play setTitle:item.motionFile ? @"Play Live Photo" : @"Play Video" forState:UIControlStateNormal];
}
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.items[self.index].video ? nil : self.photo;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    return self.zoomView.zoomScale <= self.zoomView.minimumZoomScale + 0.01;
}

- (void)swipe:(UISwipeGestureRecognizer *)gesture {
    if (gesture.direction == UISwipeGestureRecognizerDirectionDown) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    BOOL forward = gesture.direction == UISwipeGestureRecognizerDirectionLeft;
    if (self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) forward = !forward;
    NSInteger next = self.index + (forward ? 1 : -1);
    if (next >= 0 && next < (NSInteger)self.items.count) {
        self.index = next;
        [self displayItem];
    }
}
- (void)playVideo {
    MYXXAlbumItem *item = self.items[self.index];
    if (item.motionFile) {
        [self playLiveItem:item];
        return;
    }
    [self playMovieAtURL:item.file];
}

- (void)playLiveItem:(MYXXAlbumItem *)item {
    self.play.enabled = NO;
    [PHLivePhoto requestLivePhotoWithResourceFileURLs:@[item.file, item.motionFile]
        placeholderImage:self.photo.image targetSize:CGSizeZero
        contentMode:PHImageContentModeAspectFit resultHandler:MYXXHeapBlock(^(PHLivePhoto *live, NSDictionary *info) {
            if ([info[PHLivePhotoInfoIsDegradedKey] boolValue]) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.items.count || self.items[self.index] != item || !self.view.window) return;
                self.play.enabled = YES;
                if (!live) {
                    [self playMovieAtURL:item.motionFile];
                    return;
                }
                PHLivePhotoView *view = [[PHLivePhotoView alloc] initWithFrame:self.photo.bounds];
                view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                view.contentMode = UIViewContentModeScaleAspectFit;
                view.livePhoto = live;
                [self.photo addSubview:view];
                self.liveView = view;
                self.play.hidden = YES;
                [view startPlaybackWithStyle:PHLivePhotoViewPlaybackStyleFull];
            });
        })];
}

- (void)playMovieAtURL:(NSURL *)url {
    AVPlayerViewController *player = [AVPlayerViewController new];
    player.player = [AVPlayer playerWithURL:url];
    [self presentViewController:player animated:YES completion:MYXXHeapBlock(^{ [player.player play]; })];
}
- (void)share {
    PresentShare(self, @[self.items[self.index]], self.shareButton);
}
@end

@implementation MYXXPrivateAlbumController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Private Album";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.collectionView.backgroundColor = MYXXBackground();
    [self.collectionView registerClass:MYXXAlbumCell.class forCellWithReuseIdentifier:@"Item"];
    self.thumbnails = [NSCache new];
    self.thumbnails.countLimit = 120;
    self.thumbnailQueue = dispatch_queue_create("com.myxxdev.privatephotos.thumbnails", DISPATCH_QUEUE_SERIAL);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(closeAlbum)];
    self.addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
        target:self action:@selector(addItems)];
    self.selectButton = [[UIBarButtonItem alloc] initWithTitle:@"Select" style:UIBarButtonItemStylePlain
        target:self action:@selector(toggleSelection)];
    self.shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
        target:self action:@selector(shareSelected)];
    self.actionsButton = [[UIBarButtonItem alloc] initWithTitle:@"More" style:UIBarButtonItemStylePlain
        target:self action:@selector(itemActions)];
    self.trashButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
        target:self action:@selector(deleteSelection)];
    self.exportButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up.on.square"]
        style:UIBarButtonItemStylePlain target:self action:@selector(exportAll)];
    self.exportButton.accessibilityLabel = @"Export All as ZIP";
    CleanExports();
    self.toolbarItems = @[self.shareButton,
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
        self.actionsButton,
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
        self.trashButton];

    NSError *error = nil;
    self.root = PrivateRoot(&error);
    [self reloadItems];
    if (!self.root) {
        dispatch_async(dispatch_get_main_queue(), ^{
            PresentMessage(self, @"Private Album unavailable", error.localizedDescription);
        });
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self refreshControls];
}

- (void)closeAlbum {
    if (self.importAssets) {
        self.importAssets = nil;
        self.collectionView.allowsMultipleSelection = NO;
        self.title = @"Private Album";
        [self reloadItems];
        return;
    }
    if (!self.busy) [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)refreshControls {
    if (self.importAssets) {
        self.importButton.enabled = self.collectionView.indexPathsForSelectedItems.count > 0;
        return;
    }
    self.navigationItem.leftBarButtonItem.title = @"Done";
    self.navigationItem.rightBarButtonItems = self.selecting ? @[self.selectButton] : @[self.addButton, self.selectButton, self.exportButton];
    self.exportButton.enabled = !self.busy && self.items.count > 0;
    self.addButton.accessibilityLabel = @"Add Photos and Videos";
    self.addButton.enabled = self.root && !self.busy;
    self.selectButton.enabled = !self.busy && (self.selecting || self.items.count);
    self.selectButton.title = self.selecting ? @"Cancel" : @"Select";
    self.navigationItem.leftBarButtonItem.enabled = !self.busy;
    self.navigationController.modalInPresentation = self.busy;
    NSUInteger selectionCount = self.collectionView.indexPathsForSelectedItems.count;
    BOOL selected = selectionCount != 0;
    if (!self.busy) {
        self.title = self.selecting && selected ? [NSString stringWithFormat:@"%lu Selected",
            (unsigned long)selectionCount] : @"Private Album";
    }
    self.shareButton.enabled = selected && !self.busy;
    self.actionsButton.enabled = selected && !self.busy;
    self.trashButton.enabled = selected && !self.busy;
    if (self.navigationController.topViewController == self) {
        [self.navigationController setToolbarHidden:!self.selecting animated:YES];
    }
}

- (void)reloadItems {
    NSMutableArray *items = [NSMutableArray array];
    if (self.root) {
        NSArray *directories = [NSFileManager.defaultManager contentsOfDirectoryAtURL:self.root
            includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
        for (NSURL *directory in directories) {
            MYXXAlbumItem *item = [MYXXAlbumItem itemAtDirectory:directory];
            if (item) [items addObject:item];
        }
    }
    self.items = [items sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
    self.collectionView.backgroundView = self.items.count ? nil : [self emptyState];
    [self.collectionView reloadData];
    [self refreshControls];
}

// The empty gallery: the MYbloXX® mark, a title and one line on what to do.
- (UIView *)emptyState {
    UIImageView *mark = [[UIImageView alloc] initWithImage:MYXXMarkImage()];
    mark.contentMode = UIViewContentModeScaleAspectFit;
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[[mark.widthAnchor constraintEqualToConstant:64], [mark.heightAnchor constraintEqualToConstant:64]]];
    UILabel *title = [UILabel new];
    title.text = @"Private Album is empty";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    title.adjustsFontForContentSizeCategory = YES;
    title.textColor = UIColor.whiteColor;
    title.numberOfLines = 0;
    title.textAlignment = NSTextAlignmentCenter;
    UILabel *detail = [UILabel new];
    detail.text = @"Tap + to move photos and videos here. They leave your Photos library.";
    detail.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    detail.adjustsFontForContentSizeCategory = YES;
    detail.textColor = MYXXMuted();
    detail.numberOfLines = 0;
    detail.textAlignment = NSTextAlignmentCenter;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[mark, title, detail]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *host = [UIView new];
    [host addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:host.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:host.centerYAnchor constant:-40],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:host.leadingAnchor constant:32],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:host.trailingAnchor constant:-32]]];
    return host;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.importAssets ? self.importAssets.count : self.items.count;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout
    sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat side = floor((CGRectGetWidth(collectionView.bounds) - 24 - 12) / 3);
    return CGSizeMake(MAX(1, side), MAX(1, side));
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
    cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MYXXAlbumCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Item" forIndexPath:indexPath];
    cell.previewToken = nil;
    if (self.importAssets) {
        PHAsset *asset = self.importAssets[indexPath.item];
        cell.representedFile = nil;
        cell.thumbnail.image = nil;
        cell.badge.text = asset.mediaType == PHAssetMediaTypeVideo ? @" ▷ " : @"";
        cell.accessibilityLabel = asset.mediaType == PHAssetMediaTypeVideo ? @"Video" : @"Photo";
        PHImageRequestOptions *options = [PHImageRequestOptions new];
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        options.resizeMode = PHImageRequestOptionsResizeModeExact;
        options.networkAccessAllowed = YES;
        CGSize size = [self collectionView:collectionView layout:collectionView.collectionViewLayout sizeForItemAtIndexPath:indexPath];
        CGFloat scale = collectionView.traitCollection.displayScale;
        CGSize pixels = CGSizeMake(ceil(size.width * scale), ceil(size.height * scale));
        NSObject *token = [NSObject new];
        cell.previewToken = token;
        __weak MYXXAlbumCell *target = cell;
        [self.imageManager requestImageForAsset:asset targetSize:pixels
            contentMode:PHImageContentModeAspectFill options:options resultHandler:MYXXHeapBlock(^(UIImage *image, NSDictionary *info) {
                (void)info;
                if (!image) return;
                dispatch_async(dispatch_get_main_queue(), ^{
                    MYXXAlbumCell *visibleCell = target;
                    if (visibleCell.previewToken == token) visibleCell.thumbnail.image = image;
                });
            })];
        return cell;
    }
    MYXXAlbumItem *item = self.items[indexPath.item];
    cell.representedFile = item.file;
    cell.badge.text = item.video ? @" ▷ " : @"";
    cell.accessibilityLabel = item.video ? @"Video" : @"Photo";
    UIImage *cached = [self.thumbnails objectForKey:item.file];
    cell.thumbnail.image = cached;
    if (!cached) {
        __weak MYXXAlbumCell *target = cell;
        dispatch_async(self.thumbnailQueue, ^{
            UIImage *image = Thumbnail(item);
            if (!image) return;
            [self.thumbnails setObject:image forKey:item.file];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([target.representedFile isEqual:item.file]) target.thumbnail.image = image;
            });
        });
    }
    return cell;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    return !self.busy;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.selecting || self.importAssets) {
        [self refreshControls];
        return;
    }
    [collectionView deselectItemAtIndexPath:indexPath animated:NO];
    MYXXAlbumPreview *preview = [MYXXAlbumPreview new];
    preview.album = self;
    preview.items = self.items;
    preview.index = indexPath.item;
    [self.navigationController pushViewController:preview animated:YES];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self refreshControls];
}

- (void)toggleSelection {
    for (NSIndexPath *path in self.collectionView.indexPathsForSelectedItems) {
        [self.collectionView deselectItemAtIndexPath:path animated:NO];
    }
    self.selecting = !self.selecting;
    self.collectionView.allowsMultipleSelection = self.selecting;
    [self refreshControls];
}

- (NSArray<MYXXAlbumItem *> *)selection {
    NSMutableArray *selection = [NSMutableArray array];
    for (NSIndexPath *path in [self.collectionView.indexPathsForSelectedItems sortedArrayUsingSelector:@selector(compare:)]) {
        [selection addObject:self.items[path.item]];
    }
    return selection;
}

- (void)shareSelected {
    PresentShare(self, self.selection, self.shareButton);
}

- (void)addItems {
    if (!self.root || self.busy || self.importAssets) return;
    self.importLibrary = AppPhotoLibrary();
    PHFetchOptions *options = [PHFetchOptions new];
    if (!self.importLibrary || ![options respondsToSelector:@selector(setPhotoLibrary:)]) {
        PresentMessage(self, @"Library unavailable", @"Photos could not provide its active library.");
        return;
    }
    options.photoLibrary = self.importLibrary;
    options.includeHiddenAssets = NO;
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    @try {
        self.importAssets = [PHAsset fetchAssetsWithOptions:options];
    } @catch (NSException *exception) {
        PresentMessage(self, @"Unable to open library", exception.reason);
        return;
    }
    if (!self.importAssets.count) {
        self.importAssets = nil;
        PresentMessage(self, @"No Photos or Videos", @"Photos did not return any library items.");
        return;
    }
    self.imageManager = PHImageManager.defaultManager;
    self.title = @"Add to Private Album";
    self.navigationItem.leftBarButtonItem.title = @"Cancel";
    self.importButton = [[UIBarButtonItem alloc] initWithTitle:@"Move"
        style:UIBarButtonItemStyleDone target:self action:@selector(myxxImportSelection)];
    self.navigationItem.rightBarButtonItems = @[self.importButton];
    self.collectionView.backgroundView = nil;
    self.collectionView.allowsMultipleSelection = YES;
    [self.collectionView reloadData];
    [self refreshControls];
}

- (void)myxxImportSelection {
    NSMutableArray<PHAsset *> *assets = [NSMutableArray array];
    for (NSIndexPath *path in self.collectionView.indexPathsForSelectedItems) {
        [assets addObject:self.importAssets[path.item]];
    }
    if (!assets.count) return;
    // Move removes the originals from Photos, so it asks first, in words that say what is checked and what stays if something goes wrong.
    NSString *title = assets.count == 1 ? @"Move this item?" : [NSString stringWithFormat:@"Move %lu items?", (unsigned long)assets.count];
    MYXXShowChoice(self, title,
        @"Each item is copied to Private Album and the copy is checked. Only then is the original permanently removed from Photos. If anything fails, the original stays in Photos.",
        @"lock.rectangle.stack.fill", @[
        @{@"title": @"Move", @"style": @"destructive", @"handler": MYXXHeapBlock(^{ [self beginImport:assets]; })},
        @{@"title": @"Cancel", @"style": @"cancel"}]);
}

- (void)beginImport:(NSArray<PHAsset *> *)assets {
    self.importAssets = nil;
    self.collectionView.allowsMultipleSelection = NO;
    self.busy = YES;
    self.title = @"Copying Items...";
    [self reloadItems];
    [self copyAssets:assets index:0 copied:[NSMutableArray array] kept:0 skipped:0 failure:nil];
}

- (void)copyAssets:(NSArray<PHAsset *> *)assets index:(NSUInteger)index
    copied:(NSMutableArray<PHAsset *> *)copied kept:(NSUInteger)kept skipped:(NSUInteger)skipped failure:(NSError *)failure {
    if (index == assets.count) {
        self.busy = NO;
        self.title = @"Private Album";
        [self reloadItems];
        [self confirmRemoval:copied kept:kept skipped:skipped failure:failure];
        return;
    }

    PHAsset *asset = assets[index];
    ExportAsset(asset, self.root, MYXXHeapBlock(^(NSError *error, BOOL canRemoveOriginal) {
        if (canRemoveOriginal) [copied addObject:asset];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self copyAssets:assets index:index + 1 copied:copied kept:kept + (!error && !canRemoveOriginal) skipped:skipped + (error != nil) failure:failure ?: error];
        });
    }));
}

- (void)confirmRemoval:(NSArray<PHAsset *> *)assets kept:(NSUInteger)kept skipped:(NSUInteger)skipped failure:(NSError *)failure {
    NSString *keptMessage = kept ? [NSString stringWithFormat:
        @"%lu copied. Those originals stay in Photos to preserve edit history or extra files.",
        (unsigned long)kept] : nil;
    if (!assets.count && kept) {
        NSString *message = failure ? [keptMessage stringByAppendingFormat:@"\n\n%@", failure.localizedDescription] : keptMessage;
        PresentMessage(self, @"Added to Private Album", message);
        return;
    }
    if (!assets.count) {
        PresentMessage(self, @"Nothing copied", failure.localizedDescription ?: @"The originals are still in Photos.");
        return;
    }
    NSMutableSet *identifiers = [NSMutableSet set];
    NSMutableDictionary *dates = [NSMutableDictionary dictionary];
    for (PHAsset *asset in assets) {
        [identifiers addObject:asset.localIdentifier];
        dates[asset.localIdentifier] = (id)asset.modificationDate ?: NSNull.null;
    }
    PHFetchOptions *options = [PHFetchOptions new];
    options.photoLibrary = self.importLibrary;
    PHFetchResult<PHAsset *> *current = [PHAsset fetchAssetsWithLocalIdentifiers:identifiers.allObjects options:options];
    NSMutableArray *unchanged = [NSMutableArray array];
    for (NSUInteger index = 0; index < current.count; index++) {
        PHAsset *asset = current[index];
        id date = (id)asset.modificationDate ?: NSNull.null;
        if ([date isEqual:dates[asset.localIdentifier]]) [unchanged addObject:asset];
    }
    if (!unchanged.count) {
        PresentMessage(self, @"Copied to Private Album", @"The original is still in Photos. It changed after copying, so it was not removed.");
        return;
    }
    if (![PHAssetChangeRequest respondsToSelector:@selector(expungeAssets:)]) {
        PresentMessage(self, @"Copied to Private Album", @"The original is still in Photos.");
        return;
    }
    self.busy = YES;
    [self refreshControls];
    [self.importLibrary performChanges:MYXXHeapBlock(^{
        [PHAssetChangeRequest expungeAssets:unchanged];
    }) completionHandler:MYXXHeapBlock(^(BOOL performed, NSError *error) {
        (void)error;
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL success = performed;
            self.busy = NO;
            [self refreshControls];
            // "Moved" is claimed only after Photos is asked again and the originals are really gone.
            NSMutableArray *ids = [NSMutableArray array];
            for (PHAsset *removed in unchanged) [ids addObject:removed.localIdentifier];
            PHFetchOptions *check = [PHFetchOptions new];
            check.photoLibrary = self.importLibrary;
            NSUInteger remaining = ids.count ? [PHAsset fetchAssetsWithLocalIdentifiers:ids options:check].count : 0;
            if (success && remaining) success = NO;
            if (success) {
                NSString *message = [NSString stringWithFormat:
                    @"%lu originals permanently removed from Photos.",
                    (unsigned long)unchanged.count];
                if (keptMessage) message = [message stringByAppendingFormat:@"\n\n%@", keptMessage];
                if (failure) message = [message stringByAppendingFormat:@"\n\n%@", failure.localizedDescription];
                PresentMessage(self, @"Moved to Private Album", message);
            } else {
                PresentMessage(self, @"Copied to Private Album", @"The original is still in Photos.");
            }
        });
    })];
}

- (void)itemActions {
    NSArray *items = self.selection;
    if (!items.count) return;
    MYXXShowChoice(self, items.count == 1 ? @"This item" : [NSString stringWithFormat:@"%lu items", (unsigned long)items.count],
        nil, @"photo.on.rectangle.angled", @[
        @{@"title": @"Restore to Library", @"detail": @"Puts a copy back in Photos. The private copy stays.", @"style": @"primary",
          @"handler": MYXXHeapBlock(^{ [self restore:items]; })},
        @{@"title": @"Export as ZIP", @"detail": @"Makes one ZIP you can send or save with the share sheet. The private copies stay.",
          @"style": @"secondary", @"handler": MYXXHeapBlock(^{ [self exportItems:items]; })},
        @{@"title": @"Delete Permanently", @"style": @"destructive", @"handler": MYXXHeapBlock(^{ [self confirmDelete:items]; })},
        @{@"title": @"Cancel", @"style": @"cancel"}]);
}

- (void)exportAll { [self exportItems:self.items]; }

- (void)exportItems:(NSArray<MYXXAlbumItem *> *)items {
    if (!items.count || self.busy) return;
    NSString *what = items.count == 1 ? @"1 item" : [NSString stringWithFormat:@"%lu items", (unsigned long)items.count];
    MYXXShowChoice(self, @"Export as ZIP?", [NSString stringWithFormat:@"%@ will be copied into one ZIP that you can send or save with the share sheet. Your private copies stay in the Private Album. The ZIP is not private once you save it, so delete it from wherever you put it when you are done.", what],
        @"square.and.arrow.up.on.square", @[
        @{@"title": @"Export", @"style": @"primary", @"handler": MYXXHeapBlock(^{ [self buildExport:items]; })},
        @{@"title": @"Cancel", @"style": @"cancel"}]);
}

- (void)buildExport:(NSArray<MYXXAlbumItem *> *)items {
    self.busy = YES;
    self.title = @"Preparing ZIP\u2026";
    [self refreshControls];
    BuildZip(items, MYXXHeapBlock(^(NSURL *zip, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO;
            self.title = @"Private Album";
            [self refreshControls];
            if (!zip) { PresentMessage(self, @"Export failed", [NSString stringWithFormat:@"The ZIP could not be created, so nothing was exported. Your private items are untouched. %@", error.localizedDescription ?: @""]); return; }
            UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[zip] applicationActivities:nil];
            sheet.popoverPresentationController.barButtonItem = self.exportButton;
            sheet.completionWithItemsHandler = MYXXHeapBlock(^(UIActivityType type, BOOL completed, NSArray *returned, NSError *activityError) {
                CleanExports();   // the temporary ZIP goes away; whatever the person saved or sent stays with them
            });
            [self presentViewController:sheet animated:YES completion:nil];
        });
    }));
}

- (void)restore:(NSArray<MYXXAlbumItem *> *)items {
    PHPhotoLibrary *library = AppPhotoLibrary();
    if (!library) {
        PresentMessage(self, @"Restore unavailable", @"Photos could not provide its active library.");
        return;
    }
    self.busy = YES;
    [self refreshControls];
    [library performChanges:MYXXHeapBlock(^{
        for (MYXXAlbumItem *item in items) {
            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
            request.creationDate = item.date;
            [request addResourceWithType:item.video ? PHAssetResourceTypeVideo : PHAssetResourceTypePhoto
                fileURL:item.file options:nil];
            if (item.motionFile) [request addResourceWithType:PHAssetResourceTypePairedVideo fileURL:item.motionFile options:nil];
        }
    }) completionHandler:MYXXHeapBlock(^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO;
            [self refreshControls];
            if (!success) {
                PresentMessage(self, @"Restore failed", error.localizedDescription);
                return;
            }
            [self removePrivateItems:items title:@"Restored to Photos"];
        });
    })];
}

- (void)deleteSelection {
    [self confirmDelete:self.selection];
}

- (void)confirmDelete:(NSArray<MYXXAlbumItem *> *)items {
    if (!items.count) return;
    ConfirmPrivateDeletion(self, items.count, MYXXHeapBlock(^{
        [self removePrivateItems:items title:nil];
    }));
}

- (void)removePrivateItems:(NSArray<MYXXAlbumItem *> *)items title:(NSString *)title {
    NSUInteger failed = 0;
    for (MYXXAlbumItem *item in items) {
        if (![NSFileManager.defaultManager removeItemAtURL:item.directory error:NULL]) {
            failed++;
        }
    }
    if (self.selecting) [self toggleSelection];
    [self reloadItems];
    if (failed) {
        PresentMessage(self, title ?: @"Some items were kept",
            @"Some private copies could not be removed and remain available in Private Album.");
    }
}
@end

UIViewController *MYXXCreatePrivateAlbum(void) {
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumLineSpacing = 6;
    layout.minimumInteritemSpacing = 6;
    layout.sectionInset = UIEdgeInsetsMake(8, 12, 12, 12);
    MYXXPrivateAlbumController *album = [[MYXXPrivateAlbumController alloc] initWithCollectionViewLayout:layout];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:album];
    navigation.navigationBar.prefersLargeTitles = YES;
    MYXXStyleNavigation(navigation);
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    return navigation;
}
