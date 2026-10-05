# Fresence

Presence for a few friends: who's online, what's open on their screen, what's playing, which game they're in, photos that leave on their own. Phone and desktop, one small server that can't read any of it.

What it looks like, plus a demo you can try in the browser: [fresence.ug3n.com](https://fresence.ug3n.com).

Cards, state and photos are end-to-end encrypted. The server forwards blobs and sees who's in which room and when a device is online, but not what's on it.

## Install

Builds are on [Releases](https://github.com/Berupor/Fresence/releases), every client updates itself.

- Android: `fresence-android.apk`.
- Windows: `fresence-windows-amd64-setup.exe`, per user, no admin rights.
- Linux x86_64: installs the app to `~/.local/share/fresence/desktop` and `fresence-desktop` to `~/.local/bin`:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/Berupor/Fresence/master/agent/packaging/install.sh | bash
  ```

- Arch: `fresence-bin` through paru, new versions come with `paru -Syu`. Add to `~/.config/paru/paru.conf`:

  ```ini
  [fresence]
  Url = https://github.com/Berupor/Fresence
  Path = agent/packaging/arch
  ```

  ```bash
  paru -Sy --pkgbuilds && paru -S fresence-bin
  ```

## Getting in

You need an invite from someone already in a room: open the link, scan its QR in the app or paste it. No invite? Write to fresence@ug3n.com.

A second device joins your account: on the one that's already in, Settings, "Link a device". There's no password and no recovery, so keep at least two devices linked.

## Bugs and ideas

From the app: Settings, "About Fresence", "Feedback".
