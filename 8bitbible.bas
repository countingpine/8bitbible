#ifdef USE_GIF '' define USE_GIF to output screen frames to GIF (compile with gifwriter.bas)
#include "gifwriter.bi"
#endif

'const SWID=256\8, SHEI=240\8
const SWID=320\8, SHEI=240\8
const VWID=SWID-6

dim shared as integer skip = 0, esc = 0
dim shared as integer focus
dim shared as string kqueue

#ifdef USE_GIF
dim shared as GifWriter ptr g
#endif

enum
  FC_PLAY = 0
  FC_BOOK = 1
  FC_CHAP = 2
  FC_VERS = 3
end enum

sub locprint(y as integer, x as integer, s as const string)
	locate y, x
	print s;
	'draw string ((x-1)*8, (y-1)*8), s
end sub

function wrap(s as const string, wid as integer) as string
	dim ret as string = ""
	dim lin as string = ""
	dim word as string = ""
	dim as integer i = 0, j = 0, c

	'' Swallow leading spaces
	'while i < len(s) andalso s[i] = 32
	'	i += 1
	'wend

	do while i < len(s)
		'' Copy non-spaces to word
		do while i < len(s) andalso (s[i] <> 32 and s[i] <> 10)
			word += chr(s[i])
			i += 1
		loop

		'' Append lin to ret if too long
		if len(lin) + len(word) > wid then
			ret += rtrim(lin, "_") + !"\n"
			lin = ""
		end if
		lin += word
		word = ""

		'' Append chunks of lin to ret if too long
		while len(lin) > wid
			ret += left(lin, wid) + !"\n"
			lin = mid(lin, wid+1)
		wend

		'' Copy trailing spaces to lin
		do while i < len(s) andalso (s[i] = 32 or s[i] = 10)
			if s[i] = 32 then
				if len(lin) < wid then lin += "_"
			else
				ret += lin + !"\n"
				lin = ""
			end if
			i += 1
		loop
	loop

	if len(word) then
		'' Append lin to ret if too long
		if len(lin) + len(word) > wid then
			ret += rtrim(lin, "_") + !"\n"
			lin = ""
		end if
		lin += word
		word = ""
	end if

	'' Append chunks of lin to ret if too long
	while len(lin) > wid
		ret += left(lin, wid) + !"\n"
		lin = mid(lin, wid+1)
	wend
	ret += rtrim(lin, "_")
	lin = ""

	return ret
end function

sub keyevent()
	dim as string k = inkey
	if k <> "" then
		kqueue += k
		skip = 1
	end if
	select case k
	'' quit
	case !"\27", !"\255k", "q", "Q", !"\x11" '' Ctrl-Q
		esc = 1
	end select
end sub

function peekkey() as string
	if left(kqueue, 1) = !"\255" then
		function = left(kqueue, 2)
	else
		function = left(kqueue, 1)
	end if
end function	

function popkey() as string
	if left(kqueue, 1) = !"\255" then
		function = left(kqueue, 2)
		kqueue = mid(kqueue, 3)
	else
		function = left(kqueue, 1)
		kqueue = mid(kqueue, 2)
	end if
end function	

sub putchar(x as integer, y as integer, c as ubyte)
	if x < 0 or y < 0 or x >= SWID or y >= SHEI then return

	if focus = FC_PLAY and skip = 0 then
		'locprint(1+y, 1+x, "_")
		sleep 50

	end if

	keyevent()
	kqueue += inkey
	select case left(kqueue, 1)
	
	case !"\27", !"\255k": esc = 1
	case is > "": skip = 1
	end select

	locprint(1+y, 1+x, chr(c))
end sub

sub teletype(x as integer, y as integer, s as string)
	dim as integer x2 = x, y2 = y
	dim as ubyte c
	for i as integer = 0 to len(s)-1
		if esc then exit for
		c = s[i]
		if c = 10 then
			'putchar(x2, y2, 32)
			x2 = x
			y2 += 1
		else
			if c = asc("_") then c = 32
			putchar(x2, y2, c)
			x2 += 1
		end if
#ifdef USE_GIF
		if i = len(s)-1 then g->setNextFrameDuration(100)
		g->saveScreen()
#endif
	next i
end sub

function countlines(ws as string) as integer
	dim as integer ret = 0
	for i as integer = 0 to len(ws)-2
		if ws[i] = 10 then ret += 1
	next i
	return ret + 1
end function

sub nicebox(x as integer, y as integer, w as integer, h as integer)
	var x2 = x + w - 1, y2 = y + h - 1

	var sx1 = x*8+0
	var sy1 = y*8+0
	var sx2 = x2*8+7
	var sy2 = y2*8+7

	'' blue box, white border, grey inner border
	line (sx1, sy1)-(sx2, sy2), 1, bf
	line (sx1, sy1)-(sx2, sy2), 15, b
	line (sx1+1, sy1+1)-(sx2-1, sy2-1), 7, b

	'' rounded corners
	pset (sx1, sy1), 8
	pset (sx2, sy1), 8
	pset (sx1, sy2), 8
	pset (sx2, sy2), 8
end sub

sub telebox(wid as integer, s as string)
	dim as string ws = wrap(s, wid)
	dim as integer hei = countlines(ws)
	dim as integer y = (SHEI-hei)\2
	dim as integer x = (SWID-wid)\2

	nicebox x-1, y-1, wid+2, hei+2
	color 15, 1
	teletype(x, y, ws)
end sub


screenres SWID*8, SHEI*8

