# Sileo depiction

`net.myxxdev.mybloxx15.json` is a Sileo *native depiction*. It is **not** referenced from `control` because the
`SileoDepiction:` field needs a URL, and the package must not depend on an external host. A repository that hosts this
package should publish this file and add `SileoDepiction: <its URL>` to the repository's own Packages entry. Without it,
every package manager still shows the full `Description:` from `control`.
