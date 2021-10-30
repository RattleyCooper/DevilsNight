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
    lastDirection: int
  
  DropLocation = ref object of Obj

  GameStates = enum
    gsWaiting, gsPlaying, gsGameOver

  GameState = ref object of RootObj
    state: GameStates
    currentStage: RoadStages
    player: Player
    houses: seq[House]
    cam: Vec2
    frame: int

proc overlaps(a,b: Obj): bool =
  let ax0 = a.position.x + a.hitbox.x
  let ax1 = a.position.x + a.hitbox.x + a.hitbox.w - 1
  let ay0 = a.position.y + a.hitbox.y
  let ay1 = a.position.y + a.hitbox.y + a.hitbox.h - 1

  let bx0 = b.position.x + b.hitbox.x
  let bx1 = b.position.x + b.hitbox.x + b.hitbox.w - 1
  let by0 = b.position.y + b.hitbox.y
  let by1 = b.position.y + b.hitbox.y + b.hitbox.h - 1
  return not ( ax0 > bx1 or ay0 > by1 or ax1 < bx0 or ay1 < by0 )

proc newPlayer(x, y: int): Player = 
  result = new Player
  result.position = ivec2(x, y)
  result.hitbox = (x: x, y: y, w: 8, h: 8)
  result.velocity = vec2(0.0, 0.0)
  result.lastDirection = 1

proc newHouse(style: Houses): House = 
  result = new House
  result.position = ivec2(0, 0)
  result.hitbox = (x: 0, y: 0, w: 32, h: 48)
  result.velocity = vec2(0.0, 0.0)
  result.style = style


let
  gridSize = ivec2(40, 30)
  worldSize = ivec2(192 * 2, 112 * 2)
  mapSize = ivec2(192, 112)
  tileSize = ivec2(16, 16)
  houseSize = ivec2(32, 48)


var player = newPlayer(100, 100)
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
gs.currentStage = rs0
gs.player = player
gs.houses = houses
gs.cam = cam
gs.frame = 0

var
  objects = newSeq[Obj]()
  gameStart: DateTime
  timer = 5.0
  sacrifices = 0

method update(self: Obj) {.base.} =
  discard

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
  # echo $self.direction
  var maxSpeed = 2.0
  var acceleration = 0.05
  var decceleration = 0.05

  # self.velocity.x = approach()

  # gs.player.position += gs.player.direction

  # if gs.player.direction.x == 0:
  #   gs.player.velocity.x = approach(gs.player.velocity.x.float, gs.player.direction.x.float * maxSpeed, decceleration)
  # else:
  #   gs.player.velocity.x = approach(gs.player.velocity.x.float, gs.player.direction.x.float * maxSpeed, acceleration)  

  # if gs.player.direction.y == 0:
  #   gs.player.velocity.y = approach(gs.player.velocity.y.float, gs.player.direction.y.float * maxSpeed, decceleration)
  # else:
  #   gs.player.velocity.y = approach(gs.player.velocity.y.float, gs.player.direction.y.float * maxSpeed, acceleration)  


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

proc gameInit() =
  let pl = loadPaletteFromImage("palette.png")
  setPalette(pl)
  loadSpriteSheet(0, "Houses-32x48.png", 32, 48)
  loadSpriteSheet(1, "Tiles-16x16.png", 16, 16)
  loadSpriteSheet(2, "roads.png", 512, 112)
  loadSpriteSheet(3, "LoS_Cover.png", 224, 224)
  loadSpriteSheet(4, "pc.png", 20, 26)
  setSpritesheet(1)

  objects = newSeq[Obj]()
  player = newPlayer(16, 8)
  objects.add(player)

  # newMap(0,16,256,8,8)
  # setMap(0)

proc move(self: var Player, ox, oy: float32) =
  gs.player.position.x += ox
  gs.player.position.y += oy

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
    return

  if gs.state != gsGameOver:
    gs.player.move(gs.player.direction.x.toFloat, gs.player.direction.y.toFloat)
    gs.player.update()


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
      spr(ord(h.style), housePosition(i), offsets[i])
  
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

  for obj in objects:
    obj.draw()

  if gs.state == gsWaiting:
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