#ifdef USE_GIF
g = new GifWriter("out.gif")
g->setDefaultFrameDuration(5)
#endif

sub testmain()
	'paint (1,1), 12


	var wid = SWID-6

	'var verse = !"  There  is  therefore  now  no  condemnation  for  those  who  are  in  Christ  Jesus.         "

	dim verse as string
	open "es89.txt" for input as #1
	line input #1, verse
	close #1

	'print tab((SWID-wid)\2); string(wid, "#")

	nicebox(0, 0, SWID, 3)
	color 15, 1
	locprint(2, 2, "Esther 8:9")

	telebox(wid, verse)

	'print
	'print tab((SWID-wid)\2); string(wid, "#")

	sleep
end sub
'testmain()

dim verses(0 to 32000) as string
dim bks(0 to 32000) as string*20
dim chs(0 to 32000) as ubyte
dim vs(0 to 32000) as ubyte

dim as string vhead, blank
dim as integer vcount, vn = 0, dv
dim as integer sep1, sep2, sep3

open "web.txt" for input as #1
	do until eof(1)
		line input #1, vhead
		line input #1, verses(vn)
		line input #1, blank

		if blank <> "" then print using "&: '&' not blank!"; vhead; blank: sleep
		assert(blank = "")
		if verses(vn) = "" then print vhead & " blank!": sleep
		assert(verses(vn) <> "")

		'' vhead: "$$ 1 Thessalonians 3:16"
                ''         xxx^          sep1^ ^sep2

		assert(left(vhead, 3) = "$$ ")
		vhead = mid(vhead, 4)

		'sep1 = instr(vhead, " ")
		sep1 = instr(2, vhead, any "123456789") - 1
		sep2 = instr(sep1+1, vhead, ":")
		assert(sep1 andalso sep2)
		bks(vn) = left(vhead, sep1 - 1)
		chs(vn) = valint(mid(vhead, sep1+1, sep2-(sep1+1)))
		vs(vn) = valint(mid(vhead, sep2+1))

		'print using "&&&:&"; vn; bks(vn); chs(vn); vs(vn);
		'print ,

		if not (vn = 0 orelse _
			bks(vn) = bks(vn-1) and ((chs(vn) = chs(vn-1) and vs(vn) = vs(vn-1)+1) or (chs(vn) = chs(vn-1)+1 and vs(vn) = 1)) orelse _
			bks(vn) <> bks(vn-1) and chs(vn) = 1 and vs(vn) = 1) _
			then print vn, vhead: sleep

		vn += 1
	loop
close #1

vcount = vn

vn = 0
do' while vn >= 0 and vn < vcount
	color 15, 0
	cls

	nicebox(0, 0, SWID, 3)
	color 15, 1
	'locprint(2, 2, mid("TBCV", 1+focus, 1) & " " & bks(vn) & " " & chs(vn) & ":" & vs(vn))

	locprint(2, 4, bks(vn) & " " & chs(vn) & ":" & vs(vn))

	dim as integer indent = -1
	select case focus
	case FC_PLAY: indent = -1
	case FC_BOOK: indent = 0
	case FC_CHAP: indent = len(bks(vn) & " " & chs(vn)) - 1
	case FC_VERS: indent = len(bks(vn) & " " & chs(vn) & ":" & vs(vn)) - 1
	end select
	if focus = FC_PLAY then
		'indent = len(bks(vn) & " " & chs(vn) & ":" & vs(vn)) + 1
		'locprint(2, 4 + indent, !"\x10") '' Right 'play' arrow
		locprint(2, 2, !"\x10")
	else
		locprint(1, 4 + indent, !"\x1e") '' Up arrow
		locprint(3, 4 + indent, !"\x1f") '' Down arrow
	end if

	skip = 0
	telebox(VWID, verses(vn))
	if esc then exit do


	dv = 0
	select case popkey()
	'' Left
	case !"\255K"
		focus = (focus + 3) mod 4
		if focus = 0 then dv = 1
	'' Right
	case !"\255M"
		focus = (focus + 1) mod 4
		if focus = 0 then dv = 1
	'' Up
	case !"\255H"
		select case focus
		case 0
			dv = -1
		case 1:
			while vn > 0 andalso bks(vn) = bks(vn-1): vn -= 1: wend
			vn = (vn + vcount - 1) mod vcount
			while vn > 0 andalso bks(vn) = bks(vn-1): vn -= 1: wend
		case 2:
			while vn > 0 andalso chs(vn) = chs(vn-1): vn -= 1: wend
			vn = (vn + vcount - 1) mod vcount
			while vn > 0 andalso chs(vn) = chs(vn-1): vn -= 1: wend
		case 3:
			vn = (vn + vcount - 1) mod vcount
		end select
	'' Down
	case !"\255P"
		select case focus
		case FC_PLAY
			dv = 1
		case FC_BOOK:
			while vn < vcount andalso bks(vn) = bks(vn+1): vn += 1: wend
			vn = (vn + 1) mod vcount
		case FC_CHAP:
			while vn < vcount andalso chs(vn) = chs(vn+1): vn += 1: wend
			vn = (vn + 1) mod vcount
		case FC_VERS:
			vn = (vn + 1) mod vcount
		end select
	case else
		if focus <> FC_PLAY then sleep
	end select

	if dv then
		vn = (vn + vcount + dv) mod vcount
	elseif focus = FC_PLAY then
		sleep 2000
		vn = (vn + 1) mod vcount
	else
		'sleep
	end if
	keyevent()
loop
