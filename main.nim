import nico
import vmath
import times
import random
import sequtils

randomize()


type
  Directions = enum
    dNone, dUp, dDown, dLeft, dRight

  Stages = enum
    s0, s1, s2, s3, s4, s5, s6

  Houses = enum
    hFrankenstein, hVampire, hGhost, hDevil, hClown, hReaper

  Hitbox = tuple
    x, y, w, h: int
  
  Obj = ref object of RootObj
    position: IVec2
    velocity: Vec2
    hitbox: Hitbox
  
  House = ref object of Obj
    style: Houses

  Player = ref object of Obj
    holding: Obj
    direction: IVec2
    lastDirection: int

  Items = enum
    iBolt, iFang, iPot, iSoul, iBaloon, iGrate, iScythe

  Item = ref object of Obj
    style: Items
    house: House
    isGrate: bool
    isSoul: bool
  
  DropLocation = ref object of Obj

  SoundFx = enum
    fxWalking

  Music = enum
    mIntro, mTheme1, mTheme2, mTheme3, mTheme4, mTheme5, mTheme6, mTheme7

  GameStates = enum
    gsWaiting, gsPlaying, gsGameOver

  GameState = ref object of RootObj
    state: GameStates
    currentStage: Stages
    player: Player
    houses: seq[House]
    cam: Vec2
    frame: int
    currentRecipe: seq[Item]

proc overlaps(a,b: Obj): bool =
  let ax0 = a.position.x + a.hitbox.x
  let ax1 = a.position.x + a.hitbox.x + a.hitbox.w
  let ay0 = a.position.y + a.hitbox.y
  let ay1 = a.position.y + a.hitbox.y + a.hitbox.h

  let bx0 = b.position.x + b.hitbox.x
  let bx1 = b.position.x + b.hitbox.x + b.hitbox.w
  let by0 = b.position.y + b.hitbox.y
  let by1 = b.position.y + b.hitbox.y + b.hitbox.h
  return not ( ax0 > bx1 or ay0 > by1 or ax1 < bx0 or ay1 < by0 )

proc newPlayer(x, y: int): Player = 
  result = new Player
  result.position = ivec2(x, y)
  result.hitbox = (x: 0, y: 8, w: 8, h: 8)
  result.velocity = vec2(0.0, 0.0)
  result.lastDirection = 1

proc newHouse(style: Houses): House = 
  result = new House
  result.position = ivec2(0, 0)
  result.hitbox = (x: -3, y: 0, w: 32, h: 48)
  result.velocity = vec2(0.0, 0.0)
  result.style = style


let
  worldSize = ivec2(192 * 2, 112 * 2)
  mapSize = ivec2(192, 112)
  houseSize = ivec2(32, 48)


var 
  player = newPlayer(100, 100)
  objects = newSeq[Obj]()

var houses = block:
  var res = newSeq[House](6)
  var c = 0
  for house in Houses.low..Houses.high:
    echo $house
    res[c] = newHouse(house)
    c += 1
  res

var 
  cam = vec2()
  gs = new GameState

gs.state = gsWaiting
gs.currentStage = s0
gs.player = player
gs.houses = houses
gs.cam = cam
gs.frame = 0

var
  gameStart: DateTime
  timer = 5.0
  sacrifices = 0

proc randomRecipe(length: int): seq[Item] =
  result = block:
    var recipe = newSeq[Item](length)
    for i in 0..recipe.high:
      let style = rand(Items.low..Items.high)
      var item = new Item
      item.style = style
      item.isGrate = false
      item.isSoul = false

      case style:
      of iBolt:
        item.house = gs.houses.filterIt(it.style == hFrankenstein)[0]
      of iFang:
        item.house = gs.houses.filterIt(it.style == hVampire)[0]
      of iScythe:
        item.house = gs.houses.filterIt(it.style == hReaper)[0]
      of iBaloon:
        item.house = gs.houses.filterIt(it.style == hClown)[0]
      of iPot:
        item.house = gs.houses.filterIt(it.style == hGhost)[0]
      of iGrate:
        item.isGrate = true
      of iSoul:
        item.isSoul = true

      if not(item.isSoul or item.isGrate):  # 32x48
        item.position = item.house.position + ivec2(16, 48) + ivec2(0, 16)
        item.hitbox = (x: 0, y: 0, w: 16, h: 16)
        recipe[i] = item
    recipe

