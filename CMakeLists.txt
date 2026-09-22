cmake_minimum_required(VERSION 3.30...4.4.0)

# MAKRA ======================================================

MACRO(MACRO_ENSURE_OUT_OF_SOURCE_BUILD MSG)
     STRING(COMPARE EQUAL "${CMAKE_SOURCE_DIR}"
     "${CMAKE_BINARY_DIR}" insource)
     GET_FILENAME_COMPONENT(PARENTDIR ${CMAKE_SOURCE_DIR} PATH)
     STRING(COMPARE EQUAL "${CMAKE_SOURCE_DIR}"
     "${PARENTDIR}" insourcesubdir)
    IF(insource OR insourcesubdir)
        MESSAGE(FATAL_ERROR "${MSG}")
    ENDIF(insource OR insourcesubdir)
ENDMACRO(MACRO_ENSURE_OUT_OF_SOURCE_BUILD)

MACRO(MACRO_ENSURE_SYSROOT DIR)
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E make_directory ${DIR}
    )
    set(CMAKE_SYSROOT ${DIR})
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_SYSROOT}/kernel
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_SYSROOT}/EFI/BOOT
    )
ENDMACRO(MACRO_ENSURE_SYSROOT)
# ============================================================

set(CMAKE_SYSTEM_NAME Generic)


# Wybór języka jednoznacznie określa potrzebę istnienia linkera
# której nie ma :)
project(ChessOS LANGUAGES NONE)
set(CMAKE_ASM_NASM_COMPILER nasm)

MACRO_ENSURE_SYSROOT(${CMAKE_CURRENT_SOURCE_DIR}/sysroot)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set_property(CACHE CMAKE_INSTALL_PREFIX PROPERTY VALUE ${CMAKE_SYSROOT})
endif()


MACRO_ENSURE_OUT_OF_SOURCE_BUILD(
    "${CMAKE_PROJECT_NAME} wymaga zbudowania w folderze 
    niezawierającym źródeł. Skonsultuj się z dokumentacją."
)

