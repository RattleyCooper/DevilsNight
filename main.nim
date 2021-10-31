import nico
import vmath
import random
import sequtils

randomize()
#gameplay tweak:  Make it a puzzle and add item outline.  Player should
# turn in all items before picking up the outlined item.  Once they 
# pick up the outlined item the stage is cleared and the next stage begins.

type
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
    inventory: seq[Item]
    dead: bool
    lastDirectionVec: IVec2

  GameItems = enum
    iBolt, iFang, iPot, iSoul, iBaloon, iGrate, iScythe

  Item = ref object of Obj
    style: GameItems
    house: House
    isGrate: bool
    isSoul: bool
    found: bool
  
  DropLocation = ref object of Obj

  SoundFx = enum
    fxWalking, fxItemPickup, fxItemDrop, fxDeath

  Music = enum
    mIntro, 
    mTheme1, mTheme2, mTheme3, mTheme4, mTheme5, mTheme6, mTheme7,
    mGameOver,
    mCredits

  GameStates = enum
    gsWaiting, gsPlaying, gsGameOver, gsEnding, gsCredits

  GameState = ref object of RootObj
    state: GameStates
    currentStage: Stages
    player: Player
    houses: seq[House]
    cam: Vec2
    frame: int
    currentRecipe: seq[Item]
    recipeMatch: seq[Item]
    droppedItems: seq[Item]
    dropLocation: DropLocation
    clownTrap: Item

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
  result.hitbox = (x: 4, y: 8, w: 8, h: 8)
  result.velocity = vec2(0.0, 0.0)
  result.lastDirection = 1
  result.inventory = newSeq[Item]()
  result.dead = false
  result.lastDirectionVec = ivec2(0, 1)

proc newHouse(style: Houses): House = 
  result = new House
  result.position = ivec2(0, 0)
  result.hitbox = (x: -3, y: 0, w: 32, h: 48)
  result.velocity = vec2(0.0, 0.0)
  result.style = style

proc newDropoff(): DropLocation = 
  result = new DropLocation
  result.position = ivec2(514-10, 162-10)
  result.hitbox = (x: 0, y: 0, w: 26+20, h: 22+20)
  result.velocity = vec2(0.0, 0.0)

proc randomItemStyle(without: seq[Item]): GameItems = 
  let r = rand(GameItems.low..GameItems.high)
  if r == iSoul or r == iGrate:
    return randomItemStyle(without)
  var nonNil = without.filterIt(it.isNil == false)
  let inSeq = nonNil.filterIt(it.style == r).len > 0
  if inSeq:
    return randomItemStyle(without)
  return r


let
  worldSize = ivec2(512 * 2, 112 * 3)
  mapSize = ivec2(192, 112)
  houseSize = ivec2(32, 48)


var 
  player = newPlayer(520, 125)

var houses = block:
  var res = newSeq[House](6)
  var c = 0
  for house in Houses.low..Houses.high:
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
gs.dropLocation = newDropoff()
gs.cam = cam
gs.frame = 0

proc newItem(style: GameItems): Item =
  var item = new Item
  item.style = style
  item.isGrate = false
  item.isSoul = false
  item.found = false

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
    item.house = gs.houses.filterIt(it.style == hGhost)[0]
  of iSoul:
    item.isSoul = true
    item.house = gs.houses.filterIt(it.style == hDevil)[0]

  # if not(item.isSoul or item.isGrate):  # 32x48
  item.position = item.house.position + ivec2(16, 48) + ivec2(0, 16)
  item.hitbox = (x: 0, y: 0, w: 16, h: 16)
  item


proc randomRecipe(length: int): seq[Item] =
  var rec = block:
    var recipe = newSeq[Item]()
    for c in 0..length-1:
      let style = randomItemStyle(recipe)
      var item = newItem(style)
      recipe.add(item)
      
    recipe
  rec

gs.currentRecipe = randomRecipe(3)
gs.recipeMatch = gs.currentRecipe
gs.droppedItems = newSeq[Item]()
gs.clownTrap = newItem(iGrate)


