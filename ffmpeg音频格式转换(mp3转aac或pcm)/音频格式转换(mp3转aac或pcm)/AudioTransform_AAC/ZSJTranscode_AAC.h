//
//  ZSJTranscode_AAC.h
//  ffmpeg_iOSTest
//
//  Created by WillToSky on 16/9/23.
//  Copyright © 2016年 WillToSky. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "libavformat/avformat.h"
#include "libavformat/avio.h"
#include "libavcodec/avcodec.h"
#include "libavutil/audio_fifo.h"
#include "libavutil/avassert.h"
#include "libavutil/avstring.h"
#include "libavutil/frame.h"
#include "libavutil/opt.h"
#include "libswresample/swresample.h"


typedef void(^TranscodeAACOutputBlock)(NSData *aacData,NSTimeInterval pts,NSInteger size);

@interface ZSJTranscode_AAC : NSObject

@property (nonatomic, strong) TranscodeAACOutputBlock outputBlock;

@property (nonatomic, readonly, assign) int isFinish;



/**
 init with inputPath and outputBlock call back

 @param inputPath   input file Path
 @param outputBlock  outputblock

 @return ZSJTranscode_AAC object
 */
- (instancetype)initWithInputPath:(NSString*)inputPath outputBlock:(TranscodeAACOutputBlock)outputBlock;



/**
 when you call readData, will transform a frame of aac data

 the data of aac can be got by the outputBlock
 */
- (void)readData;


/**
 get the adts header

 @param packetLength aac frame length

 @return adts header
 */
- (NSData*)adtsHeader:(NSInteger)packetLength;
@end
