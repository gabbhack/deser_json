import des/des

export des


proc fromJson*(Self: typedesc, input: sink string): Self {.inline.} = ##[
Deserialize your type from string. Accepts only type that implement `deserialize` procedure.
]##
  runnableExamples:
    import deser

    let integer = int.fromJson("123")
    assert integer == 123

  mixin deserialize

  var deserializer = Deserializer(
    source: input,
    pos: 0
  )
  
  Self.deserialize(deserializer)
