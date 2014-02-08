fs        = require 'fs'
getPixels = require "get-pixels"
builder   = require 'xmlbuilder'

TMP_PATH  = 'tmp'
FONT_SIZE = 8

codeMap = [
  '1234567890!?.,。、ゃゅょャュョ',
  'abcdefghijklmnopqrstuvwxyz',
  'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
  'あいうえおかきくけこさしすせそたちつてとなにぬねのっ',
  'はひふへほまみむめもやゆよらりるれろわをんぁぃぅぇぉ',
  'がきぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽ',
  'アイウエオカキクケコサシスセソタチツテトナニヌネノッ',
  'ハヒフヘホマミムメモヤユヨラリルレロワヲンァィゥェォ',
  'ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ'
]

class PixelImage
  constructor: (@pixels, @width, @height) ->

  getPixel: (x, y)->
    offset = x * 4 + y * 4 * @width
    @pixels[offset] << 16 | @pixels[offset + 1] << 8 | @pixels[offset + 2]

  getSubPixels: (x, y, width, height)->
    @getPixel x + x2, y + y2 for x2 in [0..(width - 1)] for y2 in [0..(height - 1)]

createSvg = (paths)->
  svg = builder.create 'svg', {version: '1.0', encoding: 'UTF-8', standalone: true}
  svg.att xmlns: 'http://www.w3.org/2000/svg'
  font = svg
    .ele('def')
      .ele 'font', {id: '8x8', 'horiz-adv-x': '1024'}
  font.ele 'font-face', {'units-per-em': '1024', 'ascent':'960', 'descent': '-64'}
  font.ele 'missing-glyph', {'horiz-adv-x': '1024'}
  font.ele 'glyph', {'unicode': '&#x20;', 'd':'', 'horiz-adv-x': '512'}
  for code, path of paths
    font.ele 'glyph', {
      'unicode': "&#x#{code.charCodeAt(0).toString(16)};",
      'd':path
    }
  svg.end(pretty: true, indent: '  ', newline: '\n').replace(/&amp;/g, '&')

pixelsToPath = (pixels)->
  # 重複するパスを取り除きながらパスのリストをつくる
  paths = {}
  for y in [0..(pixels.length - 1)]
    for x in [0..(pixels[y].length - 1)]
      if pixels[y][x] == 0
        if paths["#{x+1},#{y}L"]?
          delete paths["#{x+1},#{y}L"]
        else
          paths["#{x},#{y}R"] = {x:x, y:y, path:"R", used:false}

        if paths["#{x+1},#{y+1}D"]?
          delete paths["#{x+1},#{y+1}D"]
        else
          paths["#{x+1},#{y}U"] = {x:x+1, y:y, path:"U", used:false}

        if paths["#{x},#{y+1}R"]
          delete paths["#{x},#{y+1}R"]
        else
          paths["#{x+1},#{y+1}L"] = {x:x+1, y:y+1, path:"L", used:false}

        if paths["#{x},#{y}U"]
          delete paths["#{x},#{y}U"]
        else
          paths["#{x},#{y+1}D"] = {x:x, y:y+1, path:"D", used:false}

  # unusedなパスを順番にたどり、パス文字列を作る
  pathStr = []
  for _, path of paths
    if !path.used
      current = path
      x = path.x
      y = path.y
      pathStr.push "M#{path.x * 1024 / FONT_SIZE} #{(FONT_SIZE-path.y) * 1024 / FONT_SIZE}"

      while !current.used
        current.used = true
        pathStr.push current.path
        switch current.path
          when 'U'
            y++
            current = paths["#{x},#{y}U"]||paths["#{x},#{y}R"]||paths["#{x},#{y}D"]||paths["#{x},#{y}L"]
          when 'D'
            y--
            current = paths["#{x},#{y}D"]||paths["#{x},#{y}L"]||paths["#{x},#{y}U"]||paths["#{x},#{y}R"]
          when 'R'
            x++
            current = paths["#{x},#{y}R"]||paths["#{x},#{y}D"]||paths["#{x},#{y}L"]||paths["#{x},#{y}U"]
          when 'L'
            x--
            current = paths["#{x},#{y}L"]||paths["#{x},#{y}U"]||paths["#{x},#{y}R"]||paths["#{x},#{y}D"]

  # 連続する同じ方向のパスの簡略化を行う
  pathStr
    .join('')
    .replace(/R+/g, (match)-> "h#{match.length * 1024 / FONT_SIZE}")
    .replace(/L+/g, (match)-> "h-#{match.length * 1024 / FONT_SIZE}")
    .replace(/U+/g, (match)-> "v-#{match.length * 1024 / FONT_SIZE}")
    .replace(/D+/g, (match)-> "v#{match.length * 1024 / FONT_SIZE}")
    .replace(/[vh]-?\d+$/, 'z')

main = ->
  fs.mkdirSync TMP_PATH if !fs.existsSync TMP_PATH

  getPixels "8x8_font.png", (err, pixels)->
    throw "Bad image path" if err

    img = new PixelImage pixels.data, pixels._shape1, pixels._shape0

    paths = {}
    for y in [0..(codeMap.length - 1)]
      for x in [0..(codeMap[y].length - 1)]
        paths[codeMap[y].charAt(x)] = pixelsToPath img.getSubPixels x * FONT_SIZE, y * FONT_SIZE, FONT_SIZE, FONT_SIZE

    fs.writeFileSync '8x8.svg', createSvg paths

main()
