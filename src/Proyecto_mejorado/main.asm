; ============================================================================
; Lenguajes de Interfaz - Unidad 2 | Tienda de videojuegos: ventas e inventario
; MASM x86 32 bits + Irvine32
; DESCUENTO POR CANTIDAD (10 o mas unidades -> 10%, sin fraccion de centavo)
; Archivo "inventario.txt":  INV1<CR><LF>  y luego  ABC-123;Nombre;CENTAVOS;EXISTENCIA<CR><LF>
; (Los textos de consola no llevan acentos para que la consola no muestre basura)
; CONVENCION DE RESULTADOS de los procedimientos propios (sin banderas especiales):
;   EDX = 0  -> operacion correcta / dato valido
;   EDX = 1  -> operacion rechazada / dato invalido
; ============================================================================
INCLUDE Irvine32.inc

MAX_PRODUCTOS     = 10
TAM_REGISTRO      = 44
DESP_NOMBRE       = 8
DESP_PRECIO       = 36
DESP_EXISTENCIA   = 40
MAX_EXISTENCIA    = 100
PRECIO_MAXIMO     = 999999            ; $9999.99 en centavos
MAX_CARACTERES_ENTRADA = 127
TAM_BUFFER_ARCHIVO = 600
UNIDADES_PARA_DESCUENTO = 10
PORCENTAJE_DESCUENTO    = 10
MAX_INTENTOS      = 3                 ; intentos por dato antes de cancelar la operacion

.data
catalogoProductos   BYTE MAX_PRODUCTOS*TAM_REGISTRO DUP(0)
catalogoTemporal    BYTE MAX_PRODUCTOS*TAM_REGISTRO DUP(0)  ; catalogo temporal: se valida aqui antes de reemplazar
totalProductos      DWORD 0
hayCambiosSinGuardar DWORD 0                        ; 1 = cambios sin guardar
ingresosSesion      DWORD 0                         ; centavos vendidos en la sesion
finDatosLeidos      DWORD 0
espInicial          DWORD 0
intentosRestantes   DWORD 0
archivoHandle       DWORD 0                         ; identificador del archivo abierto
bytesPorEscribir    DWORD 0
bytesEscritos       DWORD 0
bytesLeidos         DWORD 0
ptrRegistroTemporal DWORD 0
bufferEntrada       BYTE 128 DUP(0)
bufferBasura        BYTE 128 DUP(0)
bufferNumero        BYTE 16 DUP(0)
bufferArchivo       BYTE TAM_BUFFER_ARCHIVO DUP(0)
nombreArchivo       BYTE "inventario.txt",0
encabezadoArchivo   BYTE "INV1",0

textoMenu    BYTE 0Dh,0Ah,"== TIENDA DE VIDEOJUEGOS ==",0Dh,0Ah,"1 Registrar  2 Inventario  3 Buscar  4 Recibir",0Dh,0Ah
             BYTE "5 Vender  6 Resumen  7 Guardar  8 Cargar  0 Salir",0Dh,0Ah,"Opcion: ",0
txtPedirCodigo       BYTE "Codigo (ABC-123): ",0
txtPedirNombre       BYTE "Nombre (1 a 25 caracteres): ",0
txtPedirPrecio       BYTE "Precio MXN (ej. 185.50): ",0
txtPedirExistencia   BYTE "Existencia (0 a 100): ",0
txtPedirUnidadesRecibidas BYTE "Unidades recibidas: ",0
txtPedirUnidadesVenta     BYTE "Unidades a vender: ",0
txtPreguntaGuardarAlSalir BYTE "Hay cambios sin guardar. Guardar? (S=guardar, N=descartar, otra=cancelar): ",0
txtPreguntaConfirmarCarga BYTE "Hay cambios sin guardar, cargar los reemplaza. Continuar? (S/N): ",0
msgOpcionInvalida    BYTE "Opcion no valida.",0Dh,0Ah,0
msgCodigoInvalido    BYTE "Codigo invalido (3 letras mayusculas, guion, 3 digitos).",0Dh,0Ah,0
msgCodigoDuplicado   BYTE "Rechazado: codigo duplicado.",0Dh,0Ah,0
msgCatalogoLleno     BYTE "Rechazado: catalogo lleno (10 productos).",0Dh,0Ah,0
msgNombreInvalido    BYTE "Nombre invalido (1 a 25 caracteres, sin ';').",0Dh,0Ah,0
msgPrecioInvalido    BYTE "Precio invalido (0.01 a 9999.99; pesos o punto con 1-2 decimales).",0Dh,0Ah,0
msgExistenciaInvalida BYTE "Existencia invalida (entero de 0 a 100).",0Dh,0Ah,0
msgCantidadInvalida  BYTE "Cantidad invalida (entero mayor que cero, solo digitos).",0Dh,0Ah,0
msgDemasiadosIntentos BYTE "Demasiados intentos. Operacion cancelada, no se modifico nada.",0Dh,0Ah,0
msgProductoNoEncontrado BYTE "Producto no encontrado.",0Dh,0Ah,0
msgProductoRegistrado   BYTE "Producto registrado.",0Dh,0Ah,0
msgInventarioVacio   BYTE "Inventario vacio.",0Dh,0Ah,0
encabezadoInventario BYTE "CODIGO | NOMBRE | PRECIO | EXISTENCIA",0Dh,0Ah,0
msgExcedeCapacidad   BYTE "Rechazado: excede 100 unidades.",0Dh,0Ah,0
msgMercanciaRecibida BYTE "Recibido. Nueva existencia: ",0
msgExistenciasInsuficientes BYTE "Rechazado: existencias insuficientes.",0Dh,0Ah,0
msgDesbordamiento    BYTE "Rechazado: desbordamiento. No se modifico nada.",0Dh,0Ah,0
etiquetaImporteBase  BYTE "Importe base : ",0
etiquetaDescuento    BYTE "Descuento    : ",0
etiquetaTotal        BYTE "TOTAL        : ",0
tituloResumen        BYTE 0Dh,0Ah,"--- RESUMEN ---",0Dh,0Ah,0
etiquetaUnidades     BYTE "Unidades disponibles : ",0
etiquetaValorInventario BYTE "Valor del inventario : ",0
etiquetaIngresos     BYTE "Ingresos de la sesion: ",0
msgGuardadoCorrecto  BYTE "Catalogo guardado.",0Dh,0Ah,0
msgErrorArchivo      BYTE "Error de archivo (crear, escribir, leer o cerrar).",0Dh,0Ah,0
msgArchivoAusente    BYTE "El archivo inventario.txt no existe. Catalogo intacto.",0Dh,0Ah,0
msgArchivoInvalido   BYTE "Archivo invalido o danado. Catalogo intacto.",0Dh,0Ah,0
msgCargaCorrecta     BYTE "Catalogo cargado. Productos: ",0
msgPilaDesbalanceada BYTE "*** ERROR: pila desbalanceada ***",0Dh,0Ah,0
textoPunto           BYTE ".",0
textoCero            BYTE "0",0
textoMXN             BYTE " MXN",0
textoSeparador       BYTE " | ",0

