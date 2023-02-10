#[
MIT

Copyright 2020 Andre von Houck

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]#
import std/[
  json, options, sets, strutils, tables, typetraits, unicode
]

from std/parseutils import nil

from deser/des/errors import
  DeserializationError

from deser_json/parseutils as local_parseutils import
  parseHexInt,
  parseInt

from deser_json/strutils as local_strutils import
  toString

type JsonError* = object of DeserializationError

const whiteSpace = {' ', '\n', '\t', '\r'}

when defined(release):
  {.push checks: off, inline.}

proc parseHook*(s: openArray[char], i: var int, v: var char)

template error(msg: string, i: int) =
  ## Shortcut to raise an exception.
  raise newException(JsonError, msg & " At offset: " & $i)

template eatSpace*(s: openArray[char], i: var int) =
  ## Will consume whitespace.
  while i < s.len:
    let c = s[i]
    if c notin whiteSpace:
      break
    inc i

template eatChar*(s: openArray[char], i: var int, c: char) =
  ## Will consume space before and then the character `c`.
  ## Will raise an exception if `c` is not found.
  eatSpace(s, i)
  if i >= s.len:
    error("Expected " & c & " but end reached.", i)
  if s[i] == c:
    inc i
  else:
    error("Expected " & c & " but got " & s[i] & " instead.", i)

proc parseSymbol*(s: openArray[char], i: var int): string =
  ## Will read a symbol and return it.
  ## Used for numbers and booleans.
  eatSpace(s, i)
  var j = i
  while i < s.len:
    case s[i]
    of ',', '}', ']', whiteSpace:
      break
    else:
      discard
    inc i
  return s.toOpenArray(j, i-1).toString()

proc parseHook*(s: openArray[char], i: var int, v: var bool) =
  ## Will parse boolean true or false.
  when nimvm:
    let symbol = parseSymbol(s, i)
    if symbol == ['t', 'r', 'u', 'e']:
      v = true
    elif symbol == ['f', 'a', 'l', 's', 'e']:
      v = false
    else:
      error("Boolean true or false expected.", i)
  else:
    # Its faster to do char by char scan:
    eatSpace(s, i)
    if i + 3 < s.len and
        s[i+0] == 't' and
        s[i+1] == 'r' and
        s[i+2] == 'u' and
        s[i+3] == 'e':
      i += 4
      v = true
    elif i + 4 < s.len and
        s[i+0] == 'f' and
        s[i+1] == 'a' and
        s[i+2] == 'l' and
        s[i+3] == 's' and
        s[i+4] == 'e':
      i += 5
      v = false
    else:
      error("Boolean true or false expected.", i)

proc parseHook*(s: openArray[char], i: var int, v: var SomeUnsignedInt) =
  ## Will parse unsigned integers.
  when nimvm:
    v = type(v)(parseInt(parseSymbol(s, i)))
  else:
    eatSpace(s, i)
    var
      v2: uint64 = 0
      startI = i
    while i < s.len and s[i] in {'0'..'9'}:
      v2 = v2 * 10 + (s[i].ord - '0'.ord).uint64
      inc i
    if startI == i:
      error("Number expected.", i)
    v = type(v)(v2)

proc parseHook*(s: openArray[char], i: var int, v: var SomeSignedInt) =
  ## Will parse signed integers.
  when nimvm:
    v = type(v)(parseInt(parseSymbol(s, i)))
  else:
    eatSpace(s, i)
    if i < s.len and s[i] == '+':
      inc i
    if i < s.len and s[i] == '-':
      var v2: uint64
      inc i
      parseHook(s, i, v2)
      v = -type(v)(v2)
    else:
      var v2: uint64
      parseHook(s, i, v2)
      try:
        v = type(v)(v2)
      except:
        error("Number type to small to contain the number.", i)

proc parseHook*(s: string, i: var int, v: var SomeFloat) =
  ## Will parse float32 and float64.
  var f: float
  eatSpace(s, i)
  let chars = parseutils.parseFloat(s, f, i)
  if chars == 0:
    error("Failed to parse a float.", i)
  i += chars
  v = f

