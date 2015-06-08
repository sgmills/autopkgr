//
//  LGTools.m
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGIntegration.h"
#import "LGIntegration+Protocols.h"
#import "LGAutoPkgr.h"
#import "LGInstaller.h"
#import "LGUninstaller.h"
#import "LGAutoPkgTask.h"
#import "LGHostInfo.h"

#ifndef LGTOOL_SUBCLASS
#define LGTOOL_SUBCLASS
#endif

// Dispatch queue for synchronizing infoHanler setter and refresh.
static dispatch_queue_t autopkgr_tool_synchronizer_queue()
{
    static dispatch_queue_t autopkgr_tool_synchronizer_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        autopkgr_tool_synchronizer_queue = dispatch_queue_create("com.lindegroup.autopkgr.tool.synchronizer.queue", DISPATCH_QUEUE_SERIAL );
    });

    return autopkgr_tool_synchronizer_queue;
}

NSString *const kLGNotificationIntegrationStatusDidChange = @"com.lindegroup.autopkgr.notification.toolstatus.did.change";

@interface LGIntegration ()
@property (copy, nonatomic, readwrite) LGIntegrationInfo *info;
@end

@interface LGIntegrationInfo ()
- (instancetype)initWithIntegration:(LGIntegration *)tool;
@end

void subclassMustImplement(id className, SEL _cmd)
{
    NSString *reason = [NSString stringWithFormat:@"Subclass of %s must implement the method \"%s\".",
                                                  object_getClassName(className), sel_getName(_cmd)];
    @throw [NSException exceptionWithName:@"SubclassMustImplement"
                                   reason:reason
                                 userInfo:nil];
}

void subclassMustConformToProtocol(id className)
{
    NSString *reason = [NSString stringWithFormat:@"[ EXCEPTION ] %s must conform to at least one LGTool protocol",
                                                  object_getClassName(className)];
    @throw [NSException exceptionWithName:@"SubclassMustConform"
                                   reason:reason
                                 userInfo:nil];
}

@implementation LGIntegration {
    void (^_progressUpdateBlock)(NSString *, double);
    void (^_replyErrorBlock)(NSError *);
    NSMutableDictionary *_infoUpdateBlocksDict;
    id<LGProgressDelegate> _origProgressDelegate;
}

@synthesize installedVersion = _installedVersion;
@synthesize remoteVersion = _remoteVersion;
@synthesize gitHubInfo = _gitHubInfo;

#pragma mark - Protocol conform check
+ (void)initialize
{
    // We only need to check subclasses, the super
    if ((self != [LGIntegration class]) && [self isSubclassOfClass:[LGIntegration class]]) {

        // The subclasses must conform to at least one of the protocols
        if (([self conformsToProtocol:@protocol(LGIntegrationSharedProcessor)] ||
             [self conformsToProtocol:@protocol(LGIntegrationPackageInstaller)]) == NO) {
            subclassMustConformToProtocol(self);
        }
    }
}

#pragma mark - Tool
+ (BOOL)isInstalled
{
    if ((self.typeFlags & kLGIntegrationTypeAutoPkgSharedProcessor) && (![self components])) {
        return [[LGAutoPkgTask repoList] containsObject:[self defaultRepository]];
    } else {
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *file in self.components) {
            if (![fm fileExistsAtPath:file]) {
                return NO;
            }
        }
    }
    return YES;
}

+ (BOOL)isUninstallable
{
    return NO;
}

+ (BOOL)meetsRequirements:(NSError *__autoreleasing *)error
{
    return YES;
}

#pragma mark - Init / Dealloc
- (void)dealloc
{
    DevLog(@"Dealloc %@", self);

    // nil out the blocks to break retain cycles.
    _progressUpdateBlock = nil;
    _replyErrorBlock = nil;

    /* Repoint so we don't loose reference to the _infoUpdateBlockDict after dealloc */
    NSMutableDictionary *releaseDict = _infoUpdateBlocksDict;
    dispatch_async(autopkgr_tool_synchronizer_queue(), ^{
        [releaseDict enumerateKeysAndObjectsUsingBlock:^(void (^infoUpdate)(LGIntegrationInfo *), id obj, BOOL *stop) {
            infoUpdate = nil;
        }];
        [releaseDict removeAllObjects];
    });
}

