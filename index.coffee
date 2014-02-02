fs        = require 'fs'
getPixels = require "get-pixels"
builder   = require 'xmlbuilder'

TMP_PATH  = 'tmp'
FONT_SIZE = 8

class PixelImage
  constructor: (@pixels, @width, @height) ->

  getPixel: (x, y)->
    offset = x * 4 + y * 4 * @width
    @pixels[offset] << 16 | @pixels[offset + 1] << 8 | @pixels[offset + 2]

  getSubPixels: (x, y, width, height)->
    @getPixel x + x2, y + y2 for x2 in [0..(width - 1)] for y2 in [0..(height - 1)]

createSvg = (pathString)->
  builder.create(
    svg:
      '@width'           : '8px'
      '@height'          : '8px'
      '@viewBox'         : '0 0 8 8'
      '@shape-rendering' : 'crispEdges'
      '@xmlns'           : 'http://www.w3.org/2000/svg'
      '@xmlns:xlink'     : 'http://www.w3.org/1999/xlink'
      path:
        '@fill' : '#000000'
        '@d'    : pathString
    , {version: '1.0', encoding: 'UTF-8', standalone: true}
  ).end pretty: true, indent: '  ', newline: '\n'

pixelsToPath = (pixels)->
  # 重複するパスを取り除きながらパスのリストをつくる
  paths = {}
  for y in [0..(pixels.length - 1)]
    for x in [0..(pixels[y].length - 1)]
      if pixels[y][x]
        if paths["#{x+1},#{y}h-1"]?
          delete paths["#{x+1},#{y}h-1"]
        else
          paths["#{x},#{y}h1"] = {x:x, y:y, path:"h1", used:false}
        if paths["#{x+1},#{y+1}v-1"]?
          delete paths["#{x+1},#{y+1}v-1"]
        else
          paths["#{x+1},#{y}v1"] = {x:x+1, y:y, path:"v1", used:false}
        if paths["#{x},#{y+1}h1"]
          delete paths["#{x},#{y+1}h1"]
        else
          paths["#{x+1},#{y+1}h-1"] = {x:x+1, y:y+1, path:"h-1", used:false}
        if paths["#{x},#{y}v1"]
          delete paths["#{x},#{y}v1"]
        else
          paths["#{x},#{y+1}v-1"] = {x:x, y:y+1, path:"v-1", used:false}

  # pathのリストからパス文字列を作る
  pathStr = []
  for _, path of paths
    if !path.used
      start = path
      x = start.x
      y = start.y
      pathStr.push "M#{start.x},#{start.y}"

      current = start
      while true
        current.used = true
        pathStr.push current.path
        switch current.path
          when 'v1'
            y++
            current = paths["#{x},#{y}v1"]||paths["#{x},#{y}h1"]||paths["#{x},#{y}v-1"]||paths["#{x},#{y}h-1"]
          when 'v-1'
            y--
            current = paths["#{x},#{y}v-1"]||paths["#{x},#{y}h-1"]||paths["#{x},#{y}v1"]||paths["#{x},#{y}h1"]
          when 'h1'
            x++
            current = paths["#{x},#{y}h1"]||paths["#{x},#{y}v-1"]||paths["#{x},#{y}h-1"]||paths["#{x},#{y}v1"]
          when 'h-1'
            x--
            current = paths["#{x},#{y}h-1"]||paths["#{x},#{y}v1"]||paths["#{x},#{y}h1"]||paths["#{x},#{y}v-1"]
        break if current is start

  # 連続する同じ方向のパスの簡略化を行う
  pathStr
    .join('')
    .replace(/(h1)+/g, (match)-> "h#{match.length / 2}")
    .replace(/(h-1)+/g, (match)-> "h-#{match.length / 3}")
    .replace(/(v1)+/g, (match)-> "v#{match.length / 2}")
    .replace(/(v-1)+/g, (match)-> "v-#{match.length / 3}")
    .replace(/[vh]-?\d$/, 'z')


processFont = (img, baseX, baseY)->
  hasPixel = false
  pixelMap = for row in img.getSubPixels baseX * FONT_SIZE, baseY * FONT_SIZE, 8, 8
    for pixel in row
      hasPixel = hasPixel || pixel == 0
      pixel == 0
  if hasPixel
    fs.writeFileSync "#{TMP_PATH}/#{baseY}_#{baseX}.svg", (createSvg pixelsToPath pixelMap)

main = ->
  fs.mkdirSync TMP_PATH if !fs.existsSync TMP_PATH

  getPixels "8x8_font.png", (err, pixels)->
    throw "Bad image path" if err

    img = new PixelImage pixels.data, pixels._shape1, pixels._shape0

    for fontY in [0..(img.height / FONT_SIZE - 1)]
      for fontX in [0..(img.width / FONT_SIZE - 1)]
        processFont img, fontX, fontY

main()
