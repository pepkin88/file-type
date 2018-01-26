require! {fs, path: {join}, ava: test, \read-chunk, \. : fileType}

check = (filename) ->
	file = join __dirname, \fixture, filename
	fileType readChunk.sync file, 0, 4 + 4096 ?.ext

# fixtureFiles = <[
# 	jpg png gif webp flif cr2 bmp jxr psd zip tar rar bz2 7z dmg
# 	mp4 mid mkv webm mov avi wmv mpg mp3 m4a oga ogg ogv opus flac wav
# 	spx amr pdf epub exe swf rtf wasm woff woff2 eot ttf otf ico flv
# 	ps sqlite nes crx xpi cab deb ar rpm msi mxf mts blend bpg
# 	docx pptx xlsx 3gp jp2 jpm jpx mj2 aif odt ods odp xml mobi
# ]>map (\fixture. +)

# additionalFixtures =
# 	woff2: <[ -otto ]>
# 	woff:  <[ -otto ]>
# 	eot:   <[ -0x20001 ]>
# 	mov:   <[ -mjpeg ]>
# 	mp3:   <[ -offset1-id3 -offset1 -mp2l3 -ffe3 ]>
# 	mp4:   <[ -imovie -isom -isomv2 -mp4v2 -m4v -dash ]>
# 	tif:   <[ -big-endian -little-endian ]>
# 	gz:    <[ .tar ]>
# 	xz:    <[ .tar ]>
# 	lz:    <[ .tar ]>
# 	Z:     <[ .tar ]>
# 	mkv:   <[ 2 ]>
# 	mpg:   <[ 2 ]>
# 	heic:  <[ -mif1 -msf1 -heic ]>

# for own ext, postfixes of additionalFixtures
# 	fixtureFiles ++= postfixes.map -> "fixture#it.#ext"

fixtureFiles = fs.readdirSync "#__dirname/fixture"

testFile = (t, ext, filename) -> ext `t.is` check filename

for let filename in fixtureFiles
	[, ext] = filename == /\.([^.]+)$/
	test ext, testFile, ext, filename