proc parseUnicodeEscape(s: openArray[char], i: var int): int =
  inc i
  result = parseHexInt(s[i ..< i + 4])
  i += 3
  # Deal with UTF-16 surrogates. Most of the time strings are encoded as utf8
  # but some APIs will reply with UTF-16 surrogate pairs which needs to be dealt
  # with.
  if (result and 0xfc00) == 0xd800:
    inc i
    if s[i] != '\\':
      error("Found an Orphan Surrogate.", i)
    inc i
    if s[i] != 'u':
      error("Found an Orphan Surrogate.", i)
    inc i
    let nextRune = parseHexInt(s[i ..< i + 4])
    i += 3
    if (nextRune and 0xfc00) == 0xdc00:
      result = 0x10000 + (((result - 0xd800) shl 10) or (nextRune - 0xdc00))

proc parseStringSlow(s: openArray[char], i: var int, v: var string) =
  while i < s.len:
    let c = s[i]
    case c
    of '"':
      break
    of '\\':
      inc i
      let c = s[i]
      case c
      of '"', '\\', '/': v.add(c)
      of 'b': v.add '\b'
      of 'f': v.add '\f'
      of 'n': v.add '\n'
      of 'r': v.add '\r'
      of 't': v.add '\t'
      of 'u':
        v.add(Rune(parseUnicodeEscape(s, i)).toUTF8())
      else:
        v.add(c)
    else:
      v.add(c)
    inc i
  eatChar(s, i, '"')

template scanStringLen(s: openArray[char], i: var int): int =
  var
    j = i
    ll = 0
  while j < s.len:
    let c = s[j]
    case c
    of '"':
      break
    of '\\':
      inc j
      let c = s[j]
      case c
      of 'u':
        ll += Rune(parseUnicodeEscape(s, j)).toUTF8().len
      else:
        inc ll
    else:
      inc ll
    inc j
  ll

proc parseStringFast(s: openArray[char], i: var int, v: var openArray[char]) =
  # v must be initialized with the correct length
  # you can get the length with scanStringLen
  var
    at = 0
  template add(ss: var openArray[char], c: char) =
    ss[at] = c
    inc at
  while i < s.len:
    let c = s[i]
    case c
    of '"':
      break
    of '\\':
      inc i
      let c = s[i]
      case c
      of '"', '\\', '/': v.add(c)
      of 'b': v.add '\b'
      of 'f': v.add '\f'
      of 'n': v.add '\n'
      of 'r': v.add '\r'
      of 't': v.add '\t'
      of 'u':
        for c in Rune(parseUnicodeEscape(s, i)).toUTF8():
          v.add(c)
      else:
        v.add(c)
    else:
      v.add(c)
    inc i

  eatChar(s, i, '"')

proc parseHook*(s: openArray[char], i: var int, v: var string) =
  ## Parse string.
  eatSpace(s, i)
  if i + 3 < s.len and
      s[i+0] == 'n' and
      s[i+1] == 'u' and
      s[i+2] == 'l' and
      s[i+3] == 'l':
    i += 4
    return
  eatChar(s, i, '"')

  when nimvm:
    parseStringSlow(s, i, v)
  else:
    when defined(js):
      parseStringSlow(s, i, v)
    else:
      v = newString(scanStringLen(s, i))
      parseStringFast(s, i, v)

proc parseHook*(s: openArray[char], i: var int, v: var char) =
  eatChar(s, i, '"')

  let strLen = scanStringLen(s, i)

  if strLen != 1:
    error("String can't fit into a char.", i)

  when nimvm:
    var str: string
    parseStringSlow(s, i, str)
    v = str[0]
  else:
    when defined(js):
      var str: string
      parseStringSlow(s, i, str)
      v = str[0]
    else:
      var temp: array[1, char]
      parseStringFast(s, i, temp)
      v = temp[0]

when defined(release):
  {.pop.}
