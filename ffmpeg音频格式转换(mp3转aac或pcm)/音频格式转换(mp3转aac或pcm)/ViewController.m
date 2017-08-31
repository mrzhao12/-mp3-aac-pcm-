/*
 *FFmpeg音频格式转换(mp3转aac或pcm)
 *音频格式转换(mp3转aac或pcm)
 *赵彤 mrzhao12  ttdiOS
 *1107214478@qq.com
 *http://www.jianshu.com/u/fd9db3b2363b
 *本程序是iOS平台下FFmpeg音频格式转换(mp3转aac或pcm)
 *1.解码mp3
 *2.mp3转pcm或者aac
 *3.一定要添加CoreMedia.framework不然会出现Undefined symbols for architecture x86_64：（模拟器64位处理器测试（iphone5以上的模拟器））
 */
//  ViewController.m
//  音频格式转换(mp3转aac或pcm)
//
//  Created by sjhz on 2017/8/31.
//  Copyright © 2017年 sjhz. All rights reserved.
//

#import "ViewController.h"
#import "ZSJTranscode_AAC.h"
#import "ZSJPathUtilities.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // mp3->aac
//    [self transcode];
    // 简单版mp3转aac     mp3->aac,和pcm
     [self convertMP3ToAAC];
}

- (void)transcode {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *docDir = [ZSJPathUtilities documentsPath];
    NSString *bundle = [ZSJPathUtilities bundlePath];
    
    NSString *AACFileName = @"北京欢迎你.aac";
    NSString *inputName = @"北京欢迎你.mp3";   //月光の云海 - 久石譲.pcm
    //    NSString *inputName  =@"月光の云海 - 久石譲.pcm";
    NSString *fileName = [bundle stringByAppendingPathComponent:inputName];
    
    NSString *AACPath = [docDir stringByAppendingPathComponent:AACFileName];
    
    [fileManager removeItemAtPath:AACPath error:nil];
    [fileManager createFileAtPath:AACPath contents:nil attributes:nil];
    
    
    NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath:AACPath];
    
    ZSJTranscode_AAC *tranc = [[ZSJTranscode_AAC alloc]initWithInputPath:fileName outputBlock:nil];
    
    __weak ZSJTranscode_AAC *weakTranc = tranc;
    tranc.outputBlock = ^(NSData* data, NSTimeInterval pts , NSInteger size) {
        
        if (data) {
            [fileHandle writeData:[weakTranc adtsHeader:data.length]];
            [fileHandle writeData:data];
        }
    };
    
    while (!tranc.isFinish) {
        [tranc readData];
    }
    
    NSLog(@"---------------------------<end---%@",NSHomeDirectory());
    
}

- (void)convertMP3ToAAC {
    
    // 创建文件夹
    
    NSString *docDir = [ZSJPathUtilities documentsPath];
    
    NSString *bundle = [ZSJPathUtilities bundlePath];
    
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *aacFileName = @"凉凉 (Cover张碧晨&杨宗纬)-黄仁烁;王若伊.aac";
    NSString *pcmFileName = @"凉凉 (Cover张碧晨&杨宗纬)-黄仁烁;王若伊.pcm";
    
    
    NSString *aacPath = [docDir stringByAppendingPathComponent:aacFileName];
    NSString *pcmPath = [docDir stringByAppendingPathComponent:pcmFileName];
    
    [fileManager removeItemAtPath:aacPath error:nil];
    [fileManager removeItemAtPath:pcmPath error:nil];
    
    
    [fileManager createFileAtPath:aacPath contents:nil attributes:nil];
    [fileManager createFileAtPath:pcmPath contents:nil attributes:nil];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:aacPath];
    NSFileHandle *pcmfileHandle = [NSFileHandle fileHandleForWritingAtPath:pcmPath];
    
    
    NSLog(@"stroe aac and pcm dic = %@",docDir);
    //  NSString *inputName = @"北京欢迎你.mp3";   /
