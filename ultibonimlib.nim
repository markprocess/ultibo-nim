
import volatile

type
  RingBufferOfInt = object
    address: int
    powerOfTwoLimit: int
    readCounter: int
    writeCounter: int

proc addrOfInt(buff: ptr RingBufferOfInt, index:int):ptr int =
  cast[ptr int](buff.address + sizeof(int)*(index and (buff.powerOfTwoLimit - 1)))

proc put(buff: ptr RingBufferOfInt, x: int) =
  addrOfInt(buff, buff.writeCounter)[] = x
  inc buff.writeCounter

proc get(buff: ptr RingBufferOfInt, x: var int): bool =
  var writeCounterSample = volatileLoad(addr(buff.writeCounter))
  if buff.readCounter != writeCounterSample:
    x = addrOfInt(buff, buff.readCounter)[]
    inc buff.readCounter
    result = true
  else:
    result = false

proc nimBlinkLoop(clock: ptr RingBufferOfInt, led: ptr RingBufferOfInt) {.exportc.} =
  var state = 0
  var now = 0
  while true:
    if clock.get(now):
      let newState = if now mod 1000 < 100: 1 else: 0
      if state != newState:
        led.put state
        state = newState
