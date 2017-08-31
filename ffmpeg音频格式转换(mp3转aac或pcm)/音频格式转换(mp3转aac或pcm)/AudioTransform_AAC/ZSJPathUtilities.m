//
//  ZSJPathUtilities.m
//  ffmpeg_iOSTest
//
//  Created by WillToSky on 16/9/14.
//  Copyright © 2016年 WillToSky. All rights reserved.
//

#import "ZSJPathUtilities.h"

@implementation ZSJPathUtilities

+ (NSString *)documentsPath {
    return [[self documentsURL] path];
}

+ (NSURL *)documentsURL {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}


+ (NSString*)bundlePath {
    return [[NSBundle mainBundle] bundlePath];
}

+ (NSArray *)getFilenamelistOfTypes:(NSArray *)types fromDirPath:(NSString *)dirPath {
    NSError *error = nil;
    NSArray *tmplist = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirPath error:&error];
    
    if (types.count == 0 || types == nil) {
        return tmplist;
    }
    NSArray *fileList = [tmplist pathsMatchingExtensions:types];
    return fileList;
}


+ (NSArray*)pathsMatchingDirectory:(NSArray<NSString *>*)paths parentDir:(NSString*)parentDir {
    
    NSMutableArray *dirList = [NSMutableArray array];
    for (NSString *fileName in paths) {
        NSString *path = [parentDir stringByAppendingPathComponent:fileName];
        if([self isDirectoryWithPath:path]) {
            [dirList addObject:fileName];
        }
    }
    
    return [dirList copy];
}

+ (BOOL)isDirectoryWithPath:(NSString*)path {
    BOOL isDir = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    return isDir;
}


+ (NSArray*)getDirListFromPath:(NSString *)path {
    return [self pathsMatchingDirectory:[self getFilenamelistOfTypes:nil fromDirPath:path] parentDir:path];
}

@end