//        NSString *inputFileName = [bundle stringByAppendingPathComponent:@"北京欢迎你.mp3"];
    NSString *inputFileName = [bundle stringByAppendingPathComponent:@"凉凉 (Cover张碧晨&杨宗纬)-黄仁烁;王若伊.mp3"];
    
    av_register_all();
    avcodec_register_all();
    
    AVFormatContext *inputFormatCtx = NULL;
    
    
    
    // 打开输入音频文件
    int ret = avformat_open_input(&inputFormatCtx, [inputFileName UTF8String], NULL, 0);
    
    if (ret != 0) {
        NSLog(@"打开文件失败");
        return;
    }
    
    //获取音频中流的相关信息
    ret = avformat_find_stream_info(inputFormatCtx, 0);
    
    if (ret != 0) {
        NSLog(@"不能获取流信息");
        return;
    }
    
    
    // 获取数据中音频流的序列号，这是一个标识符
    int  index = 0,audioStream = -1;
    AVCodecContext *inputCodecCtx;
    
    for (index = 0; index <inputFormatCtx->nb_streams; index++) {
        AVStream *stream = inputFormatCtx->streams[index];
        AVCodecContext *code = stream->codec;
        if (code->codec_type == AVMEDIA_TYPE_AUDIO){
            audioStream = index;
            break;
        }
    }
    
    
    //从音频流中获取输入编解码相关的上下文
    inputCodecCtx = inputFormatCtx->streams[audioStream]->codec;
    //查找解码器
    AVCodec *pCodec = avcodec_find_decoder(inputCodecCtx->codec_id);
    // 打开解码器
    int result =  avcodec_open2(inputCodecCtx, pCodec, nil);
    if (result < 0) {
        NSLog(@"打开音频解码器失败");
        return;
    }
    
    // 创建aac编码器
    AVCodec *aacCodec = avcodec_find_encoder(AV_CODEC_ID_AAC);
    
    if (!aacCodec){
        printf("Can not find encoder!\n");
        return ;
    }
    
    
    //常见aac编码相关上下文信息
    AVCodecContext *aacCodeContex = avcodec_alloc_context3(aacCodec);
    
    
    
    // 设置编码相关信息
    aacCodeContex->sample_fmt = aacCodec->sample_fmts[0];
    aacCodeContex->sample_rate= inputCodecCtx->sample_rate;				// 音频的采样率
    aacCodeContex->channel_layout = av_get_default_channel_layout(2);
    aacCodeContex->channels = inputCodecCtx->channels;
    aacCodeContex->strict_std_compliance = FF_COMPLIANCE_EXPERIMENTAL;
    
    //打开编码器
    AVDictionary *opts = NULL;
    result = avcodec_open2(aacCodeContex, aacCodec, &opts);
    
    if (result < 0) {
        NSLog(@"failure open code");
        return;
    }
    
    
    
    //初始化先进先出缓存队列
    AVAudioFifo *fifo = av_audio_fifo_alloc(AV_SAMPLE_FMT_FLTP,aacCodeContex->channels, aacCodeContex->frame_size);
    
    //获取编码每帧的最大取样数
    int output_frame_size = aacCodeContex->frame_size;
    
    
    // 初始化重采样上下文
    SwrContext *resample_context = NULL;
    if (init_resampler(inputCodecCtx, aacCodeContex,
                       &resample_context)){
    }
    
    
    BOOL finished  = NO;
    while (1) {
        
        if (finished){
            break;
        }
        
        // 查看fifo队列中的大小是否超过可以编码的一帧的大小
        while (av_audio_fifo_size(fifo) < output_frame_size) {
            
            // 如果没超过，则继续进行解码
            
            if (finished)
            {
                break;
            }
            
            //
            AVFrame *audioFrame = av_frame_alloc();
            AVPacket packet;
            packet.data = NULL;
            packet.size = 0;
            int data_present;
            
            // 读取出一帧未解码数据
            finished =  (av_read_frame(inputFormatCtx, &packet) == AVERROR_EOF);
            
            // 判断该帧数据是否为音频数据
            if (packet.stream_index != audioStream) {
                continue;
            }
            
            // 开始进行解码
            if ( avcodec_decode_audio4(inputCodecCtx, audioFrame, &data_present, &packet) < 0) {
                NSLog(@"音频解码失败");
                return ;
            }
            
            
            if (data_present)
            {
                //将pcm数据写入文件
                for(int i = 0 ; i <audioFrame->channels;i++)
                {
                    NSData *data = [NSData dataWithBytes:audioFrame->data[i] length:audioFrame->linesize[0]];
                    [pcmfileHandle writeData:data];
                    
                }
            }
            
            
            // 初始化进行重采样的存储空间
            uint8_t **converted_input_samples = NULL;
            if (init_converted_samples(&converted_input_samples, aacCodeContex,
                                       audioFrame->nb_samples))
            {
                return;
            }
            
            // 进行重采样
            if (convert_samples((const uint8_t**)audioFrame->extended_data, converted_input_samples,
                                audioFrame->nb_samples, resample_context))
            {
                return;
            }
            
            //将采样结果加入进fifo中
            add_samples_to_fifo(fifo, converted_input_samples,audioFrame->nb_samples);
            
            
            // 释放重采样存储空间
            if (converted_input_samples)
            {
                av_freep(&converted_input_samples[0]);
                free(converted_input_samples);
            }
        }
        
        
        // 从fifo队列中读入数据
        while (av_audio_fifo_size(fifo) >= output_frame_size || finished) {
            
            AVFrame *frame;
            
            frame = av_frame_alloc();
            
            const int frame_size = FFMIN(av_audio_fifo_size(fifo),aacCodeContex->frame_size);
            
            // 设置输入帧的相关参数
            (frame)->nb_samples     = frame_size;
            (frame)->channel_layout = aacCodeContex->channel_layout;
            (frame)->format         = aacCodeContex->sample_fmt;
            (frame)->sample_rate    = aacCodeContex->sample_rate;
            
            int error;
            
            //根据帧的相关参数，获取数据存储空间
            if ((error = av_frame_get_buffer(frame, 0)) < 0)
            {
                av_frame_free(&frame);
                return ;
            }
            
            // 从fifo中读取frame_size个样本数据
            if (av_audio_fifo_read(fifo, (void **)frame->data, frame_size) < frame_size)
            {
                av_frame_free(&frame);
                return ;
            }
            
            
            AVPacket pkt;
            av_init_packet(&pkt);
            pkt.data = NULL;
            pkt.size = 0;
            
            int data_present = 0;
            
            frame->pts = av_frame_get_best_effort_timestamp(frame);
            frame->pict_type=AV_PICTURE_TYPE_NONE;
            
            // 将pcm数据进行编码
            if ((error = avcodec_encode_audio2(aacCodeContex, &pkt,frame, &data_present)) < 0)
            {
                av_free_packet(&pkt);
                return ;
            }
            av_frame_free(&frame);
            
            // 如果编码成功，写入文件
            if (data_present) {
                NSData *data = [NSData dataWithBytes:pkt.data length:pkt.size];
                NSLog(@"pkt length = %d",pkt.size);
                [fileHandle writeData:[self adtsDataForPacketLength:pkt.size]];
                [fileHandle writeData:data];
            }
            
            av_free_packet(&pkt);
        }
        
    }
    
    NSLog(@"***************************************end");
}