set(ARCH_AGNOSTIC_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/kernel")
set(EFI_DIR "${SYSROOT}/EFI/BOOT")
set(OUTPUT_ISO "${CMAKE_CURRENT_BINARY_DIR}/chessos.iso")



add_custom_target(boot
COMMAND ${CMAKE_ASM_NASM_COMPILER}
"${ARCH_AGNOSTIC_ROOT}/efi.asm" 
"-i${ARCH_AGNOSTIC_ROOT}/headers"
"-i${ARCH_AGNOSTIC_ROOT}/inc"
"-i${ARCH_AGNOSTIC_ROOT}/io/files"
"-i${ARCH_AGNOSTIC_ROOT}/io/mouse"
"-i${ARCH_AGNOSTIC_ROOT}/io/network"
"-i${ARCH_AGNOSTIC_ROOT}/graphics"
"-i${ARCH_AGNOSTIC_ROOT}/utils"
"-i${ARCH_AGNOSTIC_ROOT}/chess"
"-i${ARCH_AGNOSTIC_ROOT}/chess/logic"
"-i${ARCH_AGNOSTIC_ROOT}/chess/graphics"
"-i${ARCH_AGNOSTIC_ROOT}/chess/c960"
"-fbin"
"-o${CMAKE_SYSROOT}/EFI/BOOT/BOOTX64.EFI" 
"$<$<CONFIG:DEBUG>:-L+listings/efi.lst>"
# "$<$<CONFIG:DEBUG>:-llistings/efi.lst>"
)


set(EFI_ROOT ${CMAKE_SYSROOT}/EFI/BOOT)

# Create an assets folder
set(SOURCE_ASSETS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/assets")

# Grab its contents
file(GLOB_RECURSE ASSET_FILES CONFIGURE_DEPENDS "${SOURCE_ASSETS_DIR}/*")

# Copy on diff
add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/assets_copy.stamp"
    COMMAND ${CMAKE_COMMAND} -E rm -rf "${CMAKE_SYSROOT}/ASSETS"
    COMMAND ${CMAKE_COMMAND} 
        -E copy_directory "${SOURCE_ASSETS_DIR}" "${CMAKE_SYSROOT}/ASSETS"
    COMMAND ${CMAKE_COMMAND} 
        -E touch "${CMAKE_CURRENT_BINARY_DIR}/assets_copy.stamp"
    DEPENDS ${ASSET_FILES}
    COMMENT "Synchronizowanie zasobów do sysroot/ASSETS..."
)

add_custom_target(compile_system ALL DEPENDS boot
    kernel 
    "${CMAKE_CURRENT_BINARY_DIR}/assets_copy.stamp"

# standard UEFI, punkt 13.3.2.1
# można uruchomić płytę po UEFI, nie emulując dyskietki ani dysku, 
# jeśli jednocześnie:
# 1. jest w formacie ISO9660, ale ma struktury UDF 2.0,
# 2. jest tylko jeden system ISO9660 na płycie,
# 3. płyta spełnia warunki El Torrito (czyli da się ją uruchomić po BIOS)
# Wtedy bootloader jest traktowany jak program EFI.

# dlaczego to ważne, że nie emulujemy?
# UEFI zapewnia łatwy dostęp do urządzenia, z którego bootujesz
# gdyby użyć starszego podejścia (dyskietka FAT12), 
# to musiałbym i tak znaleźć swoje DVD
# a teraz nie jest to potrzebne
# poza tym ogromny plus: nie muszę tworzyć sterownika systemu plików,
# bo UEFI łaskawie to robi za mnie

COMMAND "mkisofs" 
"-udf"
"-input-charset" "iso8859-1"
"-R" # włącz uniksopodobne nazwy plików + atrybuty dostępu
"-iso-level" "3" # zezwól na duże pliki
"-V" "'ChessOS '" 
#"-U" # nagnij specyfikację i rozszerz zestaw znaków nazw plików
"-no-emul-boot" # nie ma emulacji dyskietki
"-b" "EFI/BOOT/BOOTX64.EFI" # plik rozruchowy
"-o" "../chessos.iso" 
"${CMAKE_SYSROOT}" 
COMMENT "Tworzenie ISO UDF..."
)



set(BIOS_PATH /usr/share/edk2-ovmf/x64/ovmf_custom.fd)
set(QEMU_BASE_ARGS
    "-cpu" "qemu64"
    "-bios" "${BIOS_PATH}"
    "-cdrom" "${CMAKE_SYSROOT}/../chessos.iso"
    "-device" "qemu-xhci"
    "-device" "usb-mouse"
    "-device" "virtio-rng-pci"
    "-display" "gtk,show-tabs=on"
    "-machine" "q35"
)
add_custom_target(run_host DEPENDS compile_system
    COMMAND "qemu-system-x86_64"
    ${QEMU_BASE_ARGS}
    # Utwórz sieć multicast, przydziel MAC z :01 na koniec
    "-netdev" "socket,id=net0,mcast=230.0.0.1:1234"
    "-device" "e1000,netdev=net0,mac=52:54:00:12:34:01"
    "-chardev" "stdio,id=char0,logfile=serial_host.log,signal=off"
    "-serial" "chardev:char0"
    "$<$<CONFIG:DEBUG>:-s>"
    "$<$<CONFIG:DEBUG>:-S>"
)
add_custom_target(run_client DEPENDS compile_system
    COMMAND "qemu-system-x86_64"
    ${QEMU_BASE_ARGS}
    "-netdev" "socket,id=net0,mcast=230.0.0.1:1234"
    # ta sama sieć, ale MAC z :02 na finiszu
    "-device" "e1000,netdev=net0,mac=52:54:00:12:34:02"
    "-chardev" "stdio,id=char0,logfile=serial_client.log,signal=off"
    "-serial" "chardev:char0"
)

add_custom_target(run_both DEPENDS compile_system
    COMMAND "qemu-system-x86_64"
    ${QEMU_BASE_ARGS}
    "-netdev" "socket,id=net0,mcast=230.0.0.1:1234"
    "-device" "e1000,netdev=net0,mac=52:54:00:12:34:02"
    "-chardev" "stdio,id=char0,logfile=serial_client.log,signal=off"
    "-serial" "chardev:char0" 
    "&"
    
    COMMAND "qemu-system-x86_64"
    ${QEMU_BASE_ARGS}
    "-netdev" "socket,id=net0,mcast=230.0.0.1:1234"
    "-device" "e1000,netdev=net0,mac=52:54:00:12:34:01"
    "-chardev" "stdio,id=char1,logfile=serial_host.log,signal=off"
    "-serial" "chardev:char1"
    "$<$<CONFIG:DEBUG>:-s>"
    "$<$<CONFIG:DEBUG>:-S>"
)

# debug: uruchom z fizycznego dysku USB podłączonego do stanowiska
add_custom_target(run_usb
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/run_qemu_usb.sh" "${BIOS_PATH}"
    COMMENT "Uruchamianie QEMU z fizycznego dysku USB..."
    USES_TERMINAL
)