IMPRIMIR_TEXTO MACRO texto
    mov edx, OFFSET texto
    call WriteString
ENDM

AGREGAR_BYTE MACRO valor
    mov BYTE PTR [edi], valor
    inc edi
ENDM

AGREGAR_NUEVA_LINEA MACRO
    AGREGAR_BYTE 0Dh
    AGREGAR_BYTE 0Ah
ENDM

VERIFICAR_ERROR MACRO etiqueta
    test edx, edx
    jnz etiqueta
ENDM

.code
; ============================ PROGRAMA PRINCIPAL ============================
main PROC
    mov espInicial, esp                  ; referencia para comprobar la pila
    call CargarArchivo                   ; carga inventario.txt al iniciar (si existe)
menu_ciclo:
    mov edx, OFFSET textoMenu
    call CapturarTexto                   ; EAX = caracteres capturados
    cmp eax, 1
    jne menu_invalido
    mov al, [bufferEntrada]
    cmp al, '0'
    je menu_salir
    cmp al, '1'
    jne menu_opcion2
    call RegistrarProducto
    jmp menu_verificarPila
menu_opcion2:
    cmp al, '2'
    jne menu_opcion3
    call MostrarInventario
    jmp menu_verificarPila
menu_opcion3:
    cmp al, '3'
    jne menu_opcion4
    call BuscarProductoMenu
    jmp menu_verificarPila
menu_opcion4:
    cmp al, '4'
    jne menu_opcion5
    call RecibirMercancia
    jmp menu_verificarPila
menu_opcion5:
    cmp al, '5'
    jne menu_opcion6
    call VenderProducto
    jmp menu_verificarPila
menu_opcion6:
    cmp al, '6'
    jne menu_opcion7
    call MostrarResumen
    jmp menu_verificarPila
menu_opcion7:
    cmp al, '7'
    jne menu_opcion8
    call GuardarArchivo
    jmp menu_verificarPila
menu_opcion8:
    cmp al, '8'
    jne menu_invalido
    call CargarArchivo
menu_verificarPila:
    cmp esp, espInicial                  ; evidencia: pila equilibrada tras cada CALL
    je menu_ciclo
    IMPRIMIR_TEXTO msgPilaDesbalanceada
    mov espInicial, esp
    jmp menu_ciclo
menu_invalido:
    IMPRIMIR_TEXTO msgOpcionInvalida
    jmp menu_ciclo
menu_salir:
    cmp hayCambiosSinGuardar, 0
    je menu_fin
    mov edx, OFFSET txtPreguntaGuardarAlSalir
    call CapturarTexto
    mov al, [bufferEntrada]
    or al, 20h                           ; a minuscula (mascara OR, tema 2.12)
    cmp al, 's'
    jne menu_noGuardar
    call GuardarArchivo
    VERIFICAR_ERROR menu_ciclo                       ; si fallo el guardado no se sale
    jmp menu_fin
menu_noGuardar:
    cmp al, 'n'
    jne menu_ciclo                       ; cualquier otra tecla cancela la salida
menu_fin:
    exit
main ENDP

; ============================ CAPTURA Y CADENAS ============================
; CapturarTexto: Entrada EDX=prompt
;   Salida EAX=num. de caracteres, ESI=bufferEntrada (texto con 00h)
;          EDX=0 normal | EDX=1 si la linea fue demasiado larga (se descarta el resto)
;   Modifica EAX, ECX, EDX, ESI
CapturarTexto PROC
    call WriteString
    mov edx, OFFSET bufferEntrada        ; EDX = donde guardar la entrada
    mov ecx, MAX_CARACTERES_ENTRADA      ; ECX = maximo de caracteres
    call ReadString                      ; EAX = caracteres leidos
    mov esi, OFFSET bufferEntrada
    xor edx, edx
    cmp eax, MAX_CARACTERES_ENTRADA-2
    jb capturar_fin
