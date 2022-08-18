import std/[strformat, options]

import jsony
import deser/des


type
  Deserializer* = object
    source: string
    pos: int
  
  SeqAccess = object
    deserializer: ptr Deserializer
    first: bool
  
  MapAccess = object
    deserializer: ptr Deserializer
    first: bool


proc raiseError(self: Deserializer, msg: sink string) {.noinline, noreturn.} =
  raise newException(JsonError, msg & " At offset: " & $self.pos)


proc raiseUnexpectedError(self: Deserializer, expected, unexpected: sink string) =
  self.raiseError(&"Invalid value: `{unexpected}`, expected: `{expected}`.")


when defined(release):
  {.push inline, checks: off.}

implSeqAccess(SeqAccess, public=true)
implMapAccess(MapAccess, public=true)
implDeserializer(Deserializer, public=true)

template eatSpace(self: var Deserializer) =
  bind jsony.eatSpace

  jsony.eatSpace(self.source, self.pos)


template eatChar(self: var Deserializer, c: char) =
  bind eatSpace
  bind raiseUnexpectedError

  self.eatSpace()
  if self.pos >= self.source.len:
    raiseUnexpectedError(self, $c, "EOF")
  if self.source[self.pos] == c:
    inc self.pos
  else:
    raiseUnexpectedError(self, $c, $self.source[self.pos])


proc parseBool(self: var Deserializer): bool =
  parseHook(self.source, self.pos, result)


proc parseInteger(self: var Deserializer, T: typedesc[SomeInteger]): T =
  when not defined(deserJsonOverflowChecksOff):
    when T is SomeSignedInt:
      var temp: int64
    else:
      var temp: uint64

    parseHook(self.source, self.pos, temp)

    if temp in T.low..T.high:
      result = T(temp)
    else:
      self.raiseUnexpectedError($T, $temp)
  else:
    parseHook(self.source, self.pos, result)


proc parseFloat(self: var Deserializer, T: typedesc[SomeFloat]): T =
  parseHook(self.source, self.pos, result)


proc parseChar(self: var Deserializer): char =
  parseHook(self.source, self.pos, result)


proc parseString(self: var Deserializer): string =
  parseHook(self.source, self.pos, result)


proc isNull(self: var Deserializer): bool =
  self.pos + 3 < self.source.len and
    self.source[self.pos+0] == 'n' and 
    self.source[self.pos+1] == 'u' and
    self.source[self.pos+2] == 'l' and
    self.source[self.pos+3] == 'l'


func fromString*(Self: typedesc, input: sink string): Self =
  mixin deserialize

  var deserializer = Deserializer(
    source: input,
    pos: 0
  )
  
  Self.deserialize(deserializer)


proc deserializeAny*(self: var Deserializer, visitor: auto): visitor.Value =
  self.eatSpace()
  if self.pos < self.source.len:
    let ch = self.source[self.pos]
    case ch
    of '{':
      result = self.deserializeMap(visitor)
    of '[':
      result = self.deserializeSeq(visitor)
    of '"':
      result = self.deserializeString(visitor)
    of 't', 'f':
      result = self.deserializeBool(visitor)
    of 'n':
      result = self.deserializeOption(visitor)
    of '0'..'9', '+':
      result = self.deserializeInt64(visitor)
    of '-':
      result = self.deserializeUint64(visitor)
    else:
      self.raiseUnexpectedError("object, array, string, booolean or integer", $ch)
  else:
    self.raiseUnexpectedError("object, array, string, booolean or integer", "EOF")


proc deserializeBool*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitBool

  visitor.visitBool(self.parseBool())


proc deserializeInt8*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitInt8

  visitor.visitInt8(self.parseInteger(int8))


proc deserializeInt16*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitInt16

  visitor.visitInt16(self.parseInteger(int16))


proc deserializeInt32*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitInt32

  visitor.visitInt32(self.parseInteger(int32))


proc deserializeInt64*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitInt64

  visitor.visitInt64(self.parseInteger(int64))


proc deserializeUint8*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitUint8

  visitor.visitUint8(self.parseInteger(uint8))


proc deserializeUint16*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitUint16

  visitor.visitUint16(self.parseInteger(uint16))


proc deserializeUint32*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitUint32

  visitor.visitUint32(self.parseInteger(uint32))


proc deserializeUint64*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitUint64

  visitor.visitUint64(self.parseInteger(uint64))


proc deserializeFloat32*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitFloat32

  visitor.visitFloat32(self.parseFloat(float32))


proc deserializeFloat64*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitFloat64

  visitor.visitFloat64(self.parseFloat(float64))


proc deserializeChar*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitChar

  visitor.visitChar(self.parseChar())


proc deserializeString*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitString

  visitor.visitString(self.parseString())


proc deserializeBytes*(self: var Deserializer, visitor: auto): visitor.Value =
  self.deserializeSeq(visitor)


proc deserializeOption*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitNone, visitSome

  if self.isNull:
    self.pos += 4
    visitor.visitNone
  else:
    visitor.visitSome(self)


proc deserializeSeq*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitSeq

  self.eatChar('[')
  var sequence = SeqAccess(deserializer: self.addr, first: true)
  result = visitor.visitSeq(sequence)
  self.eatChar(']')


proc deserializeMap*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin visitMap

  self.eatChar('{')
  var map = MapAccess(deserializer: self.addr, first: true)
  result = visitor.visitMap(map)
  self.eatChar('}')


proc deserializeStruct*(self: var Deserializer, name: static[string], fields: static[array], visitor: auto): visitor.Value =
  self.deserializeMap(visitor)


proc deserializeIdentifier*(self: var Deserializer, visitor: auto): visitor.Value =
  self.deserializeString(visitor)


proc deserializeEnum*(self: var Deserializer, visitor: auto): visitor.Value =
  self.deserializeString(visitor)


proc deserializeIgnoredAny*(self: var Deserializer, visitor: auto): visitor.Value =
  self.deserializeAny(visitor)


proc deserializeArray*(self: var Deserializer, len: static[int], visitor: auto): visitor.Value =
  self.deserializeSeq(visitor)


proc nextElementSeed*(self: var SeqAccess, seed: auto): Option[seed.Value] =
  mixin deserialize

  self.deserializer[].eatSpace()
  if self.deserializer[].source[self.deserializer[].pos] == ']':
    none seed.Value
  else:
    if not self.first:
      self.deserializer[].eatChar(',')
  
    self.first = false

    some seed.deserialize(self.deserializer[])


proc nextKeySeed*(self: var MapAccess, seed: auto): Option[seed.Value] =
  mixin deserialize

  self.deserializer[].eatSpace()
  if self.deserializer[].source[self.deserializer[].pos] == '}':
    none seed.Value
  else:
    if not self.first:
      self.deserializer[].eatChar(',')

    self.first = false

    some seed.deserialize(self.deserializer[])


proc nextValueSeed*(self: var MapAccess, seed: auto): seed.Value =
  mixin deserialize

  self.deserializer[].eatChar(':')
  seed.deserialize(self.deserializer[])


when defined(release):
  {.pop.}
