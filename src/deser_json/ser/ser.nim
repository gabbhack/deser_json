import std/[
  options
]
import
  deser,
  formatter


type
  JsonSerializer*[F] = object
    writer*: string
    formatter*: F
  
  State* = enum
    Empty,
    First,
    Rest

  Compound*[F] = object
    ser*: ptr JsonSerializer[F]
    state*: State

  # Aliases
  SerializeArray[F] = Compound[F]
  SerializeSeq[F] = Compound[F]
  SerializeMap[F] = Compound[F]
  SerializeStruct[F] = Compound[F]

# Serializer impl
when defined(release):
  {.push inline.}
# Utils
proc initJsonSerializer*[F](formatter: F): JsonSerializer[F] =
  result = JsonSerializer[F](writer: newStringOfCap(64), formatter: formatter)

proc initCompound*[F](ser: var JsonSerializer[F], state: State): Compound[F] =
  result = Compound[F](ser: ser.addr, state: state)

implSerializer(JsonSerializer, public=true)

# Implementation
proc serializeBool(self: var JsonSerializer, value: bool) =
  self.formatter.writeBool(self.writer, value)

proc serializeInt8*(self: var JsonSerializer, value: int8) =
  self.formatter.writeInt(self.writer, value)

proc serializeInt16*(self: var JsonSerializer, value: int16) =
  self.formatter.writeInt(self.writer, value)

proc serializeInt32*(self: var JsonSerializer, value: int32) =
  self.formatter.writeInt(self.writer, value)

proc serializeInt64*(self: var JsonSerializer, value: int64) =
  self.formatter.writeInt(self.writer, value)

proc serializeUint8*(self: var JsonSerializer, value: uint8) =
  self.formatter.writeInt(self.writer, value)

proc serializeUint16*(self: var JsonSerializer, value: uint16) =
  self.formatter.writeInt(self.writer, value)

proc serializeUint32*(self: var JsonSerializer, value: uint32) =
  self.formatter.writeInt(self.writer, value)

proc serializeUint64*(self: var JsonSerializer, value: uint64) =
  self.formatter.writeInt(self.writer, value)

proc serializeFloat32*(self: var JsonSerializer, value: float32) =
  self.formatter.writeFloat(self.writer, value)

proc serializeFloat64*(self: var JsonSerializer, value: float64) =
  self.formatter.writeFloat(self.writer, value)

proc serializeString*(self: var JsonSerializer, value: openArray[char]) =
  formatEscapedStr(self.writer, self.formatter, value)

proc serializeChar(self: var JsonSerializer, value: char) =
  self.serializeString($value)

proc serializeBytes*(self: var JsonSerializer, value: openArray[byte]) =
  var state = self.serializeSeq(some value.len)
  for b in value:
    state.serializeSeqElement(b)
  state.endSeq()

proc serializeNone*(self: var JsonSerializer) =
  self.formatter.writeNull(self.writer)

proc serializeSome*(self: var JsonSerializer, value: auto)=
  mixin serialize

  value.serialize(self)

proc serializeEnum*(self: var JsonSerializer, value: enum) =
  self.serializeString($value)

proc serializeSeq*[F](self: var JsonSerializer[F], len: Option[int]): SerializeSeq[F] =
  self.formatter.beginArray(self.writer)
  if len.isSome and len.unsafeGet == 0:
    self.formatter.endArray(self.writer)
    result = initCompound[F](self, State.Empty)
  else:
    result = initCompound[F](self, State.First)

proc serializeArray*[F](self: var JsonSerializer[F], len: static[int]): SerializeArray[F] =
  result = serializeSeq[F](self, some len)

proc serializeMap*[F](self: var JsonSerializer[F], len: Option[int]): SerializeMap[F] =
  self.formatter.beginObject(self.writer)
  if len.isSome and len.unsafeGet == 0:
    self.formatter.endObject(self.writer)
    result = initCompound[F](self, State.Empty)
  else:
    result = initCompound[F](self, State.First)

proc serializeStruct*[F](self: var JsonSerializer[F], name: static[string]): SerializeStruct[F] =
  result = serializeMap[F](self, none int)

# SerializeArray impl
implSerializeArray(SerializeArray, public=true)

proc serializeArrayElement*(self: var SerializeArray, value: auto) =
  self.serializeSeqElement(value)

proc endArray*(self: var SerializeArray) =
  self.endSeq()

# SerializeSeq impl
implSerializeSeq(SerializeSeq, public=true)

proc serializeSeqElement*(self: var SerializeSeq, value: auto) =
  mixin serialize

  self.ser[].formatter.beginArrayValue(self.ser[].writer, self.state == State.First)

  self.state = State.Rest
  value.serialize(self.ser[])
  self.ser[].formatter.endArrayValue(self.ser[].writer)

  
proc endSeq*(self: var SerializeSeq) =
  if self.state != State.Empty:
    self.ser[].formatter.endArray(self.ser[].writer)

# SerializeMap impl
implSerializeMap(SerializeMap, public=true)

proc serializeMapKey*(self: var SerializeMap, key: auto) =
  mixin serialize

  when key isnot string:
    {.error: "Key must be string not " & $type(key).}
  else:
    self.ser[].formatter.beginObjectKey(self.ser[].writer, self.state == State.First)
    self.state = State.Rest

    key.serialize(self.ser[])

    self.ser[].formatter.endObjectKey(self.ser[].writer)

proc serializeMapValue*(self: var SerializeMap, value: auto) =
  mixin serialize

  self.ser[].formatter.beginObjectValue(self.ser[].writer)
  value.serialize(self.ser[])
  self.ser[].formatter.endObjectValue(self.ser[].writer)

proc endMap*(self: var SerializeMap) =
  if self.state != State.Empty:
    self.ser[].formatter.endObject(self.ser[].writer)

# SerializeStruct impl
implSerializeStruct(SerializeStruct, public=true)

proc serializeStructField*(self: var SerializeStruct, key: static[string], value: auto) =
  self.serializeMapEntry(key, value)

proc endStruct*(self: var SerializeStruct) =
  self.endMap()
when defined(release):
  {.pop.}