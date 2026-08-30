# ChessOS

Projekt na Noc Naukowców 2026 budowany całkowicie od zera :)

== Budowanie 
*Uwaga*: przy wyborze emulacji w QEMU należy zbudować własny obraz UEFI, który zawiera sterowniki dla myszy. Na szczęście wszystkie potrzebne pliki już istnieją.
Konfiguracja jest rozsądnie łatwa:

1. Należy sklonować repozytorium EDK2:

```bash
git clone https://github.com/tianocore/edk2.git
cd edk2
git submodule update --init
cd ..
```

Ten krok zajmie około 10 minut.

1. Trzeba zadeklarować, że chce się dodatkowych sterowników:

1.1. Znajdź plik `OvmfPkg/OvmfPkgX64.dsc`, a w nim sekcję `[Components]`. Tam dopisz wiersz (wsród wielu podobnych importów):

```txt
MdeModulePkg/Bus/Usb/UsbMouseDxe/UsbMouseDxe.inf
```

1.2. Znajdź plik `OvmfPkg/OvmfPkgX64.fdf`, a w nim sekcję `[FX.DXEFV]`. Dopisz wiersz:

```txt
INI MdeModulePkg/Bus/Usb/UsbMouseDxe/UsbMouseDxe.inf
```

1. Zainstaluj zależności, jeśli ich nie masz:

```bash
sudo apt install build-essential uuid-dev iasl git nasm python3-distutils
```

(czy inny menedżer paczek)

1. Zbuduj wstępną konfigurację:

```bash
make -c BuildTools
. edksetup.sh
```

1. Zbuduj właściwą konfigurację:

```bash
build -p OvmfPkg/OvmfPkgX64.dsc -a X64 -t GCC -b RELEASE
```

Przy odrobinie szczęścia plik pojawi się jako `Build/OvmfX64/RELEASE_GCC/FV/OVMF.fd`. Można go już używać do zabawy :)
