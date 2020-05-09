function wrap(s as string, wid as integer) as string
	dim ret as string
	dim lin as string
	dim i as integer, j as integer, c as integer

	i = 0
	lin = ""
	do while i < len(s)
		do while i < len(s)
			c = s[i]
			if c = 32 then
				if len(lin) >= wid then i += 1: exit do
			end if
			lin += chr(c)
			i += 1
		loop
		while i < len(s) andalso s[i] = 32
			i += 1
		wend

		if len(lin) > wid then
			j = len(lin) - 1
			do while j >= 0
				if lin[j] = 32 then exit do
				j -= 1
			loop
			if j >= 0 then
				ret += left(lin, j) + !"\n"
				lin = mid(lin, 1+j+1) + " "
			else
				ret += left(lin, wid) + !"\n"
				lin = mid(lin, 1+wid) + " "
			end if
		else
			ret += lin + !"\n"
			lin = ""
		end if
	loop

	return ret + lin
end function

var wid = 7
print string(wid, "#")
print wrap("There  is  therefore  now  no  condemnation  for  those  who  are  in  Christ  Jesus.                              ", wid)
print string(wid, "#")
