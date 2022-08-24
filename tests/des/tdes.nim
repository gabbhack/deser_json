discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc"
"""

import std/[
  unittest,
  options,
  tables
]

import
  deser,
  deser_json/des

type
  Struct = object
    id: int
    text: string

makeDeserializable(Struct)

suite "serialize":
  test "bool":
    doAssert true == bool.fromJson("true")
    doAssert false == bool.fromJson("false")
  
  test "int":
    doAssert 123 == int.fromJson("123")
    doAssert 123i8 == int8.fromJson("123")
    doAssert 123i16 == int16.fromJson("123")
    doAssert 123i32 == int32.fromJson("123")
    doAssert 123i64 == int64.fromJson("123")

    doAssert 123.uint == uint.fromJson("123")
    doAssert 123u8 == uint8.fromJson("123")
    doAssert 123u16 == uint16.fromJson("123")
    doAssert 123u32 == uint32.fromJson("123")
    doAssert 123u64 == uint64.fromJson("123")

  test "float":
    doAssert 123.0 == float.fromJson("123.0")
    doAssert 123.0f32 == float32.fromJson("123.0")
    doAssert 123.0f64 == float64.fromJson("123.0")

  test "string":
    doAssert "123" == string.fromJson("\"123\"")
  
  test "char":
    doAssert '1' == char.fromJson("\"1\"")
  
  test "bytes":
    doAssert ['0'.byte, '1'.byte] == fromJson(array[2, byte], "[48,49]")
  
  test "none":
    doAssert none[int]() == fromJson(Option[int], "null")
  
  test "some":
    doAssert some(123) == fromJson(Option[int], "123")
  
  test "array":
    doAssert [1,2,3] == fromJson(array[3, int], "[1,2,3]")

  test "seq":
    doAssert @[1,2,3] == fromJson(seq[int], "[1,2,3]")
  
  test "tuple":
    doAssert (1,2,3) == fromJson((int, int, int), "[1,2,3]")
  
  test "named tuple":
    doAssert (id: 123, text: "123") == fromJson(tuple[id: int, text: string], "[123,\"123\"]")

  test "map":
    doAssert {"text": "123"}.toTable == fromJson(Table[string, string], "{\"text\":\"123\"}")
  
  test "struct":
    doAssert Struct(id: 123, text: "123") == Struct.fromJson("{\"id\":123,\"text\":\"123\"}")

  test "enum":
    type Foo = enum
      First = "first"
    
    doAssert First == Foo.fromJson("\"first\"")

    type Bar = enum
      Second
    
    doAssert Second == Bar.fromJson("\"Second\"")
