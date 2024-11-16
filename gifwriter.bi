#pragma once

#ifndef __GIF_WRITER_BI__
#define __GIF_WRITER_BI__

#include "gif_lib.bi"

type GifWriter
	public:
	declare constructor(byref filename as const string, byval TestExistence as boolean = false)
	declare sub setDefaultFrameDuration(byval centiseconds as ushort)
	declare sub setNextFrameDuration(byval centiseconds as ushort)
	declare function saveScreen() as long
	declare function saveFrame( _
		byval p as const ubyte ptr, _
		byval wid as long, byval hei as long, byval pitch as long, _
		byval pal as const ulong const ptr) as long
	declare function close() as long
	declare function errorString() as string
	declare destructor()

	as long errorcode = E_GIF_SUCCEEDED
	enum
		LOOP_FOREVER = 0
		PLAY_ONCE = 1
	end enum
	as ushort loopcount = PLAY_ONCE

	private:
	'' disable copying
	declare constructor(byref as const GifWriter)
	declare operator let(byref as const GifWriter)

	declare function putDuration() as long
	declare function putLoop() as long

	as GifFileType ptr gif

	as boolean writtenfirstframe = false

	as GifPixelType ptr prevframe
	as GifPixelType ptr gifline
	as long gifwid, gifhei
	as ulong prevpal(0 to 255), gpal(0 to 255)

	as integer defaultduration = -1
	as integer nextduration = -1
end type

#endif
