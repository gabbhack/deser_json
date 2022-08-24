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
  deser_json/ser

type
  Struct = object
    id: int
    text: string

makeSerializable(Struct)

suite "serialize":
  test "bool":
    doAssert ser.toJson(true) == "true"
    doAssert ser.toJson(false) == "false"
  
  test "int":
    doAssert ser.toJson(123) == "123"
    doAssert ser.toJson(123i8) == "123"
    doAssert ser.toJson(123i16) == "123"
    doAssert ser.toJson(123i32) == "123"
    doAssert ser.toJson(123i64) == "123"

    doAssert ser.toJson(123u8) == "123"
    doAssert ser.toJson(123u16) == "123"
    doAssert ser.toJson(123u32) == "123"
    doAssert ser.toJson(123u64) == "123"

  test "float":
    doAssert ser.toJson(123.0) == "123.0"
    doAssert ser.toJson(123.0f32) == "123.0"
    doAssert ser.toJson(123.0f64) == "123.0"

  test "string":
    doAssert ser.toJson("123") == "\"123\""
  
  test "char":
    doAssert ser.toJson('1') == "\"1\""
  
  test "bytes":
    doAssert ser.toJson(['0'.byte, '1'.byte]) == "[48,49]"
  
  test "none":
    doAssert ser.toJson(none int) == "null"
  
  test "some":
    doAssert ser.toJson(some 123) == "123"
  
  test "array":
    doAssert ser.toJson([1,2,3]) == "[1,2,3]"

  test "seq":
    doAssert ser.toJson(@[1,2,3]) == "[1,2,3]"
  
  test "tuple":
    doAssert ser.toJson((1,2,3)) == "[1,2,3]"
  
  test "named tuple":
    doAssert ser.toJson((id: 123, text: "123")) == "[123,\"123\"]"

  test "map":
    doAssert ser.toJson({"text": "123"}.toTable) == "{\"text\":\"123\"}"
  
  test "struct":
    doAssert ser.toJson(Struct(id: 123, text: "123")) == "{\"id\":123,\"text\":\"123\"}"

  test "enum":
    type Foo = enum
      First = "first"
    
    doAssert ser.toJson(First) == "\"first\""

    type Bar = enum
      Second
    
    doAssert ser.toJson(Second) == "\"Second\""
