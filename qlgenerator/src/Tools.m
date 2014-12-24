//
//  Tools.m
//  qlMoviePreview
//
//  Created by @Nyx0uf on 15/04/14.
//  Copyright (c) 2014 Nyx0uf. All rights reserved.
//  www.cocoaintheshell.com
//


#import "Tools.h"
#import "MediainfoParser.h"
#import <CommonCrypto/CommonDigest.h>


#define NYX_MEDIAINFO_SYMLINK_PATH @"/tmp/qlmoviepreview/tmp-symlink-for-mediainfo-to-be-happy-lulz"


@implementation Tools

+(BOOL)isValidFilepath:(NSString*)filepath
{
	// Add extensions in the array to support more file types
	static NSArray* __valid_exts = nil;
	if (!__valid_exts)
		__valid_exts = [[NSArray alloc] initWithObjects:@"avi", @"divx", @"dv", @"flv", @"hevc", @"mkv", @"mk3d", @"mov", @"mp4", @"mts", @"m2ts", @"m4v", @"ogv", @"rmvb", @"ts", @"vob", @"webm", @"wmv", @"yuv", @"y4m", @"264", @"3gp", @"3gpp", @"3g2", @"3gp2", nil];
	NSString* extension = [filepath pathExtension];
	return [__valid_exts containsObject:extension];
}

