//
//  ZipArchive.h
//  ZipArchive
//
//  Objective-C code Copyright (c) 2008 aish (acsolu@gmail.com). All rights reserved.
//

#import <Foundation/Foundation.h>

#include "zip.h"
#include "unzip.h"


@protocol ZipArchiveDelegate <NSObject>

@optional
- (void)errorMessage:(NSString *)msg;
- (BOOL)overwriteOperation:(NSString *)file;

@end


@interface ZipArchive : NSObject {
@private
	zipFile _zipFile;
	unzFile _unzFile;
	
	NSString *_password;
	id _delegate;
}

@property (nonatomic, retain) id delegate;

- (BOOL)createZipFile:(NSString *)zipFile;
- (BOOL)createZipFile:(NSString *)zipFile password:(NSString *)password;
- (BOOL)addFileToZip:(NSString *)file newname:(NSString *)newname;
- (BOOL)closeZipFile;

- (BOOL)unzipOpenFile:(NSString *)zipFile;
- (BOOL)unzipOpenFile:(NSString *)zipFile password:(NSString *)password;
- (BOOL)unzipFileTo:(NSString *)path overwrite:(BOOL)overwrite;
- (BOOL)unzipCloseFile;

@end
