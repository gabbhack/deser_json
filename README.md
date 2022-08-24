# deser_json [![nim-version-img]][nim-version]

[nim-version]: https://nim-lang.org/blog/2021/10/19/version-160-released.html
[nim-version-img]: https://img.shields.io/badge/Nim_-v1.6.0%2B-blue

**JSON-Binding for deser**

`nimble install deser_json`

[Deser documentation](https://deser.nim.town)

---

## Usage
First, install [deser](https://github.com/gabbhack/deser) via `nimble install deser`

deser_json provides three procedures:
1. `toString` for serialization
1. `toPrettyString` for pretty serialization
1. `fromString` for deserialization

```nim
import
  deser,
  deser_json

var some = [1, 2, 3]

echo some.toString()

some = fromString(typeof(some), "[1, 2, 3]")
```

See the [deser documentation](https://deser.nim.town/deser.html) for a complete example.

## License
Licensed under <a href="LICENSE">MIT license</a>.

deser_json uses third-party libraries or other resources that may be
distributed under licenses different than the deser_json.

<a href="THIRD-PARTY-NOTICES.TXT">THIRD-PARTY-NOTICES.TXT</a>

## Acknowledgements
- [jsony](https://github.com/treeform/jsony), for json parser
