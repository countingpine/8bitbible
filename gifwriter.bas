#include "gifwriter.bi"
#include "gif_lib.bi"
#include "crt.bi"

'' PRESERVE_INDICES (pixels should preserve their colour indices, not just their colours)
'' PRESERVE_PALETTES (print frames with their exact palettes, possibly with extra colours at the end)
'' KEYFRAME_ON_PALETTE_CHANGE (pretty much implies above points)
'' Double buffering to allow pre-delays?

constructor GifWriter(byref filename as const string, byval TestExistence as boolean)
	gif = EGifOpenFileName(filename, TestExistence, @errorcode)
	EGifSetGifVersion(gif, 1) '' GIF89A
end constructor

destructor GifWriter()
	close()
end destructor

function GifWriter.close() as long
	if gif then
		if loopcount <> PLAY_ONCE then putLoop()

		EGifCloseFile(gif, @errorcode)
		gif = NULL
	end if
	if gifline then
		deallocate(gifline)
		gifline = NULL
	end if
	if prevframe then
		deallocate(prevframe)
		prevframe = NULL
	end if

	return errorcode
end function

function GifWriter.saveScreen() as long
	dim as integer wid, hei, pitch, bypp
	dim as ubyte ptr src
	dim as long pal(0 to 255)
	dim as ubyte frame()

	screenlock
	src = screenptr
	if src then
		screeninfo wid, hei, 0, bypp, pitch
		if bypp = 1 then
			for i as integer = 0 to 255
				dim as integer r, g, b
				palette get i, r, g, b
				pal(i) = RGB(r, g, b)
			next i
			saveFrame(src, wid, hei, pitch, @pal(0))
		else
			errorcode = E_GIF_ERR_NO_COLOR_MAP
		end if
	else
		errorcode = E_GIF_ERR_WRITE_FAILED '' there's no generic error code
	end if
	screenunlock

	errorcode = E_GIF_SUCCEEDED
	return errorcode
end function

function GifWriter.saveFrame( _
		byval src as const ubyte ptr, _
		byval wid as long, byval hei as long, byval pitch as long, _
		byval pal as const ulong const ptr) as long

	dim cmap as ColorMapObject ptr = NULL
	dim as GifPixelType c1, c2

	if writtenFirstFrame = false then
		gifwid = wid: gifhei = hei
		gifline = allocate(wid)
		prevframe = allocate(wid * hei)
		if gifline = NULL or prevframe = NULL then
			errorcode = E_GIF_ERR_NOT_ENOUGH_MEM
		end if

		memcpy(@gpal(0),    pal, sizeof(long)*256)
		memcpy(@prevpal(0), pal, sizeof(long)*256)

		cmap = GifMakeMapObject(256, NULL)
		for i as integer = 0 to 255
			cmap->Colors[i].Red   = pal[i] shr 16 and 255
			cmap->Colors[i].Green = pal[i] shr  8 and 255
			cmap->Colors[i].Blue  = pal[i]        and 255
		next i

		'' This must be the first thing written to the gif.
		EGifPutScreenDesc(gif, wid, hei, 256, 0, cmap)
		GifFreeMapObject(cmap)

		PutDuration()

		EGifPutImageDesc(gif, 0, 0, wid, hei, 0, NULL)
		for y as integer = 0 to hei-1
			'' Because EGifPutLine reserves the right to modify the line!
			memcpy(gifline, src + y * pitch, wid)

			memcpy(prevframe + y * wid, src + (y * pitch), wid)
			EGifPutLine(gif, gifline, wid)
		next y

		writtenFirstFrame = true
	else
		if wid > gifwid then wid = gifwid
		if hei > gifhei then hei = gifhei

		PutDuration()

		'' Can we output a smaller, changed region?
		'' Trim off unchanged rows/columns from top/bottom/left/right.
		'' We could only check the colours of the pixels, but it's
		'' better to check the palette indexes as well, so that each 
		'' frame can be rendered with given palette (plus any global
		'' palette entries if the local palette is truncated).
		'' (Checking only colours would probably cause unexpected
		'' problems anyway)

		dim as integer x1 = 0, y1 = 0, x2 = wid-1, y2 = hei-1

		while y1 <= y2 '' Top down
			for x as integer = 0 to wid-1
				c1 = src[y1 * pitch + x]
				c2 = prevframe[y1 * wid + x]
				if c1 <> c2 then exit while
				if pal[c1] <> prevpal(c2) then exit while
			next x
			y1 += 1
		wend
		while y2 >= y1 '' Bottom up 
			for x as integer = 0 to wid-1
				c1 = src[y2 * pitch + x]
				c2 = prevframe[y2 * wid + x]
				if c1 <> c2 then exit while
				if pal[c1] <> prevpal(c2) then exit while
			next x
			y2 -= 1
		wend
		if y1 > y2 then x1 = 0: y1 = 0: x2 = 0: y2 = 0
		while x1 < x2 '' From left
			for y as integer = y1 to y2
				c1 = src[y * pitch + x1]
				c2 = prevframe[y * wid + x1]
				if c1 <> c2 then exit while
				if pal[c1] <> prevpal(c2) then exit while
			next y
			x1 += 1
		wend
		while x2 > x1 '' From right
			for y as integer = y1 to y2
				c1 = src[y * pitch + x2]
				c2 = prevframe[y * wid + x2]
				if c1 <> c2 then exit while
				if pal[c1] <> prevpal(c2) then exit while
			next y
			x2 -= 1
		wend

		'' Can we use the global palette?
		'' Check only changes from the the pixels used in the changed
		'' region.
		'' A stricter check would check all the pixels in the frame.
		'' Stricter still would just be to memcmp pal and gpal.

		dim as boolean use_gpal = true
		dim as ubyte lastindex = 0'255
		for y as integer = y1 to y2
			for x as integer = x1 to x2
				c1 = src[y * pitch + x]
				c2 = prevframe[y * wid + x]
				if c1 > lastindex then lastindex = c1
				if pal[c1] = gpal(c1) then use_gpal = false
			next x
			if lastindex = 255 and (use_gpal = 0) then exit for
		next y

		if use_gpal = 0 then
			'' Need to assign a local palette.
			'' We'll use the full 256-colour palette, but we could
			'' save space and lower bpp by taking the number of
			'' used/changed colours (rounded up to a power of two
			'' because GIF).
			lastindex = 255
			cmap = GifMakeMapObject(lastindex + 1, NULL)
			for i as integer = 0 to lastindex
				cmap->Colors[i].Red   = pal[i] shr 16 and 255
				cmap->Colors[i].Green = pal[i] shr  8 and 255
				cmap->Colors[i].Blue  = pal[i]        and 255
			next i
		end if

		memcpy(@prevpal(0), pal, sizeof(long) * (lastindex+1))

		EGifPutImageDesc(gif, x1, y1, x2-x1+1, y2-y1+1, 0, cmap)
		if cmap then GifFreeMapObject(cmap)

		'' Output each line, update (changed areas of) prev_frame
		for y as integer = y1 to y2
			'' Because EGifPutLine reserves the right to modify the line!
			memcpy(gifline, src + y * pitch + x1, wid)

			memcpy(prevframe + y * wid + x1, gifline, x2-x1+1)
			EGifPutLine(gif, gifline, x2-x1+1)
		next y

	end if

	return errorcode
