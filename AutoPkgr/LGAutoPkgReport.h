//  LGAutoPkgReport.h
//
//  AutoPkgr
//
//  Created by Eldon Ahrold on 3/22/15.
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
#import "LGAutoPkgr.h"

/**
 *  Class to construct formatted messages from defined attributes.
 */
@interface LGAutoPkgReport : NSObject

/**
 *  Initialize the report with an AutoPkg(r) --report-plist dictionary
 *
 *  @param dictionary Dictionary representation of --report-plist output
 *
 *  @return Initialized LGAutoPkgReport object
 */
- (instancetype)initWithReportDictionary:(NSDictionary *)dictionary;

/**
 *  Dictionary representation of --report-plist output
 */
@property (copy, nonatomic) NSDictionary *autoPkgReport;

/**
 *  Error object to parse
 */
@property (copy, nonatomic) NSError *error;

/**
 *  Array of LGTools
 */
@property (copy, nonatomic) NSArray *tools;

/**
 *  Flags to define what to display in the report
 */
@property (assign, nonatomic) LGReportItems reportedItemFlags;

#pragma mark - Strings
/**
 *  Fully formatted HTML message suitable for email
 */
@property (copy, nonatomic, readonly) NSString *emailMessageString;

/**
 *  Email subject message
 */
@property (copy, nonatomic, readonly) NSString *emailSubjectString;

/**
 *  Check to determine if there is anything to report.
 */
@property (nonatomic, readonly) BOOL updatesToReport;

@end