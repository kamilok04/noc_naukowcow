#import "@preview/touying:0.8.0": *
#import themes.simple: *
#import "theme/metropolis.typ": *
#import "@preview/staunton:2.0.0": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node
#import fletcher.shapes: diamond
#set page(paper: "presentation-16-9")
#set text(size: 25pt, font: "Fira Sans")
#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  footer: self => self.info.title,
  config-info(
      title: [Działający program bez systemu operacyjnego?],
      subtitle: [Programowanie UEFI w praktyce],
      author: [Kamil Bublij]
    )
)

#title-slide()


#show figure.where(kind: image): set figure(supplement: "Rysunek")

#show figure.where(kind: raw): set figure(supplement: [Program])

#show figure: it => {
  show figure.caption: set text(16pt)
  it
}

#show: simple-theme.with(
  config-common(horizontal-line-to-pagebreak: true),
)

#set table(
  fill: (_, y) => (none, rgb("DAF2F5")).at(calc.rem(y, 2)),
  stroke: none,
  row-gutter: 0.2em,
  inset: (right: 1.5em),
)

#set align(center + horizon)
#let biggrey(body) = {
  set text(weight: "bold", gray, size: 50pt)
  [#body]
}
#let colboard(fen, ..args) = {
  align(center + horizon)[
    // Skalowanie zredukowane z 200% na 125%, co chroni marginesy
    #scale(x: 175%, y: 175%, reflow: true)[
      #board(fen, ..args)
    ]
  ]
}

#let annotate-board(
  fen,
  annotations,
  size: 6.8cm, // Zmniejszony rozmiar bazowy (dopasowany do tekstu 25pt)
  ..args
) = {
  let square-size = size / 8
  
  align(center + horizon)[
    #scale(x: 175%, y: 175%, reflow: true)[
      #box(width: size, height: size)[
        #place(center + horizon, board(fen, ..args))
        
        #for (square, mark) in annotations {
          let file = square.at(0)
          let rank = int(square.at(1))
          
          let file-index = ("a", "b", "c", "d", "e", "f", "g", "h").position(x => x == file)
          let rank-index = rank - 1

          let x = file-index * (square-size - 0.5mm)
          let y = (7 - rank-index) * (square-size - 0.5mm)

          place(
            top + left,
            dx: x,
            dy: y,
            box(
              width: square-size + 4mm,
              height: square-size + 4mm,
              align(center + horizon)[
                #set text(weight: "bold", size: 14pt)
                #mark
              ]
            )
          )
        }
      ]
    ]
  ]
}
#let hex(num) = {
  let digits = "0123456789ABCDEF"
  let res = ""
  while true {
    let x = int(calc.rem(num, 16))
    res = digits.at(x) + res
    num = int(num / 16)
    if num == 0 {
      if calc.rem(res.len(), 2) == 1 {
        res = "0" + res
      }
      break
    }
  }
  res
}

#let s(body) = context {
  let size = measure(body)
  box(
    width: size.width,
    height: size.height,
    stack(
      spacing: 0pt,
      body,
      place(
        top + left,
        line(
          start: (0pt, 0pt),
          end: (size.width, -size.height),
          stroke: 2pt + red,
        ),
      ),
    ),
  )
}


---

=== Co tu zobaczymy?

#uncover("2-")[- Wprowadzenie: założenia, cel, narzędzia]
#uncover("3-")[- Crash course o architekturze]
#uncover("4-")[- Pogadanka o systemie]
#uncover("5-")[- Pogadanka o szachach]
#uncover("6-")[- Jak pisać kod na niskim poziomie?]

---

=== Co robimy?
Omówimy implementację gry w szachy, która jest:

#box(width: 30%)[
  #uncover("2-")[- rozruchowa]
  #uncover("3-")[- graficzna]
  #uncover("4-")[- sieciowa]
  #uncover("5-")[- prosta]

]
---
=== Rozruchowa? Gdzie?
Będziemy działać w środowisku UEFI w architekturze \ Intel x86\_64, powszechnej w PC.

---
=== BIOS -- rozruch w czasie przeszłym

#box(width: 80%)[
  #set list(spacing: 1em)
  #uncover("2-")[- 1975 rok]
  #uncover("3-")[- szuka konkretnych danych na dysku]
  #uncover("4-")[- program rozruchowy musi ważyć ≤ 512 bajtów]
  #uncover("5-")[- tryb rzeczywisty]
]
---

#columns(2)[
  #v(1in)
  Program rozruchowy zmieściłby się na przeciętnej dyskietce dokładnie 2880 razy!

  2880 #math.dot 512 B = 1.44 MB


  #colbreak()
  #figure(image("img/2025-01-14_eaccaed4d98b3.png"), caption: [przeciętna dyskietka])
]

---
=== UEFI -- gwiazda wieczoru

#box(width: 50%)[
  #uncover("2-")[- 2005 rok]
  #uncover("3-")[- szuka konkretnych plików]
  #uncover("4-")[- dowolny rozmiar programu]
  #uncover("5-")[- tryb chroniony/rozszerzony]

]
---
#columns(2)[
  #v(1in)
  === Prehistoria

  Procesor *Intel 8080* (1974) korzystał\ z 8-bitowych rejestrów, kreatywnie nazwanych
  ```asm
  A, B, C, D, E, H, L
  ```


  #colbreak()
  #figure(
    image("img/NEC_8080AF_die.jpg", width: 90%),
    caption: [Intel 8080 z bliska\ #set text(size: 12pt);Zdjęcie autorstwa Pauli Rautakorpi na licencji CC-BY 3.0],
  )
]

---

