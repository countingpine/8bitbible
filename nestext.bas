dim shared skip as integer = 0
const SWID=256\8, SHEI=240\8

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

sub putchar(x as integer, y as integer, c as ubyte)
	if x < 0 or y < 0 or x >= SWID or y >= SHEI then return

	if skip = 0 then
		locate 1+y, 1+x
		print "_";
		sleep 50
		if len(inkey) then skip = 1
	end if

	locate 1+y, 1+x
	print chr(c);
end sub

sub teletype(x as integer, y as integer, s as string)
	dim as integer x2 = x, y2 = y
	dim as ubyte c
	for i as integer = 0 to len(s)-1
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
	dim as integer x2 = x + w - 1, y2 = y + h - 1
	line (x*8, y*8)-(x2*8+7, y2*8+7), 1, bf
	line (x*8, y*8)-(x2*8+7, y2*8+7), 15, b
	line (x*8+1, y*8+1)-(x2*8+6, y2*8+6), 7, b
end sub

sub telebox(wid as integer, s as string)
	dim as string ws = wrap(s, wid)
	dim as integer hei = countlines(ws)

	nicebox (SWID-wid)\2-1, (SHEI-hei)\2-1, wid+2, hei+2
	color 15, 1
	teletype((SWID-wid)\2, (SHEI-hei)\2, ws)
end sub


screenres SWID*8, SHEI*8
'paint (1,1), 12
var wid = SWID-6

'var verse = !"  There  is  therefore  now  no  condemnation  for  those  who  are  in  Christ  Jesus.         "

dim verse as string
open "es89.txt" for input as #1
line input #1, verse
close #1

'print tab((SWID-wid)\2); string(wid, "#")

telebox(wid, verse)

'print
'print tab((SWID-wid)\2); string(wid, "#")

sleep
