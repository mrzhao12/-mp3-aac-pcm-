# -mp3-aac-pcm-
音频格式转换(mp3转aac或pcm)

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
.a文件ffmpeg编译iOS端下生成的，可以带libmp3lame.a也可以不带，笔者都试试过了，都可以使用本工程
