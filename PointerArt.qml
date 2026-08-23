import QtQuick

// Theme-aware vector artwork shared by the live cursor, bar icon, and picker.
Canvas {
  id: root

  property string styleKey: "tiny-hand"
  property color fillColor: "#fff4d6"
  property color shadeColor: "#ffc987"
  property color outlineColor: "#171922"
  property color accentColor: "#ff9f1c"
  property color urgentColor: "#ff5d73"
  property real lineScale: 1

  antialiasing: true
  renderStrategy: Canvas.Cooperative

  onStyleKeyChanged: requestPaint()
  onFillColorChanged: requestPaint()
  onShadeColorChanged: requestPaint()
  onOutlineColorChanged: requestPaint()
  onAccentColorChanged: requestPaint()
  onUrgentColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  function begin(ctx, refWidth, refHeight) {
    ctx.reset()
    ctx.scale(width / refWidth, height / refHeight)
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    ctx.lineWidth = Math.max(2.5, 4.5 * lineScale)
    ctx.strokeStyle = outlineColor
    ctx.shadowColor = Qt.rgba(0, 0, 0, 0.32)
    ctx.shadowBlur = 5
    ctx.shadowOffsetX = 2
    ctx.shadowOffsetY = 3
  }

  function path(ctx, commands, fill, stroke) {
    ctx.beginPath()
    for (var i = 0; i < commands.length; i++) {
      var c = commands[i]
      if (c[0] === "M") ctx.moveTo(c[1], c[2])
      else if (c[0] === "L") ctx.lineTo(c[1], c[2])
      else if (c[0] === "C") ctx.bezierCurveTo(c[1], c[2], c[3], c[4], c[5], c[6])
      else if (c[0] === "Q") ctx.quadraticCurveTo(c[1], c[2], c[3], c[4])
      else if (c[0] === "Z") ctx.closePath()
    }
    if (fill) { ctx.fillStyle = fill; ctx.fill() }
    if (stroke !== false) ctx.stroke()
  }

  function detail(ctx, commands, color, width) {
    ctx.save()
    ctx.shadowColor = "transparent"
    ctx.strokeStyle = color || outlineColor
    ctx.lineWidth = width || 3
    path(ctx, commands, null, true)
    ctx.restore()
  }

  function tinyHand(ctx) {
    begin(ctx, 112, 126)
    path(ctx, [
      ["M",55,5],["C",47,5,41,11,41,20],["L",41,67],
      ["L",35,59],["C",30,52,21,51,15,56],["C",9,61,10,70,15,77],
      ["L",35,104],["C",42,114,52,120,65,120],["L",71,120],
      ["C",92,120,106,103,106,82],["L",106,65],
      ["C",106,57,101,52,94,52],["C",89,52,85,55,83,59],
      ["L",83,52],["C",83,44,77,38,70,38],["C",65,38,61,41,59,46],
      ["L",59,20],["C",59,11,63,5,55,5],["Z"]
    ], fillColor, true)
    detail(ctx, [["M",59,46],["L",59,72],["M",83,59],["L",83,74],["M",41,67],["L",46,75]], outlineColor, 3)
    path(ctx, [["M",37,104],["C",54,101,79,100,99,106],["C",92,115,82,120,70,120],["L",64,120],["C",52,120,43,114,37,104],["Z"]], accentColor, true)
    detail(ctx, [["M",49,109],["C",62,106,79,107,90,110]], fillColor, 2.5)
  }

  function middleFinger(ctx) {
    begin(ctx, 92, 118)
    path(ctx, [
      ["M",46,4],["C",38,4,33,10,33,18],["L",33,64],
      ["C",29,57,24,53,18,55],["C",10,57,8,66,12,73],
      ["L",27,99],["C",33,109,42,114,55,114],["C",73,114,84,101,84,83],
      ["L",84,69],["C",84,62,79,57,73,57],["C",68,57,64,60,63,64],
      ["L",63,54],["C",63,47,58,42,52,42],["L",52,18],
      ["C",52,10,54,4,46,4],["Z"]
    ], fillColor, true)
    detail(ctx, [["M",33,64],["L",38,72],["M",52,42],["L",52,68],["M",63,64],["L",63,75]], outlineColor, 3)
    path(ctx, [["M",27,99],["C",43,96,66,97,80,102],["C",74,110,65,114,55,114],["C",42,114,33,109,27,99],["Z"]], urgentColor, true)
    detail(ctx, [["M",37,104],["C",48,102,61,103,70,106]], fillColor, 2.5)
  }

  function catPaw(ctx) {
    begin(ctx, 74, 82)
    path(ctx, [["M",37,4],["C",29,4,25,12,27,20],["C",29,27,35,30,41,27],["C",48,24,50,16,47,10],["C",45,6,41,4,37,4],["Z"]], fillColor, true)
    path(ctx, [["M",15,22],["C",8,23,5,31,8,38],["C",11,44,18,46,23,42],["C",28,38,27,30,23,26],["C",21,23,18,22,15,22],["Z"]], fillColor, true)
    path(ctx, [["M",59,22],["C",52,22,48,29,50,36],["C",52,43,59,46,65,42],["C",71,38,70,29,65,25],["C",63,23,61,22,59,22],["Z"]], fillColor, true)
    path(ctx, [["M",37,30],["C",24,30,14,43,15,57],["C",16,71,28,78,38,78],["C",50,78,61,70,60,56],["C",59,43,50,30,37,30],["Z"]], shadeColor, true)
    ctx.save(); ctx.shadowColor = "transparent"
    ctx.fillStyle = accentColor
    ctx.beginPath(); ctx.ellipse(37,56,12,10,0,0,Math.PI*2); ctx.fill()
    for (var i=0;i<3;i++) { ctx.beginPath(); ctx.ellipse(25+i*12,42+(i===1?-3:0),5,6,0,0,Math.PI*2); ctx.fill() }
    ctx.restore()
  }

  function pixelGauntlet(ctx) {
    begin(ctx, 70, 78)
    ctx.lineJoin = "miter"; ctx.lineCap = "square"; ctx.lineWidth = 5
    path(ctx, [
      ["M",4,4],["L",34,4],["L",34,14],["L",45,14],["L",45,24],
      ["L",56,24],["L",56,34],["L",66,34],["L",66,57],["L",56,57],
      ["L",56,68],["L",45,68],["L",45,74],["L",22,74],["L",22,64],
      ["L",12,64],["L",12,54],["L",4,54],["Z"]
    ], fillColor, true)
    ctx.save(); ctx.shadowColor="transparent"; ctx.fillStyle=accentColor
    ctx.fillRect(10,10,18,10); ctx.fillRect(18,48,10,10); ctx.fillRect(30,58,20,10)
    ctx.fillStyle=shadeColor; ctx.fillRect(35,20,7,26); ctx.fillRect(47,30,7,22)
    ctx.restore()
  }

  function neonComet(ctx) {
    begin(ctx, 64, 64)
    ctx.lineWidth = 4
    path(ctx, [["M",3,3],["L",59,25],["L",35,34],["L",27,60],["Z"]], fillColor, true)
    path(ctx, [["M",8,8],["L",49,25],["L",31,29],["Z"]], accentColor, false)
    detail(ctx, [["M",31,29],["L",26,47]], urgentColor, 3)
    ctx.save(); ctx.shadowColor="transparent"; ctx.fillStyle=accentColor
    ctx.beginPath(); ctx.arc(13,45,4,0,Math.PI*2); ctx.fill()
    ctx.beginPath(); ctx.arc(7,56,2.5,0,Math.PI*2); ctx.fill()
    ctx.restore()
  }

  function omarchyBlade(ctx) {
    begin(ctx, 60, 82)
    path(ctx, [["M",30,3],["L",45,56],["L",31,69],["L",16,56],["Z"]], fillColor, true)
    path(ctx, [["M",30,3],["L",31,61],["L",20,54],["Z"]], accentColor, false)
    path(ctx, [["M",12,60],["L",48,60],["L",48,69],["L",12,69],["Z"]], urgentColor, true)
    path(ctx, [["M",25,69],["L",35,69],["L",39,79],["L",21,79],["Z"]], shadeColor, true)
    detail(ctx, [["M",30,12],["L",30,47]], fillColor, 2)
  }

  function jazzHand(ctx) {
    begin(ctx, 90, 96)
    path(ctx, [
      ["M",38,92],["C",25,88,17,77,17,63],["L",17,47],
      ["C",17,41,21,37,26,37],["C",29,37,32,39,33,42],
      ["L",31,19],["C",31,13,35,9,40,9],["C",45,9,48,13,48,18],["L",49,39],
      ["L",52,10],["C",53,4,57,2,62,3],["C",67,4,69,8,68,13],["L",65,42],
      ["L",70,21],["C",71,16,75,13,79,15],["C",84,17,85,21,83,27],["L",77,55],
      ["C",83,51,88,53,89,58],["C",90,62,87,66,82,70],["L",68,84],
      ["C",60,92,49,95,38,92],["Z"]
    ], fillColor, true)
    detail(ctx, [["M",33,42],["L",35,61],["M",49,39],["L",50,61],["M",65,42],["L",63,62],["M",77,55],["L",68,66]], outlineColor, 3)
    path(ctx, [["M",29,79],["C",42,76,58,78,70,85],["C",61,92,49,95,38,92],["C",34,89,31,84,29,79],["Z"]], accentColor, true)
    detail(ctx, [["M",39,84],["C",48,83,57,85,62,88]], shadeColor, 2.5)
  }

  onPaint: {
    var ctx = getContext("2d")
    if (styleKey === "jazz-hand") jazzHand(ctx)
    else if (styleKey === "middle-finger") middleFinger(ctx)
    else if (styleKey === "cat-paw") catPaw(ctx)
    else if (styleKey === "pixel-gauntlet") pixelGauntlet(ctx)
    else if (styleKey === "neon-comet") neonComet(ctx)
    else if (styleKey === "omarchy-blade") omarchyBlade(ctx)
    else tinyHand(ctx)
  }
}
