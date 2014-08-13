//
//  LGError.h
//  AutoPkgr
//
//  Created by Eldon on 8/9/14.
//
//  Copyright 2014 The Linde Group, Inc.
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

#import <Foundation/Foundation.h>

void DLog(NSString *format, ...);

#pragma mark - AutoPkgr specific Error codes
typedef NS_ENUM(NSInteger, LGErrorCodes) {
    /** Success */
    kLGErrorSuccess,
    /** Error when sending email fails */
    kLGErrorSendingEmail,
    /** Error when testing port failed */
    kLGErrorTestingPort,
    /** Error when some preferences could not be repaired, and values were removed */
    kLGErrorReparingAutoPkgPrefs,
};

#pragma mark - AutoPkg specific Error codes
typedef NS_ENUM(NSInteger, LGErrorAutoPkgCodes) {
    /** Autopkg most often return -1 on misconfiguration errors */
    kLGErrorAutoPkgConfig = -1,

    /** Autopkg returns 255 if no recipe is specified */
    kLGErrorAutoPkgNoRecipes = 255,
};

typedef NS_ENUM(NSInteger, LGAutoPkgrVerb) {
    kLGUnknown,
    kLGAutoPkgrRun,
    kLGAutoPkgrRepoUpdate,
    kLGAutoPkgrRepoAdd,
    kLGAutoPkgrRepoDelete,
    kLGAutoPkgrMakeOverride,
    kLGAutoPkgrInstallGit,
    kLGAutoPkgrInstallAutoPkg,
};

@interface LGError : NSObject

#ifdef _APPKITDEFINES_H
+ (void)presentErrorWithCode:(LGErrorCodes)code
                      window:(NSWindow *)window
                    delegate:(id)sender
          didPresentSelector:(SEL)selector;
#endif

#pragma mark - AutoPkgr Defined Errors
/**
 *  Populate an NSError Object for AutoPkgr
 *
 *  @param code  cooresponging LGErrorCodes
 *  @param error __autoreleasing NSError object
 *
 *  @return YES if Error has occured, NO if error.code = kLGErrorSuccess.
 */
+ (BOOL)errorWithCode:(LGErrorCodes)code error:(NSError **)error;
/**
 *  Generate an NSError Object for AutoPkgr
 *
 *  @param code  cooresponging LGErrorCodes
 *
 *  @return Populated NSError Object if error code is != kLGErrorSuccess, nil otherwise;
 */
+ (NSError *)errorWithCode:(LGErrorCodes)code;

#pragma mark - NSTask Error
/**
 *  Populate an NSError using a completed NSTask
 *
 *  @param task  Completed NSTask Object
 *  @param verb  Cooresponding Action Word Describing the AutoPkgr task process
 *  @param error __autoreleasing NSError object
 *
 *  @return YES if Error has occured, NO if error.code = kLGErrorSuccess.
 *  @discussion If the task is not complete the error will return NO;
 */
+ (BOOL)errorWithTaskError:(NSTask *)task verb:(LGAutoPkgrVerb)verb error:(NSError **)error;
/**
 *  Generated NSError Object from and AutoPkgr NSTask
 *
 *  @param task  Completed NSTask Object
 *  @param verb  Cooresponding Action Word Describing the AutoPkgr task process
 *
 *  @return Populated NSError Object if exit status is != kLGErrorSuccess, nil otherwise;
 *  @discussion If the returned object will be nil if the task has not complete;
 */
+ (NSError *)errorWithTaskError:(NSTask *)task verb:(LGAutoPkgrVerb)verb;

@end
