import std/[enumerate]
import faststreams/[outputs, multisync]

type
  Formatter* = concept ##[
This concept abstracts away serializing the JSON control characters, which allows the user to
optionally pretty print the JSON output.
  ]##
    proc writeNull(self: var Self, writer: OutputStream)  ## Writes a `null` value to the specified writer.
    proc writeBool(self: var Self, writer: OutputStream, v: bool)  ## Writes a `true` or `false` value to the specified writer.
    proc writeInt(self: var Self, writer: OutputStream, v: SomeInteger)  ## Writes an integer value like `-123` to the specified writer.
    proc writeFloat(self: var Self, writer: OutputStream, v: SomeFloat)  ## Writes a floating point value like `-31.26e+12` to the specified writer.
    proc beginString(self: var Self, writer: OutputStream)  ## Called before each series of `write_string_fragment` and `write_char_escape`.  Writes a `"` to the specified writer.
    proc endString(self: var Self, writer: OutputStream)  ## Called after each series of `write_string_fragment` and`write_char_escape`.  Writes a `"` to the specified writer.
    proc writeStringFragment(self: var Self, writer: OutputStream, fragment: string)  ## Writes a string fragment that doesn't need any escaping to the specified writer.
    proc writeCharEscape(self: var Self, writer: OutputStream, charEscape: CharEscape)  ## Writes a character escape code to the specified writer.
    proc beginArray(self: var Self, writer: OutputStream)  ## Called before every array.  Writes a `[` to the specified writer.
    proc endArray(self: var Self, writer: OutputStream)  ## Called after every array.  Writes a `]` to the specified writer.
    proc beginArrayValue(self: var Self, writer: OutputStream, first: bool)  ## Called before every array value.  Writes a `,` if needed to the specified writer.
    proc endArrayValue(self: var Self, writer: OutputStream)  ## Called after every array value.
    proc beginObject(self: var Self, writer: OutputStream)  ## Called before every object.  Writes a `{` to the specified writer.
    proc endObject(self: var Self, writer: OutputStream)  ## Called after every object.  Writes a `}` to the specified writer.
    proc beginObjectKey(self: var Self, writer: OutputStream, first: bool)  ## Called before every object key.
    proc endObjectKey(self: var Self, writer: OutputStream)  ## Called after every object key.  A `:` should be written to the specified writer by either this method or `begin_object_value`.
    proc beginObjectValue(self: var Self, writer: OutputStream)  ## Called before every object value.  A `:` should be written to the specified writer by either this method or `end_object_key`.
    proc endObjectValue(self: var Self, writer: OutputStream)  ## Called after every object value.
    proc writeRawFragment(self: var Self, writer: OutputStream, fragment: string)  ## Writes a raw JSON fragment that doesn't need any escaping to the specified writer.

  CompactFormatter* = object  ## This structure compacts a JSON value with no extra whitespace.
  
  PrettyFormatter* = object  ## This structure pretty prints a JSON value to make it human readable.
    currentIndex: uint
    hasValue: bool
    indent: seq[byte]
  
  CharEscapeKind = enum
    ## An escaped quote `"`
    Quote,
    ## An escaped reverse solidus `\`
    ReverseSolidus,
    ## An escaped solidus `/`
    Solidus,
    ## An escaped backspace character (usually escaped as `\b`)
    Backspace,
    ## An escaped form feed character (usually escaped as `\f`)
    FormFeed,
    ## An escaped line feed character (usually escaped as `\n`)
    LineFeed,
    ## An escaped carriage return character (usually escaped as `\r`)
    CarriageReturn,
    ## An escaped tab character (usually escaped as `\t`)
    Tab,
    ## An escaped ASCII plane control character (usually escaped as
    ## `\u00XX` where `XX` are two hex characters)
    AsciiControl

  CharEscape = object  ## Represents a character escape code in a type-safe manner.
    case kind: CharEscapeKind
    of CharEscapeKind.AsciiControl:
      character: byte
    else:
      discard

template asBytes*(str: string): openArray[byte] =
  str.toOpenArrayByte(0, str.high)

const BB = 'b'.byte # \x08
const TT = 't'.byte # \x09
const NN = 'n'.byte # \x0A
const FF = 'f'.byte # \x0C
const RR = 'r'.byte # \x0D
const QU = '"'.byte # \x22
const BS = '\\'.byte # \x5C
const UU = 'u'.byte # \x00...\x1F except the ones above
const ZZ = 0.byte

# Lookup table of escape sequences. A value of b'x' at index i means that byte
# i is escaped as "\x" in JSON. A value of 0 means that byte i is not escaped.
const ESCAPE: array[256, byte] = [
    #   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    UU, UU, UU, UU, UU, UU, UU, UU, BB, TT, NN, UU, FF, RR, UU, UU, # 0
    UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, # 1
    ZZ, ZZ, QU, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # 2
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # 3
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # 4
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, BS, ZZ, ZZ, ZZ, # 5
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # 6
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # 7
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # 8
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # 9
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # A
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # B
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # C
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # D
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # E
    ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, ZZ, # F
]

{.push inline.}
proc initCompactFormatter*(): CompactFormatter = CompactFormatter()

proc initPrettyFormatter*(indent: openArray[byte]): PrettyFormatter =
  result = PrettyFormatter(currentIndex: 0, hasValue: false, indent: @indent)

proc fromEscapeTable*(self: typedesc[CharEscape], escape: byte, b: byte): CharEscape =
  case escape
  of BB:
    CharEscape(kind: CharEscapeKind.Backspace)
  of TT:
    CharEscape(kind: CharEscapeKind.Tab)
  of NN:
    CharEscape(kind: CharEscapeKind.LineFeed)
  of FF:
    CharEscape(kind: CharEscapeKind.FormFeed)
  of RR:
    CharEscape(kind: CharEscapeKind.CarriageReturn)
  of QU:
    CharEscape(kind: CharEscapeKind.Quote)
  of BS:
    CharEscape(kind: CharEscapeKind.ReverseSolidus)
  of UU:
    CharEscape(kind: CharEscapeKind.AsciiControl, character: b)
  else:
    raise newException(Defect, "Unreachable")

proc formatEscapedStrContents*[F](writer: OutputStream, formatter: var F, v: string) =
  template bytes: untyped = v.asBytes
  
  var start = 0

  for i, b in enumerate(bytes):
    let escape = ESCAPE[b.int]
    if escape != 0:
      if start < i:
        formatter.writeStringFragment(writer, v[start..<i])
      
      let charEscape = CharEscape.fromEscapeTable(escape, b)
      formatter.writeCharEscape(writer, charEscape)

      start = i + 1

  if start != bytes.len:
    formatter.writeStringFragment(writer, v[start..v.high])

proc formatEscapedStr*[F](writer: OutputStream, formatter: var F, v: string) =
  formatter.beginString(writer)
  formatEscapedStrContents(writer, formatter, v)
  formatter.endString(writer)

# CompactFormatter
proc writeNull*(self: var CompactFormatter, writer: OutputStream) {.fsMultiSync.} =
  writer.write("null".asBytes)

proc writeBool*(self: var CompactFormatter, writer: OutputStream, v: bool) {.fsMultiSync.} =
  if v:
    writer.write("true".asBytes)
  else:
    writer.write("false".asBytes)

const lookup = block:
  ## Generate 00, 01, 02 ... 99 pairs.
  var s = ""
  for i in 0 ..< 100:
    if ($i).len == 1:
      s.add("0")
    s.add($i)
  s

proc writeInt(self: var CompactFormatter, writer: OutputStream, v: SomeUnsignedInt) {.fsMultiSync.} =
  if v == 0:
    writer.write '0'
    return
  # Max size of a uin64 number is 20 digits.
  var digits: array[20, char]
  var v = v
  var p = 0
  while v != 0:
    # Its faster to look up 2 digits at a time, less int divisions.
    let idx = v mod 100
    digits[p] = lookup[idx*2+1]
    inc p
    digits[p] = lookup[idx*2]
    inc p
    v = v div 100
  if digits[p-1] == '0':
    dec p
  dec p
  while p >= 0:
    writer.write digits[p]
    dec p

proc writeInt(self: var CompactFormatter, writer: OutputStream, v: SomeSignedInt) {.fsMultiSync.} =
  if v < 0:
    writer.write '-'
    self.writeInt(writer, 0.uint64 - v.uint64)
  else:
    self.writeInt(writer, v.uint64)

proc writeInt*(self: var CompactFormatter, writer: OutputStream, v: SomeInteger) {.fsMultiSync.} =
  self.writeInt(writer, v)

proc writeFloat*(self: var CompactFormatter, writer: OutputStream, v: SomeFloat) {.fsMultiSync.} =
  writer.write ($v).asBytes

proc beginString*(self: var CompactFormatter, writer: OutputStream) {.fsMultiSync.} =
  writer.write "\"".asBytes

proc endString*(self: var CompactFormatter, writer: OutputStream) {.fsMultiSync.} =
  writer.write "\"".asBytes

proc writeStringFragment*(self: var CompactFormatter, writer: OutputStream, fragment: string) {.fsMultiSync.} =
  writer.write fragment.asBytes

proc writeCharEscape*(self: var CompactFormatter, writer: OutputStream, charEscape: CharEscape) {.fsMultiSync.} =
  let str = case charEscape.kind
    of CharEscapeKind.Quote:
      "\\\""
    of CharEscapeKind.ReverseSolidus:
      "\\\\"
    of CharEscapeKind.Solidus:
      "\\/"
    of CharEscapeKind.Backspace:
      "\\b"
    of CharEscapeKind.FormFeed:
      "\\f"
    of CharEscapeKind.LineFeed:
      "\\n"
    of CharEscapeKind.CarriageReturn:
      "\\r"
    of CharEscapeKind.Tab:
      "\\t"
    of CharEscapeKind.AsciiControl:
      const HEX_DIGITS: array[16, byte] = [48.byte, 49, 50, 51, 52, 53, 54, 55, 56, 57, 97, 98, 99, 100, 101, 102]
      let bytes = [
        '\\'.byte,
        'u'.byte,
        '0'.byte,
        '0'.byte,
        HEX_DIGITS[charEscape.character shr 4],
        HEX_DIGITS[charEscape.character and 0xF]
      ]
      writer.write bytes
      return
  
  writer.write str.asBytes

proc beginArray*(self: var CompactFormatter, writer: OutputStream) {.fsMultiSync.} =
  writer.write '['.byte

proc endArray*(self: var CompactFormatter, writer: OutputStream) {.fsMultiSync.} =
  writer.write ']'.byte

proc beginArrayValue*(self: var CompactFormatter, writer: OutputStream, first: bool) {.fsMultiSync.} =
  if not first:
    writer.write ','

proc endArrayValue*(self: var CompactFormatter, writer: OutputStream) {.fsMultiSync.} =
  discard

proc beginObject*(self: var CompactFormatter, writer: OutputStream) {.fsMultiSync.} =
  writer.write '{'.byte

proc endObject*(self: var CompactFormatter, writer: OutputStream) {.fsMultiSync.} =
  writer.write '}'.byte

proc beginObjectKey*(self: var CompactFormatter, writer: OutputStream, first: bool) {.fsMultiSync.} =
  if not first:
    writer.write ','.byte

proc endObjectKey*(self: var CompactFormatter, writer: OutputStream) {.fsMultiSync.} =
  discard

proc beginObjectValue*(self: var CompactFormatter, writer: OutputStream) {.fsMultiSync.} =
  writer.write ':'.byte

proc endObjectValue*(self: var CompactFormatter, writer: OutputStream) {.fsMultiSync.} =
  discard

proc writeRawFragment*(self: var CompactFormatter, writer: OutputStream, fragment: string) {.fsMultiSync.} =
  writer.write fragment.asBytes

# PrettyFormatter
proc indent(writer: OutputStream, n: uint, s: openArray[byte]) =
  for _ in 0..<n:
    writer.write s

proc writeNull*(self: var PrettyFormatter, writer: OutputStream) {.fsMultiSync.} =
  writer.write("null".asBytes)

proc writeBool*(self: var PrettyFormatter, writer: OutputStream, v: bool) {.fsMultiSync.} =
  if v:
    writer.write("true".asBytes)
  else:
    writer.write("false".asBytes)

proc writeInt(self: var PrettyFormatter, writer: OutputStream, v: SomeUnsignedInt) {.fsMultiSync.} =
  if v == 0:
    writer.write '0'
    return
  # Max size of a uin64 number is 20 digits.
  var digits: array[20, char]
  var v = v
  var p = 0
  while v != 0:
    # Its faster to look up 2 digits at a time, less int divisions.
    let idx = v mod 100
    digits[p] = lookup[idx*2+1]
    inc p
    digits[p] = lookup[idx*2]
    inc p
    v = v div 100
  if digits[p-1] == '0':
    dec p
  dec p
  while p >= 0:
    writer.write digits[p]
    dec p

proc writeInt(self: var PrettyFormatter, writer: OutputStream, v: SomeSignedInt) {.fsMultiSync.} =
  if v < 0:
    writer.write '-'
    self.writeInt(writer, 0.uint64 - v.uint64)
  else:
    self.writeInt(writer, v.uint64)

proc writeInt*(self: var PrettyFormatter, writer: OutputStream, v: SomeInteger) {.fsMultiSync.} =
  self.writeInt(writer, v)

proc writeFloat*(self: var PrettyFormatter, writer: OutputStream, v: SomeFloat) {.fsMultiSync.} =
  writer.write ($v).asBytes

proc beginString*(self: var PrettyFormatter, writer: OutputStream) {.fsMultiSync.} =
  writer.write "\"".asBytes

proc endString*(self: var PrettyFormatter, writer: OutputStream) {.fsMultiSync.} =
  writer.write "\"".asBytes

proc writeCharEscape*(self: var PrettyFormatter, writer: OutputStream, charEscape: CharEscape) {.fsMultiSync.} =
  let str = case charEscape.kind
    of CharEscapeKind.Quote:
      "\\\""
    of CharEscapeKind.ReverseSolidus:
      "\\\\"
    of CharEscapeKind.Solidus:
      "\\/"
    of CharEscapeKind.Backspace:
      "\\b"
    of CharEscapeKind.FormFeed:
      "\\f"
    of CharEscapeKind.LineFeed:
      "\\n"
    of CharEscapeKind.CarriageReturn:
      "\\r"
    of CharEscapeKind.Tab:
      "\\t"
    of CharEscapeKind.AsciiControl:
      const HEX_DIGITS: array[16, byte] = [48.byte, 49, 50, 51, 52, 53, 54, 55, 56, 57, 97, 98, 99, 100, 101, 102]
      let bytes = [
        '\\'.byte,
        'u'.byte,
        '0'.byte,
        '0'.byte,
        HEX_DIGITS[charEscape.character shr 4],
        HEX_DIGITS[charEscape.character and 0xF]
      ]
      writer.write bytes
      return
  
  writer.write str.asBytes

proc writeStringFragment*(self: var PrettyFormatter, writer: OutputStream, fragment: string) {.fsMultiSync.} =
  writer.write fragment.asBytes

proc beginArray*(self: var PrettyFormatter, writer: OutputStream) {.fsMultiSync.} =
  inc self.currentIndex
  self.hasValue = false
  writer.write '['.byte

proc endArray*(self: var PrettyFormatter, writer: OutputStream) {.fsMultiSync.} =
  dec self.currentIndex

  if self.hasValue:
    writer.write '\n'.byte
    indent(writer, self.currentIndex, self.indent)
  
  writer.write ']'.byte

proc beginArrayValue*(self: var PrettyFormatter, writer: OutputStream, first: bool) {.fsMultiSync.} =
  if first:
    writer.write '\n'.byte
  else:
    writer.write ",\n".asBytes
  
  indent(writer, self.currentIndex, self.indent)

proc endArrayValue*(self: var PrettyFormatter, writer: OutputStream) {.fsMultiSync.} =
  self.hasValue = true

proc beginObject*(self: var PrettyFormatter, writer: OutputStream) {.fsMultiSync.} =
  inc self.currentIndex
  self.hasValue = false
  writer.write '{'.byte

proc endObject*(self: var PrettyFormatter, writer: OutputStream) {.fsMultiSync.} =
  dec self.currentIndex

  if self.hasValue:
    writer.write '\n'.byte
    indent(writer, self.currentIndex, self.indent)

  writer.write '}'.byte

proc beginObjectKey*(self: var PrettyFormatter, writer: OutputStream, first: bool) {.fsMultiSync.} =
  if first:
    writer.write '\n'.byte
  else:
    writer.write ",\n".asBytes
  indent(writer, self.currentIndex, self.indent)

proc endObjectKey*(self: var PrettyFormatter, writer: OutputStream) {.fsMultiSync.} =
  discard

proc beginObjectValue*(self: var PrettyFormatter, writer: OutputStream) {.fsMultiSync.} =
  writer.write ": ".asBytes

proc endObjectValue*(self: var PrettyFormatter, writer: OutputStream) {.fsMultiSync.} =
  self.hasValue = true

proc writeRawFragment*(self: var PrettyFormatter, writer: OutputStream, fragment: string) {.fsMultiSync.} =
  writer.write fragment.asBytes

{.pop.}
