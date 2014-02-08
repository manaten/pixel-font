fs        = require 'fs'
getPixels = require "get-pixels"
builder   = require 'xmlbuilder'
setting   = require (process.argv[2] or './8x8.json')

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
      .ele 'font', {id: setting.name, 'horiz-adv-x': '1024'}
  font.ele 'font-face', {'units-per-em': '1024', 'ascent':'1024', 'descent': '0'}
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
      pathStr.push "M#{path.x * 1024 / setting.size} #{(setting.size-path.y) * 1024 / setting.size}"

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
    .replace(/R+/g, (match)-> "h#{match.length * 1024 / setting.size}")
    .replace(/L+/g, (match)-> "h-#{match.length * 1024 / setting.size}")
    .replace(/U+/g, (match)-> "v-#{match.length * 1024 / setting.size}")
    .replace(/D+/g, (match)-> "v#{match.length * 1024 / setting.size}")
    .replace(/[vh]-?\d+$/, 'z')

main = ->
  getPixels setting.img, (err, pixels)->
    throw "Bad image path" if err

    img = new PixelImage pixels.data, pixels._shape1, pixels._shape0

    paths = {}
    for y in [0..(setting.map.length - 1)]
      for x in [0..(setting.map[y].length - 1)]
        paths[setting.map[y].charAt(x)] = pixelsToPath img.getSubPixels x * setting.size, y * setting.size, setting.size, setting.size

    fs.writeFileSync "#{setting.name}.svg", createSvg paths

main()
