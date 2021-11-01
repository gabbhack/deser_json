import std/[options]
import faststreams/[outputs]
import deser

import formatter

type
  JsonSerializer*[F: Formatter] = object
    writer: OutputStream
    formatter: F
  
  State* = enum
    Empty,
    First,
    Rest

  Compound*[F] = object
    ser*: ptr JsonSerializer[F]
    state*: State
  
  MapKeySerializer*[F] = object
    ser*: ptr JsonSerializer[F]

  # Aliases
  SerializeArray[F] = Compound[F]
  SerializeSeq[F] = Compound[F]
  SerializeTuple[F] = Compound[F]
  SerializeNamedTuple[F] = Compound[F]
  SerializeMap[F] = Compound[F]
  SerializeStruct[F] = Compound[F]
  SerializeSeqMap[F] = Compound[F]

# Serializer impl
{.push inline.}
# Utils
proc initJsonSerializer*[F](writer: OutputStream, formatter: F): JsonSerializer[F] =
  result = JsonSerializer[F](writer: writer, formatter: formatter)

proc initCompound*[F](ser: var JsonSerializer[F], state: State): Compound[F] =
  result = Compound[F](ser: ser.addr, state: state)

# Forward declaration
# Array
proc serializeArray*[F](self: var JsonSerializer[F], len: static[int]): SerializeArray[F]
proc serializeArrayElement*[F; T](self: var SerializeArray[F], v: T)
proc endArray*[F](self: var SerializeArray[F])
# Seq
proc serializeSeq*[F](self: var JsonSerializer[F], len: Option[int]): SerializeSeq[F]
proc serializeSeqElement*[F; T](self: var SerializeSeq[F], v: T)
proc endSeq*[F](self: var SerializeSeq[F])
# Tuple
proc serializeTuple*[F](self: var JsonSerializer[F], name: static[string], len: static[int]): SerializeTuple[F]
proc serializeTupleElement*[F; T](self: var SerializeTuple[F], v: T)
proc endTuple*[F](self: var SerializeTuple[F])
# NamedTuple
proc serializeNamedTuple*[F](self: var JsonSerializer[F], name: static[string], len: static[int]): SerializeNamedTuple[F]
proc serializeNamedTupleField*[F; T](self: var SerializeNamedTuple[F], key: static[string], v: T)
proc endNamedTuple*[F](self: var SerializeNamedTuple[F])
# SerializeMap
proc serializeMap*[F](self: var JsonSerializer[F], len: Option[int]): SerializeMap[F]
proc serializeMapKey*[F; T](self: var SerializeMap[F], key: T)
proc serializeMapValue*[F; T](self: var SerializeMap[F], v: T)
proc endMap*[F](self: var SerializeMap[F])
# SerializeStruct
proc serializeStruct*[F](self: var JsonSerializer[F], name: static[string]): SerializeStruct[F]
proc serializeStructField*[F; T](self: var SerializeStruct[F], key: static[string], v: T)
proc endStruct*[F](self: var SerializeStruct[F])
# SerializeSeqMap
proc serializeSeqMap*[F](self: var JsonSerializer[F], len: Option[int]): SerializeSeqMap[F]
proc serializeSeqMapKey*[F; T](self: var SerializeSeqMap[F], key: T)
proc serializeSeqMapValue*[F; T](self: var SerializeSeqMap[F], v: T)
proc endSeqMap*[F](self: var SerializeSeqMap[F])

# Implementation
proc serializeBool*[F](self: var JsonSerializer[F], v: bool) =
  self.formatter.writeBool(self.writer, v)

proc serializeInt*[F](self: var JsonSerializer[F], v: SomeInteger) =
  self.formatter.writeInt(self.writer, v)

proc serializeFloat*[F](self: var JsonSerializer[F], v: SomeFloat) =
  self.formatter.writeFloat(self.writer, v)

proc serializeString*[F](self: var JsonSerializer[F], v: string) =
  formatEscapedStr(self.writer, self.formatter, v)

proc serializeChar*[F](self: var JsonSerializer[F], v: char) =
  self.serializeString($v)

proc serializeBytes*[F](self: var JsonSerializer[F], v: openArray[byte]) =
  var state = self.serializeSeq(some v.len)
  for b in v:
    state.serializeSeqElement(b)
  state.endSeq()

proc serializeNone*[F](self: var JsonSerializer[F]) =
  self.formatter.writeNull(self.writer)

proc serializeSome*[F; T](self: var JsonSerializer[F], v: T) =
  v.serialize(self)

proc serializeUnitStruct*[F](self: var JsonSerializer[F], name: static[string]) =
  self.serializeNone()

proc serializeUnitTuple*[F](self: var JsonSerializer[F], name: static[string]) =
  self.serializeNone()