method update(self: Obj) {.base.} =
  discard

proc move(self: var Player, ox, oy: float32) =
  gs.player.position.x += ox
  gs.player.position.y += oy


proc testCollision(house: House, x, y: float32): bool =
  var testObj = new Obj

  testObj.position = gs.player.position
  testObj.hitbox = gs.player.hitbox
  testObj.velocity = gs.player.velocity

  testObj.position.x += x
  testObj.position.y += y

  if testObj.overlaps(house):
    result = true
  else:
    result = false

method update(self: House) =
  discard
  # self.hitbox.x = self.position.x
  # self.hitbox.y = self.position.y

method update(self: Player) =
  gs.player.direction = block:
    var res = ivec2(0, 0)
    if btn(pcRight): 
      res.x = 1
      gs.player.lastDirection = 1
    elif btn(pcLeft): 
      res.x = -1
      gs.player.lastDirection = -1

    if btn(pcUp): res.y = -1
    elif btn(pcDown): res.y = 1

    res

  if gs.player.direction != ivec2(0, 0):
    sfxVol(255)
    sfx(1, fxWalking.ord)

  for h in gs.houses:
    if h.testCollision(gs.player.direction.x.toFloat, gs.player.direction.y.toFloat):
      gs.player.direction.x = 0
      gs.player.direction.y = 0


method draw(self: Obj) {.base.} =
  setColor(10)
  rect(self.position.x + self.hitbox.x, self.position.y + self.hitbox.y, self.position.x + self.hitbox.x + self.hitbox.w - 1, self.position.y + self.hitbox.y + self.hitbox.h - 1)

method draw(self: Player) =
  setColor(11)
  var whichSprite = block:
    var sp: int
    if (gs.player.direction.x != 0 or gs.player.direction.y != 0) and gs.frame >= 15:
      sp = 1
    elif gs.player.direction.x != 0 or gs.player.direction.y != 0:
      sp = 2
    else:
      sp = 0
    sp
  setSpritesheet(4)
  if gs.player.direction.x == -1:
    spr(
      whichSprite, 
      gs.player.position.x, 
      gs.player.position.y, 
      1, 1, 
      true
    )
  elif gs.player.direction.x == 1:
    spr(whichSprite, gs.player.position.x, gs.player.position.y)
  else:
    spr(
      whichSprite, 
      gs.player.position.x, 
      gs.player.position.y, 
      1, 1, 
      if gs.player.lastDirection == 1: false else: true
    )
  # rect(self.position.x + self.hitbox.x, self.position.y + self.hitbox.y, self.position.x + self.hitbox.x + self.hitbox.w - 1, self.position.y + self.hitbox.y + self.hitbox.h - 1)

proc advanceStage() =
  if gs.state == gsWaiting:
    gs.currentStage = s0
    music(0, mTheme1.ord)

  case gs.currentStage:
  of s0:
    gs.currentStage = s1
    music(0, mTheme2.ord)
  of s1:
    gs.currentStage = s2
    music(0, mTheme3.ord)
  of s2:
    gs.currentStage = s3
    music(0, mTheme4.ord)
  of s3:
    gs.currentStage = s4
    music(0, mTheme5.ord)
  of s4:
    gs.currentStage = s5
    music(0, mTheme6.ord)
  of s5:
    gs.currentStage = s6
    music(0, mTheme7.ord)
  of s6:
    gs.currentStage = s0
    music(0, mTheme1.ord)