#columns(2)[
  #v(0.88in)
  === Czym jest PC?

  Procesor tej maszyny z 1981 roku, *Intel 8086*, posiada \ 16-bitowe rejestry:

  ```asm
   AX ; A
   CX ; BC
   DX ; DE
   BX ; HL
  ```

  #colbreak()
  #figure(
    image("img/IBM_PC-IMG_7271_(transparent).png"),
    caption: [_IBM Personal Computer_, pierwszy w rodzinie\ #set text(size: 12pt);Zdjęcie autorstwa Rama & Musée Bolo na licencji CC-BY 2.0 SA],
  )
]

---
===
#columns(2)[
  #v(1in)
  To tylko jedna z cech _trybu rzeczywistego_.
  Poza tym:


  - jeden proces naraz,

  - brak ochrony pamięci,

  - maksymalnie 1MB RAM.

  #colbreak()
  #figure(image("img/win20.png", width: 90%), caption: [Microsoft Windows 2.0, system trybu rzeczywistego])
]



// Bramka A20
// Czemu tryb rzeczywisty jest rzeczywisty?



---


#columns(2)[
  #v(1in)
  === Tryb chroniony
  1985 rok -- *Intel 80386* (i386) \ i 32-bitowe rejestry\  (`E`, czyli `E`xtended):
  ```asm
  EAX, EBX, ECX, EDX
  ```

  #colbreak()
  #figure(
    image("img/KL_Intel_i386DX.jpg", width: 65%),
    caption: [Intel 80386\ #set text(size: 12pt);Zdjęcie autorstwa Konstantin Lanzet na licencji CC BY-SA 3.0],
  )



  // segmentacja pamięci
  // stronicowanie
  // wielozadaniowość
  // ...

]

---
#columns(2)[
  #v(1in)
  === Tryb rozszerzony (długi)
  #v(1cm)
  2003 rok, *AMD Opteron* \ i 64-bitowe rejestry \ (`R`, czyli `R`egister):
  ```asm RAX, RBX, RCX, RDX
  ```
  #colbreak()
  #v(1in + 1cm + 1em)

  Każdy program UEFI domyślnie korzysta z trybu długiego.

]

---

=== Więcej bitów?
#v(0.5in)
Na teraz (2026) nie ma procesorów pracujących w 128-bitowej przestrzeni adresowej.
#v(0.5in)
Istnieją rejestry 128-bitowe (od 2016 roku nawet 512-bitowe), \ ale służą jedynie do operacji zmiennoprzecinkowych i wektorowych.

---

=== Język i narzędzia
---

#columns(2)[

  #v(1in)
  === Netwide Assembler

  Programowanie odbywa się \ w zgodzie z instrukcją architektury Intel 64/IA-32.
  #figure(image("img/intel.png"), caption: [Instrukcja nie jest lekturą do poduszki])
  #colbreak()
  #figure(
    ```asm
    mov rcx, 10
    mov rax, 0
    mov rbx, 1
    .licz:
      mov rdx, rax
      add rax, rbx
      mov rbx, rdx
      loop .licz
    ret ; wynik w RAX
    ; co to robi? :)

    ```,
    caption: [Przykładowy program],
  )
]

---

=== Asembler od podstaw

Instrukcja zwykle ma postać: ```asm operacja cel, źródło```, gdzie:

#box[
  - ```asm operacja``` to instrukcja -- ciąg znaków,

  - ```asm cel, źródło``` to, w zależności od potrzeb: rejestr, adres albo stała.

  Czasami ```asm źródło``` nie jest potrzebne albo (rzadko) \ podajemy więcej niż jedno.
]

---

*Ważna sprawa*: cel operacji zawsze jest "po lewej".

---

Przykłady:

#uncover("2-")[+ ```asm mov rax, 2 ; RAX = 2```]
#uncover("3-")[+ ```asm xor rdx, rdx ; RDX ^= RDX, czyli RDX = 0```]
#uncover("4-")[+ ```asm call [rax] ; bez źródła, (*RAX)()```]
#uncover("5-")[
  + ```asm vaddps xmm0, xmm1, xmm2 ; xmm0 = xmm1 + xmm2
    ; to tylko przykład, będzie łatwiej :)```
]

---
#place(top + left, dx: 50%, dy: 17.5%)[
  #box(width: 50%)[=== Ile prezentacji, tyle wytłumaczeń: co to wskaźnik?]]
#v(1in)
#columns(2)[
  #v(1in)

  #uncover("2-")[*Teoria*: wskaźnik to adres w pamięci.]

  #uncover("3-")[*Tutaj*: pudełko :)]

  #colbreak()
  #uncover("3-")[#figure(image("img/pudelko(1).png", width: 70%), caption: [Wskaźnik (nie do skali)])]
]
---

NASM wspiera składnię "pudełkową" -- działania na wskaźnikach \ są oznaczone \[kwadratowymi nawiasami\].