static int init_converted_samples(uint8_t ***converted_input_samples,
                                  AVCodecContext *output_codec_context,
                                  int frame_size)
{
    int error;
    /**
     * Allocate as many pointers as there are audio channels.
     * Each pointer will later point to the audio samples of the corresponding
     * channels (although it may be NULL for interleaved formats).
     */
    if (!(*converted_input_samples = calloc(output_codec_context->channels,
                                            sizeof(**converted_input_samples)))) {
        fprintf(stderr, "Could not allocate converted input sample pointers\n");
        return AVERROR(ENOMEM);
    }
    /**
     * Allocate memory for the samples of all channels in one consecutive
     * block for convenience.
     */
    if ((error = av_samples_alloc(*converted_input_samples, NULL,
                                  output_codec_context->channels,
                                  frame_size,
                                  output_codec_context->sample_fmt, 0)) < 0) {
        av_freep(&(*converted_input_samples)[0]);
        free(*converted_input_samples);
        return error;
    }
    return 0;
}


static int convert_samples(const uint8_t **input_data,
                           uint8_t **converted_data, const int frame_size,
                           SwrContext *resample_context)
{
    int error;
    /** Convert the samples using the resampler. */
    if ((error = swr_convert(resample_context,
                             converted_data, frame_size,
                             input_data    , frame_size)) < 0) {
        
        return error;
    }
    return 0;
}

static int add_samples_to_fifo(AVAudioFifo *fifo,
                               uint8_t **converted_input_samples,
                               const int frame_size)
{
    int error;
    /**
     * Make the FIFO as large as it needs to be to hold both,
     * the old and the new samples.
     */
    if ((error = av_audio_fifo_realloc(fifo, av_audio_fifo_size(fifo) + frame_size)) < 0) {
        fprintf(stderr, "Could not reallocate FIFO\n");
        return error;
    }
    /** Store the new samples in the FIFO buffer. */
    if (av_audio_fifo_write(fifo, (void **)converted_input_samples,
                            frame_size) < frame_size) {
        fprintf(stderr, "Could not write data to FIFO\n");
        return AVERROR_EXIT;
    }
    return 0;
}


static int init_resampler(AVCodecContext *input_codec_context,
                          AVCodecContext *output_codec_context,
                          SwrContext **resample_context)
{
    int error;
    /**
     * Create a resampler context for the conversion.
     * Set the conversion parameters.
     * Default channel layouts based on the number of channels
     * are assumed for simplicity (they are sometimes not detected
     * properly by the demuxer and/or decoder).
     */
    *resample_context = swr_alloc_set_opts(NULL,
                                           av_get_default_channel_layout(output_codec_context->channels),
                                           output_codec_context->sample_fmt,
                                           output_codec_context->sample_rate,
                                           av_get_default_channel_layout(input_codec_context->channels),
                                           input_codec_context->sample_fmt,
                                           input_codec_context->sample_rate,
                                           0, NULL);
    if (!*resample_context) {
        fprintf(stderr, "Could not allocate resample context\n");
        return AVERROR(ENOMEM);
    }
    /**
     * Perform a sanity check so that the number of converted samples is
     * not greater than the number of samples to be converted.
     * If the sample rates differ, this case has to be handled differently
     */
    //av_assert0(output_codec_context->sample_rate == input_codec_context->sample_rate);
    av_assert0(output_codec_context->sample_rate == input_codec_context->sample_rate);
    /** Open the resampler with the specified parameters. */
    
    if ((error = swr_init(*resample_context)) < 0) {
        fprintf(stderr, "Could not open resample context\n");
        swr_free(resample_context);
        return error;
    }
    return 0;
}



- (NSData*) adtsDataForPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //44.1KHz
    int chanCfg = 1;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF; // 11111111     = syncword
    packet[1] = (char)0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




@end