+(NSString*)md5String:(NSString*)string
{
	uint8_t digest[CC_MD5_DIGEST_LENGTH];
	CC_MD5([string UTF8String], (CC_LONG)[string length], digest);
	NSMutableString* ret = [[NSMutableString alloc] init];
	for (NSUInteger i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
		[ret appendFormat:@"%02x", (int)(digest[i])];
	return [ret copy];
}

+(NSDictionary*)mediainfoForFilepath:(NSString*)filepath
{
	// mediainfo can't handle paths with some characters, like '?!*'...
	// So we create a symlink to make it happy... this is so moronic.
	NSString* okFilepath = filepath;
	if ([filepath rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"?!*"]].location != NSNotFound)
	{
		if ([[NSFileManager defaultManager] createSymbolicLinkAtPath:NYX_MEDIAINFO_SYMLINK_PATH withDestinationPath:filepath error:nil])
			okFilepath = NYX_MEDIAINFO_SYMLINK_PATH;
	}

	// Parse the mediainfo XML output
	MediainfoParser* parser = [[MediainfoParser alloc] initWithPath:okFilepath];
	NSDictionary* tracks = [parser analyze];

	// Remove the symlink, me -> zetsuboushita.
	if ([okFilepath isEqualToString:NYX_MEDIAINFO_SYMLINK_PATH])
		[[NSFileManager defaultManager] removeItemAtPath:NYX_MEDIAINFO_SYMLINK_PATH error:nil];

	/* General file info */
	NSMutableDictionary* outDict = [[NSMutableDictionary alloc] init];
	NSDictionary* generalDict = tracks[@(NYXTrackTypeGeneral)];
	NSMutableString* strGeneral = [[NSMutableString alloc] initWithString:@"<h2 class=\"stitle\">General</h2><ul>"];
	// Movie name
	NSString* moviename = generalDict[NYX_GENERAL_MOVIENAME];
	if (moviename && ![moviename isEqualToString:@""])
		[strGeneral appendFormat:@"<li><span class=\"st\">Title:</span> <span class=\"sc\">%@</span></li>", moviename];
	else
		[strGeneral appendString:@"<li><span class=\"st\">Title:</span> <span class=\"sc\"><em>Undefined</em></span></li>"];
	// Duration
	NSString* duration = generalDict[NYX_GENERAL_DURATION];
	[strGeneral appendFormat:@"<li><span class=\"st\">Duration:</span> <span class=\"sc\">%@</span></li>", duration];
	// Filesize
	NSString* filesize = generalDict[NYX_GENERAL_FILESIZE];
	[strGeneral appendFormat:@"<li><span class=\"st\">Size:</span> <span class=\"sc\">%@</span></li>", filesize];
	[strGeneral appendString:@"</ul>"];
	outDict[@"general"] = strGeneral;

	/* Video stream(s) */
	NSArray* videoArray = tracks[@(NYXTrackTypeVideo)];
	NSUInteger nbTracks = [videoArray count];
	if (nbTracks > 0)
	{
		NSMutableString* strVideo = [[NSMutableString alloc] initWithFormat:@"<h2 class=\"stitle\">Video%@</h2><ul>", (nbTracks > 1) ? @"s" : @""];
		NSUInteger i = 1;
		for (NSDictionary* track in videoArray)
		{
			// WIDTHxHEIGHT (aspect ratio)
			NSString* width = track[NYX_VIDEO_WIDTH];
			NSString* height = track[NYX_VIDEO_HEIGHT];
			NSString* aspect = track[NYX_VIDEO_ASPECT];
			[strVideo appendFormat:@"<li><span class=\"st\">Resolution:</span> <span class=\"sc\">%@x%@ <em>(%@)</em></span></li>", width, height, aspect];
			// Format, profile, bitrate, reframe
			NSString* format = track[NYX_VIDEO_FORMAT];
			NSString* profile = track[NYX_VIDEO_PROFILE];
			NSString* bitrate = track[NYX_VIDEO_BITRATE];
			NSString* ref = track[NYX_VIDEO_REFRAMES];
			[strVideo appendFormat:@"<li><span class=\"st\">Format/Codec:</span> <span class=\"sc\">%@", format];
			if (profile)
				[strVideo appendFormat:@" / %@", profile];
			if (bitrate)
				[strVideo appendFormat:@" / %@", bitrate];
			if (ref)
				[strVideo appendFormat:@" / %@ ReF", ref];
			[strVideo appendString:@"</span></li>"];
			// Framerate (mode)
			NSString* fps = track[NYX_VIDEO_FRAMERATE];
			NSString* fpsmode = track[NYX_VIDEO_FRAMERATE_MODE];
			if (!fps)
			{
				fps = track[NYX_VIDEO_FRAMERATE_ORIGINAL];
				if (!fps) // assume variable framerate
					fps = @"Undefined";
			}
			[strVideo appendFormat:@"<li><span class=\"st\">Framerate:</span> <span class=\"sc\">%@ <em>(%@)</em></span></li>", fps, fpsmode];
			// Bit depth
			NSString* bitdepth = track[NYX_VIDEO_BITDEPTH];
			[strVideo appendFormat:@"<li><span class=\"st\">Bit depth:</span> <span class=\"sc\">%@</span></li>", bitdepth];
			// Title
			NSString* title = track[NYX_VIDEO_TITLE];
			if (title)
				[strVideo appendFormat:@"<li><span class=\"st\">Title:</span> <span class=\"sc\">%@</span></li>", title];
			// Separator if multiple streams
			if (i < [videoArray count])
			{
				[strVideo appendString:@"<div class=\"sep\">----</div>"];
				i++;
			}
		}
		[strVideo appendString:@"</ul>"];
		outDict[@"video"] = strVideo;
	}

	/* Audio stream(s) */
	NSArray* audioArray = tracks[@(NYXTrackTypeAudio)];
	nbTracks = [audioArray count];
	if (nbTracks > 0)
	{
		NSMutableString* strAudio = [[NSMutableString alloc] initWithFormat:@"<h2 class=\"stitle\">Audio%@</h2><ul>", (nbTracks > 1) ? @"s" : @""];
		NSUInteger i = 1;
		for (NSDictionary* track in audioArray)
		{
			// Language
			NSString* lang = track[NYX_AUDIO_LANGUAGE];
			const BOOL def = [track[NYX_AUDIO_TRACK_DEFAULT] boolValue];
			[strAudio appendFormat:@"<li><span class=\"st\">Language:</span> <span class=\"sc\">%@ %@</span></li>", (lang) ? lang : @"<em>Undefined</em>", (def) ? @"<em>(Default)</em>" : @""];
			// Format, profile, bit depth, bitrate, sampling rate
			NSString* format = track[NYX_AUDIO_FORMAT];
			NSString* profile = track[NYX_AUDIO_PROFILE];
			NSString* bitdepth = track[NYX_AUDIO_BITDEPTH];
			NSString* bitrate = track[NYX_AUDIO_BITRATE];
			NSString* sampling = track[NYX_AUDIO_SAMPLING];
			[strAudio appendFormat:@"<li><span class=\"st\">Format/Codec:</span> <span class=\"sc\">%@", format];
			if (profile)
				[strAudio appendFormat:@" %@", profile];
			if (bitdepth)
				[strAudio appendFormat:@" / %@", bitdepth];
			if (bitrate)
				[strAudio appendFormat:@" / %@", bitrate];
			if (sampling)
				[strAudio appendFormat:@" / %@", sampling];
			[strAudio appendString:@"</span></li>"];
			// Channels
			NSString* channels = track[NYX_AUDIO_CHANNELS];
			const NSUInteger ich = (NSUInteger)[channels integerValue];
			NSString* tmp = nil;
			switch (ich)
			{
				case 1:
					tmp = @"1.0 [Mono]";
					break;
				case 2:
					tmp = @"2.0 [Stereo]";
					break;
				case 3:
					tmp = @"2.1 [Surround]";
					break;
				case 6:
					tmp = @"5.1 [Surround]";
					break;
				case 7:
					tmp = @"6.1 [Surround]";
					break;
				case 8:
					tmp = @"7.1 [Surround]";
					break;
				default:
					tmp = @"???";
					break;
			}
			[strAudio appendFormat:@"<li><span class=\"st\">Channels:</span> <span class=\"sc\">%@ <em>(%@)</em></span></li>", channels, tmp];
			// Title
			NSString* title = track[NYX_AUDIO_TITLE];
			if (title)
				[strAudio appendFormat:@"<li><span class=\"st\">Title:</span> <span class=\"sc\">%@</span></li>", title];
			// Separator if multiple streams
			if (i < [audioArray count])
			{
				[strAudio appendString:@"<div class=\"sep\">----</div>"];
				i++;
			}
		}
		[strAudio appendString:@"</ul>"];
		outDict[@"audio"] = strAudio;
	}

	/* Subs stream(s) */
	NSArray* subsArray = tracks[@(NYXTrackTypeText)];
	nbTracks = [subsArray count];
	if (nbTracks > 0)
	{
		NSMutableString* strSubs = [[NSMutableString alloc] initWithFormat:@"<h2 class=\"stitle\">Subtitle%@</h2><ul>", (nbTracks > 1) ? @"s" : @""];
		NSUInteger i = 1;
		for (NSDictionary* track in subsArray)
		{
			// Language
			NSString* lang = track[NYX_SUB_LANGUAGE];
			const BOOL def = [track[NYX_SUB_TRACK_DEFAULT] boolValue];
			[strSubs appendFormat:@"<li><span class=\"st\">Language:</span> <span class=\"sc\">%@ %@</span></li>", (lang) ? lang : @"<em>Undefined</em>", (def) ? @"<em>(Default)</em>" : @""];
			// Format
			NSString* format = track[NYX_SUB_FORMAT];
			[strSubs appendFormat:@"<li><span class=\"st\">Format:</span> <span class=\"sc\">%@</span></li>", format];
			// Title
			NSString* title = track[NYX_SUB_TITLE];
			if (title)
				[strSubs appendFormat:@"<li><span class=\"st\">Title:</span> <span class=\"sc\">%@</span></li>", title];
			// Separator if multiple streams
			if (i < [subsArray count])
			{
				[strSubs appendString:@"<div class=\"sep\">----</div>"];
				i++;
			}
		}
		[strSubs appendString:@"</ul>"];
		outDict[@"subs"] = strSubs;
	}

	return outDict;
}

@end