#figure(```asm
mov rax, [pudełko]
```, caption: [RAX dostanie to, co jest w pudełku.])

---

#columns(2)[
  #v(1in)
=== Parę słów o stosie
  #v(1cm)
Stos to nic innego jak _stos_ pudełek w pewnym obszarze pamięci. 

  #uncover("2-")[
    #figure(
    ```asm
    push 20
    ```,
    caption: [Wrzucanie wartości na stos]
    )
  ]
  #colbreak()
  #only("1")[#figure(image("img/part_stack.png"), caption: [Stos (nie do skali)])]
  #only("2")[#figure(image("img/stack_inserted.png"), caption: [Stos (nie do skali)])]
  
]

---
#columns(2)[
#v(1in)
=== Skąd komputer wie, gdzie trzyma pudełka?
#v(1cm)
Istnieją specjalne rejestry odpowiedzialne za stos: ```asm RSP``` oraz ```asm RBP```.

#box[
  #set text(size: 16pt)
  Istnieje też ```asm SS```, ale w trybie chronionym i wyżej zwykle ma zawsze wartość `0`.
]


#colbreak()

#figure(image("img/stack_registers.png", width: 50%), caption: [Rejestry stosu])
]
---
#columns(2)[
#v(1in)
=== Grawitacja stosu
#v(1cm)
W architekturze x86 stos zwykle rośnie _w dół_. 

Nie zmienia to zasady działania, ale warto mieć to na uwadze.
#figure(rotate(180deg)[#image("img/stack_flip.psd.png", width: 47.5%)], caption: [Stos bliższy rzeczywistości (nadal nie do skali)])

]

---

=== CMake, czyli klej do kodu
#v(1in)
Powszechne narzędzie -- alternatywa dla `Makefile`.

Po co CMake, skoro program nie potrzebuje ani kompilatora, ani konsolidatora?

--- 

=== Role CMake w kodzie 
+ zapewnienie warunków
+ wywołanie asemblera
+ synchronizacja plików (np. grafiki)
+ budowa pliku `.iso`

Powstaje plik `.iso` do wypalenia na płycie oraz folder `sysroot`.
---

= UEFI od spodu: konwencje i protokoły

---

=== Standardy, czyli jak rozmawiać z komputerem

Istnieją ścisłe standardy komunikacji między programem a płytą główną.

#uncover("2-")[
  W trybie długim obowiązuje *Microsoft x64 Calling Convention*.
]
---

Niedostosowanie się do konwencji skutkuje po prostu zawieszeniem się komputera bez możliwości negocjacji.

---
#v(1.5cm)
=== Jak wywołać funkcję UEFI i nie zepsuć komputera
#v(1cm)
  + *Rejestry:* Pierwsze cztery argumenty są kolejno w ```asm rcx, rdx, r8, r9```. Więcej argumentów ląduje na stosie.

  + *Shadow Space:* Przy każdym wywołaniu trzeba zostawić układowi przynajmniej 32B miejsca.

  + *Wyrównanie:* Przy wywołaniu stos musi być wyrównany do 16B.

---

=== Przykład




  ```asm
  sub rsp, 40       ; 32B shadow + 8B wyrównania
  mov rcx, [handle] ; 1. Argument
  mov rdx, 0x05     ; 2. Argument
  xor r8, r8        ; 3. Argument
  xor r9, r9        ; 4. Argument
  mov rax, [funkcja]
  call rax          ; Skok do UEFI

  add rsp, 40       ; Sprzątanie
  ```


---

#columns(2)[
  #v(1in)
=== Protokoły i GUID
#v(0.3in)
Mimo tego, że UEFI jest implementowane w C, jest modularne.

Pojedyncze funkcjonalności nazywamy *protokołami*.

#colbreak()
#v(1cm)
#figure(```asm
struc EFI_BLOCK_IO_PROTOCOL
    .Revision    resq 1  ; +0
    .Media       resq 1  ; +8: Ptr to EFI_BLOCK_IO_MEDIA
    .Reset       resq 1  ; +16
    .ReadBlocks  resq 1  ; +24:
    .WriteBlocks resq 1  ; +32
    .FlushBlocks resq 1  ; +40
