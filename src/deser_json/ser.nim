import ser/[
  ser,
  formatter
]

export
  ser,
  formatter


func toString*(value: auto): string {.inline.} = ##[
Serialize your value to string. Accepts only type that implement `serialize` procedure.
]##
  runnableExamples:
    import deser

    let str = 123.toString()
    assert str == "123"

  mixin serialize

  var ser = initJsonSerializer(initCompactFormatter())
  value.serialize(ser)
  result = ser.writer


func toPrettyString*(value: auto): string {.inline.} = ##[
Serialize your value to pretty string. Accepts only type that implement `serialize` procedure.
]##
  runnableExamples:
    import deser

    let str = 123.toPrettyString()
    assert str == "123"

  mixin serialize

  var ser = initJsonSerializer(initPrettyFormatter([' ', ' ', ' ', ' ']))
  value.serialize(ser)
  result = ser.writer