- (instancetype)init
{
    if (self = [super init]) {
        if ([[self class] typeFlags] & kLGIntegrationTypeInstalledPackage) {
            self.gitHubInfo = [[LGGitHubReleaseInfo alloc] initWithURL:[[self class] gitHubURL]];
        }
    }
    return self;
}

#pragma mark - Subclass responsibility

+ (NSString *)name
{
    subclassMustImplement(self, _cmd);
    return nil;
}

+ (LGIntegrationTypeFlags)typeFlags
{
    LGIntegrationTypeFlags flags = kLGIntegrationTypeUnspecified;
    if ([self conformsToProtocol:@protocol(LGIntegrationSharedProcessor)]) {
        flags += kLGIntegrationTypeAutoPkgSharedProcessor;
    }

    if ([self conformsToProtocol:@protocol(LGIntegrationPackageInstaller)]) {
        flags += kLGIntegrationTypeInstalledPackage;
    }

    if ([self isUninstallable]) {
        flags += kLGIntegrationTypeUninstallableIntegration;
    }

    return flags;
}

+ (NSString *)binary
{
    if ([self typeFlags] & kLGIntegrationTypeInstalledPackage) {
        subclassMustImplement(self, _cmd);
    }
    return nil;
}

+ (NSArray *)components
{
    if ([self typeFlags] & kLGIntegrationTypeAutoPkgSharedProcessor) {
        subclassMustImplement(self, _cmd);
    }
    return nil;
}

+ (NSString *)defaultRepository
{
    if ([self typeFlags] & kLGIntegrationTypeAutoPkgSharedProcessor) {
        subclassMustImplement(self, _cmd);
    }
    return nil;
}

+ (NSString *)gitHubURL
{
    if ([[self class] typeFlags] & kLGIntegrationTypeInstalledPackage) {
        subclassMustImplement(self, _cmd);
    }
    return nil;
}

+ (NSArray *)packageIdentifiers
{
    if ([[self class] typeFlags] & kLGIntegrationTypeInstalledPackage) {
        subclassMustImplement(self, _cmd);
    }
    return nil;
}

+ (NSString *)credits
{
    return nil;
}

+ (NSURL *)homePage
{
    return nil;
}

+ (NSString *)shortName
{
    return nil;
}

#pragma mark - Super implementation
- (void)customInstallActions
{
}
- (void)customUninstallActions {}

- (BOOL)isInstalled
{
    return [[self class] isInstalled];
}

- (NSString *)name
{
    return [[self class] name];
}

- (void)getInfo:(void (^)(LGIntegrationInfo *))reply
{
    _isRefreshing = YES;
    void (^updateInfoHandlers)() = ^() {
        dispatch_async(autopkgr_tool_synchronizer_queue(), ^{
            if (reply || _infoUpdateHandler) {
                _info = [[LGIntegrationInfo alloc] initWithIntegration:self];

                if (_infoUpdateHandler) {
                    _infoUpdateHandler(_info);
                }
                if (reply) {
                    reply(_info);
                }
            } else {
                _info = [[LGIntegrationInfo alloc] initWithIntegration:self];
            }
            _isRefreshing = NO;
        });
    };

    if (self.gitHubInfo.isExpired) {
        DevLog(@"Getting remote GitHub info for %@", NSStringFromClass([self class]));

        LGGitHubJSONLoader *loader = [[LGGitHubJSONLoader alloc] initWithGitHubURL:[[self class] gitHubURL]];

        [loader getReleaseInfo:^(LGGitHubReleaseInfo *gitHubInfo, NSError *error) {
            self.gitHubInfo = gitHubInfo;
            updateInfoHandlers();
        }];
    } else {
        DevLog(@"Using cached GitHub info for %@", NSStringFromClass([self class]));
        updateInfoHandlers();
    }
}

- (void)refresh;
{
    [self getInfo:nil];
}