endstruc```,
caption:[Przykładowy protokół UEFI])

]

---
#place(top + left, dx: 55%, dy: 20%)[ === Gdzie jest protokół?]
#v(0.8in)

  Do ustalenia tego służy *GUID* -- 128-bitowa liczba, która jest inna dla każdego protokołu.
    ```asm
        GUID_BLOCK_IO:
        dd 0x964e5b21
        dw 0x6459, 0x11d2
        db 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b
    ```
  Bardziej popularny zapis: *{964E5B21-6459-11D2-8E39-00A0C969723B}*.



---

=== Jak GUID ma się do protokołu?
#v(0.3in)
Mamy GUID, chcemy wywołać powiązaną funkcję. Po to UEFI ma specjalną funkcję `LocateProtocol`: sama płyta zawiera bazę danych z kluczami.

---

=== UEFI z lotu ptaka

---

#v(1in)
=== Kroki UEFI

Zanim uruchomi się jakikolwiek OS, płyta główna przechodzi przez złożony proces inicjalizacji.

#align(center)[
  #diagram(
    node-stroke: 1.5pt,
    edge-stroke: 1.5pt,
    node-corner-radius: 5pt,
    spacing: 1.2cm,
    mark-scale: 120%,

    node((0, 0), [SEC\ #text(size: 14pt)[(Security)]], fill: rgb("eeeeee")),
    edge("-|>"),
    node((1, 0), [PEI\ #text(size: 14pt)[(Pre-EFI Init)]], fill: rgb("eeeeee")),
    edge("-|>"),
    node((2, 0), [DXE\ #text(size: 14pt)[(Driver Exec)]], fill: rgb("eeeeee")),
    edge("-|>"),
    node((3, 0), [BDS\ #text(size: 14pt)[(Boot Select)]], fill: rgb("eeeeee")),
    edge("-|>"),
    node((4, 0), [*TSL*\ #text(size: 14pt)[(tu jesteśmy)]], fill: rgb("DAF2F5")),
    edge("-|>"),
    node((5, 0), [RT\ #text(size: 14pt)[(Runtime OS)]], fill: rgb("eeeeee")),
  )
]

---

  Program działa na etapie *TSL* (_Transient System Load_). To moment, \ w którym firmware załadował już wszystkie sterowniki sprzętowe (pamięć, grafikę, sieć w fazie DXE) i pozwala z nich korzystać, dopóki OS nie zostanie uruchomiony.


---

#columns(2)[
#v(1in)
=== System Table
Skąd program wie, jak wyświetlić obraz albo zaalokować pamięć?

Firmware przekazuje wskaźnik do *System Table* -- tablicę wskaźników do funkcji.

#colbreak()
#figure(
  image("img/phonebook1936-4d41a0.jpg", width: 40%),
  caption: [`System Table`, mniej więcej]
)
]
---
=== Co jest w System Table?

#v(0.2in)

  Sporo, ale dwie rzeczy są najważniejsze:
  - *Boot Services (BS):* Wszystko, czego będziemy używać (grafika, sieć, wejście myszy/klawiatury, ...)
  - *Runtime Services (RT):* Kilka funkcji dostępnych cały czas

---

=== Czy ten projekt to system operacyjny?
#v(0.5in)
*Nie.*

Nasza gra w szachy to aplikacja wykonywalna w formacie PE32+ (tzw. *Aplikacja UEFI*). Czym różni się od systemu operacyjnego?
---

#v(1in)
=== Aplikacja UEFI a system operacyjny


#columns(2)[
  #v(0.2in)
  #set text(size: 20pt)
  *System Operacyjny:*
  - Wywołuje `ExitBootServices()`, co niszczy sterowniki UEFI.
  - Przejmuje absolutną kontrolę nad sprzętem i ma własne sterowniki.
  - Wdraża własne mechanizmy ochrony pamięci czy wielowątkowości.

  #colbreak()
  #v(0.2in)
  #set text(size: 20pt)
  *Szachy z niczego:*
  - Nie wychodzą z poziomu bootloadera, nigdy.
  - Korzystają z dobrodziejstw płyty głównej.
  - Jeden wątek, który działa do wyłączenia prądu.
]



#v(1in)
=== Sieć z niczego
#v(0.5in)
Jak porozumieć się ze zdalnym komputerem bez systemu operacyjnego, wątków czy nawet stosu IP?

---

#columns(2)[
#v(1in)
  === Zejście do łącza danych
  #v(0.5in)

  Nie mamy standardowych narzędzi (IP, port, socket).

  Pracujemy na warstwie łącza danych -- protokół *SNP*.

  #colbreak()
  #figure(
    image("img/osi-model-pl.png", width: 70%),
    caption: [Model ISO/OSI a nasz system]
  )
]

---
  === Polling
  Bez pojęcia wątków nie ma pojęcia przerwań -- karta sieciowa \ nie "zawoła" procesora, gdy nadejdą dane. Ręcznie pytamy _masz coś dla mnie?_


---

#place(top + left, dx: 50%, dy: 15%)[=== Mechanizm działania ruchu]
#image("img/pakiet.svg", width: 68%)
---

#v(1in)
=== Anatomia ruchu

Co jest "w kablu"? Pakiet to zwykła ramka Ethernetowa -- używamy eksperymentalnego typu ramki.

#v(0.5in)
Zaledwie *3 bajty danych* wystarczą, aby w pełni i bezstratnie zsynchronizować stan obu szachownic pomiędzy dwoma fizycznymi komputerami.
---

#v(0.5in)
#align(center)[
  #table(
    columns: (auto, auto, auto),
    align: center + horizon,
    fill: (c, r) => if c == 2 and r == 1 { rgb("ffcccc") } else { rgb("DAF2F5") },
    stroke: 1pt + black,
    inset: 1em,
    [*Nagłówek Ethernet (14 B)*], [*EtherType (2 B)*], [*Dane ruchu (3 B)*],
    [Fizyczne adresy MAC], [`0x88B5`], [Skąd | Dokąd | Promocja],
  )
]


#box(fill: white, width:200%, height:200%)[
#v(0.5in)
#align(center)[
  #diagram(
    node-stroke: 1.5pt,
    edge-stroke: 1.5pt,
    node-corner-radius: 5pt,
    spacing: (-0.75cm, 0.6cm),
    mark-scale: 100%,

    // Standard OS Stack
    node((0, 0), [*Tradycyjny system*]),
    node((0, 1), [Aplikacja], fill: rgb("eeeeee")),
    node((0, 2), [Socket], fill: rgb("ffffff")),
    node((0, 3), [TCP / UDP], fill: rgb("ffffff")),
    node((0, 4), [IPv4 / IPv6], fill: rgb("ffffff")),
    node((0, 5), [Sterownik sieciowy], fill: rgb("ffffff")),

    edge((0, 1), (0, 2), "-|>"),
    edge((0, 2), (0, 3), "-|>"),
    edge((0, 3), (0, 4), "-|>"),
    edge((0, 4), (0, 5), "-|>"),

    // Bare metal UEFI Stack
    node((3, 0), [*Projekt UEFI*]),
    node((3, 1), [System], fill: rgb("DAF2F5")),
    node((3, 3.5), [SNP], fill: rgb("DAF2F5")),

    edge((3, 1), (3, 3.5), "-|>", label: [ 3 bajty ], label-pos: 0.5, label-side: left),

    // Hardware Layer (Shared visually)
    node((1.5, 6.5), [Fizyczny adapter sieciowy], fill: rgb("ffe6cc"), width: 8cm),
    edge((0, 5), (0, 6.5), (1.5, 6.5), "-|>"),
    edge((3, 3.5), (3, 6.5), (1.5, 6.5), "-|>"),
  )
]
]

---

=== Cykl życia SNP
#v(0.5in)
Obsługa karty sieciowej na takim poziomie to tylko kilka wywołań.
#v(0.2in)
#align(center)[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    fill: (c, r) => if r == 0 { rgb("DAF2F5") } else { none },
    stroke: none,
    row-gutter: 0.8em,
    [*Krok*], [*Funkcja i znaczenie*],
    [1. Pobudka], [`Start()` -- Włącza zasilanie układu PHY karty sieciowej.],
    [2. Konfiguracja], [`Initialize()` -- Resetuje bufory i negocjuje link (np. 1 Gbps).],
    [#v(1in); 3. Filtrowanie], [#v(1in); `ReceiveFilters()` -- Określa, jakie pakiety dopuszczać],
    [4. Pętla Gry], [`Transmit()` / `Receive()` -- Nadawanie i ciągłe odpytywanie sprzętu o dane.],
    [5. Wyłączanie], [`Shutdown()` / `Stop()` -- Usypia sprzęt po powrocie do menu.],
  )
]
---
=== Techniki programowania szachów

---

#columns(2)[
  #v(1in)
  === Co to szachownica?

  Siatka o wymiarach 8x8 składająca się z 64 identycznych kwadratów, naprzemiennie jasnych \ i ciemnych...

  #box[#set text(size: 14pt); ...umieszczona między graczami tak, że prawy narożnik bliżej gracza jest biały.]


  #colbreak()

  #colboard("8/8/8/8/8/8/8/8 w - - 0 1")
]



---
=== Jak to widzi komputer?
#v(1in)

Jest kilka pomysłów, każdy jest inny.

---
#v(-1cm)
#columns(2)[
  #v(1.2in)
  === Ponumerowanie pól

  Łatwa konwersja na nasz system:

  - wiersz =  $8 - floor "pole"/8 floor.r$,
  - kolumna = $"pole" mod 8$
  \
  Trudna logika dla figur!

  #colbreak()

  // Generowanie adnotacji: a8 = 0, b8 = 1 ... h1 = 63
  #annotate-board(
    "8/8/8/8/8/8/8/8 w - - 0 1",
    range(0, 64).fold((:), (acc, i) => {
      let file = "abcdefgh".at(calc.rem(i, 8))
      let rank = 8 - int(i / 8) // Odwrócenie osi pionowej planszy
      acc.insert(file + str(rank), str(i))
      acc
    })
  )
]
---

#v(-1cm)
#columns(2)[
  #annotate-board(
    "8/8/8/8/8/8/8/8 w - - 0 1",
    range(0, 64).fold((:), (acc, i) => {
      let file = "abcdefgh".at(calc.rem(i, 8))
      let rank = 8 - int(i / 8)
      acc.insert(file + str(rank), str(i))
      acc
    })
  )
  
  #colbreak()

  // Adnotacje konkretnych offsetów 10x12 wokół króla
  #annotate-board(
    "8/8/8/8/3K4/8/8/8 w - - 0 1",
    (
      "c5": "-9", "d5": "-8", "e5": "-7", 
      "c4": "-1",             "e4": "+1", 
      "c3": "+7", "d3": "+8", "e3": "+9"
    ),
    highlight: ("e3", "e4", "e5", "d3", "d5", "c3", "c4", "c5")
  )
]
---


#columns(2)[
  #v(1in)
  === Ruch przez całą planszę?
  #v(1cm)
  Zdefiniowanie zestawu dopuszczonych ruchów dla każdej figury jest _trudne_.

  Da się prościej :)

  #colbreak()
  #colboard(
      "8/8/8/8/7K/8/8/8 w - - 0 1",
      highlight: ("g3", "g4", "g5", "h3", "h5", "a3", "a4", "a5"),
    )
]

---

=== Układ 0x88

Na nasze potrzeby indeksowanie będę zaczynać od *zera*.\
Pole a8 znajduje się w 0. wierszu i 0. kolumnie.

---
=== Zapis pola
#v(1in)
Numer pola jest zawarty w bajcie.

#box(width: 180pt)[
  #text(blue, size: 48pt)[`0000`]#text(red, size: 48pt)[`0000`]
  #text(blue)[wiersz] #h(1fr) #text(red)[kolumna]

]

Na przykład: pole #text(blue)[f]#text(red)[5] (poprzednio 29) otrzymuje wartość \ #text(blue)[f]#text(red)[5] = #text(blue)[`0100`]#text(red)[`0100`] = `0x`#text(blue)[`3`]#text(red)[`5`]

---
#columns(2)[
  #v(1in)
  === Ponumerowanie pól (0x88)
  #v(1cm)
  Zapis szesnastkowy, bardzo podobny.

  A co z logiką figury?
  #colbreak()

  // Generowanie adnotacji szesnastkowych 0x88 (0x00 na a8)
  #annotate-board(
    "8/8/8/8/8/8/8/8 w - - 0 1",
    range(0, 128).fold((:), (acc, i) => {
      if calc.rem(i, 16) < 8 {
        let file = "abcdefgh".at(calc.rem(i, 16))
        let rank = 8 - int(i / 16) // Odwrócenie dla systemu 0x88
        acc.insert(file + str(rank), hex(i))
      }
      acc
    })
  )
]

--- 

#v(-1cm)
#columns(2)[
  #annotate-board(
    "8/8/8/8/8/8/8/8 w - - 0 1",
    range(0, 128).fold((:), (acc, i) => {
      if calc.rem(i, 16) < 8 {
        let file = "abcdefgh".at(calc.rem(i, 16))
        let rank = 8 - int(i / 16)
        acc.insert(file + str(rank), hex(i))
      }
      acc
    })
  )
  
  #colbreak()

  // Adnotacje offsetów w systemie 0x88
  #annotate-board(
    "8/8/8/8/3K4/8/8/8 w - - 0 1",
    (
      "c5": "-11", "d5": "-10", "e5": "-F", 
      "c4": "-1",               "e4": "+1", 
      "c3": "+F",  "d3": "+10", "e3": "+11"
    ),
    highlight: ("e3", "e4", "e5", "d3", "d5", "c3", "c4", "c5")
  )
]

--- 


#columns(2)[
  #v(1in)
  === Krawędzie a 0x88
  Poniżej znajdują się *wszystkie* kontrole krawędzi w  całym programie:
  ```asm
  is_on_board:
    test rax, 0x88
    ret
  ```


  #colbreak()
  #colboard(
      "8/8/8/8/7K/8/8/8 w - - 0 1",
      highlight: ("g3", "g4", "g5", "h3", "h5"),
    )
  
]
---

=== Zasada działania 0x88
Najwyższy dopuszczalny numer wiersza i kolumny to 7.

#text(blue, size: 36pt)[`0111`]#text(red, size: 36pt)[`0111`]

---

=== Test 0x88: przykłady

#v(1in)

#columns(2)[
  #align(right)[
  #text(blue, size: 36pt)[`0111`]#text(red, size: 36pt)[`0111`]\ 
  `AND` #text(blue, size: 36pt)[`1000`]#text(red, size: 36pt)[`1000`]
  #v(-1em)
  #line(length:50%)
  #v(-1em)
  #text(blue, size: 36pt)[`0000`]#text(red, size: 36pt)[`0000`]\
  ]
  #colbreak()
  #align(left)[
  #text(blue, size: 36pt)[`1001`]#text(red, size: 36pt)[`0111`]\ 
  #text(blue, size: 36pt)[`1000`]#text(red, size: 36pt)[`1000`] `AND`
  #v(-1em)
  #line(length:50%)
  #v(-1em)
  #text(blue, size: 36pt)[`1000`]#text(red, size: 36pt)[`0000`]\

  ]
]

---
#columns(2)[
#v(1in)
=== Co z pozostałym miejscem?
Nie marnuje się :)

Niepoprawne pola, po walidacji, są stosowane jako *komendy silnika*.

#colbreak()

#table(columns: (5em, 5em), rows: (5em, 5em), align: horizon + center, gutter: 0mm, fill: (x, y) => {if x == 0 and y == 0 {green} else {red}})[#rotate(30deg)[Poprawne pola]][][][#rotate(-30deg)[Przestrzeń poleceń]]

]

---
=== Niepoprawne ruchy jako komendy


Takie podejście pozwala przekazać _wszystkie_ aspekty gry \ w bezpieczny sposób w zaledwie trzech bajtach. 


---
=== Ruchy jako komendy: przykłady z kodu
#v(1cm)

#figure(
  ```asm
