# [RIP] deser_json.
## Rewrite in progress. Only serialize works for now

**JSON-Binding for deser**

```nim
import std/[options, times, macros]

import deser
import deser_json/ser
  

proc toTimestamp[Serializer](date: DateTime, serializer: var Serializer) =
  serializer.serializeInt(date.toTime().toUnix())

type
  User = object
    id: int
    name: string
    photo {.skipSerializeIf(isNone).}: Option[string]
    registerTime {.serializeWith(toTimestamp).}: DateTime

    case isAdmin {.untagged.}: bool
    of true:
      permissions: int
    else:
      discard
  
  Pagination = object
    limit: uint64
    offset: uint64
    total: uint64
  
  Users = object
    users: seq[User]
    pagination {.inlineKeys.}: Pagination

expandMacros:
  makeSerializable(User)
makeSerializable(Pagination)
makeSerializable(Users)

echo ser.toPrettyString(Users(
  users: @[
    User(id: 0, name: "CEO", isAdmin: true, permissions: 99, registerTime: now()),
    User(id: 9999, name: "noname", isAdmin: false, registerTime: now(), photo: some "url"),
  ],
  pagination: Pagination(limit: 10, offset: 0, total: 2)
))
```
will output

```nim
type
  SerializeWith_436207683 = object
    value: DateTime

proc serialize[T](self: SerializeWith_436207683; serializer: var T) =
  toTimestamp(self.value, serializer)

proc serialize[T](self: User; serializer: var T) =
  when compiles(serializeStruct(serializer, "User").addr):
    let temp`gensym0 = serializeStruct(serializer, "User").addr
    template state(): untyped =
      temp`gensym0[]

  else:
    var state = serializeStruct(serializer, "User")
  serializeStructField(state, "id", self.id)
  serializeStructField(state, "name", self.name)
  if not isNone(self.photo):
    serializeStructField(state, "photo", self.photo)
  serializeStructField(state, "registerTime",
                       SerializeWith_436207683(value: self.registerTime))
  case self.isAdmin
  of true:
    serializeStructField(state, "permissions", self.permissions)
  else:
    discard
  endStruct(state)

{
    "users": [
        {
            "id": 0,
            "name": "CEO",
            "registerTime": 1635845780,
            "permissions": 99
        },
        {
            "id": 9999,
            "name": "noname",
            "photo": "url",
            "registerTime": 1635845780
        }
    ],
    "limit": 10,
    "offset": 0,
    "total": 2
}
```