- (LGIntegrationInfo *)info
{
    if (!_info) {
        _info = [[LGIntegrationInfo alloc] initWithIntegration:self];
    }
    return _info;
}

- (NSString *)remoteVersion
{
    if ([[self class] typeFlags] & kLGIntegrationTypeInstalledPackage) {
        return self.gitHubInfo.latestVersion;
    }

    // For now shared processors don't report a version.
    // We could possibly use git to check for an update.
    return nil;
}

- (NSString *)installedVersion
{
    LGIntegrationTypeFlags typeFlags = [[self class] typeFlags];

    if (typeFlags & kLGIntegrationTypeInstalledPackage) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *packageReceipt = [[@"/private/var/db/receipts/" stringByAppendingPathComponent:[[[self class] packageIdentifiers] firstObject]] stringByAppendingPathExtension:@"plist"];

        if ([[self class] isInstalled]) {
            if ([fm fileExistsAtPath:packageReceipt]) {
                NSDictionary *receiptDict = [NSDictionary dictionaryWithContentsOfFile:packageReceipt];
                _installedVersion = receiptDict[@"PackageVersion"];
            }
        }
    } else if (typeFlags & kLGIntegrationTypeAutoPkgSharedProcessor) {
        _installedVersion = @"Shared Processor";
    }

    return _installedVersion;
}

- (NSString *)downloadURL
{
    return self.gitHubInfo.latestReleaseDownload;
}

#pragma mark - Installer
- (void)install:(id)sender
{
    // Disable the sender to prevent multiple signals
    if ([sender respondsToSelector:@selector(isEnabled)]) {
        [sender setEnabled:NO];
    }

    LGIntegrationTypeFlags flags = [[self class] typeFlags];
    NSError *error = nil;
    if (![[self class] meetsRequirements:&error]) {
        [self didCompleteInstallAction:sender error:error];
    } else if (flags & kLGIntegrationTypeInstalledPackage) {
        [self installPackage:sender];
    } else if (flags & kLGIntegrationTypeAutoPkgSharedProcessor) {
        [self installDefaultRepository:sender];
    }
}

- (void)installPackage:(id)sender
{
    NSString *name = [[self class] name];
    LGIntegrationTypeFlags typeFlags = [[self class] typeFlags];

    NSString *installMessage = [NSString stringWithFormat:@"Installing %@...", [[self class] name]];
    [self.progressDelegate startProgressWithMessage:installMessage];

    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.downloadURL = self.downloadURL;
    installer.progressDelegate = self.progressDelegate;

    [installer runInstaller:name reply:^(NSError *error) {
        if (!error && (typeFlags & kLGIntegrationTypeAutoPkgSharedProcessor)) {
            [self installDefaultRepository:sender];
        } else {
            [self didCompleteInstallAction:sender error:error];
        }
    }];
}

- (void)installDefaultRepository:(id)sender
{
    NSString *name = [[self class] name];

    LGAutoPkgTask *task = [LGAutoPkgTask repoAddTask:[[self class] defaultRepository]];

    if (_progressDelegate) {
        [_progressDelegate startProgressWithMessage:[NSString stringWithFormat:@"Adding default AutoPkg repo for %@", name]];

        task.progressDelegate = _progressDelegate;
    }

    [task launchInBackground:^(NSError *error) {
        [self didCompleteInstallAction:sender error:error];
    }];
}

- (void)install:(void (^)(NSString *, double))progress reply:(void (^)(NSError *))reply
{
    if (progress) {
        if (_progressDelegate) {
            _origProgressDelegate = _progressDelegate;
        }
        _progressUpdateBlock = progress;
        _progressDelegate = self;
    }

    if (reply) {
        _replyErrorBlock = reply;
    }

    [self install:nil];
}

#pragma mark - Uninstall
- (void)uninstall:(id)sender
{
    void (^removeRepo)() = ^void() {
        NSString *defaultRepo = [[self class] defaultRepository];
        if ([LGAutoPkgTask version] && [[LGAutoPkgTask repoList] containsObject:defaultRepo]) {
            LGAutoPkgTask *task = [LGAutoPkgTask repoDeleteTask:defaultRepo];
            if (_progressDelegate) {
                task.progressDelegate = _progressDelegate;
            }
            [task launchInBackground:^(NSError *error) {
                [self didCompleteInstallAction:sender error:error];
            }];
        } else {
            [self didCompleteInstallAction:sender error:nil];
        }
    };

    if ([[self class] isInstalled]) {
        LGIntegrationTypeFlags flags = [[self class] typeFlags];

        if (flags & kLGIntegrationTypeInstalledPackage) {
            LGUninstaller *uninstaller = [[LGUninstaller alloc] init];

            NSString *message = [NSString stringWithFormat:@"Uninstalling %@...", [[self class] name]];
            [_progressDelegate startProgressWithMessage:message];

            if (_progressDelegate) {
                uninstaller.progressDelegate = _progressDelegate;
            }

            [uninstaller uninstallPackagesWithIdentifiers:[[self class] packageIdentifiers] reply:^(NSError *error) {
                if (error || !(flags & kLGIntegrationTypeAutoPkgSharedProcessor)) {
                    [self didCompleteInstallAction:sender error:error];
                } else {
                    removeRepo();
                }
            }];
        }
    }
}

- (void)uninstall:(void (^)(NSString *, double))progress reply:(void (^)(NSError *))reply
{

    if (progress) {
        if (_progressDelegate) {
            _origProgressDelegate = _progressDelegate;
        }
        _progressUpdateBlock = progress;
        _progressDelegate = self;
    }

    if (reply) {
        _replyErrorBlock = reply;
    }

    [self uninstall:nil];
}

#pragma mark - Install / Uninstall completion
- (void)didCompleteInstallAction:(id)sender error:(NSError *)error
{
    BOOL isInstalled = [[self class] isInstalled];
    if ([self.progressDelegate respondsToSelector:@selector(stopProgress:)]) {
        [self.progressDelegate stopProgress:error];
    }

    if ([sender respondsToSelector:@selector(isEnabled)]) {
        [sender setEnabled:YES];
    }

    if ([sender respondsToSelector:@selector(action)]) {
        if ([[self class] isUninstallable]) {
            [sender setAction:isInstalled ? @selector(uninstall:) : @selector(install:)];
        }
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kLGNotificationIntegrationStatusDidChange object:self];

    if (_origProgressDelegate) {
        _progressDelegate = _origProgressDelegate;
        _origProgressDelegate = nil;
    }

    [self refresh];
}

#pragma mark - Util

- (NSString *)versionTaskWithExec:(NSString *)exec arguments:(NSArray *)arguments
{
    NSString *installedVersion = nil;

    if ([[NSFileManager defaultManager] isExecutableFileAtPath:exec]) {
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = exec;
        task.arguments = arguments;
        task.standardOutput = [NSPipe pipe];

        [task launch];
        [task waitUntilExit];

        NSData *data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
        if (data) {
            installedVersion = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
    }

    return installedVersion ?: @"";
}

+ (NSError *)requirementsError:(NSString *)reason
{
    NSString *description = [NSString stringWithFormat:@"Requirements for %@ are not met.", [[self class] name]];
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey : description,
        NSLocalizedRecoverySuggestionErrorKey : reason ?: @"",
    };

    return [NSError errorWithDomain:kLGApplicationName code:(4 << 1)userInfo:userInfo];
}

#pragma mark - LGProgress Delegate

- (void)stopProgress:(NSError *)error
{
    if (_replyErrorBlock) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            _replyErrorBlock(error);
        }];
    }
}

- (void)updateProgress:(NSString *)message progress:(double)progress
{
    if (_progressUpdateBlock) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            _progressUpdateBlock(message, progress);
        }];
    }
}

- (void)startProgressWithMessage:(NSString *)message { /* Not implemented */}
- (void)bringAutoPkgrToFront { /* Not implemented */}

@end

#pragma mark - Tool Info Object
@implementation LGIntegrationInfo {
    NSString *_name;
    NSString *_shortName;
    LGIntegrationTypeFlags _typeFlags;
    LGIntegrationInstallStatus _status;
    BOOL _installed;
}