capturar_vaciar:                         ; ciclo condicional: tira lo que sobro de la linea
    mov edx, OFFSET bufferBasura
    mov ecx, MAX_CARACTERES_ENTRADA
    call ReadString
    cmp eax, MAX_CARACTERES_ENTRADA-2
    jae capturar_vaciar
    mov eax, MAX_CARACTERES_ENTRADA      ; marca la entrada como demasiado larga
    mov esi, OFFSET bufferEntrada
    mov edx, 1
capturar_fin:
    ret
CapturarTexto ENDP

; CadenasIguales: Entrada ESI, EDI = cadenas | Salida ZF=1 si son iguales | Modifica solo banderas
CadenasIguales PROC USES esi edi eax
compararCadenas_ciclo:
    mov al, [esi]
    cmp al, [edi]
    jne compararCadenas_fin              ; ZF=0
    test al, al
    jz compararCadenas_fin               ; ZF=1
    inc esi
    inc edi
    jmp compararCadenas_ciclo
compararCadenas_fin:
    ret
CadenasIguales ENDP

; CopiarCadena: Entrada ESI=origen, EDI=destino | copia incluyendo 00h
;          Salida ESI y EDI quedan sobre el 00h | Modifica ESI, EDI, AL
CopiarCadena PROC
copiarCadena_ciclo:
    mov al, [esi]
    mov [edi], al
    test al, al
    jz copiarCadena_fin
    inc esi
    inc edi
    jmp copiarCadena_ciclo
copiarCadena_fin:
    ret
CopiarCadena ENDP

; AvanzarAlSiguienteCampo: Entrada ESI en un campo | Salida ESI al inicio del siguiente campo (tras el 00h)
AvanzarAlSiguienteCampo PROC
siguienteCampo_ciclo:
    cmp BYTE PTR [esi], 0
    je siguienteCampo_fin
    inc esi
    jmp siguienteCampo_ciclo
siguienteCampo_fin:
    inc esi
    ret
AvanzarAlSiguienteCampo ENDP

; SaltarSaltoDeLinea: si ESI esta sobre un 00h (el LF de un CR LF) lo salta | Modifica ESI
SaltarSaltoDeLinea PROC
    cmp BYTE PTR [esi], 0
    jne saltoLinea_fin
    inc esi
saltoLinea_fin:
    ret
SaltarSaltoDeLinea ENDP

; ============================ VALIDACIONES (cadenas con formato) ============================
; ValidarCodigo: Entrada ESI=cadena | Salida EDX=0 si cumple AAA-999, EDX=1 si NO | Modifica EDX
ValidarCodigo PROC USES eax ecx esi
    mov ecx, 3                           ; tres letras: ciclo numerico con LOOP
validarCodigo_letras:
    mov al, [esi]
    cmp al, 'A'
    jb validarCodigo_error
    cmp al, 'Z'
    ja validarCodigo_error
    inc esi
    loop validarCodigo_letras
    cmp BYTE PTR [esi], '-'
    jne validarCodigo_error
    inc esi
    mov ecx, 3                           ; tres digitos
validarCodigo_digitos:
    mov al, [esi]
    cmp al, '0'
    jb validarCodigo_error
    cmp al, '9'
    ja validarCodigo_error
    inc esi
    loop validarCodigo_digitos
    cmp BYTE PTR [esi], 0                ; debe terminar aqui
    jne validarCodigo_error
    xor edx, edx
    jmp validarCodigo_salida
validarCodigo_error:
    mov edx, 1
validarCodigo_salida:
    ret
ValidarCodigo ENDP

; ValidarNombre: Entrada ESI | Salida EDX=0 si tiene 1 a 25 caracteres ASCII 32..126, sin ';'
;   y con al menos un caracter que no sea espacio; EDX=1 si no | Modifica EDX
ValidarNombre PROC USES eax ebx ecx esi
    xor ecx, ecx                         ; contador de caracteres
    xor ebx, ebx                         ; caracteres que no son espacio
validarNombre_ciclo:
    mov al, [esi]
    test al, al
    jz validarNombre_fin
    cmp al, 32
    jb validarNombre_error
    cmp al, 126
    ja validarNombre_error
    cmp al, ';'
    je validarNombre_error               ; ';' separa campos en el archivo
    cmp al, ' '
    je validarNombre_espacio
    inc ebx
validarNombre_espacio:
    inc ecx
    cmp ecx, 25
    ja validarNombre_error
    inc esi
    jmp validarNombre_ciclo
validarNombre_fin:
    test ecx, ecx                        ; vacio = invalido
    jz validarNombre_error
    test ebx, ebx                        ; solo espacios = invalido
    jz validarNombre_error
    xor edx, edx
    jmp validarNombre_salida
validarNombre_error:
    mov edx, 1
validarNombre_salida:
    ret
ValidarNombre ENDP

; ============================ CONVERSIONES DE ENTRADA ============================
; ConvertirCadenaAEntero: Entrada ESI=cadena solo con digitos
;   Salida EAX=valor, EDX=0 si es valida | EDX=1 si vacia, con caracteres no permitidos o desbordamiento
;   Modifica EAX, EDX. Conserva EBX, ECX, ESI.
ConvertirCadenaAEntero PROC USES ebx ecx esi
    xor eax, eax                         ; acumulador
    mov ecx, 10
    cmp BYTE PTR [esi], 0
    je convertirEntero_error             ; cadena vacia
convertirEntero_ciclo:
    xor ebx, ebx
    mov bl, [esi]
    test ebx, ebx
    jz convertirEntero_ok
    sub ebx, '0'                         ; ASCII -> digito
    cmp ebx, 9
    ja convertirEntero_error             ; no es digito
    mul ecx                              ; EDX:EAX = EAX * 10
    jc convertirEntero_error             ; desbordamiento
    add eax, ebx
    jc convertirEntero_error             ; desbordamiento
    inc esi
    jmp convertirEntero_ciclo
convertirEntero_ok:
    xor edx, edx
    jmp convertirEntero_salida
convertirEntero_error:
    mov edx, 1
convertirEntero_salida:
    ret
ConvertirCadenaAEntero ENDP

; ConvertirPrecioACentavos: Entrada ESI = "185.50", "185.5" o "185"
;   Salida EAX=centavos (1..999999) y EDX=0, o EDX=1 si es invalido | Modifica EAX, EDX
;   Acumula todos los digitos sin el punto, cuenta los decimales (ECX) y al final
;   multiplica por 10 las veces que falten para tener 2 decimales. Un 3er decimal se rechaza.
ConvertirPrecioACentavos PROC USES ebx ecx edi esi
    xor eax, eax                         ; acumulado
    xor ebx, ebx                         ; digitos de pesos
    xor ecx, ecx                         ; decimales
    xor edi, edi                         ; 1 = ya hubo punto
convertirPrecio_ciclo:
    xor edx, edx
    mov dl, [esi]
    test edx, edx
    jz convertirPrecio_fin
    cmp edx, '.'
    jne convertirPrecio_digitos
    test edi, edi
    jnz convertirPrecio_error            ; segundo punto
    mov edi, 1
    jmp convertirPrecio_siguiente
convertirPrecio_digitos:
    sub edx, '0'
    cmp edx, 9
    ja convertirPrecio_error             ; simbolo, coma, letra o espacio
    imul eax, eax, 10
    add eax, edx
    cmp eax, PRECIO_MAXIMO
    ja convertirPrecio_error             ; corta antes de desbordar
    test edi, edi
    jnz convertirPrecio_decimales
    inc ebx
    jmp convertirPrecio_siguiente
convertirPrecio_decimales:
    inc ecx
    cmp ecx, 2
    ja convertirPrecio_error             ; tercer decimal
convertirPrecio_siguiente:
    inc esi
    jmp convertirPrecio_ciclo
convertirPrecio_fin:
    test ebx, ebx
    jz convertirPrecio_error             ; sin pesos
    test edi, edi
    jz convertirPrecio_escalar
    test ecx, ecx
    jz convertirPrecio_error             ; "185." sin decimales
convertirPrecio_escalar:
    mov edx, 2
    sub edx, ecx                         ; decimales que faltan
convertirPrecio_multiplicar:
    test edx, edx
    jz convertirPrecio_rango
    imul eax, eax, 10
    dec edx
    jmp convertirPrecio_multiplicar
convertirPrecio_rango:
    cmp eax, 1
    jb convertirPrecio_error
    cmp eax, PRECIO_MAXIMO
    ja convertirPrecio_error
    xor edx, edx
    jmp convertirPrecio_salida
convertirPrecio_error:
    mov edx, 1
convertirPrecio_salida:
    ret
ConvertirPrecioACentavos ENDP

; ============================ BUSQUEDA (recorrido con ESI) ============================
; BuscarProductoPorCodigo: Entrada ESI=primer registro, ECX=cuantos, EDI=codigo
;           Salida ESI=registro encontrado, o ESI=0 si no existe | Modifica ESI, banderas
BuscarProductoPorCodigo PROC USES ecx
    test ecx, ecx
    jz buscarProducto_noEncontrado
buscarProducto_ciclo:
    call CadenasIguales                  ; codigo del registro (ESI+0) contra EDI
    je buscarProducto_salida
    add esi, TAM_REGISTRO                ; siguiente registro
    loop buscarProducto_ciclo
buscarProducto_noEncontrado:
    xor esi, esi
buscarProducto_salida:
    ret
BuscarProductoPorCodigo ENDP

; CapturarCodigoYBuscar: pide un codigo (hasta MAX_INTENTOS veces si el formato es invalido) y lo busca
;   Salida EDX=0 y ESI=registro (o ESI=0 si no existe) | EDX=1 si no se obtuvo un codigo valido
;   Modifica ESI, EDX
CapturarCodigoYBuscar PROC USES eax ecx edi
    mov intentosRestantes, MAX_INTENTOS
capturarCodigo_pedir:
    mov edx, OFFSET txtPedirCodigo
    call CapturarTexto
    VERIFICAR_ERROR capturarCodigo_error             ; linea demasiado larga
    call ValidarCodigo
    test edx, edx
    jz capturarCodigo_valido
capturarCodigo_error:
    IMPRIMIR_TEXTO msgCodigoInvalido
    dec intentosRestantes
    jnz capturarCodigo_pedir             ; repite mientras queden intentos
    IMPRIMIR_TEXTO msgDemasiadosIntentos
    mov edx, 1
    jmp capturarCodigo_fin
capturarCodigo_valido:
    mov edi, esi
    mov esi, OFFSET catalogoProductos
    mov ecx, totalProductos
    call BuscarProductoPorCodigo
    xor edx, edx
capturarCodigo_fin:
    ret
CapturarCodigoYBuscar ENDP

; CapturarCodigoExistente: como CapturarCodigoYBuscar pero exige que exista | Salida EDX=1 si falla, ESI=registro
CapturarCodigoExistente PROC
    call CapturarCodigoYBuscar
    VERIFICAR_ERROR capturarExistente_salida
    test esi, esi
    jnz capturarExistente_salida         ; existe: EDX sigue en 0
    IMPRIMIR_TEXTO msgProductoNoEncontrado
    mov edx, 1
capturarExistente_salida:
    ret
CapturarCodigoExistente ENDP

; CapturarCantidad: Entrada EDX=prompt | Salida EAX=entero > 0 y EDX=0, o EDX=1 si se rechazo
;   Repite la captura hasta MAX_INTENTOS veces | Modifica EAX, EDX
CapturarCantidad PROC USES ebx esi
    mov ebx, edx                         ; EBX = prompt
    mov intentosRestantes, MAX_INTENTOS
capturarCantidad_pedir:
    mov edx, ebx
    call CapturarTexto
    VERIFICAR_ERROR capturarCantidad_error
    call ConvertirCadenaAEntero
    VERIFICAR_ERROR capturarCantidad_error
    test eax, eax
    jnz capturarCantidad_ok
capturarCantidad_error:
    IMPRIMIR_TEXTO msgCantidadInvalida
    dec intentosRestantes
    jnz capturarCantidad_pedir
    IMPRIMIR_TEXTO msgDemasiadosIntentos
    mov edx, 1
    jmp capturarCantidad_salida
capturarCantidad_ok:
    xor edx, edx
capturarCantidad_salida:
    ret
CapturarCantidad ENDP

; ============================ SALIDA: NUMERO -> CADENA ============================
; EnteroACadena: Entrada EAX=valor, EDI=destino | Salida digitos ASCII en [EDI], EDI = siguiente byte libre
;   DIV entre 10: el residuo es el ultimo digito; la pila invierte el orden. Modifica EAX, EDI
EnteroACadena PROC USES ebx ecx edx
    mov ebx, 10
    xor ecx, ecx                         ; cuenta digitos
enteroACadena_dividir:
    xor edx, edx                         ; dividendo = EDX:EAX
    div ebx                              ; EAX = cociente, EDX = residuo
    push edx
    inc ecx
    test eax, eax
    jnz enteroACadena_dividir
enteroACadena_salida:
    pop edx                              ; sale primero el digito mas significativo
    add dl, '0'                          ; digito -> ASCII
    mov [edi], dl
    inc edi
    loop enteroACadena_salida
    ret
EnteroACadena ENDP

; MostrarEntero: Entrada EAX=valor | Muestra el numero con WriteString | Modifica nada
MostrarEntero PROC USES eax edx edi
    mov edi, OFFSET bufferNumero
    call EnteroACadena
    mov BYTE PTR [edi], 0
    IMPRIMIR_TEXTO bufferNumero
    ret
MostrarEntero ENDP

; MostrarImporteMXN: Entrada EAX=centavos | Muestra "pesos.cc MXN" (residuo 5 -> "05") | Modifica nada
MostrarImporteMXN PROC USES eax ebx edx
    xor edx, edx
    mov ebx, 100
    div ebx                              ; EAX = pesos, EDX = centavos
    push edx
    call MostrarEntero
    IMPRIMIR_TEXTO textoPunto
    pop eax                              ; centavos
    cmp eax, 10
    jae mostrarImporte_centavosDosDigitos
    IMPRIMIR_TEXTO textoCero
mostrarImporte_centavosDosDigitos:
    call MostrarEntero
    IMPRIMIR_TEXTO textoMXN
    ret
MostrarImporteMXN ENDP

; MostrarLineaImporte: Entrada EDX=etiqueta, EAX=centavos | Muestra "etiqueta importe MXN" | Modifica EDX
MostrarLineaImporte PROC
    push eax
    call WriteString
    pop eax
    call MostrarImporteMXN
    call Crlf
    ret
MostrarLineaImporte ENDP

; MostrarProducto: Entrada ESI=registro | Muestra codigo | nombre | precio | existencia | Modifica nada
MostrarProducto PROC USES eax edx
    mov edx, esi                         ; el codigo esta en el byte 0 del registro
    call WriteString
    IMPRIMIR_TEXTO textoSeparador
    mov edx, esi
    add edx, DESP_NOMBRE
    call WriteString
    IMPRIMIR_TEXTO textoSeparador
    mov eax, [esi+DESP_PRECIO]
    call MostrarImporteMXN
    IMPRIMIR_TEXTO textoSeparador
    mov eax, [esi+DESP_EXISTENCIA]
    call MostrarEntero
    call Crlf
    ret
MostrarProducto ENDP

; ============================ OPCIONES DEL MENU ============================
; Los PROC que declaran USES guardan/restauran automaticamente los registros listados
; por MASM. Los registros que transportan resultados se dejan fuera de USES.
; Las instrucciones PUSH/POP que aun aparecen son temporales internos y estan balanceadas.

; RegistrarProducto: escribe en el registro libre y solo lo cuenta (totalProductos) si TODO fue valido
;   Cada dato se repite hasta MAX_INTENTOS veces si es invalido.
RegistrarProducto PROC USES eax ebx ecx edx esi edi
    cmp totalProductos, MAX_PRODUCTOS
    jb registrar_hayEspacio
    mov edx, OFFSET msgCatalogoLleno     ; capacidad superada
    jmp registrar_mensaje
registrar_hayEspacio:
    call CapturarCodigoYBuscar
    VERIFICAR_ERROR registrar_fin                    ; ya se mostro el mensaje
    test esi, esi
    jz registrar_codigoLibre
    mov edx, OFFSET msgCodigoDuplicado   ; ya existe
    jmp registrar_mensaje
registrar_codigoLibre:
    mov eax, totalProductos
    imul ebx, eax, TAM_REGISTRO
    add ebx, OFFSET catalogoProductos    ; EBX = registro libre
    mov esi, OFFSET bufferEntrada
    mov edi, ebx
    call CopiarCadena                    ; codigo
    ; ---- nombre ----
    mov intentosRestantes, MAX_INTENTOS
