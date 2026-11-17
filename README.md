# Sistema de ventas e inventario

Proyecto de consola en **ensamblador MASM x86 de 32 bits**, con la biblioteca **Irvine32**.

## Cambios de la Unidad 3

Se reorganizó el código de la versión anterior para hacerlo más legible y evitar repetir instrucciones:

- Se agruparon tareas en procedimientos.
- Se agregaron macros para reutilizar instrucciones frecuentes.
- Se incorporó `USES` para preservar los registros utilizados por los procedimientos.
- Se mantuvieron las opciones del sistema, sus validaciones y la regla de descuento.

Estos cambios facilitan la lectura, el mantenimiento y la reutilización del código.

## Funciones

Registrar y buscar productos, consultar inventario, recibir mercancía, realizar ventas, mostrar un resumen y guardar o cargar los datos en `inventario.txt`. Las ventas de **10 unidades o más** reciben un descuento del **10 %**.

## Cómo abrir y ejecutar

1. Abre `main.asm` en Visual Studio o en un editor de texto.
2. Para compilarlo, utiliza **x86 Native Tools Command Prompt for Visual Studio** y asegúrate de tener MASM y la biblioteca Irvine32 instalados.
3. Desde la carpeta del proyecto, ejecuta los siguientes comandos (ajusta `C:\Irvine` a la ubicación de Irvine32):

```bat
ml /c /coff /I"C:\Irvine" main_unidad3_actualizado_corregido.asm
link /SUBSYSTEM:CONSOLE /MACHINE:X86 /LIBPATH:"C:\Irvine" main_unidad3_actualizado_corregido.obj Irvine32.lib kernel32.lib user32.lib
main_unidad3_actualizado_corregido.exe
```

El programa utiliza `inventario.txt` en el directorio desde el que se ejecuta. Si no existe, puede comenzar con el inventario vacío.

## Archivos

- `main.asm`: código fuente del sistema.
- `.gitignore`: excluye archivos generados y el inventario local.