proc gameInit() =
  let pl = loadPaletteFromImage("palette.png")
  setPalette(pl)
  loadSpriteSheet(0, "Houses-32x48.png", 32, 48)
  loadSpriteSheet(1, "Tiles-16x16.png", 16, 16)
  loadSpriteSheet(2, "roads.png", 512, 112)
  loadSpriteSheet(3, "LoS_Cover.png", 224, 224)
  loadSpriteSheet(4, "pc.png", 16, 16)
  loadSpriteSheet(5, "title.png", 192, 112)

  loadMusic(mIntro.ord, "Start Screen Theme.ogg")
  loadMusic(mTheme1.ord, "Theme 1.ogg")
  loadMusic(mTheme2.ord, "Theme 2.ogg")
  loadMusic(mTheme3.ord, "Theme 3-1.ogg")
  loadMusic(mTheme4.ord, "Theme 4-1.ogg")
  loadMusic(mTheme5.ord, "Theme 5-1.ogg")
  loadMusic(mTheme6.ord, "Theme 6-1.ogg")
  loadMusic(mTheme7.ord, "Theme 7-1.ogg")

  # musicVol(180)
  music(mIntro.ord, 0)

  loadSfx(fxWalking.ord, "Footsteps (Fast).ogg")

  setSpritesheet(1)

  objects = newSeq[Obj]()
  player = newPlayer(16, 8)
  objects.add(player)

  # newMap(0,16,256,8,8)
  # setMap(0)

proc gameUpdate(dt: float32) =
  # echo $dt
  gs.frame += 1
  if gs.frame == 29: gs.frame = 0
  gs.cam.x = gs.player.position.x.toFloat - (mapSize.x div 2).toFloat + (10).toFloat
  gs.cam.y = gs.player.position.y.toFloat - (mapSize.y div 2).toFloat + (13).toFloat
  setCamera(gs.cam.x, gs.cam.y)

  if gs.state == gsWaiting:
    if btnp(pcStart):
      gs.state = gsPlaying
      gameStart = now()
      advanceStage()
    return

  if gs.state != gsGameOver:
    gs.player.move(gs.player.direction.x.toFloat, gs.player.direction.y.toFloat)
    gs.player.update()
    for h in gs.houses:
      h.update()


proc housePosition(index: int): int = 
  let sixth = (1.0 / 6.0) * worldSize.x.toFloat
  result = (sixth * index.float).int + (houseSize.x div 2)

proc gameDraw() = 
  cls()

  block grass:
    setColor(21)
    rectfill(-150, -150, 450, 450)
    # setSpritesheet(1)
    # for x in countup(0, worldSize.x, tileSize.x):
    #   for y in countup(0, worldSize.y, tileSize.y):
    #     spr(13, x, y)

  block houses:
    setSpritesheet(0)
    let offsets = @[45, 30, 60, 30, 45, 60]
    for i, h in gs.houses:
      h.position.x = housePosition(i)
      h.position.y = offsets[i]
      spr(ord(h.style), housePosition(i), offsets[i])
      setColor(25)
      
  
  block road:
    setSpritesheet(2)
    case gs.currentStage:
    of s0:
      spr(0, -80, 128)
    of s1:
      spr(1, -80, 128)      
    of s2:
      spr(2, -80, 128)
    of s3:
      spr(3, -80, 128)
    of s4:
      spr(4, -80, 128)
    of s5:
      spr(5, -80, 128)
    of s6:
      spr(6, -80, 128)

  for obj in objects:
    obj.draw()

  if gs.state == gsWaiting:
    setSpritesheet(5)
    spr(0, gs.cam.x, gs.cam.y)
    setColor(12)
    return

  var displayTime = timer - (now() - gameStart).inSeconds

  if displayTime <= 0:
    # Game over
    displayTime = 0
    setColor(7)
    printc("Time's Up!", screenWidth / 2, screenHeight / 3)
    printc($sacrifices & " sacrifices complete", screenWidth / 2, (screenHeight / 3) + 8)

  # Ui
  setColor(7)
  printc($displayTime, screenWidth / 2, 1)


nico.init("We Jammin'", "Devil's Night")
nico.createWindow("Devil's Night", mapSize.x, mapSize.y, 6)

loadFont(0, "font.png")
setFont(0)
fixedSize(true)
integerScale(true)

nico.run(gameInit, gameUpdate, gameDraw)