proc serializeArray*[F](self: var JsonSerializer[F], len: static[int]): SerializeArray[F] =
  result = serializeSeq[F](self, some len)

proc serializeSeq*[F](self: var JsonSerializer[F], len: Option[int]): SerializeSeq[F] =
  self.formatter.beginArray(self.writer)
  if len.isSome and len.unsafeGet == 0:
    self.formatter.endArray(self.writer)
    result = initCompound[F](self, State.Empty)
  else:
    result = initCompound[F](self, State.First)

proc serializeTuple*[F](self: var JsonSerializer[F], name: static[string], len: static[int]): SerializeTuple[F] =
  result = serializeSeq[F](self, some len)

proc serializeNamedTuple*[F](self: var JsonSerializer[F], name: static[string], len: static[int]): SerializeNamedTuple[F] =
  result = serializeMap[F](self, some len)

proc serializeMap*[F](self: var JsonSerializer[F], len: Option[int]): SerializeMap[F] =
  self.formatter.beginObject(self.writer)
  if len.isSome and len.unsafeGet == 0:
    self.formatter.endObject(self.writer)
    result = initCompound[F](self, State.Empty)
  else:
    result = initCompound[F](self, State.First)

proc serializeStruct*[F](self: var JsonSerializer[F], name: static[string]): SerializeStruct[F] =
  result = serializeMap[F](self, none int)

proc serializeSeqMap*[F](self: var JsonSerializer[F], len: Option[int]): SerializeSeqMap[F] =
  result = serializeMap[F](self, len)

# SerializeArray impl
proc serializeArrayElement*[F; T](self: var SerializeArray[F], v: T) =
  self.serializeSeqElement(v)

proc endArray*[F](self: var SerializeArray[F]) =
  self.endSeq()

# SerializeSeq impl
proc serializeSeqElement*[F; T](self: var SerializeSeq[F], v: T) =
  self.ser[].formatter.beginArrayValue(self.ser[].writer, self.state == State.First)

  self.state = State.Rest
  v.serialize(self.ser[])
  self.ser[].formatter.endArrayValue(self.ser[].writer)

  
proc endSeq*[F](self: var SerializeSeq[F]) =
  if self.state != State.Empty:
    self.ser[].formatter.endArray(self.ser[].writer)

# SerializeTuple impl
proc serializeTupleElement*[F; T](self: var SerializeTuple[F], v: T) =
  self.serializeSeqElement(v)

proc endTuple*[F](self: var SerializeTuple[F]) =
  self.endSeq()

# SerializeNamedTuple impl
proc serializeNamedTupleField*[F; T](self: var SerializeNamedTuple[F], key: static[string], v: T) =
  self.serializeMapEntry(key, v)

proc endNamedTuple*[F](self: var SerializeNamedTuple[F]) =
  self.endMap()

# SerializeMap impl
proc serializeMapKey*[F; T](self: var SerializeMap[F], key: T) =
  when T is string:
    self.ser[].formatter.beginObjectKey(self.ser[].writer, self.state == State.First)
    self.state = State.Rest

    key.serialize(self.ser[])

    self.ser[].formatter.endObjectKey(self.ser[].writer)
  else:
    {.error: "Map key must be a string".}

proc serializeMapValue*[F; T](self: var SerializeMap[F], v: T) =
  self.ser[].formatter.beginObjectValue(self.ser[].writer)
  v.serialize(self.ser[])
  self.ser[].formatter.endObjectValue(self.ser[].writer)

proc endMap*[F](self: var SerializeMap[F]) =
  if self.state != State.Empty:
    self.ser[].formatter.endObject(self.ser[].writer)

# SerializeStruct impl
proc serializeStructField*[F; T](self: var SerializeStruct[F], key: static[string], v: T) =
  self.serializeMapEntry(key, v)

proc endStruct*[F](self: var SerializeStruct[F]) =
  self.endMap()

# SerializeSeqMap impl
proc serializeSeqMapKey*[F; T](self: var SerializeSeqMap[F], key: T) =
  self.serializeMapKey(key)

proc serializeSeqMapValue*[F; T](self: var SerializeSeqMap[F], v: T) =
  self.serializeMapValue(v)

proc endSeqMap*[F](self: var SerializeSeqMap[F]) =
  self.endMap()

proc toWriter*[T; F](writer: OutputStream, v: T, formatter: F) =
  var ser = initJsonSerializer[F](writer, formatter)
  v.serialize(ser)

proc toString*[T](v: T): string =
  var stream = memoryOutput()
  toWriter(stream, v, initCompactFormatter())
  result = stream.getOutput(string)

proc toPrettyString*[T](v: T): string =
  var stream = memoryOutput()
  toWriter(stream, v, initPrettyFormatter([' '.byte, ' '.byte, ' '.byte, ' '.byte]))
  result = stream.getOutput(string)
{.pop.}