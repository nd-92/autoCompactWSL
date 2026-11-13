# WSL2 VHDX Auto-Compactor

A Windows batch script that automatically finds and compacts **all** of your WSL2 `ext4.vhdx` virtual disks using `diskpart`, reclaiming disk space that WSL never gives back on its own.

Unlike many similar scripts, this one does **not** assume your distros live in the default `%LOCALAPPDATA%` folders. It reads the Windows registry to locate every registered WSL distribution — including ones installed to a custom drive (e.g. `D:\WSL\...`) via `wsl --import` or `wsl --install --location`.

---

## The Problem

WSL2 stores each distribution inside a dynamically growing `ext4.vhdx` file. That file **grows** as you add data but **never shrinks** when you delete files. Over time a distro can balloon to tens of gigabytes of dead, unused space. The fix is to shut WSL down and compact the VHDX with `diskpart` — but doing that by hand for every distro, on every drive, is tedious and error-prone.

This script automates the whole process.

---

## Features

- 🔍 **Finds every distro** — enumerates WSL distributions from the registry, so custom install locations (D:, E:, etc.) are included.
- 🛑 **Safely shuts down WSL** (`wsl --shutdown`) before touching any disk.
- 👑 **Self-elevates** — requests Administrator rights automatically via UAC if not already elevated.
- 📋 **Lists what it found** and asks for confirmation before doing anything destructive.
- 📦 **Compacts each VHDX** using `diskpart` (`attach readonly` → `compact vdisk` → `detach vdisk`).
- 📊 **Per-file status + summary** — reports how many succeeded and failed, and shows `diskpart` output on failure.
- 🧹 **Cleans up** all temporary files.

---

## Requirements

- Windows 10 or Windows 11 with **WSL2** installed.
- The script must run **as Administrator** (it will prompt you automatically).
- `diskpart` (built into Windows).
- PowerShell (only used for the self-elevation step).

---

## Usage

1. Download or clone this repository.
2. Run `compact-wsl-vhdx.bat`.
3. Accept the UAC prompt when asked for Administrator rights.
4. Review the list of VHDX files the script found.
5. Type `y` to proceed.
6. When it finishes, read the summary.

> ⚠️ **All running WSL instances are shut down** when the script starts. Save any work in your distros first.

### Example run

```
Shutting down all WSL instances...
Reading WSL distribution paths from the registry...

Found the following VHDX files:
  1: C:\Users\you\AppData\Local\wsl\{...}\ext4.vhdx
  2: D:\WSL\Ubuntu\ext4.vhdx
Proceed with compaction? (y/n): y

[1/2] Compacting: C:\Users\you\AppData\Local\wsl\{...}\ext4.vhdx
  -> Compacted successfully.

[2/2] Compacting: D:\WSL\Ubuntu\ext4.vhdx
  -> Compacted successfully.

=== Summary ===
Total files found: 2
Successfully compacted: 2
Failed: 0
```

---

## How It Works

1. **Elevation check** — uses `net session` to test for admin rights and re-launches itself with `Start-Process -Verb RunAs` if needed.
2. **`wsl --shutdown`** — releases the VHDX files so `diskpart` can lock them.
3. **Registry discovery** — queries `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss` for each distro's `BasePath` value and builds the `ext4.vhdx` path. This is why custom-drive distros are found.
   - WSL may store paths with a `\\?\` (long-path) prefix; the script strips it for `diskpart` compatibility.
4. **Compaction** — for each file, writes a temporary `diskpart` script that selects the vdisk, attaches it read-only, compacts it, and detaches it.
5. **Result parsing** — inspects `diskpart`'s exit code and output to classify each run as success or failure.
6. **Cleanup & summary**.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `No ext4.vhdx files found via the registry.` | No WSL distros registered for the current user, or WSL isn't installed. Run `wsl -l -v` to confirm. |
| `Failed` with **"The specified file is encrypted"** | The VHDX (or its folder) has the Windows "Encrypt contents" attribute. Turn it off via **Properties → Advanced → Encrypt contents to secure data**. `diskpart` cannot compact encrypted VHDX files. |
| `Failed` with **access denied / in use** | Another process is still holding the file. Make sure Docker Desktop, WSLg, or other WSL-backed tools are closed, then re-run. |
| Script closes instantly | You may have run it from a path with spaces without quotes, or UAC was declined. Run from a plain `cmd` window to see output. |
| Spaces in the VHDX path | Paths are quoted in the `diskpart` script; custom locations with spaces are supported. |

---

## Notes & Caveats

- **This is a destructive-ish operation.** Compaction is generally safe, but backing up important distros (`wsl --export`) before first use is wise.
- **Run it periodically** — after heavy file deletions inside WSL, or when your `.vhdx` looks much larger than your actual data.
- **Not for WSL1.** WSL1 distros don't use `ext4.vhdx`.
- The script operates on the **current user's** registered distros. If multiple Windows users have their own WSL installs, run it once per user account.

---

## Optional: Schedule It

You can add this as a **Task Scheduler** task (run with highest privileges) to compact automatically, e.g. weekly. Remember it forces `wsl --shutdown`, so schedule it when you're not actively using WSL.

---

## License

This project is licensed under the **GNU General Public License v3.0**.
See the [LICENSE](LICENSE) file for the full text.

Copyright (C) 2026 <Your Name>

> **Note on redistribution:** Because this is GPL-3.0, if you distribute a
> modified version of this script, you must also make the modified source
> (the `.bat` file) available under the same license, and keep the license
> and copyright notices intact.

---

## Contributing

Issues and pull requests welcome. If you hit an edge case (unusual install path, encrypted disk, multiple users), please open an issue with the `diskpart` output.