- (instancetype)initWithIntegration:(LGIntegration *)tool;
{
    if (self = [super init]) {
        _name = [[tool class] name];
        _shortName = [[tool class] shortName];
        _typeFlags = [[tool class] typeFlags];
        _installed = [[tool class] isInstalled];

        _remoteVersion = tool.remoteVersion;
        _installedVersion = tool.installedVersion;
    }

    return self;
}

- (LGIntegrationInstallStatus)status
{
    _status = kLGIntegrationUpToDate;

    if (!_installed || !_installedVersion) {
        _status = kLGIntegrationNotInstalled;
    } else if (_installedVersion && _remoteVersion) {
        if ([_remoteVersion version_isGreaterThan:_installedVersion]) {
            _status = kLGIntegrationUpdateAvailable;
        }
    }
    return _status;
}

#pragma mark - Mappings

- (NSImage *)statusImage
{
    NSImage *stausImage = nil;
    switch (self.status) {
    case kLGIntegrationNotInstalled:
        stausImage = [NSImage LGStatusNotInstalled];
        break;
    case kLGIntegrationUpdateAvailable:
        stausImage = [NSImage LGStatusUpdateAvailable];
        break;
    case kLGIntegrationUpToDate:
    default:
        stausImage = [NSImage LGStatusUpToDate];
        break;
    }
    return stausImage;
}

- (NSString *)statusString
{
    NSString *statusString = @"";
    switch (self.status) {
    case kLGIntegrationNotInstalled:
        statusString = [NSString stringWithFormat:@"%@ not installed.", _name];
        break;
    case kLGIntegrationUpdateAvailable:
        statusString = [NSString stringWithFormat:@"%@ %@ update now available.", _name, self.remoteVersion];
        break;
    case kLGIntegrationUpToDate:
    default:
        statusString = [NSString stringWithFormat:@"%@ %@ installed.", _name, self.installedVersion];
        break;
    }
    return statusString;
}

- (BOOL)needsInstalled
{
    switch (self.status) {
    case kLGIntegrationNotInstalled:
    case kLGIntegrationUpdateAvailable:
        return YES;
    case kLGIntegrationUpToDate:
    default:
        return NO;
    }
}

- (NSString *)installButtonTitle
{
    NSString *title;
    switch (self.status) {
    case kLGIntegrationUpToDate:
        if (_typeFlags & kLGIntegrationTypeUninstallableIntegration) {
            title = @"Uninstall ";
            break;
        }
    case kLGIntegrationNotInstalled:
        title = @"Install ";
        break;
    case kLGIntegrationUpdateAvailable:
        title = @"Update ";
        break;
    default:
        title = @"";
        break;
    }
    return [title stringByAppendingString:_shortName ?: _name];
}

- (BOOL)installButtonEnabled
{
    switch (self.status) {
    case kLGIntegrationNotInstalled: {
    }
    case kLGIntegrationUpdateAvailable: {
        return YES;
    }
    case kLGIntegrationUpToDate: {
        return (_typeFlags & kLGIntegrationTypeUninstallableIntegration);
    }
    default: {
        break;
    }
    }
}

- (SEL)installButtonTargetAction
{
    if ((self.status == kLGIntegrationUpToDate) && (_typeFlags | kLGIntegrationTypeUninstallableIntegration)) {
        return @selector(uninstall:);
    } else {
        return @selector(install:);
    }
}

- (NSString *)configureButtonTitle
{
    NSString *title;
    switch (self.status) {
    case kLGIntegrationNotInstalled:
        title = @"Install ";
        break;
    case kLGIntegrationUpToDate:
    case kLGIntegrationUpdateAvailable:
        title = @"Configure ";
        break;
    default:
        title = @"??? ";
        break;
    }
    return [title stringByAppendingString:_shortName ?: _name];
}

- (BOOL)configureButtonEnabled
{
    return YES;
}

- (SEL)configureButtonTargetAction
{
    SEL selector = nil;

    if (self.status != kLGIntegrationNotInstalled) {
        selector = NSSelectorFromString(@"configure:");
    } else {
        selector = @selector(install:);
    }
    return selector;
}

@end
