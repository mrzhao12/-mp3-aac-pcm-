//
//  ZSJTranscode_AAC.m
//  ffmpeg_iOSTest
//
//  Created by WillToSky on 16/9/23.
//  Copyright © 2016年 WillToSky. All rights reserved.
//

#import "ZSJTranscode_AAC.h"




@interface ZSJTranscode_AAC ()
{
    
    AVFormatContext *inputFormatContext_;
    AVCodecContext *inputCodecContext_;
    
    AVFormatContext *outputFormatContex_;
    AVCodecContext *outputCodecContext_;
    
    
    SwrContext *resampleContext_;
    
    AVAudioFifo *fifo_;
    
    int audioStreamIndex_;
}

@property (nonatomic,assign,readonly) char* inputPath;

@end

@implementation ZSJTranscode_AAC

@synthesize isFinish = isFinish_;
@synthesize outputBlock = outputBlock_;

static const char *get_error_text(const int error)
{
    static char error_buffer[255];
    av_strerror(error, error_buffer, sizeof(error_buffer));
    return error_buffer;
}



- (instancetype)initWithInputPath:(NSString *)inputPath
                      outputBlock:(TranscodeAACOutputBlock)outputBlock {
    
    if (self = [super init]) {
        _inputPath = (char*)[inputPath UTF8String];
        self.outputBlock = outputBlock;
        [self init_All];
    }
    return self;
}



#pragma mark - public

- (void)readData {

    
    if (isFinish_) {
        return;
    }
    int _outputFrameSize = outputCodecContext_->frame_size;
    int _audioStreamIndex = audioStreamIndex_;
    while (av_audio_fifo_size(fifo_) < _outputFrameSize) {
        
        if ([self readDecodeConvertAndStore:fifo_ inputFormatContext:inputFormatContext_ inputCodecContext:inputCodecContext_ outputCodecContext:outputCodecContext_ resamplerContext:resampleContext_ finished:&isFinish_ streamIndex:_audioStreamIndex]) {
            return  ;
        }
        
        if (isFinish_) {
            break;
        }
    }
    
    while (av_audio_fifo_size(fifo_) >= _outputFrameSize ||
           (isFinish_ && av_audio_fifo_size(fifo_) > 0)) {
        
        if ([self loadEncodeAndWrite:fifo_ outputFormatContext:outputFormatContex_ outputCodecContext:outputCodecContext_ outputBlock:outputBlock_]) {
            return ;
        }
        
        if (isFinish_) {
            int _dataWritten;
            do {
                if ([self encodeAudioFrame:NULL outputFormatContext:outputFormatContex_ outputCodecContext:outputCodecContext_ dataPresent:&_dataWritten outputBlock:nil]) {
                
                }
            }while(_dataWritten);
                break;
            
        }
    }
    return ;
}


