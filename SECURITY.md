# Security policy

Please avoid publishing an exploitable security issue before a fix is ready.
If the repository host supports private security advisories, use that channel;
otherwise contact the maintainer privately.

Reports are especially useful when they include the affected macOS and DeskMate
versions, a minimal reproduction, expected impact and whether the issue touches
application replacement, persistence, code signing or private touch callbacks.

The public release currently provides source code. Local builds produced by this
repository are ad-hoc signed. A
maintainer distributing binaries to other users should use Apple Developer ID
signing and notarization. DeskMate's private MultitouchSupport fallback is
version-gated and intentionally fails closed, but it also means this source is
not suitable for Mac App Store distribution in its current form.
