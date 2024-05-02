# [Overleaf](https://www.Overleaf.com) Installer for Windows

### This script automates the entire installation of [Overleaf](https://github.com/overleaf/overleaf) on Windows.


It should take care of all the requirements for you: 
- [ ] Checks for WSL and Docker, and installs them if necessary. For now, you must manually install [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) and [Docker](https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe?utm_location=module). 
- [X] Offers customizing certain things, and a persistent data folder.
- [X] Offers creation of username and password, and provides a link to create the password.
- [X] Creates a "shortcut" that you can click on to start Overleaf automatically.

In other words, the whole works. I just hope it works for you.


## Quick Start

1. **Download the Installer**: Click [here](https://github.com/sm18lr88/Overleaf_Installer/raw/main/Install_Overleaf.bat).
2. **Run**: Right-click the downloaded file and select "Run as administrator".

## Note on Antivirus

Your antivirus might block this script. If it does:
- Temporarily disable your antivirus, or
- Add an exclusion for `Install_Overleaf.bat` in your antivirus settings.
- After the script is done, you'll also need to add an exclusion for the resulting `Start_Overleaf.bat`.

## License

Provided under the MIT License.
