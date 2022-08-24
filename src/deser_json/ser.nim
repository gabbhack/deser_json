import ser/[
  ser,
  formatter
]

export
  ser,
  formatter


func toJson*(value: auto): string {.inline.} = ##[
Serialize your value to string. Accepts only type that implement `serialize` procedure.
]##
  runnableExamples:
    import deser

    let str = 123.toJson()
    assert str == "123"

  mixin serialize

  var ser = initJsonSerializer(initCompactFormatter())
  value.serialize(ser)
  result = ser.writer


func toPrettyJson*(value: auto): string {.inline.} = ##[
Serialize your value to pretty string. Accepts only type that implement `serialize` procedure.
]##
  runnableExamples:
    import deser

    let str = 123.toPrettyJson()
    assert str == "123"

  mixin serialize

  var ser = initJsonSerializer(initPrettyFormatter([' ', ' ', ' ', ' ']))
  value.serialize(ser)
  result = ser.writer