method update(self: Obj) {.base.} =
  discard

method update(item: var Item) {.base.} =
  item.position = item.house.position + ivec2(16, 48) + ivec2(0, 16)

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

proc advanceStage() =
  gs.houses.shuffle()
  gs.clownTrap.position.x = rand(100..924)
  if gs.state == gsWaiting:
    gs.currentStage = s0
    music(0, mTheme1.ord)
    # echo $gs.currentStage
    return

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
    gs.state = gsWaiting
    music(0, mTheme1.ord)
  # echo $gs.currentStage

proc killPlayer() =
  gs.player.dead = true
  gs.player.direction.x = 0
  gs.player.direction.y = 0
  sfx(4, fxDeath.ord)
  music(0, mGameOver.ord)

proc collide(itm: Item, pl: Player) =
  if itm.overlaps(pl):
    if itm.style == iSoul or itm.style == iGrate:
      killPlayer()

    for i, titm in gs.currentRecipe:
      if itm.found:
        continue
      if itm.style == titm.style:
        gs.currentRecipe[i].found = true
        sfxVol(255)
        sfx(1, fxItemPickup.ord)
    if not(itm in gs.player.inventory):
      gs.player.inventory.add(itm)

proc collide(dr: DropLocation, pl: Player) =
  if dr.overlaps(pl) and gs.player.inventory.len > 0:
    for itm in gs.player.inventory:
      gs.droppedItems.add(itm)
    gs.player.inventory = newSeq[Item]()
    sfx(3, fxItemDrop.ord)

    var recipeComplete = gs.currentRecipe.filterIt(it.found == false).len == 0
    var itemsDropped = true

    for item in gs.currentRecipe:
      var itemInPit = false
      for pitItem in gs.droppedItems:
        if pitItem.style == item.style:
          itemInPit = true
      if not itemInPit:
        itemsDropped = false
    if gs.droppedItems.len == 0:
      itemsDropped = false
    if recipeComplete and itemsDropped:
      if gs.currentStage == s6:
        gs.currentRecipe = @[newItem(iSoul)]
      else:
        gs.currentRecipe = randomRecipe(3)
        gs.droppedItems = newSeq[Item]()
        advanceStage()
  

method update(self: House) =
  discard
  # self.hitbox.x = self.position.x
  # self.hitbox.y = self.position.y

method update(self: Player) =
  # echo $gs.player.position
  if gs.player.dead:
    return

  gs.player.direction = block:
    var res = ivec2(0, 0)
    if btn(pcRight): 
      res.x = 1
      gs.player.lastDirection = 1
    elif btn(pcLeft): 
      res.x = -1
      gs.player.lastDirection = -1

    if btn(pcUp): 
      res.y = -1
    elif btn(pcDown): 
      res.y = 1
    if res != ivec2(0, 0):
      gs.player.lastDirectionVec = res
    res

  # if gs.player.direction != ivec2(0, 0) and gs.frame mod 15 == 0:
  #   sfxVol(255)
  #   sfx(2, fxWalking.ord)

  for h in gs.houses:
    if h.testCollision(gs.player.direction.x.toFloat, gs.player.direction.y.toFloat):
      gs.player.direction.x = 0
      gs.player.direction.y = 0

  for itm in gs.currentRecipe:
    itm.collide(gs.player)

  gs.dropLocation.collide(gs.player)
  gs.clownTrap.collide(gs.player)


method draw(self: Obj) {.base.} =
  setColor(10)
  rect(self.position.x + self.hitbox.x, self.position.y + self.hitbox.y, self.position.x + self.hitbox.x + self.hitbox.w - 1, self.position.y + self.hitbox.y + self.hitbox.h - 1)

var deathFrames = 0
var deathAnim = 3

