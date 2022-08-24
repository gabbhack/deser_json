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
    doAssert ser.toString(true) == "true"
    doAssert ser.toString(false) == "false"
  
  test "int":
    doAssert ser.toString(123) == "123"
    doAssert ser.toString(123i8) == "123"
    doAssert ser.toString(123i16) == "123"
    doAssert ser.toString(123i32) == "123"
    doAssert ser.toString(123i64) == "123"

    doAssert ser.toString(123u8) == "123"
    doAssert ser.toString(123u16) == "123"
    doAssert ser.toString(123u32) == "123"
    doAssert ser.toString(123u64) == "123"

  test "float":
    doAssert ser.toString(123.0) == "123.0"
    doAssert ser.toString(123.0f32) == "123.0"
    doAssert ser.toString(123.0f64) == "123.0"

  test "string":
    doAssert ser.toString("123") == "\"123\""
  
  test "char":
    doAssert ser.toString('1') == "\"1\""
  
  test "bytes":
    doAssert ser.toString(['0'.byte, '1'.byte]) == "[48,49]"
  
  test "none":
    doAssert ser.toString(none int) == "null"
  
  test "some":
    doAssert ser.toString(some 123) == "123"
  
  test "array":
    doAssert ser.toString([1,2,3]) == "[1,2,3]"

  test "seq":
    doAssert ser.toString(@[1,2,3]) == "[1,2,3]"
  
  test "tuple":
    doAssert ser.toString((1,2,3)) == "[1,2,3]"
  
  test "named tuple":
    doAssert ser.toString((id: 123, text: "123")) == "[123,\"123\"]"

  test "map":
    doAssert ser.toString({"text": "123"}.toTable) == "{\"text\":\"123\"}"
  
  test "struct":
    doAssert ser.toString(Struct(id: 123, text: "123")) == "{\"id\":123,\"text\":\"123\"}"

  test "enum":
    type Foo = enum
      First = "first"
    
    doAssert ser.toString(First) == "\"first\""

    type Bar = enum
      Second
    
    doAssert ser.toString(Second) == "\"Second\""
