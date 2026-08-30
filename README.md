# ChessOS

Projekt na Noc Naukowców 2026 budowany całkowicie od zera :)

== Budowanie 
*Uwaga*: przy wyborze emulacji w QEMU należy zbudować własny obraz UEFI, który zawiera sterowniki dla myszy. Na szczęście wszystkie potrzebne pliki już istnieją.
Konfiguracja jest rozsądnie łatwa:
1. Należy sklonować repozytorium EDK2:
```
git clone https://github.com/tianocore/edk2.git
cd edk2
git submodule update --init
cd ..
``` Ten krok zajmie około 10 minut.
1. Trzeba zadeklarować, że chce się dodatkowych sterowników:
