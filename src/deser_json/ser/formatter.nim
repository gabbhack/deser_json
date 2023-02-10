import std/[
  enumerate
]


type
  CompactFormatter* = object  ## This structure compacts a JSON value with no extra whitespace.
  
  PrettyFormatter*[Size] = object  ## This structure pretty prints a JSON value to make it human readable.
    currentIndex: uint
    hasValue: bool
    indent: array[Size, char]
  
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
      character: char
    else:
      discard


const
  BB = 'b' # \x08
  TT = 't' # \x09
  NN = 'n' # \x0A
  FF = 'f' # \x0C
  RR = 'r' # \x0D
  QU = '"' # \x22
  BS = '\\' # \x5C
  UU = 'u' # \x00...\x1F except the ones above
  ZZ = 0.char

# Lookup table of escape sequences. A value of b'x' at index i means that byte
# i is escaped as "\x" in JSON. A value of 0 means that byte i is not escaped.
  ESCAPE = [
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

when defined(release):
  {.push inline.}

proc add(str: var string, slice: openArray[char]) =
  for i in slice:
    str.add i

proc initCompactFormatter*(): CompactFormatter = CompactFormatter()

proc initPrettyFormatter*[Size](indent: array[Size, char]): PrettyFormatter[Size] =
  result = PrettyFormatter[Size](currentIndex: 0, hasValue: false, indent: indent)

proc fromEscapeTable*(self: typedesc[CharEscape], escape: char, b: char): CharEscape =
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

proc formatEscapedStrContents*(writer: var string, formatter: var auto, v: openArray[char]) =  
  var start = 0

  for i, b in enumerate(v):
    let escape = ESCAPE[b.int]
    if escape != 0.char:
      if start < i:
        formatter.writeStringFragment(writer, v[start..<i])
      
      let charEscape = CharEscape.fromEscapeTable(escape, b)
      formatter.writeCharEscape(writer, charEscape)

      start = i + 1

  if start != v.len:
    formatter.writeStringFragment(writer, v[start..v.high])

proc formatEscapedStr*(writer: var string, formatter: var auto, v: openArray[char]) =
  formatter.beginString(writer)
  formatEscapedStrContents(writer, formatter, v)
  formatter.endString(writer)

# CompactFormatter
proc writeNull*(self: var (CompactFormatter | PrettyFormatter), writer: var string) =
  writer.add "null"

proc writeBool*(self: var (CompactFormatter | PrettyFormatter), writer: var string, v: bool) =
  writer.add $v

const lookup = block:
  ## Generate 00, 01, 02 ... 99 pairs.
  var s = ""
  for i in 0 ..< 100:
    if ($i).len == 1:
      s.add("0")
    s.add($i)
  s

proc writeInt(self: var (CompactFormatter | PrettyFormatter), writer: var string, v: SomeUnsignedInt) =
  if v == 0:
    writer.add '0'
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
    writer.add digits[p]
    dec p

proc writeInt(self: var (CompactFormatter | PrettyFormatter), writer: var string, v: SomeSignedInt) =
  if v < 0:
    writer.add '-'
    self.writeInt(writer, 0.uint64 - v.uint64)
  else:
    self.writeInt(writer, v.uint64)

proc writeInt*(self: var (CompactFormatter | PrettyFormatter), writer: var string, v: SomeInteger) =
  self.writeInt(writer, v)

proc writeFloat*(self: var (CompactFormatter | PrettyFormatter), writer: var string, v: SomeFloat) =
  writer.add $v

proc beginString*(self: var (CompactFormatter | PrettyFormatter), writer: var string) =
  writer.add "\""

proc endString*(self: var (CompactFormatter | PrettyFormatter), writer: var string) =
  writer.add "\""

proc writeStringFragment*(self: var (CompactFormatter | PrettyFormatter), writer: var string, fragment: openArray[char]) =
  writer.add fragment

proc writeCharEscape*(self: var (CompactFormatter | PrettyFormatter), writer: var string, charEscape: CharEscape) =
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
      const HEX_DIGITS = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f']
      let chars = [
        '\\',
        'u',
        '0',
        '0',
        HEX_DIGITS[charEscape.character.byte shr 4],
        HEX_DIGITS[charEscape.character.byte and 0xF]
      ]
      for i in chars:
        writer.add i
      return
  
  writer.add str

proc beginArray*(self: var CompactFormatter, writer: var string) =
  writer.add '['

proc endArray*(self: var CompactFormatter, writer: var string)  =
  writer.add ']'

proc beginArrayValue*(self: var CompactFormatter, writer: var string, first: bool) =
  if not first:
    writer.add ','

proc endArrayValue*(self: var CompactFormatter, writer: var string) =
  discard

proc beginObject*(self: var CompactFormatter, writer: var string) =
  writer.add '{'

proc endObject*(self: var CompactFormatter, writer: var string) =
  writer.add '}'

proc beginObjectKey*(self: var CompactFormatter, writer: var string, first: bool) =
  if not first:
    writer.add ','

proc endObjectKey*(self: var CompactFormatter, writer: var string) =
  discard

proc beginObjectValue*(self: var CompactFormatter, writer: var string) =
  writer.add ':'

proc endObjectValue*(self: var CompactFormatter, writer: var string) =
  discard

proc writeRawFragment*(self: var CompactFormatter, writer: var string, fragment: openArray[char]) =
  writer.add fragment

# PrettyFormatter
proc indent(writer: var string, n: uint, s: openArray[char]) =
  for _ in 0..<n:
    for i in s:
      writer.add i

proc beginArray*(self: var PrettyFormatter, writer: var string) =
  inc self.currentIndex
  self.hasValue = false
  writer.add '['

proc endArray*(self: var PrettyFormatter, writer: var string) =
  dec self.currentIndex

  if self.hasValue:
    writer.add '\n'
    indent(writer, self.currentIndex, self.indent)
  
  writer.add ']'

proc beginArrayValue*(self: var PrettyFormatter, writer: var string, first: bool) =
  if first:
    writer.add '\n'
  else:
    writer.add ",\n"
  
  indent(writer, self.currentIndex, self.indent)

proc endArrayValue*(self: var PrettyFormatter, writer: var string) =
  self.hasValue = true

proc beginObject*(self: var PrettyFormatter, writer: var string) =
  inc self.currentIndex
  self.hasValue = false
  writer.add '{'

proc endObject*(self: var PrettyFormatter, writer: var string) =
  dec self.currentIndex

  if self.hasValue:
    writer.add '\n'
    indent(writer, self.currentIndex, self.indent)

  writer.add '}'

proc beginObjectKey*(self: var PrettyFormatter, writer: var string, first: bool) =
  if first:
    writer.add '\n'
  else:
    writer.add ",\n"
  indent(writer, self.currentIndex, self.indent)

proc endObjectKey*(self: var PrettyFormatter, writer: var string) =
  discard

proc beginObjectValue*(self: var PrettyFormatter, writer: var string) =
  writer.add ": "

proc endObjectValue*(self: var PrettyFormatter, writer: var string) =
  self.hasValue = true

proc writeRawFragment*(self: var PrettyFormatter, writer: var string, fragment: openArray[char])=
  writer.add fragment

when defined(release):
  {.pop.}