.check_draw:
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xCC
    je .remote_offer_draw
    ```, 
    caption: [Dowolny ruch z pola `0xCC` (L-3) oznacza, że przeciwnik prosi o remis.]
)

---
=== Ruchy jako komendy: przykłady z kodu II
#v(1cm)

#figure(
  ```asm
.check_hello:
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xEE
    jne .check_reset

    ```, 
    caption: [Dowolny ruch z pola `0xEE` (N-5) oznacza, że przeciwnik dołączył i chce rozpocząć grę.]
)

---

=== Perft: Test silnika

---

=== Skąd taka nazwa?
#v(0.5in)
*Perft* (_Performance Test_) to standardowa metoda testowania *generatorów ruchów*.

Zasada działania jest prosta.
---

=== Zasada działania Perft
#v(0.5in)
*Dane*: pożądana głębokość (N) i pozycja startowa

Dla każdej głębokości ≤ N wyznaczamy wszystkie dopuszczalne ruchy.

Suma ilości wszystkich ruchów ze wszystkich głębokości to wynik testu.
---
=== Po co?
#v(0.5in)
Dowolny błąd logiczny (niewykryty szach, nadmiarowe bicie \ w przelocie) *natychmiast* powoduje niedopuszczalny stan, który zakłamuje wynik gry.

---
#columns(2)[
#v(0.5in)
=== Tabela wyników Perft dla standardowej pozycji

Liczba dopuszczalnych ruchów rośnie wykładniczo.


#colbreak()
#align(center)[
  #table(
    columns: (auto, auto),
    align: center + horizon,
    fill: (c, r) => if r == 0 { rgb("DAF2F5") } else { none },
    stroke: none,
    row-gutter: 0.8em,
    [*Głębokość*], [*Liczba ruchów*],
    [1], [20], 
    [2], [400],
    [5], [4 865 609],
    [6], [119 060 324], 
    [7], [3 195 901 860]
  )
]
]

---

#columns(2)[
#v(1in)
=== Męczenie silnika: Kiwipete
  Dla standardowej pozycji pierwsze kilka ruchów to strata czasu.


  //W 2007 roku Peter McKenzie stworzył słynną pozycję testową zwaną *Kiwipete*. Została ona ułożona specjalnie po to, aby psuć silniki szachowe.

  Pozycja *Kiwipete* na rysunku jest bardziej obciążająca.


  #colbreak()
  #v(0.2in)
  #colboard("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
]

---

=== Dlaczego to trudna pozycja?
#v(0.5in)
 Zaledwie po kilku ruchach pojawiają się problemy typu:
  - szach z odkrycia,
  - przypięcie,
  - roszada w obie strony (+ czasowa i trwała strata prawa),
  - bicie w przelocie,
  - promocje.


---

=== Tabela Perft (Kiwipete)

#align(center)[
  #table(
    columns: (auto, auto),
    align: center + horizon,
    fill: (c, r) => if r == 0 { rgb("DAF2F5") } else { none },
    stroke: none,
    row-gutter: 0.8em,
    [*Głębokość*], [*Liczba ruchów*],
    [1], [48],
    [2], [2039],
    [5], [193 690 690],
    [6], [8 031 647 685],
    [7], [374 190 009 323]
  )
]

---

=== Algorytm rozstawiania planszy Chess960

---

=== Założenia

#v(0.5in)
Normalne założenia dla pozycji początkowej \
szachów, dodatkowo:

#box(width: 70%)[
  #set align(left)
  #set enum(numbering: { it => strong[#numbering("a.", it)] })

  + król znajduje się między wieżami,
  + gońce są na polach przeciwnych kolorów,
  + czarne figury są ustawione symetrycznie poziomo i identycznie pionowo względem białych.

]

---
#columns(2)[
  #v(1in)
  === Startowa plansza
  #colbreak()
  #colboard("8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1")
]

---
#columns(2)[
  #v(1in)
  === Startowa plansza cd.
  Maszyna losująca losuje ziarno...

  #colbreak()

  #colboard("8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1")
]
---
#columns(2)[
  #v(1in)
  === Startowa plansza cd..
  Maszyna losująca losuje ziarno...

  Wynik: *518*

  #v(0.5in)
  #box[#set text(size: 14pt); Oficjalne zasady gry w szachy bardzo liberalnie definiują _maszynę losową_, jednoznacznie dopuszczając na przykład serię rzutów kością, monetą czy wyciąganie kart z talii.]


  #colbreak()

  #colboard("8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1")
]
---
#columns(2)[
=== Start
  #biggrey[518]

  ```asm
  mov rax, 518
  xor rdx, rdx
  ```
  #colbreak()
  #table(
    columns: (auto, auto),
    ```asm rax```, [*`518`*],
    ```asm rbx```, [],
    ```asm rcx```, [],
    ```asm rdx```, [*`0`*],
  )

]
---

// TODO: wyjaśnić DIV
#columns(2)[

=== Wyznaczamy pozycję gońca
  #biggrey[518 / 4 = 129] #text(size: 24pt, gray, weight: 700)[r. 2]

  ```asm
  mov rcx, 4
  div rcx
  ```

  #colbreak()
  #set table(
    stroke: none,

    inset: (right: 1.5em),
  )
  // #colboard("8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1")
  #table(

    columns: (auto, auto),
    ```asm rax```, [#s[`518`] *`128`*],
    ```asm rbx```, [],
    ```asm rcx```, [*`4`*],
    ```asm rdx```, [#s[`0`] *`2`*],
  )
]

---

#columns(2)[
  #v(0.9in)
=== Wyznaczamy pozycję gońca cd.

  #biggrey[2 \* 2 + 1 = #text(orange)[5]]
  ```asm
  mov rbx, rdx
  shl rbx, 1
  ; albo
  ; mul rbx, 2
  inc rbx
  ```
  #colbreak()
  #v(1in)

  #set table(
    stroke: none,

    inset: (right: 1.5em),
  )
  // #colboard("8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1")
  #table(

    columns: (auto, auto),
    ```asm rax```, [#s[`518`] *`128`*],
    ```asm rbx```, text(orange)[*`5`*],
    ```asm rcx```, [`4`],
    ```asm rdx```, [`2`],
  )

]

---
#columns(2)[
  #v(1in)  
  === Kładzenie jasnopolowego gońca

  Wynik #text(orange)[*5*] to numer kolumny \
  dla komputera.

  Dla nas to kolumna _szósta_,\ czyli *f*.
  #colbreak()
  #colboard("5b2/pppppppp/8/8/8/8/PPPPPPPP/5B2 w - - 0 1")
]
---
#columns(2)[
  #v(1cm)
  #biggrey[129 / 4 = 32] #text(size: 24pt, gray, weight: 700)[r. 1]\
  #biggrey[1 \* 2 = #text(orange)[2]]
  ```asm
  xor rdx, rdx
  div rcx
  mov rbx, rdx
  shl rbx, 1
  ```

  #colbreak()

  === Wyznaczamy pozycję drugiego gońca
  #v(1cm)
  #set table(
    stroke: none,

    inset: (right: 1.5em),
  )
  // #colboard("8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1")
  #table(

    columns: (auto, auto),
    ```asm rax```, [#s[`128`] *`32`*],
    ```asm rbx```, [#s[`5`] #text(orange)[*`2`*]],
    ```asm rcx```, [`4`],
    ```asm rdx```, [#s[`2`] *`1`*],
  )

]
---
#columns(2)[
  #v(1in)
  === Kładzenie ciemnopolowego gońca

  Ponownie, system zaczyna liczyć od 0, więc wynik #text(orange)[*2*] przekłada się na _trzecią_ kolumnę.

  #colbreak()

  #colboard("2b2b2/pppppppp/8/8/8/8/PPPPPPPP/2B2B2 w - - 0 1")
]
---
#columns(2)[
#v(1cm)
=== Wyznaczamy pozycję hetmana
  #biggrey[32 / 6 = 5] #text(size: 24pt, gray, weight: 700)[r. #text(orange)[2]]
  ```asm
  mov rcx, 6
  xor rdx, rdx
  div rcx
  ```
  #colbreak()
  Otrzymany wynik (#text(orange)[*2*]) oznacza trzecie wolne pole od lewej.
  \ A które to?

  #set table(
    stroke: none,

    inset: (right: 1.5em),
  )
  // #colboard("8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1")
  #table(

    columns: (auto, auto),
    ```asm rax```, [#s[`32`] *`5`*],
    ```asm rbx```, [`2`],
    ```asm rcx```, [#s[`4`] *`6`*],
    ```asm rdx```, [#s[`2`] #text(orange)[*`2`*]],
  )

]
---
#columns(2)[
  #v(1in)
  Plan jest prosty: zliczamy pola od lewej - jeśli jest wolne, dodajemy 1 do licznika.

  Przygotujmy się do obliczeń:

  ```asm
  mov r8b, dl
  call .znajdz_nte_puste
  ```
  #colbreak()
=== Wybieranie wolnego pola
  #set table(
    stroke: none,

    inset: (right: 1.5em),
  )
  // #colboard("8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1")
  #v(2cm)
  #table(

    columns: (auto, auto),
    ```asm rax```, [#s[`32`] *`5`*],
    ```asm rbx```, [`2`],
    ```asm rcx```, [#s[`4`] *`6`*],
    ```asm rdx```, [#s[`2`] #text(orange)[*`2`*]],
    ```asm r8```,
    [`0x??????`*`02`* ]//#footnote[Ustawienie krótszego podrejestru nie zmienia stanu pozostałych jego bitów. Wyjątek to ustawienie 32-bitowego podrejestru (```asm mov rax, ebx```), które czyści górną połowę rejestru docelowego.]],
  )
]

#box(width: 100%, height: 100%, outset: 50%, fill:white)[
#align(center)[
  #v(-1cm)
  === Funkcja wybierająca wolne pole


#columns(2)[
  ```asm

  ; Bierzemy:  R8B - n
  ; Zwracamy:  RBX - pole
  ;            R8B = 0
  ; Zakładamy: R10 - wskaźnik
  ;            do wiersza
  .znajdz_nte_puste:
    xor rbx, rbx
  .petla:
    cmp byte[r10 + rbx], PUSTE
    jne .dalej
    test r8b, r8b
    jz .ok ; 0? to mamy N pól
    dec r8b


  .dalej:
    inc rbx
    jmp .petla
  .ok:
    ret
  ```
]
]
]
---
#columns(2)[
  #v(1in)
=== Kładzenie hetmana

  Funkcja dała nam znać, że 3. wolne pole jest w kolumnie numer #text(orange)[*3*].
  #colbreak()

  #colboard("2bq1b2/pppppppp/8/8/8/8/PPPPPPPP/2BQ1B2 w - - 0 1")
]
---

=== Ustalamy pozycję skoczków
#v(2cm)
#columns(2)[

  Niespodzianka! Już to zrobiliśmy.

  Reszta z poprzedniego wyznacza pozycję hetmana, \
  a _wynik_ wyznacza pozycję obu skoczków. Jak?
  #colbreak()

  #table(
    columns: (auto, auto),
    ```asm rax```, text(orange)[`5`],
    ```asm rbx```, [`2`],
    ```asm rcx```, [`6`],
    ```asm rdx```, [`2`],
    ```asm r8b```, [#s[`2`] *`0`*],
  )
]
---
#set table(
  fill: (x, y) => {
    if (x == 0) { none } else { (rgb("F0D9B5"), rgb("B58863")).at(calc.rem(x, 2)) }
  },
  row-gutter: 0pt,
  stroke: none,
  inset: (right: 0.25em),
)



#columns(2)[
#v(2cm)
=== Pozycje skoczków
  *Wiemy*, że zostało 5 wolnych pól.

  Dwa miejsca z 5 możemy zająć na $binom(5, 2) = 10$ sposobów.

  Możemy jednoznacznie przenieść wynik w ```asm rax``` na pozycję skoczków.

  #colbreak()
  #v(-0.5in)
  #scale(y: 110%)[
    #v(0.5in)
    #table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr),
      [0], [♘], [♘], [], [], [],
      [1], [♘], [], [♘], [], [],
      [2], [♘], [], [], [♘], [],
      [3], [♘], [], [], [], [♘],
      [4], [], [♘], [♘], [], [],
      [5], [], [♘], [], [♘], [],
      [6], [], [♘], [], [], [♘],
      [7], [], [], [♘], [♘], [],
      [8], [], [], [♘], [], [♘],
      [9], [], [], [], [♘], [♘],
    )
  ]
]

---
=== Pozycje skoczków
#v(0.5in)
#columns(2)[
  Pozycje skoczków są zdefiniowane w tabeli, ale to jedynie indeksy wolnych pól -- wołamy ```asm .znajdz_nte_puste```, jak przy hetmanie.

  Nie brakuje czegoś?

  //#footnote[```asm .znajdz_nte_puste``` czyści ```asm r8b```, a nie wpisaliśmy tam nic od ostatniego użycia; *wiemy*, że rejestr jest pusty, a funkcja zwróci pierwsze wolne pole -- nie musimy ustawiać argumentu po raz kolejny]

  #colbreak()

  ```asm
  ; odczyt z tabeli skoczków
  mov r8b, byte [r9 + rsi]
  call .znajdz_nte_puste
  mov [rsp + rbx], B_SKOCZEK

  mov r8b, byte [r9 + rsi + 1]
  call .znajdz_nte_puste
  mov [rsp + rbx], B_SKOCZEK
  ```

]

---

#columns(2)[
  #v(3in)
  === Kładzenie skoczków

  Funkcja oddała nam po kolei \ *1* oraz *6*, czyli umieszczamy skoczki na kolumnach _b_ oraz _g_.

  #colbreak()
  #v(1.2in)
  #colboard("1nbq1bn1/pppppppp/8/8/8/8/PPPPPPPP/1NBQ1BN1 w - - 0 1")

]

---
#set align(center + horizon)
#v(1in)
#columns(2)[
  #v(1in)
=== Pozycje króla i wież
  Zostały trzy wolne pola i wiemy, że król jest na drugim z nich. Wystarczy tylko:
  - umieścić wieżę na 1. polu,
  - umieścić króla na 1. polu,
  - umieścić wieżę na 1. polu.

  #colbreak()
  ```asm
  xor r8b, r8b
  call .znajdz_nte_puste
  mov byte [rsp + rbx], W_ROOK
  add bl, 0x70
  mov byte [rel WRa], bl

  call .znajdz_nte_puste
  mov byte [rsp + rbx], W_KING
  mov byte [rel WK], bl
  add byte [rel WK], 0x70
  ;powtórz dla drugiej wieży
  ```
]
---
#columns(2)[
  #v(1.8in)
  === Kładzenie reszty figur
  Mamy wszystkie informacje. Możemy zobaczyć, że pozycja \#518 to nic innego jak standardowe otwarcie :)

  #colbreak()
  #v(1cm)
  #colboard("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1")
]

---

=== Wsparcie Chess960 w projekcie
#v(1in)

Chess960 to na razie jedyny wspierany tryb.

Kiedy użytkownik wybiera "normalną" grę, silnik po prostu pomija losowość i wybiera pozycję \#518.

---

#title-slide()