method draw(self: Player) =
  setColor(11)
  setSpritesheet(4)

  if gs.player.dead and deathFrames == 0 and deathAnim < 11:
    deathAnim += 1

  if gs.player.dead:
    if gs.player.lastDirection == -1:
      spr(
        deathAnim,
        gs.player.position.x, 
        gs.player.position.y, 
        1, 1, 
        true
      )
    elif gs.player.lastDirection == 1:
      spr(deathAnim, gs.player.position.x, gs.player.position.y)
    else:
      spr(deathAnim, gs.player.position.x, gs.player.position.y)
    return

  var whichSprite = block:
    var sp: int
    if (gs.player.direction.x != 0 or gs.player.direction.y != 0) and gs.frame >= 15:
      sp = 1
    elif gs.player.direction.x != 0 or gs.player.direction.y != 0:
      sp = 2
    else:
      sp = 0
    sp

  if player.dead:
    spr(11, gs.player.position.x, gs.player.position.y)
    return
  elif gs.player.direction.x == -1:
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
  loadSpriteSheet(2, "roadsv2.png", 512 * 2, 112)
  loadSpriteSheet(3, "LoS_Cover.png", 224, 224)
  loadSpriteSheet(4, "pc.png", 16, 16)
  loadSpriteSheet(5, "title.png", 192, 112)
  loadSpriteSheet(6, "ending.png", 192, 112)
  loadSpriteSheet(7, "credits.png", 192, 112)

  loadMusic(mIntro.ord, "Start Screen Theme.ogg")
  loadMusic(mTheme1.ord, "Theme 1.ogg")
  loadMusic(mTheme2.ord, "Theme 2.ogg")
  loadMusic(mTheme3.ord, "Theme 3-1.ogg")
  loadMusic(mTheme4.ord, "Theme 4-1.ogg")
  loadMusic(mTheme5.ord, "Theme 5-1.ogg")
  loadMusic(mTheme6.ord, "Theme 6-1.ogg")
  loadMusic(mTheme7.ord, "Theme 7-1.ogg")
  loadMusic(mGameOver.ord, "Theme for Game Over.ogg")
  loadMusic(mCredits.ord, "End Credits.ogg")

  musicVol(100)
  music(0, mIntro.ord)

  loadSfx(fxWalking.ord, "Footsteps (Fast).ogg")
  loadSfx(fxItemPickup.ord, "Pick up object.ogg")
  loadSfx(fxItemDrop.ord, "Sacrifice Sound 6.ogg")
  loadSfx(fxDeath.ord, "Death Noise 3.ogg")

  setSpritesheet(1)

  gs.clownTrap.position.y = 138
  gs.clownTrap.position.x = rand(100..924)
  gs.houses.shuffle()


  # newMap(0,16,256,8,8)
  # setMap(0)

proc resetGame() =
  gs.state = gsWaiting
  gs.player.dead = false
  gs.player.inventory = newSeq[Item]()
  gs.player.lastDirection = 1
  gs.player.lastDirectionVec = ivec2(0, 1)
  gs.player.position = ivec2(520, 125)
  advanceStage()
  gs.frame = 0
  deathFrames = 0
  deathAnim = 0
  gs.currentRecipe = randomRecipe(3)
  gs.recipeMatch = newSeq[Item]()
  gs.droppedItems = newSeq[Item]()
  gs.dropLocation = newDropoff()

proc gameUpdate(dt: float32) =
  if gs.state == gsGameOver:
    gs.state = gsEnding
    return
  if gs.state == gsEnding:
    if btnp(pcStart):
      gs.state = gsCredits
      music(0, mCredits.ord)
    return
    
  if gs.state == gsCredits:
    if btnp(pcStart):
      gs.state = gsWaiting
      resetGame()
    return

  gs.frame += 1
  if gs.player.dead:
    deathFrames += 1
  if gs.frame == 29: gs.frame = 0
  if deathFrames == 14:
    deathFrames = 0

  if deathAnim >= 11:
    gs.state = gsGameOver
    gs.cam.x = 0.0
    gs.cam.y = 0.0
    setCamera(gs.cam.x, gs.cam.y)
    return
    
  gs.cam.x = gs.player.position.x.toFloat - (mapSize.x div 2).toFloat + (10).toFloat
  gs.cam.y = gs.player.position.y.toFloat - (mapSize.y div 2).toFloat + (13).toFloat
  setCamera(gs.cam.x, gs.cam.y)

  if gs.state == gsWaiting:
    if btnp(pcStart):
      gs.state = gsPlaying
    return

  if gs.state == gsPlaying:
    if gs.player.position.x > 40 and gs.player.position.x < 944:
      gs.player.position.x += gs.player.direction.x.toFloat
      if gs.player.position.x < 41:
        gs.player.position.x = 41
      elif gs.player.position.x > 943:
        gs.player.position.x = 943

    if gs.player.position.y < 170 and gs.player.position.y > 20:
      gs.player.position.y += gs.player.direction.y.toFloat

      if gs.player.position.y > 169:
        gs.player.position.y = 169
      elif gs.player.position.y < 21:
        gs.player.position.y = 21
    
    gs.player.update()
    for h in gs.houses:
      h.update()
    for itm in gs.currentRecipe:
      if itm.found:
        continue
      itm.position = itm.house.position + ivec2(8, 48)
      itm.update()

proc housePosition(index: int): int = 
  let sixth = (1.0 / 6.0) * (worldSize.x.toFloat - 50.0)
  result = (sixth * index.float).int + (houseSize.x div 2) + (sixth.toInt div 2)

proc gameDraw() = 
  cls()

  block grass:
    setColor(21)
    rectfill(-150, -150, 512*3, 700)
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

  block gameItems:
    setSpritesheet(1)
    for itm in gs.currentRecipe:
      if itm.found:
        continue
      itm.position = itm.house.position + ivec2(8, 48)
      let x = itm.position.x
      let y = itm.position.y
      let s = itm.style.ord
      spr(s, x, y)
  
  block road:
    setSpritesheet(2)
    case gs.currentStage:
    of s0:
      spr(0, 0, 128)
    of s1:
      spr(1, 0, 128)      
    of s2:
      spr(2, 0, 128)
    of s3:
      spr(3, 0, 128)
    of s4:
      spr(4, 0, 128)
    of s5:
      spr(5, 0, 128)
    of s6:
      spr(6, 0, 128)

  block clownTrap:
    setSpritesheet(1)
    spr(gs.clownTrap.style.ord, gs.clownTrap.position.x, gs.clownTrap.position.y)

  
  gs.player.draw()
  # box(gs.player.position.x + gs.player.hitbox.x, gs.player.position.y + gs.player.hitbox.y, gs.player.hitbox.w, gs.player.hitbox.y)

  block fovLayer:
    setSpritesheet(3)
    var fov = gs.player.position
    if gs.player.lastDirectionVec.y == 1:
      fov.x += 7
      fov.y += 14
      sprRot(0, fov.x, fov.y, degToRad(180.0))
    elif gs.player.lastDirectionVec.y == -1:
      fov = gs.cam.ivec2 + ivec2(-18, -64)
      # fov.x += 10     
      spr(0, fov.x, fov.y)
    elif gs.player.lastDirectionVec.x == -1:
      fov.x += 5
      fov.y += 10
      sprRot(0, fov.x, fov.y, degToRad(270.0))
    elif gs.player.lastDirectionVec.x == 1:
      fov.x += 10
      fov.y += 10
      sprRot(0, fov.x, fov.y, degToRad(90.0))

  if gs.state == gsWaiting:
    setSpritesheet(5)
    spr(0, gs.cam.x, gs.cam.y)
    setColor(12)
    return

  elif gs.state == gsEnding:
    setSpritesheet(6)
    spr(0, gs.cam.x, gs.cam.y)
    return

  elif gs.state == gsCredits:
    setSpritesheet(7)
    spr(0, gs.cam.x, gs.cam.y)
    return

nico.init("We Jammin'", "Devil's Night")
nico.createWindow("Devil's Night", mapSize.x, mapSize.y, 6)

loadFont(0, "font.png")
setFont(0)
fixedSize(true)
integerScale(true)

nico.run(gameInit, gameUpdate, gameDraw)