- (NSData*)adtsHeader:(NSInteger)packetLength {
    
        int adtsLength = 7;
        char *packet = malloc(sizeof(char) * adtsLength);
        // Variables Recycled by addADTStoPacket
        int profile = 2;  //AAC LC
        //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
        int freqIdx = [self getAudioSampleBitToHeaderValue:outputCodecContext_->sample_rate];  //44.1KHz
        int chanCfg = outputCodecContext_->sample_fmt;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
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



#pragma mark - private

- (int)getAudioSampleBitToHeaderValue:(NSInteger)sampleBit {
    
    NSDictionary *dic = @{@"96000":@0,
                          @"88200":@1,
                          @"64000":@2,
                          @"48000":@3,
                          @"44100":@4,
                          @"32000":@5,
                          @"24000":@6,
                          @"22050":@7,
                          @"16000":@8,
                          @"12000":@9,
                          @"11025":@10,
                          @"8000":@11,
                          @"7350":@12
                          };
    NSString*key = [NSString stringWithFormat:@"%ld",sampleBit];
    return [dic[key] intValue];
}

#pragma mark init
- (int)init_All {
    int _error = 0;
    
    av_register_all();
    avcodec_register_all();
    
    inputCodecContext_ = NULL;
    inputFormatContext_ = NULL;
    
    outputCodecContext_ = NULL;
    outputFormatContex_ = NULL;
    
    audioStreamIndex_ = -1;
    fifo_ = NULL;
    
    if ((_error = [self initInput:self.inputPath inputFormatContext:&inputFormatContext_ inputCodecContext:&inputCodecContext_ audioStreamIndex:&audioStreamIndex_]) < 0) {
        NSLog(@"Could not init input context (error : %d)",_error);
        return _error;
    }
    
    if ((errno = [self initOutput:&inputCodecContext_ outputFormatContext:&outputFormatContex_ outputCodecContext:&outputCodecContext_]) < 0) {
        NSLog(@"Could not init output context (error : %d)",_error);
        return _error;
    }

    if ((_error = [self initFifo:&fifo_ outputCodecContext:outputCodecContext_])) {
        NSLog(@"Could not init Fifo");
        return _error;
    }
    
    if ((_error = [self initResampler:inputCodecContext_ outputCodecContext:outputCodecContext_ resamplerContext:&resampleContext_]) < 0) {
        NSLog(@"Could not init resampler");
        return _error;
    }
    
    return _error;
}


- (int)initInput:(char*)inputPath
inputFormatContext:(AVFormatContext**)inputFormatContext
inputCodecContext:(AVCodecContext**)inputCodecContext
audioStreamIndex:(int*)audioStreamIndex{
    
    
    int _error = 0;
    /** Open the input file to read from it. */
    if ((_error = avformat_open_input(inputFormatContext, inputPath, NULL,
                                     0)) < 0) {
        fprintf(stderr, "Could not open input file '%s' (error '%s')\n",
                inputPath, get_error_text(_error));
        *inputFormatContext = NULL;
        return _error;
    }
    
    /** Get information on the input file (number of streams etc.). */
    if ((_error = avformat_find_stream_info(*inputFormatContext, NULL)) < 0) {
        fprintf(stderr, "Could not open find stream info (error '%s')\n",
                get_error_text(_error));
        avformat_close_input(inputFormatContext);
        return _error;
    }
    
    
    for (int index = 0; index < (*inputFormatContext)->nb_streams; index++) {
        AVStream *stream = (*inputFormatContext)->streams[index];
        AVCodecContext *codec = stream->codec;
        if (codec->codec_type == AVMEDIA_TYPE_AUDIO) {
            *audioStreamIndex = index;
            break;
        }
    }
    
    
    AVStream *_inputAudioStream = (*inputFormatContext)->streams[*audioStreamIndex];
    
    AVCodecContext *_inputAudioCodecContext = _inputAudioStream->codec;
    
    *inputCodecContext = _inputAudioCodecContext;
    
    
    AVCodec *inputCodec;
    if ((inputCodec = avcodec_find_decoder(_inputAudioCodecContext->codec_id)) == NULL) {
        fprintf(stderr, "Could not find decoder\n");
        avformat_close_input(inputFormatContext);
        avcodec_close(*inputCodecContext);
        return _error;
    }
    
    if ((_error = avcodec_open2(*inputCodecContext, inputCodec, NULL)) < 0){
        fprintf(stderr, "Could not open decoder (error '%s')\n",get_error_text(_error));
        avformat_close_input(inputFormatContext);
        avcodec_close(*inputCodecContext);
    }
    
    return _error;
}


- (int)initOutput:(AVCodecContext**)inputCodecContext
outputFormatContext:(AVFormatContext**)outputFormatContext
outputCodecContext:(AVCodecContext**)outputCodecContext {
    
    int _error = 0;

    
    AVFormatContext* _outputFormatCtx;
    _outputFormatCtx = avformat_alloc_context();
    const char* out_file = "tdjm.aac";
    AVOutputFormat* fmt;//Output URL
    fmt = av_guess_format(NULL, out_file, NULL);
    
    _outputFormatCtx->oformat = fmt;

    AVCodec *aacEncoder = avcodec_find_encoder(AV_CODEC_ID_AAC);
    
    if (aacEncoder == NULL) {
        fprintf(stderr, "Could not find encoder\n");
        return _error;
    }
    
    
    AVStream *_outputStream = avformat_new_stream(_outputFormatCtx, NULL);
    AVCodecContext *_outputCodecCtx = avcodec_alloc_context3(aacEncoder);
    
    _outputCodecCtx->sample_fmt = aacEncoder->sample_fmts[0];
    _outputCodecCtx->sample_rate = (*inputCodecContext)->sample_rate;
    _outputCodecCtx->channels = (*inputCodecContext)->channels;
    _outputCodecCtx->channel_layout = av_get_default_channel_layout((*inputCodecContext)->channels);
    _outputCodecCtx->strict_std_compliance = FF_COMPLIANCE_EXPERIMENTAL;
    
    _outputStream->time_base.den = (*inputCodecContext)->sample_rate;
    _outputStream->time_base.num = 1;
    
    
    
    if ((_outputFormatCtx)->oformat->flags & AVFMT_GLOBALHEADER) {
        _outputCodecCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
    
    AVDictionary *_opts = NULL;

    if ((_error = avcodec_open2(_outputCodecCtx, aacEncoder, &_opts)) < 0) {
        fprintf(stderr, "Could not open encoder (error '%s')\n",get_error_text(_error));
        return _error;
    }
    
    (*outputCodecContext) = _outputCodecCtx;
    (*outputFormatContext) = _outputFormatCtx;
    return _error;
}



- (int)initFifo:(AVAudioFifo**)fifo
outputCodecContext:(AVCodecContext*)outputCodecCtx {
    int _error = 0;
    
    AVAudioFifo * _fifo = av_audio_fifo_alloc(outputCodecCtx->sample_fmt, outputCodecCtx->channels, outputCodecCtx->frame_size);
    
    if (_fifo == NULL) {
        NSLog(@"Could not alloc audio fifo");
        _error = -1;
        return _error;
    }
    (*fifo) = _fifo;
    return _error;
}


- (int)initResampler:(AVCodecContext*)inputCodecContext
  outputCodecContext:(AVCodecContext*)outputCodecContext
    resamplerContext:(SwrContext**)resamplerContext {
    int _error = 0;
    
    *resamplerContext  = swr_alloc_set_opts(NULL,
                                            av_get_default_channel_layout(outputCodecContext->channels),
                                            outputCodecContext->sample_fmt
                                            ,outputCodecContext->sample_rate,
                                            av_get_default_channel_layout(inputCodecContext->channels),
                                            inputCodecContext->sample_fmt,
                                            inputCodecContext->sample_rate,
                                            0,
                                            NULL);
    if (!*resamplerContext) {
        fprintf(stderr, "Could not allocate resample context\n");
        return AVERROR(ENOMEM);
    }
    
    av_assert0(outputCodecContext->sample_rate == inputCodecContext->sample_rate);
    
    if((_error = swr_init(*resamplerContext))< 0) {
        fprintf(stderr, "Could not open resample context\n");
        swr_free(resamplerContext);
        return _error;
    }
    
    return _error;
}

- (int)initOutputFrame:(AVFrame**)frame
    outputCodecContext:(AVCodecContext*)outputCodecContext
             frameSize:(int)frameSize {
    int _error = 0;
    
    if (!(*frame = av_frame_alloc())) {
        fprintf(stderr, "Could not allocate output frame\n");
        return AVERROR_EXIT;
    }
    
    (*frame)->nb_samples        = frameSize;
    (*frame)->channel_layout    = outputCodecContext->channel_layout;
    (*frame)->format            = outputCodecContext->sample_fmt;
    (*frame)->sample_rate       = outputCodecContext->sample_rate;
    
    if ((_error = av_frame_get_buffer(*frame, 0)) < 0) {
        fprintf(stderr, "Could allocate output frame samples (error '%s')\n",
                get_error_text(_error));
        av_frame_free(frame);
        return _error;
    }
    
    return _error;
}

- (int)initInputFrame:(AVFrame**)frame {
    if (!(*frame = av_frame_alloc())) {
        fprintf(stderr, "Could not allocate input frame\n");
        return AVERROR(ENOMEM);
    }
    return 0;
}

- (void)initPacket:(AVPacket*)packet {
    av_init_packet(packet);
    /** Set the packet data and size so that it is recognized as being empty. */
    packet->data = NULL;
    packet->size = 0;
}


- (int) initConvertedSamples:(uint8_t ***)convertedInputSamples
           outputCodecContex:(AVCodecContext *)outputCodecContext
                   frameSize:(int) frame_size
{
    int _error;
    /**
     * Allocate as many pointers as there are audio channels.
     * Each pointer will later point to the audio samples of the corresponding
     * channels (although it may be NULL for interleaved formats).
     */
    if (!(*convertedInputSamples = calloc(outputCodecContext->channels,
                                            sizeof(**convertedInputSamples)))) {
        fprintf(stderr, "Could not allocate converted input sample pointers\n");
        return AVERROR(ENOMEM);
    }
    /**
     * Allocate memory for the samples of all channels in one consecutive
     * block for convenience.
     */
    if ((_error = av_samples_alloc(*convertedInputSamples, NULL,
                                  outputCodecContext->channels,
                                  frame_size,
                                  outputCodecContext->sample_fmt, 0)) < 0) {
        fprintf(stderr,
                "Could not allocate converted input samples (error '%s')\n",
                get_error_text(_error));
        av_freep(&(*convertedInputSamples)[0]);
        free(*convertedInputSamples);
        return _error;
    }
    return 0;
}


/**
 * Convert the input audio samples into the output sample format.
 * The conversion happens on a per-frame basis, the size of which is specified
 * by frame_size.
 */
- (int)convertSamples:(const uint8_t **)inputData
        convertedData:(uint8_t **)convertedData
            frameSize:(const int )frameSize
    resampleContext:(SwrContext *)resampleContext
{
    int _error;
    /** Convert the samples using the resampler. */
    if ((_error = swr_convert(resampleContext,
                             convertedData, frameSize,
                             inputData    , frameSize)) < 0) {
        fprintf(stderr, "Could not convert input samples (error '%s')\n",
                get_error_text(_error));
        return _error;
    }
    return 0;
}
/** Add converted input audio samples to the FIFO buffer for later processing. */
- (int)addSamplesToFifo:(AVAudioFifo *)fifo
  convertedInputSamples:(uint8_t **)convertedInputSamples
              frameSize:(const int)frameSize

{
    int _error;
    /**
     * Make the FIFO as large as it needs to be to hold both,
     * the old and the new samples.
     */
    if ((_error = av_audio_fifo_realloc(fifo, av_audio_fifo_size(fifo) + frameSize)) < 0) {
        fprintf(stderr, "Could not reallocate FIFO\n");
        return _error;
    }
    /** Store the new samples in the FIFO buffer. */
    if (av_audio_fifo_write(fifo, (void **)convertedInputSamples,
                            frameSize) < frameSize) {
        fprintf(stderr, "Could not write data to FIFO\n");
        return AVERROR_EXIT;
    }
    return 0;
}

#pragma mark  decode/encode

- (int)decodeAudioFrame:(AVFrame*)frame
     inputFormatContext:(AVFormatContext*)inputFormatContext
      inputCodecContext:(AVCodecContext*)inputCodecContext
            dataPresent:(int *)dataPresent
                 finish:(int *)finished streamIndex:(int)streamIndex{
    /** Packet used for temporary storage. */
    AVPacket _inputPacket;
    int _error;
    [self initPacket:&_inputPacket];
    /** Read one audio frame from the input file into a temporary packet. */
    if ((_error = av_read_frame(inputFormatContext, &_inputPacket)) < 0) {
        
        /** If we are at the end of the file, flush the decoder below. */
        if (_error == AVERROR_EOF)
            *finished = 1;
        else {
            fprintf(stderr, "Could not read frame (error '%s')\n",
                    get_error_text(_error));
            return _error;
        }
    }
    
    if (_inputPacket.stream_index != streamIndex) {
        
        return 1;
    }
    
    /**
     * Decode the audio frame stored in the temporary packet.
     * The input audio stream decoder is used to do this.
     * If we are at the end of the file, pass an empty packet to the decoder
     * to flush it.
     */
    if ((_error = avcodec_decode_audio4(inputCodecContext, frame,
                                       dataPresent, &_inputPacket)) < 0) {
        fprintf(stderr, "Could not decode frame (error '%s')\n",
                get_error_text(_error));
        av_packet_unref(&_inputPacket);
        return _error;
    }
    /**
     * If the decoder has not been flushed completely, we are not finished,
     * so that this function has to be called again.
     */
    if (*finished && *dataPresent)
        *finished = 0;
    av_packet_unref(&_inputPacket);
    return 0;
}



- (int)readDecodeConvertAndStore:(AVAudioFifo*)fifo
              inputFormatContext:(AVFormatContext*)inputFormatContext
               inputCodecContext:(AVCodecContext*)inputCodecContext
              outputCodecContext:(AVCodecContext*)outputCodecContext
                resamplerContext:(SwrContext*)resamplerContext
                        finished:(int*)finished streamIndex:(int)streamIndex{
    /** Temporary storage of the input samples of the frame read from the file. */
    AVFrame *_inputFrame = NULL;
    /** Temporary storage for the converted input samples. */
    uint8_t **_convertedInputSamples = NULL;
    int _dataPresent;
    int _ret = AVERROR_EXIT;
    /** Initialize temporary storage for one input frame. */
    if ([self initInputFrame:&_inputFrame])
        goto cleanup;
    /** Decode one frame worth of audio samples. */
    if ([self decodeAudioFrame:_inputFrame inputFormatContext:inputFormatContext inputCodecContext:inputCodecContext dataPresent:&_dataPresent finish:finished streamIndex:streamIndex])
        goto cleanup;
    /**
     * If we are at the end of the file and there are no more samples
     * in the decoder which are delayed, we are actually finished.
     * This must not be treated as an error.
     */
    if (*finished && !_dataPresent) {
        _ret = 0;
        goto cleanup;
    }
    /** If there is decoded data, convert and store it */
    if (_dataPresent) {
        /** Initialize the temporary storage for the converted input samples. */
        if ([self initConvertedSamples:&_convertedInputSamples outputCodecContex:outputCodecContext frameSize:_inputFrame->nb_samples])
            goto cleanup;
        /**
         * Convert the input samples to the desired output sample format.
         * This requires a temporary storage provided by converted_input_samples.
         */
        
        if ([self convertSamples:(const uint8_t**)_inputFrame->extended_data convertedData:_convertedInputSamples frameSize:_inputFrame->nb_samples resampleContext:resamplerContext])
            goto cleanup;
        /** Add the converted input samples to the FIFO buffer for later processing. */
        if ([self addSamplesToFifo:fifo convertedInputSamples:_convertedInputSamples frameSize:_inputFrame->nb_samples])
            goto cleanup;
        _ret = 0;
    }
    _ret = 0;
cleanup:
    if (_convertedInputSamples) {
        av_freep(&_convertedInputSamples[0]);
        free(_convertedInputSamples);
    }
    av_frame_free(&_inputFrame);
    return _ret;
    
}


static int64_t pts = 0;
- (int)encodeAudioFrame:(AVFrame*)frame
    outputFormatContext:(AVFormatContext*)outputFormatContext
     outputCodecContext:(AVCodecContext*)outputCodecContext
            dataPresent:(int*)dataPresent  outputBlock:(TranscodeAACOutputBlock)block{
    
    int _error = 0;
    AVPacket _outputPacket;
    
    [self initPacket:&_outputPacket];
    
    if (frame) {
        frame->pts          = av_frame_get_best_effort_timestamp(frame);
        frame->pict_type    =  AV_PICTURE_TYPE_NONE;
       // pts += frame->nb_samples;
    }
    if ((_error = avcodec_encode_audio2(outputCodecContext,
                                        &_outputPacket,
                                       frame, dataPresent)) < 0) {
        fprintf(stderr, "Could not encode frame (error '%s')\n",
                get_error_text(_error));
        av_packet_unref(&_outputPacket);
        return _error;
    }
    
    /** Write one audio frame from the temporary packet to the output file. */
    if (*dataPresent) {
        //NSLog(@"data length = %d",_outputPacket.size);
        NSData * aacData = [[NSData dataWithBytes:_outputPacket.data
                                          length:_outputPacket.size] mutableCopy];
        if (block) {
            block(aacData,_outputPacket.pts,_outputPacket.size);
        }
        av_packet_unref(&_outputPacket);
    }
    
    return _error;
}


- (int)loadEncodeAndWrite:(AVAudioFifo*)fifo
      outputFormatContext:(AVFormatContext*)outputFormatContext
       outputCodecContext:(AVCodecContext*)outputCodecContext outputBlock:(TranscodeAACOutputBlock)block{
    
    AVFrame *_outputFrame;
    const int _frameSize  = FFMIN(av_audio_fifo_size(fifo), outputCodecContext->frame_size);
    
    int _dataWritten;
    if ([self initOutputFrame:&_outputFrame outputCodecContext:outputCodecContext frameSize:_frameSize]) {
        fprintf(stderr, "Could not read data from FIFO\n");
        av_frame_free(&_outputFrame);
        return AVERROR_EXIT;
    }
    
    
    if (av_audio_fifo_read(fifo, (void **)_outputFrame->data, _frameSize) < _frameSize) {
        fprintf(stderr, "Could not read data from FIFO\n");
        av_frame_free(&_outputFrame);
        return AVERROR_EXIT;
    }
    
    
    if ([self encodeAudioFrame:_outputFrame outputFormatContext:outputFormatContext outputCodecContext:outputCodecContext dataPresent:&_dataWritten outputBlock:block]) {
        av_frame_free(&_outputFrame);
        return AVERROR_EXIT;
    }
    av_frame_free(&_outputFrame);
    return 0;
}






@end