registrar_pedirNombre:
    mov edx, OFFSET txtPedirNombre
    call CapturarTexto
    VERIFICAR_ERROR registrar_nombreMal
    call ValidarNombre
    test edx, edx
    jz registrar_nombreBien
registrar_nombreMal:
    IMPRIMIR_TEXTO msgNombreInvalido
    dec intentosRestantes
    jnz registrar_pedirNombre
    jmp registrar_cancelar
registrar_nombreBien:
    mov edi, ebx
    add edi, DESP_NOMBRE
    call CopiarCadena                    ; nombre (ESI = bufferEntrada)
    ; ---- precio ----
    mov intentosRestantes, MAX_INTENTOS
registrar_pedirPrecio:
    mov edx, OFFSET txtPedirPrecio
    call CapturarTexto
    VERIFICAR_ERROR registrar_precioMal
    call ConvertirPrecioACentavos
    test edx, edx
    jz registrar_precioBien
registrar_precioMal:
    IMPRIMIR_TEXTO msgPrecioInvalido
    dec intentosRestantes
    jnz registrar_pedirPrecio
    jmp registrar_cancelar
registrar_precioBien:
    mov [ebx+DESP_PRECIO], eax
    ; ---- existencia ----
    mov intentosRestantes, MAX_INTENTOS
registrar_pedirExistencia:
    mov edx, OFFSET txtPedirExistencia
    call CapturarTexto
    VERIFICAR_ERROR registrar_existenciaMal
    call ConvertirCadenaAEntero
    VERIFICAR_ERROR registrar_existenciaMal
    cmp eax, MAX_EXISTENCIA
    jbe registrar_existenciaBien
registrar_existenciaMal:
    IMPRIMIR_TEXTO msgExistenciaInvalida
    dec intentosRestantes
    jnz registrar_pedirExistencia
    jmp registrar_cancelar
registrar_existenciaBien:
    mov [ebx+DESP_EXISTENCIA], eax
    inc totalProductos                   ; hasta aqui se confirma el alta
    mov hayCambiosSinGuardar, 1
    mov edx, OFFSET msgProductoRegistrado
    jmp registrar_mensaje
registrar_cancelar:
    mov edx, OFFSET msgDemasiadosIntentos
registrar_mensaje:
    call WriteString
registrar_fin:
    ret
RegistrarProducto ENDP

; MostrarInventario: recorre el catalogo con ESI y un ciclo LOOP (ECX = productos)
MostrarInventario PROC USES ecx edx esi
    mov ecx, totalProductos
    test ecx, ecx
    jnz mostrarInventario_hay
    IMPRIMIR_TEXTO msgInventarioVacio
    jmp mostrarInventario_fin
mostrarInventario_hay:
    IMPRIMIR_TEXTO encabezadoInventario
    mov esi, OFFSET catalogoProductos
mostrarInventario_ciclo:
    call MostrarProducto
    add esi, TAM_REGISTRO
    loop mostrarInventario_ciclo
mostrarInventario_fin:
    ret
MostrarInventario ENDP

; BuscarProductoMenu: busca por codigo y muestra el registro
BuscarProductoMenu PROC USES edx esi
    call CapturarCodigoExistente
    VERIFICAR_ERROR buscarMenu_fin
    IMPRIMIR_TEXTO encabezadoInventario
    call MostrarProducto                 ; ESI = registro
buscarMenu_fin:
    ret
BuscarProductoMenu ENDP

; RecibirMercancia: suma unidades sin pasar de 100
RecibirMercancia PROC USES eax ebx ecx edx esi
    call CapturarCodigoExistente
    VERIFICAR_ERROR recibir_fin
    mov ebx, esi                         ; EBX = registro
    mov edx, OFFSET txtPedirUnidadesRecibidas
    call CapturarCantidad                ; EAX = cantidad
    VERIFICAR_ERROR recibir_fin
    mov ecx, MAX_EXISTENCIA
    sub ecx, [ebx+DESP_EXISTENCIA]       ; espacio libre
    cmp eax, ecx
    ja recibir_excede
    add [ebx+DESP_EXISTENCIA], eax
    mov hayCambiosSinGuardar, 1
    IMPRIMIR_TEXTO msgMercanciaRecibida
    mov eax, [ebx+DESP_EXISTENCIA]
    call MostrarEntero
    call Crlf
    jmp recibir_fin
recibir_excede:
    IMPRIMIR_TEXTO msgExcedeCapacidad
recibir_fin:
    ret
RecibirMercancia ENDP

; VenderProducto: calcula y valida TODO antes de modificar existencias e ingresos
;   ECX=cantidad, ESI=importe base, EDI=descuento, EBX=registro
VenderProducto PROC USES eax ebx ecx edx esi edi
    call CapturarCodigoExistente
    VERIFICAR_ERROR vender_fin
    mov ebx, esi
    mov edx, OFFSET txtPedirUnidadesVenta
    call CapturarCantidad                ; EAX = cantidad
    VERIFICAR_ERROR vender_fin
    cmp eax, [ebx+DESP_EXISTENCIA]
    ja vender_sinExistencias             ; mas de lo disponible
    mov ecx, eax
    mul DWORD PTR [ebx+DESP_PRECIO]      ; EDX:EAX = precio * cantidad
    jc vender_desbordamiento
    mov esi, eax                         ; importe base
    xor edi, edi                         ; descuento = 0
    cmp ecx, UNIDADES_PARA_DESCUENTO     ; REGLA: 10 o mas unidades
    jb vender_total
    mov eax, esi
    mov edi, PORCENTAJE_DESCUENTO
    mul edi                              ; base * 10
    jc vender_desbordamiento
    xor edx, edx
    mov edi, 100
    div edi                              ; / 100 (descarta fraccion de centavo)
    mov edi, eax
