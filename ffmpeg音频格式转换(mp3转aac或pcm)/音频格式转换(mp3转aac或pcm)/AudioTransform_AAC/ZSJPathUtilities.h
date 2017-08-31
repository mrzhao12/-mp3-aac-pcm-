//
//  ZSJPathUtilities.h
//  ffmpeg_iOSTest
//
//  Created by WillToSky on 16/9/14.
//  Copyright © 2016年 WillToSky. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZSJPathUtilities : NSObject


/**
 获取Documents目录路径

 @return 目录路径
 */
+ (NSString*)documentsPath;


/**
 获取Documents目录路径

 @return 目录路径
 */
+ (NSURL*)documentsURL;



+ (NSString*)bundlePath;



/**
 从给定的目录路径中，获取指定类型的文件名列表

 @param types   指定类型数组 例如： [@"mov",@"mp3"]; 如果types为nil或是内容为空，返回该目录中的所有文件
 @param dirPath 指定文件路径

 @return 指定文件类型列表
 */
+ (NSArray *)getFilenamelistOfTypes:(NSArray *)types fromDirPath:(NSString *)dirPath;


/**
 从给定的文件中获取其中的目录

 @param paths     文件列表
 @param parentDir 父目录列表

 @return 目录列表
 */
+ (NSArray*)pathsMatchingDirectory:(NSArray<NSString *>*)paths parentDir:(NSString*)parentDir;


/**
 判断一个路径是否是目录

 @param path 文件路径

 @return 是否是目录
 */
+ (BOOL)isDirectoryWithPath:(NSString*)path;


/**
 从指定目录中获取子目录列表

 @param path 指定目录

 @return 子目录列表
 */
+ (NSArray*)getDirListFromPath:(NSString*)path;
@end
