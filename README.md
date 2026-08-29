# Pierdolnik II
**Nowe, doroślejsze podejście do OS-deweloperki**

## Co to jest?
TODO: [co to jest?](https://www.youtube.com/watch?v=hCjXuSabCwI)

## Wymagane narzędzia i budowanie
### Wymagane narzędzia
Wymagane narzędzia kompilowane krzyżowo (pod i-686):
- gcc, projekt używa 14.1.0
- binutils, projekt używa 2.42
- gdb, projekt używa 14.2

Pozostałe (ale wciąż wymagane):
- NASM, wersja 2.00 lub wyżej - projekt używa 2.16.03
- CMake, wersja 3.8 lub wyżej - projekt używa 3.30-rc4
- jakiś pakiet do edycji obrazów dysków - projekt używa mtools

Zalecane:
- QEMU, wersja jakakolwiek
- Jakiś klient protokołu VNC

Kompatybilność ze starszymi wersjami gcc/gdb/binutils nie była sprawdzana, więc niczego nie obiecuję. 

### Budowanie

#### Windows
Zainstaluj jakieś WSL i patrz niżej

#### Linux
Po wypakowaniu źródła do folderu:

1. Utwórz folder, w którym będą pliki tymczasowe
2. W wierszu poleceń `cd wypakowany_folder`
3. `cmake --build folder_z_kroku_1 -t all`

W tym momencie system powinien być już gotowy, a w wypakowanym folderze powinien znaleźć się plik `.iso`. Możesz uruchomić go ręcznie w dowolnej maszynie wirtualnej albo użyć komendy `cmake --build folder_z_kroku_1 -t run_system`, która uruchamia instancję QEMU.

_Uwaga_: jeśli kompilujesz z użyciem WSL, QEMU nie wyświetli okna z maszyną wirtualną. Zamiast tego należy użyć klienta VNC i połączyć go z adresem `localhost` i portem podanym przez skrypt (zazwyczaj `5900`).

#### Ścieżki budowania
- `legacy` - tradycyjny, dwupiętrowy bootloader korzystający z dobrodziejstw BIOS trybu rzeczywistego. Jest™ i Działa™, ale nie będę go znacznie rozwijał.
- normalna - korzysta z UEFI, aby osiągnąć ten sam efekt.

W zależności od ścieżki pliki wczytywane podczas bootowania i ich zawartość będą różne. Docelowo obie ścieżki mają doprowadzić do identycznie działającego systemu.

#### Opcje budowania
- `PROCESSOR_MODEL` - dokładne określenie modelu procesora. Dla wartości `8086` stosowana jest starsza metoda budowania obrazu (dyskietka rozruchowa).