vender_total:
    mov eax, esi
    sub eax, edi                         ; EAX = total
    mov edx, ingresosSesion
    add edx, eax
    jc vender_desbordamiento             ; ingresos desbordados: no cambia nada
    mov ingresosSesion, edx              ; ---- venta aceptada: ahora si se actualiza ----
    sub [ebx+DESP_EXISTENCIA], ecx
    mov hayCambiosSinGuardar, 1
    push eax
    mov edx, OFFSET etiquetaImporteBase
    mov eax, esi
    call MostrarLineaImporte
    mov edx, OFFSET etiquetaDescuento
    mov eax, edi
    call MostrarLineaImporte
    mov edx, OFFSET etiquetaTotal
    pop eax
    call MostrarLineaImporte
    jmp vender_fin
vender_sinExistencias:
    IMPRIMIR_TEXTO msgExistenciasInsuficientes
    jmp vender_fin
vender_desbordamiento:
    IMPRIMIR_TEXTO msgDesbordamiento
vender_fin:
    ret
VenderProducto ENDP

; MostrarResumen: unidades, valor del inventario (precio x existencia) e ingresos
MostrarResumen PROC USES eax ebx ecx edx esi edi
    xor ebx, ebx                         ; unidades
    xor edi, edi                         ; valor en centavos
    mov esi, OFFSET catalogoProductos
    mov ecx, totalProductos
    test ecx, ecx
    jz resumen_mostrar
resumen_ciclo:
    mov eax, [esi+DESP_EXISTENCIA]
    add ebx, eax
    mul DWORD PTR [esi+DESP_PRECIO]
    jc resumen_desbordamiento
    add edi, eax
    jc resumen_desbordamiento
    add esi, TAM_REGISTRO
    loop resumen_ciclo
resumen_mostrar:
    IMPRIMIR_TEXTO tituloResumen
    IMPRIMIR_TEXTO etiquetaUnidades
    mov eax, ebx
    call MostrarEntero
    call Crlf
    mov edx, OFFSET etiquetaValorInventario
    mov eax, edi
    call MostrarLineaImporte
    mov edx, OFFSET etiquetaIngresos
    mov eax, ingresosSesion
    call MostrarLineaImporte
    jmp resumen_fin
resumen_desbordamiento:
    IMPRIMIR_TEXTO msgDesbordamiento
resumen_fin:
    ret
MostrarResumen ENDP

; ============================ ARCHIVOS ============================
; GuardarArchivo: arma el texto en bufferArchivo y lo escribe | Salida EDX=0 correcto, EDX=1 si falla
;   Cada llamada se comprueba: CreateOutputFile (handle valido), WriteToFile (bytes escritos = bytes
;   pedidos) y CloseFile (EAX distinto de 0).
GuardarArchivo PROC USES eax ebx ecx esi edi
    mov edi, OFFSET bufferArchivo
    mov esi, OFFSET encabezadoArchivo
    call CopiarCadena                    ; "INV1" (EDI queda sobre el 00h)
    AGREGAR_NUEVA_LINEA
    mov esi, OFFSET catalogoProductos    ; recorrido con ESI
    mov ecx, totalProductos
    test ecx, ecx
    jz guardar_escribir
guardar_ciclo:
    push esi                             ; guarda el inicio del registro
    call CopiarCadena                    ; codigo (ESI = inicio del registro)
    AGREGAR_BYTE ';'
    pop esi
    push esi
    add esi, DESP_NOMBRE
    call CopiarCadena                    ; nombre
    AGREGAR_BYTE ';'
    pop esi
    mov eax, [esi+DESP_PRECIO]
    call EnteroACadena                   ; precio en centavos
    AGREGAR_BYTE ';'
    mov eax, [esi+DESP_EXISTENCIA]
    call EnteroACadena                   ; existencia
    AGREGAR_NUEVA_LINEA
    add esi, TAM_REGISTRO
    dec ecx
    jnz guardar_ciclo
guardar_escribir:
    sub edi, OFFSET bufferArchivo        ; EDI = bytes a escribir
    mov bytesPorEscribir, edi
    mov edx, OFFSET nombreArchivo
    call CreateOutputFile                ; EAX = handle
    cmp eax, INVALID_HANDLE_VALUE
    je guardar_error
    mov archivoHandle, eax
    mov edx, OFFSET bufferArchivo
    mov ecx, bytesPorEscribir
    call WriteToFile                     ; EAX = bytes escritos
    mov bytesEscritos, eax
    mov eax, archivoHandle
    call CloseFile                       ; EAX distinto de 0 = cerrado
    test eax, eax
    jz guardar_error
    mov eax, bytesEscritos
    cmp eax, bytesPorEscribir            ; se escribieron todos?
    jne guardar_error
    mov hayCambiosSinGuardar, 0
    IMPRIMIR_TEXTO msgGuardadoCorrecto
    xor edx, edx
    jmp guardar_salida
guardar_error:
    IMPRIMIR_TEXTO msgErrorArchivo
    mov edx, 1
guardar_salida:
    ret
GuardarArchivo ENDP

