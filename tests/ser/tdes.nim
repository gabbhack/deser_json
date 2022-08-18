discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc"
"""

import std/[unittest, options, tables]

import deser
import deser_json/des

type
  Struct = object
    id: int
    text: string

makeDeserializable(Struct)

suite "serialize":
  test "bool":
    doAssert true == bool.fromString("true")
    doAssert false == bool.fromString("false")
  
  test "int":
    doAssert 123 == int.fromString("123")
    doAssert 123i8 == int8.fromString("123")
    doAssert 123i16 == int16.fromString("123")
    doAssert 123i32 == int32.fromString("123")
    doAssert 123i64 == int64.fromString("123")

    doAssert 123.uint == uint.fromString("123")
    doAssert 123u8 == uint8.fromString("123")
    doAssert 123u16 == uint16.fromString("123")
    doAssert 123u32 == uint32.fromString("123")
    doAssert 123u64 == uint64.fromString("123")

  test "float":
    doAssert 123.0 == float.fromString("123.0")
    doAssert 123.0f32 == float32.fromString("123.0")
    doAssert 123.0f64 == float64.fromString("123.0")

  test "string":
    doAssert "123" == string.fromString("\"123\"")
  
  test "char":
    doAssert '1' == char.fromString("\"1\"")
  
  test "bytes":
    doAssert ['0'.byte, '1'.byte] == fromString(array[2, byte], "[48,49]")
  
  test "none":
    doAssert none[int]() == fromString(Option[int], "null")
  
  test "some":
    doAssert some(123) == fromString(Option[int], "123")
  
  test "array":
    doAssert [1,2,3] == fromString(array[3, int], "[1,2,3]")

  test "seq":
    doAssert @[1,2,3] == fromString(seq[int], "[1,2,3]")
  
  test "tuple":
    doAssert (1,2,3) == fromString((int, int, int), "[1,2,3]")
  
  test "named tuple":
    doAssert (id: 123, text: "123") == fromString(tuple[id: int, text: string], "[123,\"123\"]")

  test "map":
    doAssert {"text": "123"}.toTable == fromString(Table[string, string], "{\"text\":\"123\"}")
  
  test "struct":
    doAssert Struct(id: 123, text: "123") == Struct.fromString("{\"id\":123,\"text\":\"123\"}")

  test "enum":
    type Foo = enum
      First = "first"
    
    doAssert First == Foo.fromString("\"first\"")

    type Bar = enum
      Second
    
    doAssert Second == Bar.fromString("\"Second\"")
