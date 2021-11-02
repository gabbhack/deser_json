discard """
  cmd: "nim $target --hints:on -d:testing $options $file"
"""

import std/[unittest, options, tables]

import deser
import deser_json/ser

type
  Unit = object

  UnitTuple = tuple[]

  Struct = object
    id: int
    text: string
  
  User = object
    id: int
    name: string
    address: Address
  
  Address = object
    street: string

makeSerializable(Struct)
makeSerializable(User)
makeSerializable(Address)

suite "serialize":
  test "bool":
    doAssert ser.toString(true) == "true"
    doAssert ser.toString(false) == "false"
  
  test "int":
    doAssert ser.toString(123) == "123"
  
  test "float":
    doAssert ser.toString(123.0) == "123.0"

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
  
  test "unit struct":
    doAssert ser.toString(Unit()) == "null"
  
  test "unit tuple":
    doAssert ser.toString(default(UnitTuple)) == "null"
  
  test "array":
    doAssert ser.toString([1,2,3]) == "[1,2,3]"

  test "seq":
    doAssert ser.toString(@[1,2,3]) == "[1,2,3]"
  
  test "tuple":
    doAssert ser.toString((1,2,3)) == "[1,2,3]"
  
  test "named tuple":
    doAssert ser.toString((id: 123, text: "123")) == "{\"id\":123,\"text\":\"123\"}"

  test "map":
    doAssert ser.toString({"text": "123"}.toTable) == "{\"text\":\"123\"}"
  
  test "struct":
    doAssert ser.toString(Struct(id: 123, text: "123")) == "{\"id\":123,\"text\":\"123\"}"

  test "seq map":
    doAssert ser.toString({"text": "123"}) == "{\"text\":\"123\"}"
