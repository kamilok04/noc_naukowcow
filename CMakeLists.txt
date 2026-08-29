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
"-i${ARCH_AGNOSTIC_ROOT}/inc"
"-i${ARCH_AGNOSTIC_ROOT}/io"
"-i${ARCH_AGNOSTIC_ROOT}/headers"
"-i${ARCH_AGNOSTIC_ROOT}/graphics"
"-i${ARCH_AGNOSTIC_ROOT}/utils"
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
    COMMAND ${CMAKE_COMMAND} 
        -E copy_directory "${SOURCE_ASSETS_DIR}" "${CMAKE_SYSROOT}"
    COMMAND ${CMAKE_COMMAND} 
        -E touch "${CMAKE_CURRENT_BINARY_DIR}/assets_copy.stamp"

    # Depend on all files
    DEPENDS ${ASSET_FILES}
    COMMENT "Kopiowanie zasobów do sysroot..."
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
"-boot-load-size" "4" # wymagane przez -no-emul-boot
"-b" "EFI/BOOT/BOOTX64.EFI" # plik rozruchowy
"-o" "../chessos.iso" 
"${CMAKE_SYSROOT}" 
COMMENT "Tworzenie ISO UDF..."
)



set(BIOS_PATH /usr/share/edk2-ovmf/x64/OVMF.4m.fd)
add_custom_target(run_system DEPENDS compile_system
COMMAND "killall" "qemu-system-x86_64" "||" "true" 
COMMAND "qemu-system-x86_64"
"-cpu" "qemu64"
"-bios" "${BIOS_PATH}" 
"-cdrom" "${CMAKE_SYSROOT}/../chessos.iso"
"$<$<CONFIG:DEBUG>:-s>" # otwórz port 1234 dla debuggera
"$<$<CONFIG:DEBUG>:-S>" # czekaj na zezwolenie od debuggera, zanim zaczniesz działać
# "$<$<CONFIG:DEBUG>:-serial>" "$<$<CONFIG:DEBUG>:stdio>"
)