end function

sub GifWriter.setNextFrameDuration(byval centiseconds as ushort)
	nextduration = centiseconds
end sub

sub GifWriter.setDefaultFrameDuration(byval centiseconds as ushort)
	defaultduration = centiseconds
end sub

function GifWriter.putDuration() as long
	dim as GraphicsControlBlock gcb
	dim as GifByteType gifextension(0 to 3)

	dim as ushort centiseconds = iif(nextduration >= 0, nextduration, defaultduration)

	if centiseconds < 0 then return E_GIF_SUCCEEDED

	with gcb
		.DisposalMode = DISPOSAL_UNSPECIFIED
		.UserInputFlag = false
		.DelayTime = centiseconds
		.TransparentColor = NO_TRANSPARENT_COLOR
	end with
	EGifGCBToExtension(@gcb, @gifextension(0))

	errorcode = EGifPutExtension(gif, GRAPHICS_EXT_FUNC_CODE, 4, @gifextension(0))

	if errorcode = GIF_OK then
		errorcode = E_GIF_SUCCEEDED
	else '' GIF_ERROR
		errorcode = E_GIF_ERR_WRITE_FAILED
	end if

	nextduration = -1

	return errorcode
end function

function GifWriter.putLoop() as long
	dim as GifByteType gifextension(0 to 2)

	gifextension(0) = 1
	gifextension(1) = loopcount and 255
	gifextension(2) = (loopcount shr 8) and 255

	if EGifPutExtensionLeader(gif, APPLICATION_EXT_FUNC_CODE) <> GIF_OK then
		errorcode = E_GIF_ERR_WRITE_FAILED
		return errorcode
	end if

	if EGifPutExtensionBlock(gif, 11, @"NETSCAPE2.0") <> GIF_OK then
		errorcode = E_GIF_ERR_WRITE_FAILED
		return errorcode
	end if

	if EGifPutExtensionBlock(gif, 3, @gifextension(0)) <> GIF_OK then
		errorcode = E_GIF_ERR_WRITE_FAILED
		return errorcode
	end if

	if EGifPutExtensionTrailer(gif) <> GIF_OK then
		errorcode = E_GIF_ERR_WRITE_FAILED
		return errorcode
	end if

	return E_GIF_SUCCEEDED
end function

function GifWriter.errorString() as string
	#define case_(e) case e: return #e
	select case errorcode
	case_(E_GIF_SUCCEEDED)
	case_(E_GIF_ERR_OPEN_FAILED)
	case_(E_GIF_ERR_WRITE_FAILED)
	case_(E_GIF_ERR_HAS_SCRN_DSCR)
	case_(E_GIF_ERR_HAS_IMAG_DSCR)
	case_(E_GIF_ERR_NO_COLOR_MAP)
	case_(E_GIF_ERR_DATA_TOO_BIG)
	case_(E_GIF_ERR_NOT_ENOUGH_MEM)
	case_(E_GIF_ERR_DISK_IS_FULL)
	case_(E_GIF_ERR_CLOSE_FAILED)
	case_(E_GIF_ERR_NOT_WRITEABLE)
	case else: return str(errorcode)
	end select
end function
