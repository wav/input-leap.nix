# Input Leap nix

This is [Input Leap](https://github.com/input-leap/input-leap) packaged with [nix](https://nixos.org/explore)

This has successfully been run on the following configurations:

|               Server               |                Client                 |
|:----------------------------------:|:-------------------------------------:|
| **macos sonoma** on aarch64-darwin | **gnome 45/wayland** on x86_64-linux  |

### Build

`nix build .`

Then collect your app under `./result/Applications/InputLeap.app`
                    
### Configure

**On the server,** choose `Use existing configuration` and use a configuration (`~/input-leap.conf`) that looks like the following:

```
section: screens
        ubu:
        mac:
end

section: links
        ubu:
                left = mac
        mac:
                right = ubu
end
```

Then start/reload.

**On the client,** set the `Server IP` to that of the server.

Then start, a dialog will appear, turn on `Allow remote interaction` and `[Share]`.

You should now be able to use your mouse and keyboard across machines!

### Resources

- Input Leap: https://github.com/input-leap/input-leap
- Arch wiki: https://wiki.archlinux.org/title/Input_Leap

### Things to ba aware of

- The `Configure Interactively` function doesn't to work, editing the GUI fails.
- The client needs to be logged in and the input leap GUI must be opened manually and started
- Make sure no other `synergy/barrier/input leap` instance or similar is running
- The clipboard doesn't work for me
- CMD key doesn't work on the linux client
- Focus doesn't leave the host, when interacting with the client. So the cursor and sometimes text gets selected on the
  host screen :/
- If `~/input-leap.conf` is invalid, the GUI may just crash

### Troubleshooting

```
ERROR: invalid message from client "lowrey": DINF
```
The server's `~/input-leap.conf` has an invalid configuration, confirm the configuration attributes are correct.

### What's been evaluated

When looking for a KVM to use on macbook and a linux desktop...

- Synergy was the original project, was using this with a windows client
  - Unfortunately, there's no installer yet for gnome/wayland/nix.
- Barrier is a fork of Synergy appears unmaintained.
  - This was almost working, but there was no cursor on gnome/wayland.
  - It was unclear why it would stop working frequently
- Input Leap is a fork of Barrier, the build was approachable.

### Installation - via a flake

Add the following to your flake configuration

```nix
# flake.nix
{
    inputs = {
        # ...
        input-leap.url = "github:wav/input-leap.nix";
        # ...
    };
    
    outputs = inputs: {
        # ...
        overlays = [ inputs.input-leap.overlays.default ];
        # ...
    };
}
```

Add the package to your env

```nix
# configuration.nix
{ pkgs, ...}: {
    # ...
    environment.systemPackages = [ pkgs.input-leap ];
    # ...
}
```

Then rebuild. The desktop applications will now appear in your programs/applications.
