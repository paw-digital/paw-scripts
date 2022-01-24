# paw-scripts

To compile the windows installer to .exe:

1. Install Python on Windows: https://www.python.org/downloads/windows/
2. Add pyinstaller via pip: pip install pyinstaller
3. Add our installer dependencies: pip install requests and pip install zipfile
3. Compile: pyinstaller --onefile win_paw_node_install.py

You will get a installer.exe in dist/
