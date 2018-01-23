'use strict'

# Turns byte arrays encoded in RegExps and strings into proper arrays.
getByteArray = (value) ->
	getByteArray{}_cache[value] ||= if typeof! value == \RegExp
		[parseInt .., 16 for (value.source - /\W/g)match /../g]
	else [..charCodeAt! for value / '']

# Returns a checker for a provided buffer. The checker checks if all of the provided byte arrays
# are matching the buffer with a correct offset.
#
# Possible types of arguments of the returned function:
# - number - shifts the reading offset by given number; bails (returns 0), if provided a negative number
# - RegExp - a hexadecimal representation of a byte array, with decorational characters stripped out
# - string - an ASCII representation of a byte array
# - Array of RegExps or strings - if any of the values in the array matches the current chunk of buffer,
#   the array passes
createChecker = (buffer) -> (...args) ->
	offset = 0
	args.every ->
		if typeof it == \number
			offset += it
			return it >= 0
		arr = ([] ++ it)map getByteArray
		arr.some (.every (== buffer[offset + &1]))
			offset += arr.0.length if ..

module.exports = (buffer) ->
	c = createChecker buffer

	oOfficePrefix  = \application/vnd.oasis.opendocument
	msOfficePrefix = \application/vnd.openxmlformats-officedocument
	mp4Types = <[ mp41 mp42 isom iso2 mmp4 M4V dash ]>

	# Returns the index where a byte subarray occurres in the original buffer.
	# Returns `undefined` if doesn't find anything.
	indexOf = (_from, length, ...args) ->
		for i from _from til _from + length
			return i if c i, ...args

	# https://github.com/file/file/blob/master/magic/Magdir/msooxml
	getMsOfficeOffset = ->
		if indexOf(4 2000 \PK /03 04/)?
			if indexOf(that + 4 1000 \PK /03 04/)?
				that + 30
		? -1

	# https://github.com/threatstack/libmagic/blob/master/magic/Magdir/matroska
	getMatroskaOffset = ->
		if indexOf(4 4096 /42 82/)?
			that + 3
		? -1

	# Checks the header for an MP3 file, with provided offset argument.
	checkMp3 = (offset) ->
		c offset, \ID3 or c offset, /FF/ and buffer[offset + 1] .&. 0xE2 == 0xE2

	(?{ext: 0, mime: 1} || null) []=
		| c /FF D8 FF/                                  => <[ jpg    image/jpeg ]>
		| c /89/ \PNG\r\n /1A 0A/                       => <[ png    image/png ]>
		| c \GIF                                        => <[ gif    image/gif ]>
		| c 8 \WEBP                                     => <[ webp   image/webp ]>
		| c \FLIF                                       => <[ flif   image/flif ]>
		| c <[ II*\0 MM\0* ]> => []=
			| c 8 \CR                                     => <[ cr2    image/x-canon-cr2 ]>
			| otherwise                                   => <[ tif    image/tiff ]>
		| c \BM                                         => <[ bmp    image/bmp ]>
		| c \II /BC/                                    => <[ jxr    image/vnd.ms-photo ]>
		| c \8BPS                                       => <[ psd    image/vnd.adobe.photoshop ]>
		| c \PK /03 04/ => []=
			| c 30 \mimetypeapplication/epub+zip          => <[ epub   application/epub+zip ]>
			| c 30 \META-INF/mozilla.rsa                  => <[ xpi    application/x-xpinstall ]> # assumes signed .xpi from addons.mozilla.org
			| c 30 "mimetype#oOfficePrefix.text"          =>  [\odt    "#oOfficePrefix.text"]
			| c 30 "mimetype#oOfficePrefix.spreadsheet"   =>  [\ods    "#oOfficePrefix.spreadsheet"]
			| c 30 "mimetype#oOfficePrefix.presentation"  =>  [\odp    "#oOfficePrefix.presentation"]
			| c 30 <[ [Content_Types].xml _rels/.rels ]>
				let offset = getMsOfficeOffset! => []=
					| c offset, \word/                        =>  [\docx   "#msOfficePrefix.wordprocessingml.document"]
					| c offset, \ppt/                         =>  [\pptx   "#msOfficePrefix.presentationml.presentation"]
					| c offset, \xl/                          =>  [\xlsx   "#msOfficePrefix.spreadsheetml.sheet"]
			| otherwise                                   => <[ zip    application/zip ]>
		| c \PK [/03/ /05/ /07/] [/04/ /06/ /08/]       => <[ zip    application/zip ]>
		| c 257 \ustar                                  => <[ tar    application/x-tar ]>
		| c \Rar! /1A 07/ [/00/ /01/]                   => <[ rar    application/x-rar-compressed ]>
		| c /1F 8B 08/                                  => <[ gz     application/gzip ]>
		| c \BZh                                        => <[ bz2    application/x-bzip2 ]>
		| c \7z /BC AF 27 1C/                           => <[ 7z     application/x-7z-compressed ]>
		| c /78 01/                                     => <[ dmg    application/x-apple-diskimage ]>
		| c \3gp5 or c /00 00 00/ 1 \ftyp mp4Types      => <[ mp4    video/mp4 ]>
		| c \MThd                                       => <[ mid    audio/midi ]>
		| c /1A 45 DF A3/
			let offset = getMatroskaOffset! => []=
				| c offset, \matroska                       => <[ mkv    video/x-matroska ]>
				| c offset, \webm                           => <[ webm   video/webm ]>
		| c 4 ['ftypqt  ' \free \mdat \wide]            => <[ mov    video/quicktime ]>
		| c \RIFF 4 \AVI                                => <[ avi    video/x-msvideo ]>
		| c /30 26 B2 75 8E 66 CF 11 A6 D9/             => <[ wmv    video/x-ms-wmv ]>
		| c /00 00 01/ [/BA/ /B3/]                      => <[ mpg    video/mpeg ]>
		| c /00 00 00 1C/ \ftyp3gp4                     => <[ 3gp    video/3gpp ]>
		| checkMp3 0 or checkMp3 1                      => <[ mp3    audio/mpeg ]>
		| c 'M4A ' or c 4 \ftypM4A                      => <[ m4a    audio/m4a ]>
		| c \OggS => []=
			| c 28 \OpusHead                              => <[ opus   audio/opus ]>
			| c 28 /80/ \theora                           => <[ ogv    video/ogg ]>
			| c 28 /01/ \video\0                          => <[ ogm    video/ogg ]>
			| c 28 /7F/ \FLAC                             => <[ oga    audio/ogg ]>
			| c 28 'Speex  '                              => <[ spx    audio/ogg ]>
			| c 28 /01/ \vorbis                           => <[ ogg    audio/ogg ]>
			| otherwise                                   => <[ ogx    application/ogg ]> # Default OGG container https://www.iana.org/assignments/media-types/application/ogg
		| c \fLaC                                       => <[ flac   audio/x-flac ]>
		| c \RIFF 4 \WAVE                               => <[ wav    audio/x-wav ]>
		| c \#!AMR\n                                    => <[ amr    audio/amr ]>
		| c \%PDF                                       => <[ pdf    application/pdf ]>
		| c \MZ                                         => <[ exe    application/x-msdownload ]>
		| c <[ FWS CWS ]>                               => <[ swf    application/x-shockwave-flash ]>
		| c \{\\rtf                                     => <[ rtf    application/rtf ]>
		| c \\0asm                                      => <[ wasm   application/wasm ]>
		| c \wOFF [/00 01 00 00/ \OTTO]                 => <[ woff   font/woff ]>
		| c \wOF2 [/00 01 00 00/ \OTTO]                 => <[ woff2  font/woff2 ]>
		| c 8 [/00 00 01/ /01 00 02/ /02 00 02/] 23 \LP => <[ eot    application/octet-stream ]>
		| c /00 01 00 00 00/                            => <[ ttf    font/ttf ]>
		| c \OTTO\0                                     => <[ otf    font/otf ]>
		| c /00 00 01 00/                               => <[ ico    image/x-icon ]>
		| c \FLV /01/                                   => <[ flv    video/x-flv ]>
		| c \%!                                         => <[ ps     application/postscript ]>
		| c /FD/ \7zXZ /00/                             => <[ xz     application/x-xz ]>
		| c \SQLi                                       => <[ sqlite application/x-sqlite3 ]>
		| c \NES /1A/                                   => <[ nes    application/x-nintendo-nes-rom ]>
		| c \Cr24                                       => <[ crx    application/x-google-chrome-extension ]>
		| c <[ MSCF ISc( ]>                             => <[ cab    application/vnd.ms-cab-compressed ]>
		| c \!<arch> => []=
			| c 7 \\ndebian-binary                        => <[ deb    application/x-deb ]>
			| otherwise                                   => <[ ar     application/x-unix-archive ]>
		| c /ED AB EE DB/                               => <[ rpm    application/x-rpm ]>
		| c /1F/ [/A0/ /9D/]                            => <[ Z      application/x-compress ]>
		| c \LZIP                                       => <[ lz     application/x-lzip ]>
		| c /D0C F11E 0 A1 B1 1A E1/                    => <[ msi    application/x-msi ]> # also MS Office documents
		| c /06 0E 2B 34 02 05 01 01 0D 01 02 01 01 02/ => <[ mxf    application/mxf ]>
		| c 4 \G and (c 192 \G or c 196 \G)             => <[ mts    video/mp2t ]>
		| c \BLENDER                                    => <[ blend  application/x-blender ]>
		| c \BPG /FB/                                   => <[ bpg    image/bpg ]>
		| c /00 00 00 0C/ 'jP  \r\n' /87 0A/ => []= # JPEG-2000 family
			| c 20 'jp2 '                                 => <[ jp2    image/jp2 ]>
			| c 20 'jpx '                                 => <[ jpx    image/jpx ]>
			| c 20 'jpm '                                 => <[ jpm    image/jpm ]>
			| c 20 \mjp2                                  => <[ mj2    image/mj2 ]>
		| c \FORM\0                                     => <[ aif    audio/aiff ]>
		| c '<?xml '                                    => <[ xml    application/xml ]>
		| c 60 \BOOKMOBI                                => <[ mobi   application/x-mobipocket-ebook ]>
		| c 4 \ftyp => []= # File Type Box (https://en.wikipedia.org/wiki/ISO_base_media_file_format)
			| c 8 \mif1                                   => <[ heic   image/heif ]>
			| c 8 \msf1                                   => <[ heic   image/heif-sequence ]>
			| c 8 <[ heic heix ]>                         => <[ heic   image/heic ]>
			| c 8 <[ hevc hevx ]>                         => <[ heic   image/heic-sequence ]>
