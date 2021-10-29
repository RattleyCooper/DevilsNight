import nico
import vmath
import times


type
  Directions = enum
    dNone, dUp, dDown, dLeft, dRight

  RoadStages = enum
    rs0, rs1, rs2, rs3, rs4, rs5, rs6

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
  
  DropLocation = ref object of Obj

  GameStates = enum
    gsWaiting, gsPlaying, gsGameOver

  GameState = ref object of RootObj
    state: GameStates
    currentStage: RoadStages
    player: Player
    houses: seq[House]

proc newPlayer(x, y: int): Player = 
  result = new Player
  result.position = ivec2(x, y)
  result.hitbox = (x: x, y: y, w: 8, h: 8)
  result.velocity = vec2(0.0, 0.0)

proc newHouse(style: Houses): House = 
  result = new House
  result.position = ivec2(0, 0)
  result.hitbox = (x: 0, y: 0, w: 32, h: 48)
  result.velocity = vec2(0.0, 0.0)
  result.style = style

var player = newPlayer(15, 15)
var houses = block:
  var res = newSeq[House](6)
  var c = 0
  for house in Houses.low..Houses.high:
    echo $house
    res[c] = newHouse(house)
    c += 1
  res
    
var gs = new GameState
gs.state = gsWaiting
gs.currentStage = rs0
gs.player = player
gs.houses = houses

var player = newPlayer(15, 15)
var objects = newSeq[Obj]()
var gameStart: DateTime
var timer = 5.0
var sacrifices = 0
var cam = ivec2()


method update(self: Obj) {.base.} =
  discard

# method update(self: Player) =
#   self.direction = block:
#     var res = ivec2(0, 0)
#     if btn(pcRight): res.x = 1
#     elif btn(pcLeft): res.x = -1

#     if btn(pcUp): res.y = -1
#     elif btn(pcDown): res.y = 1

#     res

#   var maxSpeed = 2.0
#   var acceleration = 0.6
#   var decceleration = 0.15

#   if abs(self.velocity.x) > maxSpeed:
#     self.velocity.x = approach(self.velocity.x, self.direction.x.float32 * maxSpeed, decceleration)
#   else:
#     self.velocity.x = approach(self.velocity.x, self.direction.x.float32 * maxSpeed, acceleration)  

#   if abs(self.velocity.y) > maxSpeed:
#     self.velocity.y = approach(self.velocity.y, self.direction.y.float32 * maxSpeed, decceleration)
#   else:
#     self.velocity.y = approach(self.velocity.y, self.direction.y.float32 * maxSpeed, acceleration)  


method draw(self: Obj) {.base.} =
  setColor(10)
  rect(self.position.x + self.hitbox.x, self.position.y + self.hitbox.y, self.position.x + self.hitbox.x + self.hitbox.w - 1, self.position.y + self.hitbox.y + self.hitbox.h - 1)

method draw(self: Player) =
  setColor(11)
  rect(self.position.x + self.hitbox.x, self.position.y + self.hitbox.y, self.position.x + self.hitbox.x + self.hitbox.w - 1, self.position.y + self.hitbox.y + self.hitbox.h - 1)

proc gameInit() =
  let pl = loadPaletteFromImage("palette.png")
  setPalette(pl)
  loadSpriteSheet(0, "Houses-32x48.png", 32, 48)
  loadSpriteSheet(1, "Tiles-16x16.png", 16, 16)
  loadSpriteSheet(2, "V1_Road.png", 512, 96)
  setSpritesheet(1)

  objects = newSeq[Obj]()
  player = newPlayer(16, 8)
  objects.add(player)

  # newMap(0,16,256,8,8)
  # setMap(0)

proc gameUpdate(dt: float32) =
  if gs.state == gsWaiting:
    if btnp(pcStart):
      gs.state = gsPlaying
      gameStart = now()
    return

  for obj in objects:
    obj.update()


let
  gridSize = ivec2(40, 30)
  mapSize = ivec2(192, 112)
  tileSize = ivec2(16, 16)
  houseSize = ivec2(32, 48)


proc housePosition(index: int): int = 
  let sixth = (1.0 / 6.0) * mapSize.x.toFloat
  result = (sixth * index.float).int + (houseSize.x div 2)

proc gameDraw() = 
  cls()

  block grass:
    setSpritesheet(1)
    for x in countup(0, mapSize.x, tileSize.x):
      for y in countup(0, mapSize.y, tileSize.y):
        spr(13, x, y)

  block houses:
    setSpritesheet(0)

    block frankenstein:
      spr(0, housePosition(0), 45)
    block vampire:
      spr(1, housePosition(1), 30)
    block reaper:
      spr(5, housePosition(2), 60)
    block devil:
      spr(3, housePosition(3), 30)
    block clown:
      spr(4, housePosition(4), 45)
    block ghost:
      spr(2, housePosition(5), 60)
  
  block road:
    setSpritesheet(2)
    case gs.currentStage:
    of rs0:
      spr(0, -80, 128)
    of rs1:
      spr(1, -80, 128)      
    of rs2:
      spr(2, -80, 128)
    of rs3:
      spr(3, -80, 128)
    of rs4:
      spr(4, -80, 128)
    of rs5:
      spr(5, -80, 128)
    of rs6:
      spr(6, -80, 128)

  if gs.state == gsWaiting:
    setColor(7)
    printc("Devil's Night", screenWidth / 2, screenHeight / 3)
    printc("Press Start", screenWidth / 2, (screenHeight / 3) + 8)
    printc("[ Enter ]", screenWidth / 2, (screenHeight / 3) + 16)
    return

  for obj in objects:
    obj.draw()

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