; CargarArchivo: lee, valida en catalogoTemporal y SOLO si todo es correcto reemplaza el catalogo.
;   Los separadores ';', CR y LF se convierten en 00h: cada campo queda como cadena.
;   ReadFromFile devuelve en EAX los bytes LEIDOS (CF=1 si error); el buffer tiene TAM_BUFFER_ARCHIVO
;   bytes, se piden TAM-1 para reservar un byte al 00h que se escribe en bufferArchivo[bytes leidos].
CargarArchivo PROC USES eax ebx ecx edx esi edi
    cmp hayCambiosSinGuardar, 0
    je cargar_abrirArchivo
    mov edx, OFFSET txtPreguntaConfirmarCarga
    call CapturarTexto
    mov al, [bufferEntrada]
    or al, 20h
    cmp al, 's'
    jne cargar_salida
cargar_abrirArchivo:
    mov edx, OFFSET nombreArchivo
    call OpenInputFile                   ; EAX = handle
    cmp eax, INVALID_HANDLE_VALUE
    jne cargar_leer
    mov edx, OFFSET msgArchivoAusente
    jmp cargar_mensaje
cargar_leer:
    mov archivoHandle, eax
    mov edx, OFFSET bufferArchivo
    mov ecx, TAM_BUFFER_ARCHIVO-1        ; capacidad (deja un byte para el 00h)
    call ReadFromFile                    ; EAX = bytes leidos, CF = error
    mov bytesLeidos, eax                 ; MOV no cambia CF
    jc cargar_errorLectura
    mov eax, archivoHandle
    call CloseFile
    test eax, eax
    jz cargar_errorArchivo
    mov ebx, bytesLeidos
    test ebx, ebx
    jz cargar_invalido                   ; archivo vacio
    cmp ebx, TAM_BUFFER_ARCHIVO-1
    jae cargar_invalido                  ; no cupo completo
    mov BYTE PTR [bufferArchivo+ebx], 0  ; 00h justo despues del ultimo byte leido
    mov eax, OFFSET bufferArchivo
    add eax, ebx
    mov finDatosLeidos, eax              ; fin de los datos leidos
    mov esi, OFFSET bufferArchivo
    mov ecx, ebx
cargar_separadores:                      ; ';' CR LF -> 00h
    mov al, [esi]
    cmp al, ';'
    je cargar_ponerCero
    cmp al, 0Dh
    je cargar_ponerCero
    cmp al, 0Ah
    jne cargar_siguiente
cargar_ponerCero:
    mov BYTE PTR [esi], 0
cargar_siguiente:
    inc esi
    loop cargar_separadores
    mov esi, OFFSET bufferArchivo
    mov edi, OFFSET encabezadoArchivo
    call CadenasIguales                  ; encabezado "INV1"
    jne cargar_invalido
    call AvanzarAlSiguienteCampo
    call SaltarSaltoDeLinea
    xor ebx, ebx                         ; EBX = productos leidos
cargar_registros:
    cmp esi, finDatosLeidos
    jae cargar_ok                        ; ya no hay mas datos
    cmp ebx, MAX_PRODUCTOS
    jae cargar_invalido                  ; mas de 10 productos
    mov eax, ebx
    imul eax, eax, TAM_REGISTRO
    add eax, OFFSET catalogoTemporal
    mov ptrRegistroTemporal, eax         ; registro temporal donde se guarda este producto
    call ValidarCodigo                   ; ESI = campo codigo
    VERIFICAR_ERROR cargar_invalido
    push esi
    mov edi, esi
    mov esi, OFFSET catalogoTemporal
    mov ecx, ebx
    call BuscarProductoPorCodigo         ; duplicado entre los ya leidos?
    mov eax, esi
    pop esi
    test eax, eax
    jnz cargar_invalido
    mov edi, ptrRegistroTemporal
    call CopiarCadena                    ; codigo
    call AvanzarAlSiguienteCampo
    call ValidarNombre
    VERIFICAR_ERROR cargar_invalido
    mov edi, ptrRegistroTemporal
    add edi, DESP_NOMBRE
    call CopiarCadena                    ; nombre
    call AvanzarAlSiguienteCampo
    call ConvertirCadenaAEntero          ; precio en centavos
    VERIFICAR_ERROR cargar_invalido
    cmp eax, 1
    jb cargar_invalido
    cmp eax, PRECIO_MAXIMO
    ja cargar_invalido
    mov edi, ptrRegistroTemporal
    mov [edi+DESP_PRECIO], eax
    call AvanzarAlSiguienteCampo
    call ConvertirCadenaAEntero          ; existencia
    VERIFICAR_ERROR cargar_invalido
    cmp eax, MAX_EXISTENCIA
    ja cargar_invalido
    mov [edi+DESP_EXISTENCIA], eax
    call AvanzarAlSiguienteCampo
    call SaltarSaltoDeLinea
    inc ebx
    jmp cargar_registros
cargar_ok:                               ; todo valido: reemplaza el catalogo
    mov esi, OFFSET catalogoTemporal
    mov edi, OFFSET catalogoProductos
    mov ecx, MAX_PRODUCTOS*TAM_REGISTRO/4
cargar_copiar:                           ; copia DWORD por DWORD
    mov eax, [esi]
    mov [edi], eax
    add esi, 4
    add edi, 4
    loop cargar_copiar
    mov totalProductos, ebx
    mov hayCambiosSinGuardar, 0
    IMPRIMIR_TEXTO msgCargaCorrecta
    mov eax, ebx
    call MostrarEntero
    call Crlf
    jmp cargar_salida
cargar_errorLectura:
    mov eax, archivoHandle
    call CloseFile                       ; aun con error se cierra el archivo
cargar_errorArchivo:
    mov edx, OFFSET msgErrorArchivo
    jmp cargar_mensaje
cargar_invalido:
    mov edx, OFFSET msgArchivoInvalido
cargar_mensaje:
    call WriteString
cargar_salida:
    ret
CargarArchivo ENDP

END main